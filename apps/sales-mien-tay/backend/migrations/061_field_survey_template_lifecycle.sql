-- 061: Manage template availability separately from immutable published
-- versions. Pause/archive never deletes customer evidence or historic forms.
CREATE TABLE IF NOT EXISTS public.field_survey_template_visibility (
 province text PRIMARY KEY,
 status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','archived')),
 changed_by text NOT NULL,
 changed_at timestamptz NOT NULL DEFAULT now(),
 client_ref uuid NOT NULL
);
CREATE TABLE IF NOT EXISTS public.field_survey_template_status_audit (
 client_ref uuid PRIMARY KEY,
 province text NOT NULL,
 status text NOT NULL CHECK (status IN ('active','paused','archived')),
 version integer NOT NULL,
 changed_by text NOT NULL,
 changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_field_survey_template_status_audit_province
 ON public.field_survey_template_status_audit(province,changed_at DESC);
REVOKE ALL ON public.field_survey_template_visibility FROM PUBLIC;
REVOKE ALL ON public.field_survey_template_status_audit FROM PUBLIC;

-- Worker connects with sales_api. It must read active state and perform only
-- explicit lifecycle writes; no direct DELETE on any template or audit table.
GRANT SELECT,INSERT,UPDATE ON public.field_survey_template_visibility TO sales_api;
GRANT SELECT,INSERT ON public.field_survey_template_status_audit TO sales_api;
REVOKE DELETE,TRUNCATE,REFERENCES,TRIGGER
 ON public.field_survey_template_visibility,public.field_survey_template_status_audit FROM sales_api;
