-- CaseThread migration 0012: Phase 2 case-type seeds —
-- Corporate & Business + Technical & Engineering (Phases.md §3).
--
-- Pure config data (Architecture.md §2 "one core, many configs";
-- proven by Sprint 6's zero-migration Academic flow). The permission
-- grids extend the draft in docs/permission-matrix-draft.md — that
-- document must change together with this file.

insert into public.case_types (id, display_name, description) values
  ('corporate',
   'Corporate & Business',
   'Fraud audits, HR investigations, compliance reviews, and internal audits.'),
  ('technical',
   'Technical & Engineering',
   'Incident response, post-mortems, outage investigations, and bug case reviews.')
on conflict (id) do nothing;

-- Owner-default roles per case type.
update public.case_types
  set owner_role_id = 'fraud_lead'
  where id = 'corporate' and owner_role_id is null;

update public.case_types
  set owner_role_id = 'incident_commander'
  where id = 'technical' and owner_role_id is null;

-- ---------------------------------------------------------------------------
-- Corporate & Business roles (from the original concept's fraud-unit
-- persona; PRD leaves exact names open — DRAFT pending SME review).
-- ---------------------------------------------------------------------------
insert into public.roles (id, case_type, display_name, is_lead_tier, permissions) values
  ('fraud_lead', 'corporate', 'Fraud Lead', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": true,
    "export_reports": true,   "view_privileged": true
  }'),
  ('internal_auditor', 'corporate', 'Internal Auditor', false, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('compliance_officer', 'corporate', 'Compliance Officer', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": false,
    "export_reports": true,   "view_privileged": true
  }'),
  ('finance_analyst', 'corporate', 'Finance Analyst', false, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('subject_manager', 'corporate', 'Subject Manager', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('observer', 'corporate', 'Observer', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": false, "comment": false,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }')
on conflict (case_type, id) do nothing;

-- ---------------------------------------------------------------------------
-- Technical & Engineering roles (incident-response shaped).
-- ---------------------------------------------------------------------------
insert into public.roles (id, case_type, display_name, is_lead_tier, permissions) values
  ('incident_commander', 'technical', 'Incident Commander', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": true,
    "export_reports": true,   "view_privileged": true
  }'),
  ('sre_responder', 'technical', 'SRE Responder', false, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('engineering_lead', 'technical', 'Engineering Lead', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": false,
    "export_reports": true,   "view_privileged": false
  }'),
  ('reporter', 'technical', 'Reporter', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }')
on conflict (case_type, id) do nothing;

-- ---------------------------------------------------------------------------
-- Medical & Healthcare — SEED ONLY, with the SME gate honored:
-- Phases.md §3 requires the HIPAA-adjacent consult BEFORE any
-- medical-specific FIELDS are built (those land with redaction work
-- in the next migration). Generic roles only; domain fields deferred
-- pending SME sign-off (PRD.md §10, docs/permission-matrix-draft.md
-- change log updated accordingly).
-- ---------------------------------------------------------------------------
insert into public.case_types (id, display_name, description) values
  ('medical',
   'Medical & Healthcare',
   'Clinical case reviews, patient-safety investigations, and quality reviews.')
on conflict (id) do nothing;

update public.case_types
  set owner_role_id = 'case_review_lead'
  where id = 'medical' and owner_role_id is null;

insert into public.roles (id, case_type, display_name, is_lead_tier, permissions) values
  ('case_review_lead', 'medical', 'Case Review Lead', true, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": true, "manage_members": true,
    "export_reports": true,   "view_privileged": true
  }'),
  ('clinician', 'medical', 'Clinician', false, '{
    "view_case": true,        "edit_case": true,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('quality_reviewer', 'medical', 'Quality Reviewer', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": false, "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }'),
  ('patient_representative', 'medical', 'Patient Representative', false, '{
    "view_case": true,        "edit_case": false,
    "upload_evidence": true,  "comment": true,
    "approve_ai_findings": false, "manage_members": false,
    "export_reports": false,  "view_privileged": false
  }')
on conflict (case_type, id) do nothing;
