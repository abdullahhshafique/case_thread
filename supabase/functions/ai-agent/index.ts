// CaseThread Edge Function: ai-agent (Phase 3, Phases.md §4).
//
// The AI Adapter Layer (Architecture.md §4): ONE entrypoint, provider
// normalized behind an interface. Provider selection is config
// (AI_PROVIDER env), with a deterministic mock so the full pipeline
// is verifiable without any vendor key. Secrets (provider API keys)
// live ONLY in Edge Function env — never the client (Rules.md §10).
//
// Flow (Architecture.md §7):
//   user JWT → permission check (edit_case) → gather room data
//   (scoped by the USER, redaction-aware views) → prompt (versioned,
//   from ai_agents config) → provider call → insert ai_suggestions
//   (service role, status=pending) → realtime pushes the pending
//   suggestion to the room (amber, per Design.md §1).
//
// Agents never write to timeline/audit — only review_suggestion()
// (called by a Lead-tier human) can promote a finding. (Rules.md §11.)

// @ts-nocheck — Deno runtime; no local type-checking in CI.
// deno-lint-ignore-file

interface Finding {
  title: string;
  items?: string[];
  detail?: string;
}

interface ProviderResult {
  findings: Finding[];
  provider: string;
  model: string;
}

// ---------------------------------------------------------------------------
// Provider adapter: one interface, N implementations. Adding a provider
// = one new case here; core logic never changes (Phase-3 DoD).
// ---------------------------------------------------------------------------
async function callProvider(
  provider: string,
  prompt: string,
  context: string,
): Promise<ProviderResult> {
  switch (provider) {
    case "mock": {
      // Deterministic: derives findings from the context so the
      // pipeline is end-to-end testable without vendor keys.
      const events = context
        .split("\n")
        .filter((l) => l.startsWith("[event]"))
        .slice(0, 3);
      return {
        provider: "mock",
        model: "deterministic-v1",
        findings: events.length > 0
          ? [{
            title: "Possible timeline inconsistency",
            items: events.map((e) => e.replace("[event] ", "").slice(0, 40)),
            detail:
              "Mock provider: review these timeline entries for possible contradictions. (Deterministic mock output — configure a real provider via AI_PROVIDER.)",
          }]
          : [],
      };
    }
    case "openai": {
      const key = Deno.env.get("OPENAI_API_KEY");
      if (!key) throw new Error("OPENAI_API_KEY not configured");
      const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: prompt },
            { role: "user", content: context },
          ],
          response_format: { type: "json_object" },
        }),
      });
      if (!res.ok) throw new Error(`openai: ${res.status} ${await res.text()}`);
      const data = await res.json();
      return { provider: "openai", model, findings: JSON.parse(data.choices[0].message.content).findings ?? [] };
    }
    case "anthropic": {
      const key = Deno.env.get("ANTHROPIC_API_KEY");
      if (!key) throw new Error("ANTHROPIC_API_KEY not configured");
      const model = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-20250514";
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": key,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model,
          max_tokens: 1024,
          system: prompt,
          messages: [{ role: "user", content: context }],
        }),
      });
      if (!res.ok) throw new Error(`anthropic: ${res.status} ${await res.text()}`);
      const data = await res.json();
      // Extract first JSON object from the text response.
      const match = data.content[0]?.text?.match(/\{[\s\S]*\}/);
      return { provider: "anthropic", model, findings: match ? (JSON.parse(match[0]).findings ?? []) : [] };
    }
    case "gemini": {
      const key = Deno.env.get("GEMINI_API_KEY");
      if (!key) throw new Error("GEMINI_API_KEY not configured");
      const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            system_instruction: { parts: [{ text: prompt }] },
            contents: [{ parts: [{ text: context }] }],
            generation_config: { response_mime_type: "application/json" },
          }),
        },
      );
      if (!res.ok) throw new Error(`gemini: ${res.status} ${await res.text()}`);
      const data = await res.json();
      const text = data.candidates[0]?.content?.parts[0]?.text ?? "{}";
      return { provider: "gemini", model, findings: JSON.parse(text).findings ?? [] };
    }
    case "grok": {
      const key = Deno.env.get("GROK_API_KEY");
      if (!key) throw new Error("GROK_API_KEY not configured");
      const model = Deno.env.get("GROK_MODEL") ?? "grok-3-mini";
      const res = await fetch("https://api.x.ai/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: prompt },
            { role: "user", content: context },
          ],
        }),
      });
      if (!res.ok) throw new Error(`grok: ${res.status} ${await res.text()}`);
      const data = await res.json();
      const match = data.choices[0]?.message?.content?.match(/\{[\s\S]*\}/);
      return { provider: "grok", model, findings: match ? (JSON.parse(match[0]).findings ?? []) : [] };
    }
    default:
      throw new Error(`Unknown AI provider: ${provider}`);
  }
}

Deno.serve(async (req) => {
  const { createClient } = await import(
    "https://esm.sh/@supabase/supabase-js@2"
  );

  // Two clients: one AS THE USER (permission checks + redaction-aware
  // data gathering — never trust the function with more than the user
  // could read), one service-role (the only path that may write
  // ai_suggestions).
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const {
    data: { user },
  } = await userClient.auth.getUser();
  if (!user) {
    return Response.json({ code: "unauthorized" }, { status: 401 });
  }

  let body: { agent_id?: string; room_id?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ code: "bad_request" }, { status: 400 });
  }
  const { agent_id: agentId, room_id: roomId } = body;
  if (!agentId || !roomId) {
    return Response.json({ code: "bad_request" }, { status: 400 });
  }

  // 1. Permission: the CALLER's role must hold edit_case to trigger
  //    agents (checked with the user's JWT through the DB helper).
  const { data: allowed } = await userClient.rpc("user_room_permission", {
    target_room: roomId,
    permission_key: "edit_case",
  });
  if (!allowed) {
    return Response.json(
      { code: "forbidden", message: "Your role can't run agents in this room." },
      { status: 403 },
    );
  }

  // 2. Load the agent config (versioned prompt — Rules.md §11).
  const { data: agent, error: agentErr } = await userClient
    .from("ai_agents")
    .select("id, display_name, prompt, prompt_version")
    .eq("id", agentId)
    .eq("is_active", true)
    .maybeSingle();
  if (agentErr || !agent) {
    return Response.json({ code: "unknown_agent" }, { status: 404 });
  }

  // 3. Gather room context AS THE USER: only what they may see —
  //    redacted timeline (v_timeline strips privileged fields), vault.
  const [timeline, evidence] = await Promise.all([
    userClient.from("v_timeline").select("payload").eq("room_id", roomId)
      .order("occurred_at", { ascending: false }).limit(50),
    userClient.from("evidence_items").select("filename, version, uploaded_at")
      .eq("room_id", roomId).limit(50),
  ]);

  const context = [
    ...((timeline.data ?? []).map((t: { payload: { summary?: string } }) =>
      `[event] ${t.payload?.summary ?? ""}`
    )),
    ...((evidence.data ?? []).map((e: { filename: string; version: number }) =>
      `[evidence] ${e.filename} (v${e.version})`
    )),
  ].join("\n");

  // 4. Call the configured provider (default: mock — swap = env var).
  const provider = Deno.env.get("AI_PROVIDER") ?? "mock";
  let result: ProviderResult;
  try {
    result = await callProvider(provider, agent.prompt, context);
  } catch (err) {
    // Typed error; core room functionality unaffected (PRD §9).
    return Response.json(
      { code: "provider_error", message: String(err) },
      { status: 502 },
    );
  }

  if (result.findings.length === 0) {
    return Response.json({ status: "no_findings", provider: result.provider });
  }

  // 5. Service-role insert: agents write ONLY ai_suggestions (pending).
  const serviceClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: suggestion, error: insertErr } = await serviceClient
    .from("ai_suggestions")
    .insert({
      room_id: roomId,
      agent_type: agent.id,
      input_ref: `prompt_v${agent.prompt_version}:${result.provider}:${result.model}`,
      output: {
        title: result.findings[0].title,
        detail: result.findings[0].detail ?? "",
        items: result.findings[0].items ?? [],
        findings: result.findings,
        provider: result.provider,
        model: result.model,
      },
    })
    .select("id, status")
    .single();

  if (insertErr) {
    return Response.json({ code: "insert_failed" }, { status: 500 });
  }

  // Structured log (Rules.md §6): no evidence content, no PII.
  console.log(
    JSON.stringify({
      code: "agent_run",
      agent_id: agent.id,
      room_id: roomId,
      actor: user.id,
      provider: result.provider,
      findings: result.findings.length,
    }),
  );

  return Response.json({
    status: "suggestion_created",
    suggestion_id: suggestion.id,
    provider: result.provider,
  });
});
