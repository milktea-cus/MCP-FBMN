-- P0-L2: the dated route and its stops are distinct from customers and surveys.
-- Additive: the existing sales_records route/check-in history is preserved.
CREATE TABLE IF NOT EXISTS public.field_day_routes (
 id uuid PRIMARY KEY,
 monthly_plan_id uuid NOT NULL UNIQUE REFERENCES public.field_monthly_plans(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 route_date date NOT NULL,
 purpose text NOT NULL CHECK(length(btrim(purpose)) BETWEEN 2 AND 500),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=2000),
 status text NOT NULL DEFAULT 'ready' CHECK(status IN ('ready','cancelled')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_day_routes_owner_date ON public.field_day_routes(owner_sub,route_date);
CREATE TABLE IF NOT EXISTS public.field_route_stops (
 id uuid PRIMARY KEY,
 day_route_id uuid NOT NULL REFERENCES public.field_day_routes(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 stop_kind text NOT NULL CHECK(stop_kind IN ('customer','area','chain')),
 customer_id uuid REFERENCES public.customers(id) ON DELETE RESTRICT,
 chain_id uuid REFERENCES public.customer_chains(id) ON DELETE RESTRICT,
 province text,district text,
 sequence integer NOT NULL CHECK(sequence BETWEEN 1 AND 9999),
 purpose text NOT NULL DEFAULT '' CHECK(length(purpose)<=500),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT field_stop_shape CHECK(
  (stop_kind='customer' AND customer_id IS NOT NULL AND chain_id IS NULL AND province IS NULL AND district IS NULL)
  OR (stop_kind='area' AND customer_id IS NULL AND chain_id IS NULL AND province IS NOT NULL AND district IS NOT NULL)
  OR (stop_kind='chain' AND customer_id IS NULL AND chain_id IS NOT NULL AND province IS NULL AND district IS NULL))
);
CREATE INDEX IF NOT EXISTS field_route_stops_route_order ON public.field_route_stops(day_route_id,sequence,id);
CREATE UNIQUE INDEX IF NOT EXISTS field_route_stops_customer_once ON public.field_route_stops(day_route_id,customer_id) WHERE customer_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS field_route_stops_area_once ON public.field_route_stops(day_route_id,province,district) WHERE stop_kind='area';
CREATE UNIQUE INDEX IF NOT EXISTS field_route_stops_chain_once ON public.field_route_stops(day_route_id,chain_id) WHERE chain_id IS NOT NULL;
-- These new FKs coexist with legacy route_stop_id -> sales_records.
ALTER TABLE public.field_visits ADD COLUMN IF NOT EXISTS day_route_stop_id uuid REFERENCES public.field_route_stops(id) ON DELETE RESTRICT;
ALTER TABLE public.field_survey_sessions ADD COLUMN IF NOT EXISTS day_route_stop_id uuid REFERENCES public.field_route_stops(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS field_visits_day_stop ON public.field_visits(day_route_stop_id) WHERE day_route_stop_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS field_sessions_day_stop ON public.field_survey_sessions(day_route_stop_id) WHERE day_route_stop_id IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.field_route_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 entity_kind text NOT NULL CHECK(entity_kind IN ('route','stop')),
 entity_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('create','update')),
 before_state jsonb,after_state jsonb NOT NULL,
 happened_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_route_audit_entity ON public.field_route_audit(entity_kind,entity_id,happened_at DESC);

-- No implicit subordinate action grants.
CREATE OR REPLACE FUNCTION public.sales_save_day_route(
 p_actor text,p_id uuid,p_mutation uuid,p_expected integer,p_plan uuid,p_day date,
 p_purpose text,p_note text,p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE plan public.field_monthly_plans%ROWTYPE;
        old public.field_day_routes%ROWTYPE;
        saved public.field_day_routes%ROWTYPE;
BEGIN
 SELECT * INTO plan FROM public.field_monthly_plans WHERE id=p_plan;
 IF p_id IS NULL OR p_mutation IS NULL OR p_expected IS NULL OR p_expected<0
 OR NOT FOUND OR plan.owner_sub<>p_actor OR plan.status<>'planned'
 OR NOT public.sales_monthly_plan_scope_allowed(p_actor,plan.scope_kind,plan.scope_key,plan.province,plan.district)
 OR p_day IS NULL OR substring(p_day::text,1,7)<>plan.period_ym
 OR p_status NOT IN ('ready','cancelled')
 OR length(btrim(coalesce(p_purpose,''))) NOT BETWEEN 2 AND 500 OR length(coalesce(p_note,''))>2000
 THEN RAISE EXCEPTION 'invalid route permission or data'; END IF;
 SELECT * INTO old FROM public.field_day_routes WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor OR old.monthly_plan_id<>p_plan THEN RAISE EXCEPTION 'route scope forbidden'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_expected=0 OR old.version<>p_expected THEN RAISE EXCEPTION 'stale route version'; END IF;
  IF (old.route_date IS DISTINCT FROM p_day OR p_status='cancelled')
   AND EXISTS(SELECT 1 FROM public.field_route_stops s
      WHERE s.day_route_id=p_id AND (
       EXISTS(SELECT 1 FROM public.field_visits v WHERE v.day_route_stop_id=s.id)
       OR EXISTS(SELECT 1 FROM public.field_survey_sessions ss WHERE ss.day_route_stop_id=s.id)))
  THEN RAISE EXCEPTION 'route already visited'; END IF;
  UPDATE public.field_day_routes SET route_date=p_day,purpose=btrim(p_purpose),
    note=coalesce(p_note,''),status=p_status,version=version+1,
    last_mutation_ref=p_mutation,updated_at=now()
   WHERE id=p_id RETURNING * INTO saved;
  INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,before_state,after_state)
   VALUES(p_actor,'route',p_id,'update',to_jsonb(old),to_jsonb(saved));
 ELSE
  IF p_expected<>0 OR p_status<>'ready' THEN RAISE EXCEPTION 'stale route version'; END IF;
  INSERT INTO public.field_day_routes(id,monthly_plan_id,owner_sub,route_date,purpose,note,last_mutation_ref)
   VALUES(p_id,p_plan,p_actor,p_day,btrim(p_purpose),coalesce(p_note,''),p_mutation)
   RETURNING * INTO saved;
  INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,after_state)
   VALUES(p_actor,'route',p_id,'create',to_jsonb(saved));
 END IF;
 RETURN to_jsonb(saved);
END
$fbmn$;

CREATE OR REPLACE FUNCTION public.sales_save_route_stop(
 p_actor text,p_id uuid,p_mutation uuid,p_expected integer,p_route uuid,
 p_kind text,p_customer uuid,p_chain uuid,p_province text,p_district text,
 p_sequence integer,p_purpose text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE route public.field_day_routes%ROWTYPE;
        plan public.field_monthly_plans%ROWTYPE;
        old public.field_route_stops%ROWTYPE;
        saved public.field_route_stops%ROWTYPE;
BEGIN
 SELECT * INTO route FROM public.field_day_routes WHERE id=p_route;
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid route'; END IF;
 SELECT * INTO plan FROM public.field_monthly_plans WHERE id=route.monthly_plan_id;
 IF p_id IS NULL OR p_mutation IS NULL OR p_expected IS NULL OR p_expected<0
 OR route.owner_sub<>p_actor OR route.status<>'ready' OR plan.status<>'planned'
 OR NOT public.sales_monthly_plan_scope_allowed(p_actor,plan.scope_kind,plan.scope_key,plan.province,plan.district)
 OR p_sequence NOT BETWEEN 1 AND 9999 OR length(coalesce(p_purpose,''))>500
 OR NOT (
  (p_kind='area' AND plan.scope_kind='territory' AND p_customer IS NULL AND p_chain IS NULL
     AND p_province=plan.province AND p_district=plan.district)
  OR
  (p_kind='chain' AND plan.scope_kind='chain' AND p_chain::text=plan.scope_key
     AND p_customer IS NULL AND p_province IS NULL AND p_district IS NULL)
  OR
  (p_kind='customer' AND p_customer IS NOT NULL AND p_chain IS NULL AND p_province IS NULL AND p_district IS NULL
   AND public.sales_customer_plannable(p_actor,p_customer)
   AND EXISTS(SELECT 1 FROM public.customers c WHERE c.id=p_customer AND (
    (plan.scope_kind='territory' AND c.province=plan.province AND
       (plan.district='' OR c.district=plan.district))
    OR (plan.scope_kind='chain' AND EXISTS(SELECT 1 FROM public.customer_scope_bindings b
      WHERE b.customer_id=c.id AND b.scope_kind='chain' AND b.scope_key=plan.scope_key AND b.active))))))
 THEN RAISE EXCEPTION 'invalid stop permission or data'; END IF;
 SELECT * INTO old FROM public.field_route_stops WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor OR old.day_route_id<>p_route OR old.stop_kind<>p_kind
   OR old.customer_id IS DISTINCT FROM p_customer OR old.chain_id IS DISTINCT FROM p_chain
   OR old.province IS DISTINCT FROM p_province OR old.district IS DISTINCT FROM p_district
  THEN RAISE EXCEPTION 'stop scope forbidden'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_expected=0 OR old.version<>p_expected THEN RAISE EXCEPTION 'stale stop version'; END IF;
  IF EXISTS(SELECT 1 FROM public.field_visits v WHERE v.day_route_stop_id=p_id)
    OR EXISTS(SELECT 1 FROM public.field_survey_sessions ss WHERE ss.day_route_stop_id=p_id)
  THEN RAISE EXCEPTION 'stop already visited'; END IF;
  UPDATE public.field_route_stops SET sequence=p_sequence,purpose=coalesce(p_purpose,''),
    version=version+1,last_mutation_ref=p_mutation,updated_at=now()
   WHERE id=p_id RETURNING * INTO saved;
  INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,before_state,after_state)
   VALUES(p_actor,'stop',p_id,'update',to_jsonb(old),to_jsonb(saved));
 ELSE
  IF p_expected<>0 THEN RAISE EXCEPTION 'stale stop version'; END IF;
  INSERT INTO public.field_route_stops
   (id,day_route_id,owner_sub,stop_kind,customer_id,chain_id,province,district,sequence,purpose,last_mutation_ref)
  VALUES(p_id,p_route,p_actor,p_kind,p_customer,p_chain,p_province,p_district,p_sequence,
    coalesce(p_purpose,''),p_mutation) RETURNING * INTO saved;
  INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,after_state)
   VALUES(p_actor,'stop',p_id,'create',to_jsonb(saved));
 END IF;
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_day_route(text,uuid,uuid,integer,uuid,date,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_save_route_stop(text,uuid,uuid,integer,uuid,text,uuid,uuid,text,text,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_day_route(text,uuid,uuid,integer,uuid,date,text,text,text) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_save_route_stop(text,uuid,uuid,integer,uuid,text,uuid,uuid,text,text,integer,text) TO sales_api;
GRANT SELECT ON public.field_day_routes,public.field_route_stops TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_day_routes,public.field_route_stops FROM sales_api;
REVOKE ALL ON public.field_route_audit FROM sales_api;
