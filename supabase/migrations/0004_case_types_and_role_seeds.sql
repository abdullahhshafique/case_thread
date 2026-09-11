-- CaseThread migration 0004: case types + role definitions (Phase 1 scope).
--
-- DRAFT PERMISSION MATRIX — pending SME review per ExecutionPlan.md §1 P1.
-- The full grid and its rationale live in docs/permission-matrix-draft.md;
-- this seed data must stay in sync with that document (change both together).
--
-- Permission keys (PRD §6.3):
--   view_case, edit_case, upload_evidence, comment,
--   approve_ai_findings, manage_members, export_reports, view_privileged

-- ---------------------------------------------------------------------------
-- Case types (Phase 1: Legal/Investigative + Academic per PRD §5).
-- Corporate/Medical/Technical arrive in Phase 2 as new rows only.
-- ---------------------------------------------------------------------------
insert into public.case_types (id, display_name, description) values
  ('legal',
   'Legal / Investigative',
   'Legal matters, fraud investigations, and litigation support cases.'),
  ('academic',
   'Academic',
   'Academic integrity cases, misconduct hearings, and case-study coursework.');

-- ---------------------------------------------------------------------------
-- Legal / Investigative roles (named set from PRD §6.3).
-- Lead-tier = may accept/edit/dismiss AI findings (PRD P1 stories).
-- ---------------------------------------------------------------------------
insert into public.roles (id, case_type, display_name, is_lead_tier, permissions) values
  ('lead_investigator', 'legal', 'Lead Investigator', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": true,
    "export_reports": true,   "view_privileged": true
  }'),
  ('analyst', 'legal', 'Analyst', false, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('legal_counsel', 'legal', 'Legal Counsel', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": false,
    "export_reports": true,   "view_privileged": true
  }'),
  ('reviewer', 'legal', 'Reviewer', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": false, "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('observer', 'legal', 'Observer', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": false, "comment": false,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('client', 'legal', 'Client', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }');

-- ---------------------------------------------------------------------------
-- Academic roles — PROPOSED set (PRD leaves exact names open; see the
-- draft doc's "Open Questions" section; PRD.md §10 owner: Product + SME).
-- ---------------------------------------------------------------------------
insert into public.roles (id, case_type, display_name, is_lead_tier, permissions) values
  ('integrity_officer', 'academic', 'Integrity Officer', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": true,
    "export_reports": true,   "view_privileged": true
  }'),
  ('panel_member', 'academic', 'Panel Member', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": false, "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('advisor', 'academic', 'Advisor', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": false,
    "export_reports": true,   "view_privileged": false
  }'),
  ('respondent', 'academic', 'Respondent', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('witness', 'academic', 'Witness', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": true,  "comment": false,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }');
