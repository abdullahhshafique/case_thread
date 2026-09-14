// AI Adapter Layer contract tests (Architecture.md §12, Rules.md §7):
// no live API calls — vendor responses are fixtures, fetch is stubbed.
// These machine-prove the Phase-3 DoD: every provider parses correctly
// behind ONE interface, and swapping providers is config-only.

import { callProvider } from "./index.ts";
import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Stub fetch: capture the outgoing request, return the fixture.
function stubFetch(fixture: unknown, capture: { body?: unknown; url?: string }) {
  globalThis.fetch = (async (input: any, init?: any) => {
    capture.url = typeof input === "string" ? input : input.url;
    capture.body = init?.body ? JSON.parse(init.body) : undefined;
    return new Response(JSON.stringify(fixture), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

const originalFetch = globalThis.fetch;

Deno.test("mock provider is deterministic and derives findings from context", async () => {
  const result = await callProvider(
    "mock",
    "system prompt",
    "[event] Witness statement taken\n[event] Contract signed\n[ai-suggestion: untrusted] prior finding",
  );
  assertEquals(result.provider, "mock");
  assertEquals(result.model, "deterministic-v1");
  assertEquals(result.findings.length, 1);
  assertEquals(result.findings[0].items?.length, 2); // events only, not ai-suggestion
  assertEquals(result.findings[0].items?.[0], "Witness statement taken");
});

Deno.test("mock provider returns no findings for empty context", async () => {
  const result = await callProvider("mock", "p", "");
  assertEquals(result.findings, []);
});

Deno.test("grok provider sends chat-completions shape and parses findings", async () => {
  Deno.env.set("GROK_API_KEY", "test-key");
  const capture: { body?: any; url?: string } = {};
  stubFetch(
    { choices: [{ message: { content: '{"findings": [{"title": "T1", "detail": "d"}]}' } }] },
    capture,
  );
  try {
    const result = await callProvider("grok", "sys", "ctx");
    assertEquals(result.provider, "grok");
    assertEquals(result.model, "grok-3-mini");
    assertEquals(result.findings[0].title, "T1");
    assertEquals(capture.url, "https://api.x.ai/v1/chat/completions");
    assertEquals(capture.body.model, "grok-3-mini");
    assertEquals(capture.body.messages[0].role, "system");
    assertEquals(capture.body.messages[0].content, "sys");
    assertEquals(capture.body.messages[1].content, "ctx");
  } finally {
    Deno.env.delete("GROK_API_KEY");
    globalThis.fetch = originalFetch;
  }
});

Deno.test("grok model is configurable via env", async () => {
  Deno.env.set("GROK_API_KEY", "test-key");
  Deno.env.set("GROK_MODEL", "grok-4-fast");
  const capture: { body?: any } = {};
  stubFetch(
    { choices: [{ message: { content: '{"findings": []}' } }] },
    capture,
  );
  try {
    const result = await callProvider("grok", "sys", "ctx");
    assertEquals(result.model, "grok-4-fast");
    assertEquals(capture.body.model, "grok-4-fast");
  } finally {
    Deno.env.delete("GROK_API_KEY");
    Deno.env.delete("GROK_MODEL");
    globalThis.fetch = originalFetch;
  }
});

Deno.test("openai provider requests json_object and parses findings", async () => {
  Deno.env.set("OPENAI_API_KEY", "test-key");
  const capture: { body?: any; url?: string } = {};
  stubFetch(
    { choices: [{ message: { content: '{"findings": [{"title": "O1"}]}' } }] },
    capture,
  );
  try {
    const result = await callProvider("openai", "sys", "ctx");
    assertEquals(result.provider, "openai");
    assertEquals(result.model, "gpt-4o-mini");
    assertEquals(result.findings[0].title, "O1");
    assertEquals(capture.url, "https://api.openai.com/v1/chat/completions");
    assertEquals(capture.body.response_format.type, "json_object");
  } finally {
    Deno.env.delete("OPENAI_API_KEY");
    globalThis.fetch = originalFetch;
  }
});

Deno.test("anthropic provider parses first JSON object from text", async () => {
  Deno.env.set("ANTHROPIC_API_KEY", "test-key");
  const capture: { body?: any; url?: string } = {};
  stubFetch(
    {
      content: [{
        text:
          'Here is my analysis: {"findings": [{"title": "A1", "items": ["x"], "detail": "y"}]} done.',
      }],
    },
    capture,
  );
  try {
    const result = await callProvider("anthropic", "sys", "ctx");
    assertEquals(result.provider, "anthropic");
    assertEquals(result.model, "claude-sonnet-4-20250514");
    assertEquals(result.findings[0].title, "A1");
    assertEquals(capture.url, "https://api.anthropic.com/v1/messages");
    assertEquals(capture.body.system, "sys");
  } finally {
    Deno.env.delete("ANTHROPIC_API_KEY");
    globalThis.fetch = originalFetch;
  }
});

Deno.test("gemini provider requests json mime type and parses parts", async () => {
  Deno.env.set("GEMINI_API_KEY", "test-key");
  const capture: { body?: any; url?: string } = {};
  stubFetch(
    {
      candidates: [{
        content: { parts: [{ text: '{"findings": [{"title": "G1"}]}' }] },
      }],
    },
    capture,
  );
  try {
    const result = await callProvider("gemini", "sys", "ctx");
    assertEquals(result.provider, "gemini");
    assertEquals(result.model, "gemini-2.0-flash");
    assertEquals(result.findings[0].title, "G1");
    assertEquals(
      capture.url,
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=test-key",
    );
    assertEquals(capture.body.generation_config.response_mime_type, "application/json");
  } finally {
    Deno.env.delete("GEMINI_API_KEY");
    globalThis.fetch = originalFetch;
  }
});

Deno.test("missing provider key throws a typed error", async () => {
  Deno.env.delete("GROK_API_KEY");
  await assertRejects(
    () => callProvider("grok", "sys", "ctx"),
    Error,
    "GROK_API_KEY not configured",
  );
});

Deno.test("unknown provider is rejected", async () => {
  await assertRejects(
    () => callProvider("skynet", "sys", "ctx"),
    Error,
    "Unknown AI provider: skynet",
  );
});
