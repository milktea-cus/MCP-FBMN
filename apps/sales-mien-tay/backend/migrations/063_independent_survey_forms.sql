-- 063: A form has a stable ID, name, provinces and independent status.
-- Old immutable snapshots/survey responses are never deleted or rewritten.
CREATE TABLE IF NOT EXISTS public.field_survey_forms (
 id uuid PRIMARY KEY,
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 80),
 provinces text[] NOT NULL DEFAULT '{}'::text[],
 status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','paused','archived')),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>=0),
 current_template_id uuid REFERENCES public.field_survey_templates(id) ON DELETE RESTRICT,
 created_by text NOT NULL,updated_by text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 last_mutation_ref uuid,
 CHECK(cardinality(provinces)<=64),
 CHECK(array_position(provinces,'*') IS NULL),
 CHECK(array_position(provinces,'') IS NULL)
);
ALTER TABLE public.field_survey_templates
 ADD COLUMN IF NOT EXISTS form_id uuid REFERENCES public.field_survey_forms(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS idx_field_survey_template_form
 ON public.field_survey_templates(form_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_field_survey_forms_state
 ON public.field_survey_forms(status,updated_at DESC);
CREATE SEQUENCE IF NOT EXISTS public.field_survey_template_version_seq;
SELECT setval('public.field_survey_template_version_seq',
 GREATEST(1,(SELECT coalesce(max(version),0) FROM public.field_survey_templates)),true);
-- Built-in seed-only provincial examples remain for old evidence, but
-- do not become 13 unwanted business templates.
WITH latest AS (
 SELECT DISTINCT ON (province) id,province,title,created_by
 FROM public.field_survey_templates ORDER BY province,version DESC
)
INSERT INTO public.field_survey_forms(
 id,name,provinces,status,revision,current_template_id,created_by,updated_by)
SELECT t.id,t.title,CASE WHEN t.province='*' THEN '{}'::text[]
 ELSE ARRAY[t.province] END,
 coalesce(v.status,'active'),1,t.id,t.created_by,t.created_by
FROM latest t LEFT JOIN public.field_survey_template_visibility v
 ON v.province=t.province
WHERE t.province='*' OR t.created_by<>'system:initial'
ON CONFLICT(id) DO NOTHING;
UPDATE public.field_survey_templates t SET form_id=f.id
 FROM public.field_survey_forms f
 WHERE t.form_id IS NULL AND
 (t.province='*' AND cardinality(f.provinces)=0
  OR cardinality(f.provinces)=1 AND f.provinces[1]=t.province);
REVOKE ALL ON public.field_survey_forms FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE ON public.field_survey_forms TO sales_api;
GRANT USAGE,SELECT ON SEQUENCE public.field_survey_template_version_seq TO sales_api;
REVOKE DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_survey_forms FROM sales_api;
-- Province restriction is enforced at the database boundary as well.
CREATE OR REPLACE FUNCTION public.sales_guard_survey_form_scope()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE form_record record; customer_province text; submitted_at timestamptz;
BEGIN
 IF NEW.template_id IS NULL THEN RETURN NEW; END IF;
 SELECT f.provinces,f.status,f.updated_at INTO form_record
 FROM public.field_survey_templates t
 JOIN public.field_survey_forms f ON f.id=t.form_id
 WHERE t.id=NEW.template_id;
 IF NOT FOUND THEN RETURN NEW; END IF;
 SELECT c.province INTO customer_province FROM public.customers c
 WHERE c.id=NEW.customer_id;
 submitted_at:=CASE WHEN TG_TABLE_NAME='field_survey_sessions'
  THEN NEW.started_at ELSE NEW.captured_at END;
 IF customer_province IS NULL OR
  (cardinality(form_record.provinces)>0
   AND NOT (customer_province=ANY(form_record.provinces))) OR
  (form_record.status<>'active' AND submitted_at>form_record.updated_at)
 THEN RAISE EXCEPTION 'SURVEY_FORM_SCOPE_FORBIDDEN'; END IF;
 RETURN NEW;
END $fbmn$;
CREATE TRIGGER trg_survey_form_scope_session BEFORE INSERT ON public.field_survey_sessions
 FOR EACH ROW EXECUTE FUNCTION public.sales_guard_survey_form_scope();
CREATE TRIGGER trg_survey_form_scope_work BEFORE INSERT ON public.field_customer_work_actions
 FOR EACH ROW EXECUTE FUNCTION public.sales_guard_survey_form_scope();
