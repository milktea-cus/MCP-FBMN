-- P0 Sales Local monthly week cycle. Entirely separate from work/monthly plans.
-- Week 1=1..7, 2=8..14, 3=15..21, 4=22..28, 5=29..last day.
CREATE TABLE IF NOT EXISTS public.field_local_monthly_routes (
 id uuid PRIMARY KEY,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 120),
 week_no smallint NOT NULL CHECK(week_no BETWEEN 1 AND 5),
 scope_kind text NOT NULL CHECK(scope_kind IN ('territory','chain','customer')),
 scope_key text NOT NULL CHECK(length(scope_key) BETWEEN 1 AND 240),
 province text, district text,
 scope_label text NOT NULL CHECK(length(scope_label) BETWEEN 1 AND 240),
 active boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT local_monthly_scope_consistent CHECK(
  (scope_kind='territory' AND province IS NOT NULL AND district IS NOT NULL
   AND scope_key=province||'|'||district)
  OR (scope_kind IN ('chain','customer') AND province IS NULL AND district IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS local_monthly_one_assignment
 ON public.field_local_monthly_routes(owner_sub,week_no,scope_kind,scope_key) WHERE active;
CREATE INDEX IF NOT EXISTS local_monthly_owner
 ON public.field_local_monthly_routes(owner_sub,active,week_no,updated_at DESC);
CREATE TABLE IF NOT EXISTS public.field_local_monthly_route_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 route_id uuid NOT NULL REFERENCES public.field_local_monthly_routes(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 before_state jsonb, after_state jsonb NOT NULL,
 happened_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS local_monthly_audit_route
 ON public.field_local_monthly_route_audit(route_id,happened_at DESC);
CREATE OR REPLACE FUNCTION public.sales_save_local_monthly_route(
 p_actor text,p_id uuid,p_mutation uuid,p_version integer,
 p_name text,p_week smallint,p_kind text,p_key text,
 p_province text,p_district text,p_label text,p_active boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.field_local_monthly_routes%ROWTYPE;
 saved public.field_local_monthly_routes%ROWTYPE;
BEGIN
 IF p_id IS NULL OR p_mutation IS NULL OR p_version IS NULL OR p_version<0
 OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120
 OR p_week IS NULL OR p_week NOT BETWEEN 1 AND 5
 OR p_kind NOT IN ('territory','chain','customer')
 OR length(coalesce(p_key,'')) NOT BETWEEN 1 AND 240
 OR length(btrim(coalesce(p_label,''))) NOT BETWEEN 1 AND 240
 OR p_active IS NULL
 OR NOT public.sales_monthly_plan_scope_allowed(p_actor,p_kind,p_key,p_province,p_district)
 OR NOT (
  (p_kind='territory' AND p_province IS NOT NULL AND p_district IS NOT NULL
   AND p_key=p_province||'|'||p_district)
  OR (p_kind IN ('chain','customer') AND p_province IS NULL AND p_district IS NULL)
 )
 THEN RAISE EXCEPTION 'LOCAL_MONTHLY_PERMISSION_OR_INVALID'; END IF;
 SELECT * INTO old FROM public.field_local_monthly_routes WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor THEN RAISE EXCEPTION 'LOCAL_MONTHLY_FORBIDDEN'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_version=0 OR old.version<>p_version THEN RAISE EXCEPTION 'LOCAL_MONTHLY_STALE'; END IF;
  UPDATE public.field_local_monthly_routes SET
   name=btrim(p_name),week_no=p_week,scope_kind=p_kind,scope_key=p_key,
   province=p_province,district=p_district,scope_label=btrim(p_label),
   active=p_active,version=version+1,last_mutation_ref=p_mutation,updated_at=now()
  WHERE id=p_id RETURNING * INTO saved;
 ELSE
  IF p_version<>0 THEN RAISE EXCEPTION 'LOCAL_MONTHLY_STALE'; END IF;
  INSERT INTO public.field_local_monthly_routes(
   id,owner_sub,name,week_no,scope_kind,scope_key,province,district,
   scope_label,active,last_mutation_ref)
  VALUES(p_id,p_actor,btrim(p_name),p_week,p_kind,p_key,p_province,p_district,
   btrim(p_label),p_active,p_mutation) RETURNING * INTO saved;
 END IF;
 INSERT INTO public.field_local_monthly_route_audit(route_id,actor_sub,before_state,after_state)
 VALUES(p_id,p_actor,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_local_monthly_route(text,uuid,uuid,integer,text,smallint,text,text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_local_monthly_route(text,uuid,uuid,integer,text,smallint,text,text,text,text,text,boolean) TO sales_api;
GRANT SELECT ON public.field_local_monthly_routes TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_local_monthly_routes FROM sales_api;
REVOKE ALL ON public.field_local_monthly_route_audit FROM sales_api;
