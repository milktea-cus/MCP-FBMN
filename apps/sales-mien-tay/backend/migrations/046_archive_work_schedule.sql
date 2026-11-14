-- 046: audited soft deletion of work schedules.
-- Neither routes, stops, field visits nor survey evidence are physically deleted.
CREATE OR REPLACE FUNCTION public.sales_archive_monthly_plan(
 p_actor text,p_plan uuid,p_version integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public
AS $fbmn$
DECLARE
 old_plan public.field_monthly_plans%ROWTYPE;
 saved_plan public.field_monthly_plans%ROWTYPE;
 old_route public.field_day_routes%ROWTYPE;
 saved_route public.field_day_routes%ROWTYPE;
 started boolean:=false;
BEGIN
 IF p_actor IS NULL OR p_plan IS NULL OR p_version IS NULL OR p_version<1
 THEN RAISE EXCEPTION 'archive_invalid'; END IF;
 IF NOT EXISTS(
   SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor AND s.active
 ) THEN RAISE EXCEPTION 'archive_forbidden'; END IF;
 SELECT * INTO old_plan FROM public.field_monthly_plans
 WHERE id=p_plan FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'archive_not_found'; END IF;
 IF old_plan.owner_sub<>p_actor OR NOT public.sales_monthly_plan_scope_allowed(
   p_actor,old_plan.scope_kind,old_plan.scope_key,old_plan.province,old_plan.district
 ) THEN RAISE EXCEPTION 'archive_forbidden'; END IF;
 IF old_plan.status='cancelled' THEN
  RETURN jsonb_build_object('item',to_jsonb(old_plan),'already_archived',true);
 END IF;
 IF old_plan.version<>p_version THEN RAISE EXCEPTION 'archive_stale'; END IF;
 SELECT * INTO old_route FROM public.field_day_routes
 WHERE monthly_plan_id=p_plan FOR UPDATE;
 IF FOUND THEN
  SELECT EXISTS(
    SELECT 1 FROM public.field_route_stops stop
    WHERE stop.day_route_id=old_route.id
      AND (stop.missed_code IS NOT NULL
       OR EXISTS(SELECT 1 FROM public.field_visits v
                 WHERE v.day_route_stop_id=stop.id)
       OR EXISTS(SELECT 1 FROM public.field_area_visits a
                 WHERE a.day_route_stop_id=stop.id)
       OR EXISTS(SELECT 1 FROM public.field_survey_sessions ss
                 WHERE ss.day_route_stop_id=stop.id))
  ) INTO started;
  -- Preserve route status and all evidence when field work has started.
  IF NOT started AND old_route.status<>'cancelled' THEN
   UPDATE public.field_day_routes SET
      status='cancelled',version=version+1,
      last_mutation_ref=gen_random_uuid(),updated_at=now()
    WHERE id=old_route.id RETURNING * INTO saved_route;
   INSERT INTO public.field_route_audit(
    actor_sub,entity_kind,entity_id,action,before_state,after_state)
   VALUES(p_actor,'route',old_route.id,'cancel',
          to_jsonb(old_route),to_jsonb(saved_route));
  END IF;
 END IF;
 UPDATE public.field_monthly_plans SET
  status='cancelled',version=version+1,
  last_mutation_ref=gen_random_uuid(),updated_at=now()
 WHERE id=p_plan RETURNING * INTO saved_plan;
 INSERT INTO public.field_monthly_plan_audit(
  plan_id,actor_sub,action,before_state,after_state)
 VALUES(p_plan,p_actor,'cancel',to_jsonb(old_plan),to_jsonb(saved_plan));
 RETURN jsonb_build_object(
  'item',to_jsonb(saved_plan),'already_archived',false,
  'has_activity',started,
  'route_id',CASE WHEN old_route.id IS NOT NULL THEN old_route.id::text ELSE NULL END);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_archive_monthly_plan(text,uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_archive_monthly_plan(text,uuid,integer) TO sales_api;
