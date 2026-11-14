-- P0-A2: market GPS/lead belongs to the scheduled route, NOT a fabricated stop.
-- Additive and backward-compatible: all original stop-linked visits/photos/prospects
-- remain intact. Never delete or rewrite historical fieldwork.
ALTER TABLE public.field_area_visits
 ADD COLUMN IF NOT EXISTS day_route_id uuid REFERENCES public.field_day_routes(id) ON DELETE RESTRICT;
ALTER TABLE public.field_area_visits ALTER COLUMN day_route_stop_id DROP NOT NULL;
DO $fbmn$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='field_area_visit_one_parent') THEN
  ALTER TABLE public.field_area_visits ADD CONSTRAINT field_area_visit_one_parent
   CHECK ((day_route_id IS NULL) <> (day_route_stop_id IS NULL));
 END IF;
END $fbmn$;
CREATE INDEX IF NOT EXISTS field_area_visits_route
 ON public.field_area_visits(day_route_id,checkin_at DESC)
 WHERE day_route_id IS NOT NULL;

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
  AND m.status='planned' AND m.scope_kind IN ('territory','chain')
  AND public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district)
 FOR UPDATE OF r;
 IF NOT FOUND THEN RAISE EXCEPTION 'market visit permission denied'; END IF;
 IF (p_when AT TIME ZONE 'Asia/Ho_Chi_Minh')::date<>route.route_date
 THEN RAISE EXCEPTION 'invalid market visit date'; END IF;
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
REVOKE ALL ON FUNCTION public.sales_save_route_market_visit(
 text,uuid,uuid,timestamptz,double precision,double precision,double precision,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_route_market_visit(
 text,uuid,uuid,timestamptz,double precision,double precision,double precision,text,text,text) TO sales_api;

-- Extend legacy photo, conversion and route guard procedures to both parent shapes.
-- Keep the same signatures so existing Android/PWA clients continue working.
CREATE OR REPLACE FUNCTION public.sales_reserve_area_photo(
 p_actor text,p_visit uuid,p_id uuid,p_kind text,p_captured timestamptz,
 p_bytes integer,p_hash text,p_thumbnail_bytes integer,p_thumbnail_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE visit public.field_area_visits%ROWTYPE;
 old public.field_area_visit_photos%ROWTYPE;
 saved public.field_area_visit_photos%ROWTYPE;
 resource text;
 thumb text;
BEGIN
 IF p_actor IS NULL OR p_visit IS NULL OR p_id IS NULL OR
 p_kind NOT IN ('front','shelf','goods','other') OR
 p_bytes NOT BETWEEN 100 AND 2097152 OR p_thumbnail_bytes NOT BETWEEN 100 AND 153600 OR
 p_hash !~ '^[0-9a-f]{64}$' OR p_thumbnail_hash !~ '^[0-9a-f]{64}$' OR
 p_captured IS NULL OR p_captured>now()+interval '1 minute' OR
 p_captured<now()-interval '30 days'
 THEN RAISE EXCEPTION 'area photo invalid'; END IF;
 SELECT * INTO visit FROM public.field_area_visits WHERE id=p_visit FOR UPDATE;
 IF NOT FOUND OR visit.owner_sub<>p_actor OR
 NOT EXISTS(
  SELECT 1 FROM public.field_day_routes r
   JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
   LEFT JOIN public.field_route_stops st ON st.id=visit.day_route_stop_id
   WHERE r.id=coalesce(visit.day_route_id,st.day_route_id)
    AND r.owner_sub=p_actor AND
    public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district))
 THEN RAISE EXCEPTION 'area photo permission denied'; END IF;
 IF p_captured<visit.checkin_at-interval '1 minute' THEN RAISE EXCEPTION 'area photo invalid time'; END IF;
 resource:='area-visits/'||p_visit::text||'/'||p_id::text||'/'||p_hash;
 thumb:=resource||'/thumb-'||p_thumbnail_hash;
 SELECT * INTO old FROM public.field_area_visit_photos WHERE id=p_id;
 IF FOUND THEN
  IF old.owner_sub<>p_actor OR old.area_visit_id<>p_visit OR old.kind<>p_kind OR
   old.captured_at IS DISTINCT FROM p_captured OR old.sha256<>p_hash OR
   old.bytes<>p_bytes OR old.thumbnail_bytes<>p_thumbnail_bytes OR
   old.thumbnail_sha256<>p_thumbnail_hash
  THEN RAISE EXCEPTION 'area photo conflict'; END IF;
  RETURN to_jsonb(old);
 END IF;
 IF (SELECT count(*) FROM public.field_area_visit_photos WHERE area_visit_id=p_visit)>=12
 THEN RAISE EXCEPTION 'area photo limit'; END IF;
 INSERT INTO public.field_area_visit_photos
  (id,area_visit_id,owner_sub,kind,captured_at,bytes,sha256,object_key,thumbnail_bytes,thumbnail_sha256,thumbnail_key)
 VALUES(p_id,p_visit,p_actor,p_kind,p_captured,p_bytes,p_hash,resource,p_thumbnail_bytes,p_thumbnail_hash,thumb)
 RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END
$fbmn$;

CREATE OR REPLACE FUNCTION public.sales_finalize_area_photo(p_actor text,p_id uuid,p_sha text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE saved public.field_area_visit_photos%ROWTYPE;
BEGIN
 UPDATE public.field_area_visit_photos p SET status='ready'
 WHERE p.id=p_id AND p.owner_sub=p_actor AND p.sha256=p_sha AND
 EXISTS(SELECT 1 FROM public.field_area_visits v
 LEFT JOIN public.field_route_stops st ON st.id=v.day_route_stop_id
 JOIN public.field_day_routes r ON r.id=coalesce(v.day_route_id,st.day_route_id)
 JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
 WHERE v.id=p.area_visit_id AND
 public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district))
 RETURNING * INTO saved;
 IF NOT FOUND THEN RAISE EXCEPTION 'area photo permission denied'; END IF;
 RETURN to_jsonb(saved);
END
$fbmn$;

CREATE OR REPLACE FUNCTION public.sales_convert_prospect(p_actor text,p_id uuid,p_customer uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE found public.field_prospects%ROWTYPE;
 stop_row public.field_route_stops%ROWTYPE;
 visit_row public.field_area_visits%ROWTYPE;
 plan_row public.field_monthly_plans%ROWTYPE;
 customer_row public.customers%ROWTYPE;
BEGIN
 SELECT * INTO found FROM public.field_prospects WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR found.owner_sub<>p_actor THEN RAISE EXCEPTION 'prospect permission denied'; END IF;
 IF found.status='converted' AND found.converted_customer_id=p_customer THEN RETURN to_jsonb(found); END IF;
 IF found.status<>'new' THEN RAISE EXCEPTION 'prospect conflict'; END IF;
 SELECT * INTO visit_row FROM public.field_area_visits WHERE id=found.area_visit_id;
 IF NOT FOUND OR visit_row.owner_sub<>p_actor THEN RAISE EXCEPTION 'prospect permission denied'; END IF;
 SELECT * INTO stop_row FROM public.field_route_stops WHERE id=visit_row.day_route_stop_id;
 SELECT m.* INTO plan_row FROM public.field_monthly_plans m
 JOIN public.field_day_routes r ON r.monthly_plan_id=m.id
 WHERE r.id=coalesce(visit_row.day_route_id,stop_row.day_route_id)
  AND r.owner_sub=p_actor
  AND public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district);
 IF NOT FOUND THEN RAISE EXCEPTION 'prospect permission denied'; END IF;
 SELECT * INTO customer_row FROM public.customers WHERE id=p_customer;
 IF NOT FOUND OR NOT public.sales_customer_plannable(p_actor,p_customer)
 OR NOT public.sales_customer_allowed(p_actor,p_customer,'view') OR
 (stop_row.stop_kind='area' AND
  (customer_row.province IS DISTINCT FROM stop_row.province OR
  (stop_row.district<>'' AND customer_row.district IS DISTINCT FROM stop_row.district))) OR
 (stop_row.stop_kind='chain' AND NOT EXISTS(
  SELECT 1 FROM public.customer_scope_bindings cb WHERE cb.customer_id=p_customer
    AND cb.active AND cb.scope_kind='chain' AND cb.scope_key=stop_row.chain_id::text)) OR
 (visit_row.day_route_id IS NOT NULL AND (
  (plan_row.scope_kind='territory' AND
   (customer_row.province IS DISTINCT FROM plan_row.province OR
    (plan_row.district<>'' AND customer_row.district IS DISTINCT FROM plan_row.district))) OR
  (plan_row.scope_kind='chain' AND NOT EXISTS(
   SELECT 1 FROM public.customer_scope_bindings cb WHERE cb.customer_id=p_customer
    AND cb.active AND cb.scope_kind='chain' AND cb.scope_key=plan_row.scope_key))
 ))
 THEN RAISE EXCEPTION 'prospect permission denied'; END IF;
 UPDATE public.field_prospects SET status='converted',converted_customer_id=p_customer,updated_at=now()
 WHERE id=p_id RETURNING * INTO found;
 INSERT INTO public.field_prospect_events(prospect_id,actor_sub,action,customer_id)
 VALUES(p_id,p_actor,'convert',p_customer);
 RETURN to_jsonb(found);
END
$fbmn$;

CREATE OR REPLACE FUNCTION public.field_guard_area_route_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF (NEW.route_date IS DISTINCT FROM OLD.route_date OR NEW.status='cancelled')
 AND EXISTS(SELECT 1 FROM public.field_area_visits a
 LEFT JOIN public.field_route_stops s ON s.id=a.day_route_stop_id
 WHERE coalesce(a.day_route_id,s.day_route_id)=OLD.id)
 THEN RAISE EXCEPTION 'route already visited'; END IF;
 RETURN NEW;
END $fbmn$;

