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
// PROVIDER DECISION (PRD §10, resolved 2026-09-13): GROK is the
// production default. The mock provider remains for CI/dev runs
// without keys. Swapping to Claude/GPT/Gemini stays a config flip.
//
// Two modes (0018 workflow builder):
//   { agent_id, room_id }          — single agent (original behavior)
//   { workflow_id }                — chained run: steps execute
//     sequentially, each step's findings land as their OWN pending
//     ai_suggestions row (human-in-the-loop preserved per step —
//     Rules.md §11), and an ai_workflow_runs row tracks progress.
//
// Agents never write to timeline/audit — only review_suggestion()
// (called by a Lead-tier human) can promote a finding. (Rules.md §11.)

// @ts-nocheck — Deno runtime; no local type-checking in CI.
// deno-lint-ignore-file

export interface Finding {
  title: string;
  items?: string[];
  detail?: string;
}

export interface ProviderResult {
  findings: Finding[];
  provider: string;
  model: string;
}

// ---------------------------------------------------------------------------
// Provider adapter: one interface, N implementations. Adding a provider
// = one new case here; core logic never changes (Phase-3 DoD).
// Exported for contract tests (index.test.ts) — stub fetch, assert
// request shape + response parsing; no live API calls (Rules.md §7).
// ---------------------------------------------------------------------------
export async function callProvider(
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

// ---------------------------------------------------------------------------
// Shared helpers (used by both single-agent and workflow modes).
// ---------------------------------------------------------------------------

// Room context AS THE USER: only what they may see — redacted
// timeline (v_timeline strips privileged fields) + vault metadata.
// Prior-step findings are appended in workflow mode, clearly marked
// as UNTRUSTED AI output (Architecture.md §9: all AI output is
// unprivileged — never merged into the trusted context).
async function gatherRoomContext(
  userClient: any,
  roomId: string,
  priorFindings: string[] = [],
): Promise<string> {
  const [timeline, evidence] = await Promise.all([
    userClient.from("v_timeline").select("payload").eq("room_id", roomId)
      .order("occurred_at", { ascending: false }).limit(50),
    userClient.from("evidence_items").select("filename, version, uploaded_at")
      .eq("room_id", roomId).limit(50),
  ]);

  return [
    ...((timeline.data ?? []).map((t: { payload: { summary?: string } }) =>
      `[event] ${t.payload?.summary ?? ""}`
    )),
    ...((evidence.data ?? []).map((e: { filename: string; version: number }) =>
      `[evidence] ${e.filename} (v${e.version})`
    )),
    ...priorFindings.map((f) => `[ai-suggestion: untrusted] ${f}`),
  ].join("\n");
}

// Service-role insert of ONE pending suggestion (the only thing an
// agent run may ever write — Rules.md §11). Returns the id, or null
// when the provider found nothing worth flagging.
async function insertPendingSuggestion(
  serviceClient: any,
  roomId: string,
  agent: { id: string; prompt_version: number },
  result: ProviderResult,
  inputRef: string,
): Promise<string | null> {
  if (result.findings.length === 0) return null;
  const { data: suggestion, error: insertErr } = await serviceClient
    .from("ai_suggestions")
    .insert({
      room_id: roomId,
      agent_type: agent.id,
      input_ref: inputRef,
      output: {
        title: result.findings[0].title,
        detail: result.findings[0].detail ?? "",
        items: result.findings[0].items ?? [],
        findings: result.findings,
        provider: result.provider,
        model: result.model,
      },
    })
    .select("id")
    .single();
  if (insertErr) throw new Error(`insert_failed: ${insertErr.message}`);
  return suggestion.id;
}

async function requireEditCasePermission(
  userClient: any,
  roomId: string,
): Promise<void> {
  const { data: allowed } = await userClient.rpc("user_room_permission", {
    target_room: roomId,
    permission_key: "edit_case",
  });
  if (!allowed) {
    throw new HttpError(
      403,
      { code: "forbidden", message: "Your role can't run agents in this room." },
    );
  }
}

class HttpError extends Error {
  constructor(
    public status: number,
    public body: Record<string, unknown>,
  ) {
    super(JSON.stringify(body));
  }
}

// ---------------------------------------------------------------------------
// Mode 1 — single agent (original behavior, unchanged contract).
// ---------------------------------------------------------------------------
async function runSingleAgent(
  userClient: any,
  serviceClient: any,
  userId: string,
  agentId: string,
  roomId: string,
): Promise<Response> {
  await requireEditCasePermission(userClient, roomId);

  const { data: agent, error: agentErr } = await userClient
    .from("ai_agents")
    .select("id, display_name, prompt, prompt_version")
    .eq("id", agentId)
    .eq("is_active", true)
    .maybeSingle();
  if (agentErr || !agent) {
    return Response.json({ code: "unknown_agent" }, { status: 404 });
  }

  const context = await gatherRoomContext(userClient, roomId);

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

  const suggestionId = await insertPendingSuggestion(
    serviceClient,
    roomId,
    agent,
    result,
    `prompt_v${agent.prompt_version}:${result.provider}:${result.model}`,
  );

  if (!suggestionId) {
    return Response.json({ status: "no_findings", provider: result.provider });
  }

  // Structured log (Rules.md §6): no evidence content, no PII.
  console.log(
    JSON.stringify({
      code: "agent_run",
      agent_id: agent.id,
      room_id: roomId,
      actor: userId,
      provider: result.provider,
      findings: result.findings.length,
    }),
  );

  return Response.json({
    status: "suggestion_created",
    suggestion_id: suggestionId,
    provider: result.provider,
  });
}

// ---------------------------------------------------------------------------
// Mode 2 — workflow chain (0018 builder). Steps run sequentially; each
// step's findings become their own PENDING suggestion (never auto-
// promoted), and later steps see earlier steps' findings ONLY as
// clearly-marked untrusted context lines.
// ---------------------------------------------------------------------------
async function runWorkflow(
  userClient: any,
  serviceClient: any,
  userId: string,
  workflowId: string,
): Promise<Response> {
  // Load the workflow AS THE USER (member visibility via RLS).
  const { data: workflow, error: wfErr } = await userClient
    .from("ai_workflows")
    .select("id, room_id, name, steps")
    .eq("id", workflowId)
    .maybeSingle();
  if (wfErr || !workflow) {
    return Response.json({ code: "unknown_workflow" }, { status: 404 });
  }
  const roomId = workflow.room_id as string;
  const stepIds = (workflow.steps ?? []) as string[];
  if (stepIds.length === 0) {
    return Response.json({ code: "empty_workflow" }, { status: 400 });
  }

  await requireEditCasePermission(userClient, roomId);

  // Room case type — step agents must match it (or be agnostic).
  const { data: room } = await userClient
    .from("case_rooms")
    .select("case_type")
    .eq("id", roomId)
    .maybeSingle();
  const roomCaseType = room?.case_type as string | undefined;

  // Resolve + validate every step agent BEFORE starting: active and
  // case-type applicable. A bad step fails the run up front.
  const agents: Record<string, { id: string; prompt: string; prompt_version: number }> = {};
  for (const stepId of stepIds) {
    const { data: agent } = await userClient
      .from("ai_agents")
      .select("id, case_type, prompt, prompt_version, is_active")
      .eq("id", stepId)
      .maybeSingle();
    if (!agent || agent.is_active === false) {
      return Response.json(
        { code: "unknown_agent", agent_id: stepId },
        { status: 404 },
      );
    }
    if (agent.case_type && agent.case_type !== roomCaseType) {
      return Response.json(
        { code: "agent_not_applicable", agent_id: stepId },
        { status: 400 },
      );
    }
    agents[stepId] = agent;
  }

  // Run row (service role): running → completed/failed.
  const { data: run, error: runErr } = await serviceClient
    .from("ai_workflow_runs")
    .insert({
      workflow_id: workflowId,
      room_id: roomId,
      status: "running",
      steps_total: stepIds.length,
      started_by: userId,
    })
    .select("id")
    .single();
  if (runErr || !run) {
    return Response.json({ code: "run_insert_failed" }, { status: 500 });
  }

  const provider = Deno.env.get("AI_PROVIDER") ?? "mock";
  const suggestionIds: string[] = [];
  const priorFindings: string[] = [];

  try {
    for (let i = 0; i < stepIds.length; i++) {
      const agent = agents[stepIds[i]];
      const context = await gatherRoomContext(userClient, roomId, priorFindings);
      const result = await callProvider(provider, agent.prompt, context);

      const suggestionId = await insertPendingSuggestion(
        serviceClient,
        roomId,
        agent,
        result,
        `prompt_v${agent.prompt_version}:${result.provider}:${result.model}`
          + `:workflow=${workflowId}:step=${i + 1}`,
      );

      if (suggestionId) {
        suggestionIds.push(suggestionId);
        const top = result.findings[0];
        priorFindings.push(
          `${top.title} — ${(top.detail ?? "").slice(0, 200)}`,
        );
      }

      await serviceClient
        .from("ai_workflow_runs")
        .update({
          steps_done: i + 1,
          suggestion_ids: suggestionIds,
        })
        .eq("id", run.id);
    }

    await serviceClient
      .from("ai_workflow_runs")
      .update({ status: "completed", finished_at: new Date().toISOString() })
      .eq("id", run.id);

    // Structured log (Rules.md §6): no evidence content, no PII.
    console.log(
      JSON.stringify({
        code: "workflow_run",
        workflow_id: workflowId,
        run_id: run.id,
        room_id: roomId,
        actor: userId,
        provider,
        steps: stepIds.length,
        suggestions: suggestionIds.length,
      }),
    );

    return Response.json({
      status: "workflow_completed",
      run_id: run.id,
      suggestions_created: suggestionIds.length,
      suggestion_ids: suggestionIds,
      provider,
    });
  } catch (err) {
    // Completed steps' suggestions REMAIN pending + individually
    // reviewable; only the run is marked failed.
    await serviceClient
      .from("ai_workflow_runs")
      .update({
        status: "failed",
        error: String(err).slice(0, 500),
        finished_at: new Date().toISOString(),
      })
      .eq("id", run.id);
    return Response.json(
      {
        status: "workflow_failed",
        run_id: run.id,
        suggestions_created: suggestionIds.length,
        provider,
        message: String(err),
      },
      { status: 502 },
    );
  }
}

// import.meta.main is false when index.test.ts imports this module —
// the server only starts when executed directly (deno deploy / serve).
if (import.meta.main) {
  Deno.serve(async (req) => {
    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );

    // Two clients: one AS THE USER (permission checks + redaction-aware
    // data gathering — never trust the function with more than the user
    // could read), one service-role (the only path that may write
    // ai_suggestions / ai_workflow_runs).
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

    let body: { agent_id?: string; room_id?: string; workflow_id?: string };
    try {
      body = await req.json();
    } catch {
      return Response.json({ code: "bad_request" }, { status: 400 });
    }
    const { agent_id: agentId, room_id: roomId, workflow_id: workflowId } = body;

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    try {
      if (workflowId) {
        return await runWorkflow(userClient, serviceClient, user.id, workflowId);
      }
      if (agentId && roomId) {
        return await runSingleAgent(userClient, serviceClient, user.id, agentId, roomId);
      }
      return Response.json({ code: "bad_request" }, { status: 400 });
    } catch (err) {
      if (err instanceof HttpError) {
        return Response.json(err.body, { status: err.status });
      }
      return Response.json(
        { code: "internal_error", message: String(err) },
        { status: 500 },
      );
    }
  });
}
