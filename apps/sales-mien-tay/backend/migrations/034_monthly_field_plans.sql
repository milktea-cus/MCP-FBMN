-- P0-L1: standalone monthly plans, additive only. Existing routes remain untouched.
CREATE TABLE IF NOT EXISTS public.field_monthly_plans (
 id uuid PRIMARY KEY,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 period_ym text NOT NULL CHECK (period_ym ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 scope_kind text NOT NULL CHECK(scope_kind IN ('territory','chain')),
 scope_key text NOT NULL CHECK(length(scope_key) BETWEEN 1 AND 240),
 province text, district text, work_date date NOT NULL,
 purpose text NOT NULL CHECK(length(btrim(purpose)) BETWEEN 2 AND 500),
 target_new_customers integer NOT NULL DEFAULT 0 CHECK(target_new_customers BETWEEN 0 AND 9999),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=2000),
 status text NOT NULL DEFAULT 'planned' CHECK(status IN ('planned','cancelled')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT monthly_plan_day_in_month CHECK(period_ym=substring(work_date::text,1,7)),
 CONSTRAINT monthly_plan_scope_shape CHECK(
   (scope_kind='territory' AND province IS NOT NULL AND district IS NOT NULL AND scope_key=province||'|'||district)
   OR (scope_kind='chain' AND province IS NULL AND district IS NULL))
);
CREATE INDEX IF NOT EXISTS monthly_plan_owner_month ON public.field_monthly_plans(owner_sub,period_ym,work_date);
CREATE UNIQUE INDEX IF NOT EXISTS monthly_plan_one_scope_per_day
 ON public.field_monthly_plans(owner_sub,work_date,scope_kind,scope_key) WHERE status='planned';
CREATE TABLE IF NOT EXISTS public.field_monthly_plan_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 plan_id uuid NOT NULL REFERENCES public.field_monthly_plans(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK(action IN ('create','update','cancel','reopen')),
 before_state jsonb, after_state jsonb NOT NULL,
 happened_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS monthly_plan_audit_plan ON public.field_monthly_plan_audit(plan_id,happened_at DESC);

-- Personal allocations are authoritative: hierarchy never grants write access.
CREATE OR REPLACE FUNCTION public.sales_monthly_plan_scope_allowed(
 p_actor text,p_kind text,p_key text,p_province text,p_district text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
 SELECT EXISTS(SELECT 1 FROM public.staff_members s
 WHERE s.user_sub=p_actor AND s.active AND public.sales_identity_exists(s.user_sub)
 AND (
 (p_kind='territory' AND p_province IS NOT NULL AND p_district IS NOT NULL
   AND p_key=p_province||'|'||p_district
   AND (s.role='admin' OR EXISTS(SELECT 1 FROM public.staff_scopes sc
     WHERE sc.user_sub=s.user_sub AND sc.province=p_province AND (sc.district='' OR sc.district=p_district))))
 OR
 (p_kind='chain' AND p_province IS NULL AND p_district IS NULL
   AND EXISTS(SELECT 1 FROM public.customer_chains c WHERE c.id::text=p_key)
   AND (s.role='admin' OR EXISTS(SELECT 1 FROM public.staff_business_assignments a
     WHERE a.user_sub=s.user_sub AND a.active AND a.scope_kind='chain' AND a.scope_key=p_key)))
 ));
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_monthly_plan_scope_allowed(text,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_monthly_plan_scope_allowed(text,text,text,text,text) TO sales_api;

-- SECDEF writer: ACL, version, idempotency and audit run in one transaction.
CREATE OR REPLACE FUNCTION public.sales_save_monthly_plan(
 p_actor text,p_id uuid,p_mutation uuid,p_expected integer,
 p_month text,p_kind text,p_key text,p_province text,p_district text,
 p_date date,p_purpose text,p_target integer,p_note text,p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.field_monthly_plans%ROWTYPE;
        saved public.field_monthly_plans%ROWTYPE;
        action_name text;
BEGIN
 IF p_id IS NULL OR p_mutation IS NULL OR p_expected IS NULL OR p_expected<0
 OR p_month IS NULL OR p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
 OR p_date IS NULL OR p_month<>substring(p_date::text,1,7)
 OR p_kind NOT IN ('territory','chain') OR p_status NOT IN ('planned','cancelled')
 OR length(btrim(coalesce(p_purpose,''))) NOT BETWEEN 2 AND 500
 OR p_target IS NULL OR p_target NOT BETWEEN 0 AND 9999
 OR length(coalesce(p_note,''))>2000
 OR NOT public.sales_monthly_plan_scope_allowed(p_actor,p_kind,p_key,p_province,p_district)
 THEN RAISE EXCEPTION 'invalid scope or monthly plan'; END IF;
 SELECT * INTO old FROM public.field_monthly_plans WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor OR old.scope_kind<>p_kind OR old.scope_key<>p_key
  OR old.province IS DISTINCT FROM p_province OR old.district IS DISTINCT FROM p_district
  THEN RAISE EXCEPTION 'plan scope forbidden'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_expected=0 OR old.version<>p_expected THEN RAISE EXCEPTION 'stale plan version'; END IF;
  UPDATE public.field_monthly_plans SET period_ym=p_month,work_date=p_date,
   purpose=btrim(p_purpose),target_new_customers=p_target,note=coalesce(p_note,''),
   status=p_status,version=version+1,last_mutation_ref=p_mutation,updated_at=now()
  WHERE id=p_id RETURNING * INTO saved;
  action_name=CASE WHEN old.status='planned' AND saved.status='cancelled' THEN 'cancel'
                   WHEN old.status='cancelled' AND saved.status='planned' THEN 'reopen'
                   ELSE 'update' END;
  INSERT INTO public.field_monthly_plan_audit(plan_id,actor_sub,action,before_state,after_state)
  VALUES(p_id,p_actor,action_name,to_jsonb(old),to_jsonb(saved));
 ELSE
  IF p_expected<>0 OR p_status<>'planned' THEN RAISE EXCEPTION 'stale plan version'; END IF;
  INSERT INTO public.field_monthly_plans
   (id,owner_sub,period_ym,scope_kind,scope_key,province,district,work_date,
    purpose,target_new_customers,note,last_mutation_ref)
  VALUES(p_id,p_actor,p_month,p_kind,p_key,p_province,p_district,p_date,
    btrim(p_purpose),p_target,coalesce(p_note,''),p_mutation) RETURNING * INTO saved;
  INSERT INTO public.field_monthly_plan_audit(plan_id,actor_sub,action,after_state)
  VALUES(p_id,p_actor,'create',to_jsonb(saved));
 END IF;
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_monthly_plan(text,uuid,uuid,integer,text,text,text,text,text,date,text,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_monthly_plan(text,uuid,uuid,integer,text,text,text,text,text,date,text,integer,text,text) TO sales_api;
GRANT SELECT ON public.field_monthly_plans TO sales_api;
-- sales_api intentionally has no direct INSERT/UPDATE/DELETE or audit write grant.
