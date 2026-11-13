-- P0-2C/E: route execution outcomes stay separate from the original plan.
-- Additive: never synthesize customer/check-in rows for closed shops or missed stops.
ALTER TABLE public.field_route_stops
 ADD COLUMN IF NOT EXISTS is_unplanned boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS missed_code text,
 ADD COLUMN IF NOT EXISTS missed_note text,
 ADD COLUMN IF NOT EXISTS missed_at timestamptz,
 ADD COLUMN IF NOT EXISTS missed_ref uuid;

DO $fbmn$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='field_stop_missed_shape') THEN
  ALTER TABLE public.field_route_stops ADD CONSTRAINT field_stop_missed_shape
   CHECK ((missed_code IS NULL AND missed_note IS NULL AND missed_at IS NULL AND missed_ref IS NULL)
     OR (missed_code IN ('closed','unavailable','unable','other')
       AND missed_note IS NOT NULL AND length(missed_note)<=1000
       AND missed_at IS NOT NULL AND missed_ref IS NOT NULL));
 END IF;
END;
$fbmn$;
CREATE INDEX IF NOT EXISTS field_route_stops_unplanned
 ON public.field_route_stops(day_route_id,is_unplanned);
CREATE UNIQUE INDEX IF NOT EXISTS field_route_stops_missed_ref
 ON public.field_route_stops(owner_sub,missed_ref) WHERE missed_ref IS NOT NULL;

-- Writes go through the existing plannable-scope, version and idempotency
-- checks, then mark only newly created stops outside the planned baseline.
CREATE OR REPLACE FUNCTION public.sales_add_unplanned_route_stop(
 p_actor text,p_id uuid,p_ref uuid,p_route uuid,p_kind text,
 p_customer uuid,p_chain uuid,p_province text,p_district text,
 p_sequence integer,p_purpose text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE saved jsonb;
        prior public.field_route_stops%ROWTYPE;
        route public.field_day_routes%ROWTYPE;
        updated public.field_route_stops%ROWTYPE;
BEGIN
 SELECT * INTO route FROM public.field_day_routes WHERE id=p_route;
 IF NOT FOUND OR p_at IS NULL OR p_at>now()+interval '1 minute'
  OR p_at<now()-interval '30 days'
  OR (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date<>route.route_date
 THEN RAISE EXCEPTION 'invalid unplanned stop time'; END IF;
 SELECT * INTO prior FROM public.field_route_stops WHERE id=p_id;
 IF FOUND AND NOT prior.is_unplanned THEN RAISE EXCEPTION 'conflict planned stop identity'; END IF;
 saved:=public.sales_save_route_stop(p_actor,p_id,p_ref,0,p_route,p_kind,
   p_customer,p_chain,p_province,p_district,p_sequence,p_purpose);
 UPDATE public.field_route_stops SET is_unplanned=true WHERE id=p_id
  AND owner_sub=p_actor RETURNING * INTO updated;
 IF NOT FOUND THEN RAISE EXCEPTION 'unplanned stop permission denied'; END IF;
 IF NOT prior.is_unplanned OR prior.id IS NULL THEN
  INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,before_state,after_state)
   VALUES(p_actor,'stop',p_id,'update',saved,to_jsonb(updated));
 END IF;
 RETURN to_jsonb(updated);
END;
$fbmn$;

-- A missed visit is a reason, not GPS evidence or a survey completion.
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
  OR (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date<>route.route_date
 THEN RAISE EXCEPTION 'invalid missed stop time'; END IF;
 UPDATE public.field_route_stops SET missed_code=p_code,missed_note=coalesce(p_note,''),
  missed_at=p_at,missed_ref=p_ref,version=version+1,updated_at=now()
 WHERE id=p_stop RETURNING * INTO saved;
 INSERT INTO public.field_route_audit(actor_sub,entity_kind,entity_id,action,before_state,after_state)
 VALUES(p_actor,'stop',p_stop,'update',to_jsonb(prior),to_jsonb(saved));
 RETURN to_jsonb(saved);
END;
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_add_unplanned_route_stop(
 text,uuid,uuid,uuid,text,uuid,uuid,text,text,integer,text,timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_mark_route_stop_missed(
 text,uuid,uuid,uuid,text,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_add_unplanned_route_stop(
 text,uuid,uuid,uuid,text,uuid,uuid,text,text,integer,text,timestamptz) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_mark_route_stop_missed(
 text,uuid,uuid,uuid,text,text,timestamptz) TO sales_api;
