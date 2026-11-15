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

-- A single transaction per publication. Insert + snapshot + active-pointer
-- update must not be done as sibling writable CTEs (same-row ambiguity).
CREATE OR REPLACE FUNCTION public.sales_publish_survey_form(
 p_actor text,p_form_id uuid,p_ref uuid,p_name text,
 p_provinces text[],p_questions jsonb,p_expected integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE f public.field_survey_forms%ROWTYPE;
 snap public.field_survey_templates%ROWTYPE;
BEGIN
 IF p_expected=0 THEN
  INSERT INTO public.field_survey_forms
   (id,name,provinces,status,revision,created_by,updated_by)
  VALUES(p_form_id,p_name,p_provinces,'active',0,p_actor,p_actor)
  ON CONFLICT(id) DO NOTHING RETURNING * INTO f;
 ELSE
  SELECT * INTO f FROM public.field_survey_forms
   WHERE id=p_form_id AND revision=p_expected FOR UPDATE;
 END IF;
 IF NOT FOUND THEN RETURN NULL; END IF;
 INSERT INTO public.field_survey_templates
   (id,province,title,version,questions,created_by,form_id)
 VALUES(p_ref,'*',p_name,
   nextval('public.field_survey_template_version_seq'),
   p_questions,p_actor,p_form_id)
 RETURNING * INTO snap;
 UPDATE public.field_survey_forms SET
  name=p_name,provinces=p_provinces,current_template_id=snap.id,
  revision=p_expected+1,updated_by=p_actor,updated_at=now(),
  last_mutation_ref=p_ref
 WHERE id=p_form_id AND revision=p_expected
 RETURNING * INTO f;
 IF NOT FOUND THEN RAISE EXCEPTION 'SURVEY_FORM_REVISION_CONFLICT'; END IF;
 RETURN jsonb_build_object(
  'form_id',f.id,'title',f.name,'provinces',f.provinces,
  'revision',f.revision,'status',f.status,
  'id',snap.id,'version',snap.version,'questions',snap.questions);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_publish_survey_form(
 text,uuid,uuid,text,text[],jsonb,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_publish_survey_form(
 text,uuid,uuid,text,text[],jsonb,integer) TO sales_api;
