-- Existing market GPS and lead RPC, extended for trip dates.
CREATE OR REPLACE FUNCTION public.sales_save_route_market_visit(
 p_actor text,p_ref uuid,p_route uuid,p_when timestamptz,
 p_lat double precision,p_lon double precision,p_accuracy double precision,
 p_note text,p_lead_name text,p_lead_address text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE route public.field_day_routes%ROWTYPE;
        prior public.field_area_visits%ROWTYPE;
        saved public.field_area_visits%ROWTYPE;
        lead public.field_prospects%ROWTYPE;
BEGIN
 IF p_actor IS NULL OR p_ref IS NULL OR p_route IS NULL OR p_when IS NULL OR
  p_lat NOT BETWEEN -90 AND 90 OR p_lon NOT BETWEEN -180 AND 180 OR
  p_accuracy NOT BETWEEN 0 AND 100 OR
  length(coalesce(p_note,''))>2000 OR
  p_when>now()+interval '1 minute' OR p_when<now()-interval '30 days' OR
  (p_lead_name IS NULL) <> (p_lead_address IS NULL) OR
  (p_lead_name IS NOT NULL AND
   (length(btrim(p_lead_name)) NOT BETWEEN 2 AND 240 OR
    length(btrim(p_lead_address)) NOT BETWEEN 3 AND 500))
 THEN RAISE EXCEPTION 'invalid market visit'; END IF;
 SELECT r.* INTO route FROM public.field_day_routes r
 JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
 WHERE r.id=p_route AND r.owner_sub=p_actor AND r.status='ready'
  AND m.status='planned' AND (m.scope_kind IN ('territory','chain') OR
   EXISTS(SELECT 1 FROM public.field_trips t
    JOIN public.field_trip_scopes s ON s.trip_id=t.id
    WHERE t.day_route_id=r.id AND s.scope_kind IN ('territory','chain')
      AND public.sales_monthly_plan_scope_allowed(p_actor,s.scope_kind,s.scope_key,s.province,s.district)))
  AND public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district)
 FOR UPDATE OF r;
 IF NOT FOUND THEN RAISE EXCEPTION 'market visit permission denied'; END IF;
 IF NOT (
  (NOT EXISTS(SELECT 1 FROM public.field_trips t WHERE t.day_route_id=p_route)
   AND (p_when AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=route.route_date)
  OR EXISTS(SELECT 1 FROM public.field_trips t
   WHERE t.day_route_id=p_route AND t.owner_sub=p_actor
    AND (p_when AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN t.start_date AND t.end_date
    AND (t.closed_at IS NULL OR p_when<=t.closed_at))
 ) THEN RAISE EXCEPTION 'invalid market visit date'; END IF;
 SELECT * INTO prior FROM public.field_area_visits WHERE id=p_ref FOR UPDATE;
 IF prior.id IS NOT NULL THEN
  SELECT * INTO lead FROM public.field_prospects WHERE area_visit_id=p_ref;
  IF prior.owner_sub<>p_actor OR prior.day_route_id IS DISTINCT FROM p_route OR
   prior.day_route_stop_id IS NOT NULL OR prior.checkin_at IS DISTINCT FROM p_when OR
   prior.latitude IS DISTINCT FROM p_lat OR prior.longitude IS DISTINCT FROM p_lon OR
   prior.accuracy_m IS DISTINCT FROM p_accuracy OR prior.note<>coalesce(p_note,'') OR
   (p_lead_name IS NULL AND lead.id IS NOT NULL) OR
   (p_lead_name IS NOT NULL AND
    (lead.id IS NULL OR lead.name<>btrim(p_lead_name) OR
     lead.address_line<>btrim(p_lead_address)))
  THEN RAISE EXCEPTION 'market visit ref conflict'; END IF;
  RETURN to_jsonb(prior)||jsonb_build_object('prospect_id',lead.id);
 END IF;
 INSERT INTO public.field_area_visits
  (id,day_route_id,owner_sub,checkin_at,latitude,longitude,accuracy_m,note)
 VALUES(p_ref,p_route,p_actor,p_when,p_lat,p_lon,p_accuracy,coalesce(p_note,''))
 RETURNING * INTO saved;
 IF p_lead_name IS NOT NULL THEN
  INSERT INTO public.field_prospects(area_visit_id,owner_sub,name,address_line)
  VALUES(p_ref,p_actor,btrim(p_lead_name),btrim(p_lead_address))
  RETURNING * INTO lead;
 END IF;
 RETURN to_jsonb(saved)||jsonb_build_object('prospect_id',lead.id);
END
$fbmn$;
