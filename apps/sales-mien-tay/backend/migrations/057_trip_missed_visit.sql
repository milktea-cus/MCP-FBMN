-- Trip date window for the existing missed-visit RPC; history remains unchanged.
CREATE OR REPLACE FUNCTION public.sales_mark_route_stop_missed(
 p_actor text,p_route uuid,p_stop uuid,p_ref uuid,p_code text,p_note text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE prior public.field_route_stops%ROWTYPE;
        route public.field_day_routes%ROWTYPE;
        plan public.field_monthly_plans%ROWTYPE;
        saved public.field_route_stops%ROWTYPE;
BEGIN
 SELECT * INTO prior FROM public.field_route_stops WHERE id=p_stop FOR UPDATE;
 IF NOT FOUND OR p_ref IS NULL OR p_at IS NULL OR
  p_code NOT IN ('closed','unavailable','unable','other') OR
  length(coalesce(p_note,''))>1000 OR
  (p_code='other' AND length(btrim(coalesce(p_note,'')))<2)
 THEN RAISE EXCEPTION 'invalid missed stop'; END IF;
 SELECT * INTO route FROM public.field_day_routes WHERE id=prior.day_route_id;
 SELECT * INTO plan FROM public.field_monthly_plans WHERE id=route.monthly_plan_id;
 IF prior.day_route_id<>p_route OR prior.owner_sub<>p_actor OR
  route.owner_sub<>p_actor OR route.status<>'ready' OR plan.status<>'planned'
  OR NOT public.sales_monthly_plan_scope_allowed(p_actor,plan.scope_kind,plan.scope_key,plan.province,plan.district)
 THEN RAISE EXCEPTION 'missed stop permission denied'; END IF;
 IF prior.missed_ref=p_ref THEN
  IF prior.missed_code<>p_code OR prior.missed_note<>coalesce(p_note,'')
    OR prior.missed_at IS DISTINCT FROM p_at
  THEN RAISE EXCEPTION 'conflict missed stop ref'; END IF;
  RETURN to_jsonb(prior);
 END IF;
 IF prior.missed_ref IS NOT NULL OR
  EXISTS(SELECT 1 FROM public.field_visits v WHERE v.day_route_stop_id=p_stop) OR
  EXISTS(SELECT 1 FROM public.field_area_visits a WHERE a.day_route_stop_id=p_stop) OR
  EXISTS(SELECT 1 FROM public.field_survey_sessions s WHERE s.day_route_stop_id=p_stop)
 THEN RAISE EXCEPTION 'conflict visited or already reported'; END IF;
 IF p_at>now()+interval '1 minute' OR p_at<now()-interval '30 days'
  OR ((p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date<>route.route_date
    AND NOT EXISTS(SELECT 1 FROM public.field_trips t
     WHERE t.day_route_id=p_route AND t.owner_sub=p_actor
       AND (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN t.start_date AND t.end_date
       AND (t.closed_at IS NULL OR p_at<=t.closed_at)
       AND (prior.customer_id IS NULL OR public.sales_trip_customer_allowed(p_actor,t.id,prior.customer_id))))
 THEN RAISE EXCEPTION 'invalid missed stop time'; END IF;
 UPDATE public.field_route_stops SET missed_code=p_code,missed_note=coalesce(p_note,''),
  missed_at=p_at,missed_ref=p_ref,version=version+1,updated_at=now()
 WHERE id=p_stop RETURNING * INTO saved;
 INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,before_state,after_state)
 VALUES(p_actor,'stop',p_stop,'update',to_jsonb(prior),to_jsonb(saved));
 RETURN to_jsonb(saved);
END;
$fbmn$;
