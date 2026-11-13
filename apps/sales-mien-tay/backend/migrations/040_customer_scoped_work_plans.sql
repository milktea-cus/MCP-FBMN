-- P0-L2: add customer-specific scheduling alongside territory and chain.
-- Non-destructive: existing plans/route stops/audit remain unchanged.
-- customer plans authorize only customers plannable directly by actor.
ALTER TABLE public.field_monthly_plans
 DROP CONSTRAINT field_monthly_plans_scope_kind_check,
 ADD CONSTRAINT field_monthly_plans_scope_kind_check
   CHECK(scope_kind IN ('territory','chain','customer'));
ALTER TABLE public.field_monthly_plans
 DROP CONSTRAINT monthly_plan_scope_shape,
 ADD CONSTRAINT monthly_plan_scope_shape CHECK (
 (scope_kind='territory' AND province IS NOT NULL AND district IS NOT NULL
     AND scope_key=province||'|'||district)
 OR (scope_kind IN ('chain','customer') AND province IS NULL AND district IS NULL)
 );

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
 OR
 (p_kind='customer' AND p_province IS NULL AND p_district IS NULL AND
   EXISTS(SELECT 1 FROM public.customers c WHERE c.id::text=p_key
     AND public.sales_customer_plannable(s.user_sub,c.id)))
 ));
$fbmn$;

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
 OR p_kind NOT IN ('territory','chain','customer') OR p_status NOT IN ('planned','cancelled')
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
      WHERE b.customer_id=c.id AND b.scope_kind='chain' AND b.scope_key=plan.scope_key AND b.active))
    OR (plan.scope_kind='customer' AND c.id::text=plan.scope_key)))))
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

-- Execute grants inherited from migration 034/035; redefining functions does not
-- change their signatures or grants. Other permissions unchanged.
