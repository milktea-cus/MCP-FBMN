-- P0-LOCAL: recurring Sales Local rules, independent of monthly plans and trips.
CREATE TABLE IF NOT EXISTS public.field_local_route_rules (
 id uuid PRIMARY KEY, owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 120),
 mode text NOT NULL CHECK(mode IN ('day','week')),
 weekdays smallint[] NOT NULL CHECK (cardinality(weekdays) BETWEEN 1 AND 7
  AND weekdays <@ ARRAY[1,2,3,4,5,6,7]::smallint[]
  AND (mode='week' OR cardinality(weekdays)=1)),
 province text NOT NULL CHECK(length(btrim(province)) BETWEEN 1 AND 120),
 district text NOT NULL DEFAULT '' CHECK(length(district)<=120),
 start_on date NOT NULL, active boolean NOT NULL DEFAULT true,
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_local_route_rules_owner ON public.field_local_route_rules(owner_sub,active,updated_at DESC);
CREATE TABLE IF NOT EXISTS public.field_local_route_rule_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 rule_id uuid NOT NULL REFERENCES public.field_local_route_rules(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 before_state jsonb, after_state jsonb NOT NULL,changed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_local_route_rule_audit_rule ON public.field_local_route_rule_audit(rule_id,changed_at DESC);

CREATE OR REPLACE FUNCTION public.sales_save_local_route_rule(
 p_actor text,p_id uuid,p_mutation uuid,p_version integer,
 p_name text,p_mode text,p_days jsonb,p_province text,p_district text,
 p_start date,p_active boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.field_local_route_rules%ROWTYPE;
 saved public.field_local_route_rules%ROWTYPE;
 normalized smallint[];
BEGIN
 IF p_id IS NULL OR p_mutation IS NULL OR p_version IS NULL OR p_version<0
 OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120
 OR p_mode NOT IN ('day','week') OR p_start IS NULL OR p_active IS NULL
 OR length(btrim(coalesce(p_province,''))) NOT BETWEEN 1 AND 120
 OR length(coalesce(p_district,''))>120
 OR p_days IS NULL OR jsonb_typeof(p_days)<>'array'
 OR jsonb_array_length(p_days) NOT BETWEEN 1 AND 7
 OR NOT public.sales_monthly_plan_scope_allowed(
  p_actor,'territory',p_province||'|'||coalesce(p_district,''),p_province,p_district)
 THEN RAISE EXCEPTION 'LOCAL_ROUTE_PERMISSION_OR_INVALID'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_days) e
  WHERE jsonb_typeof(e.value)<>'number' OR e.value::text !~ '^[1-7]$')
 THEN RAISE EXCEPTION 'LOCAL_ROUTE_INVALID_DAYS'; END IF;
 SELECT array_agg(DISTINCT value::text::smallint ORDER BY value::text::smallint)
 INTO normalized FROM jsonb_array_elements(p_days);
 IF cardinality(normalized)<>jsonb_array_length(p_days)
 OR (p_mode='day' AND cardinality(normalized)<>1)
 THEN RAISE EXCEPTION 'LOCAL_ROUTE_INVALID_DAYS'; END IF;
 SELECT * INTO old FROM public.field_local_route_rules WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor THEN RAISE EXCEPTION 'LOCAL_ROUTE_FORBIDDEN'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_version=0 OR old.version<>p_version THEN RAISE EXCEPTION 'LOCAL_ROUTE_STALE'; END IF;
  UPDATE public.field_local_route_rules SET name=btrim(p_name),mode=p_mode,
   weekdays=normalized,province=p_province,district=coalesce(p_district,''),
   start_on=p_start,active=p_active,version=version+1,last_mutation_ref=p_mutation,
   updated_at=now() WHERE id=p_id RETURNING * INTO saved;
 ELSE
  IF p_version<>0 THEN RAISE EXCEPTION 'LOCAL_ROUTE_STALE'; END IF;
  INSERT INTO public.field_local_route_rules(
   id,owner_sub,name,mode,weekdays,province,district,start_on,active,last_mutation_ref)
  VALUES(p_id,p_actor,btrim(p_name),p_mode,normalized,p_province,
   coalesce(p_district,''),p_start,p_active,p_mutation) RETURNING * INTO saved;
 END IF;
 INSERT INTO public.field_local_route_rule_audit(rule_id,actor_sub,before_state,after_state)
 VALUES(p_id,p_actor,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_local_route_rule(text,uuid,uuid,integer,text,text,jsonb,text,text,date,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_local_route_rule(text,uuid,uuid,integer,text,text,jsonb,text,text,date,boolean) TO sales_api;
GRANT SELECT ON public.field_local_route_rules TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_local_route_rules FROM sales_api;
REVOKE ALL ON public.field_local_route_rule_audit FROM sales_api;
