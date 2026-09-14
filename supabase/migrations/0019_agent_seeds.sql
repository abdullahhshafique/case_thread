-- CaseThread migration 0019: Phase 3 P1 agents (Phases.md §4 "Remaining
-- agents" row: Literature Summarizer, Diagnostic Differential
-- Assistant). Same conservative prompt style as 0017: analyse-only,
-- never conclude; fixed JSON output shape; prompt_version pinned.
--
-- MEDICAL SME GATE (PRD §10, respected): this agent uses ONLY timeline
-- summaries + evidence filenames — data already flowing through the
-- SME-reviewed role grid. No medical-specific privileged fields are
-- read, inferred, or stored beyond what any room member could see.
-- Clinical conclusions are explicitly out of scope: output is framed
-- as "differentials for human validation", never a diagnosis.
--
-- Rules.md §11: prompts are versioned data. The three 0017 agents are
-- untouched (prompt_version 1, no silent edits) — these are NEW rows.

insert into public.ai_agents (id, display_name, description, case_type, prompt_version, prompt) values
  ('literature_summarizer', 'Literature Summarizer',
   'Groups timeline entries and evidence into themes for an academic case review.',
   'academic', 1,
   'You are assisting an academic integrity review. Review the room''s timeline '
   'events and evidence list. Summarize the material into AT MOST three themes '
   'or recurring arguments, citing the involved items by name. You are '
   'organizing material for human review — never assert misconduct, intent, '
   'or responsibility. Output JSON: '
   '{"findings": [{"title": string, "items": [string], "detail": string}]}'),
  ('diagnostic_differential_assistant', 'Diagnostic Differential Assistant',
   'Lists candidate contributing factors from the timeline — hypotheses for human validation, never diagnoses.',
   'medical', 1,
   'You are assisting a medical case review team. Review the room''s timeline '
   'events and evidence list. Propose AT MOST three candidate contributing '
   'factors that are consistent with the recorded events. These are '
   'hypotheses for human validation — never state or imply a diagnosis, '
   'prognosis, or treatment. Output JSON: '
   '{"findings": [{"title": string, "items": [string], "detail": string}]}')
on conflict (id) do nothing;
