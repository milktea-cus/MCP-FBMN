-- P0-L3: GPS evidence at real business stops and prospects (not fake customers).
CREATE TABLE IF NOT EXISTS public.field_area_visits (
 id uuid PRIMARY KEY,
 day_route_stop_id uuid NOT NULL REFERENCES public.field_route_stops(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 checkin_at timestamptz NOT NULL,
 latitude double precision NOT NULL CHECK(latitude BETWEEN -90 AND 90),
 longitude double precision NOT NULL CHECK(longitude BETWEEN -180 AND 180),
 accuracy_m double precision NOT NULL CHECK(accuracy_m BETWEEN 0 AND 100),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=2000),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(owner_sub,id)
);
CREATE INDEX IF NOT EXISTS field_area_visits_stop ON public.field_area_visits(day_route_stop_id,checkin_at DESC);
CREATE TABLE IF NOT EXISTS public.field_prospects (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 area_visit_id uuid NOT NULL UNIQUE REFERENCES public.field_area_visits(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 240),
 address_line text NOT NULL CHECK(length(btrim(address_line)) BETWEEN 3 AND 500),
 status text NOT NULL DEFAULT 'new' CHECK(status IN ('new','converted','closed')),
 converted_customer_id uuid REFERENCES public.customers(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_prospects_owner ON public.field_prospects(owner_sub,created_at DESC);
CREATE OR REPLACE FUNCTION public.sales_customer_fieldwork_allowed(p_actor text,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
 SELECT public.sales_customer_plannable(p_actor,p_customer)
 AND public.sales_customer_allowed(p_actor,p_customer,'view');
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_customer_fieldwork_allowed(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_fieldwork_allowed(text,uuid) TO sales_api;

-- Route and visit permission are checked inside an atomic DB writer, not only at the API.
CREATE OR REPLACE FUNCTION public.sales_save_area_visit(
 p_actor text,p_ref uuid,p_stop uuid,p_when timestamptz,
 p_lat double precision,p_lon double precision,p_accuracy double precision,
 p_note text,p_lead_name text,p_lead_address text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE prior public.field_area_visits%ROWTYPE;
        saved public.field_area_visits%ROWTYPE;
        prospect_id uuid;
BEGIN
 IF p_ref IS NULL OR p_stop IS NULL OR p_when IS NULL OR
  p_lat NOT BETWEEN -90 AND 90 OR p_lon NOT BETWEEN -180 AND 180 OR
  p_accuracy NOT BETWEEN 0 AND 100 OR length(coalesce(p_note,''))>2000 OR
  p_when>now()+interval '1 minute' OR p_when<now()-interval '30 days'
 THEN RAISE EXCEPTION 'invalid area visit'; END IF;
 SELECT * INTO prior FROM public.field_area_visits WHERE id=p_ref;
 IF FOUND THEN
  IF prior.owner_sub<>p_actor OR prior.day_route_stop_id<>p_stop
  OR prior.latitude IS DISTINCT FROM p_lat OR prior.longitude IS DISTINCT FROM p_lon
  OR prior.accuracy_m IS DISTINCT FROM p_accuracy OR prior.checkin_at IS DISTINCT FROM p_when
  THEN RAISE EXCEPTION 'visit ref conflict'; END IF;
  RETURN to_jsonb(prior);
 END IF;
 IF (p_lead_name IS NULL) <> (p_lead_address IS NULL) OR
   (p_lead_name IS NOT NULL AND
    (length(btrim(p_lead_name)) NOT BETWEEN 2 AND 240
      OR length(btrim(p_lead_address)) NOT BETWEEN 3 AND 500))
 THEN RAISE EXCEPTION 'invalid prospect'; END IF;
 IF NOT EXISTS(
  SELECT 1 FROM public.field_route_stops s
  JOIN public.field_day_routes r ON r.id=s.day_route_id
  JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
  WHERE s.id=p_stop AND s.owner_sub=p_actor AND s.stop_kind IN ('area','chain')
    AND r.owner_sub=p_actor AND r.status='ready' AND p.status='planned'
    AND (p_when AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=r.route_date
    AND public.sales_monthly_plan_scope_allowed(p_actor,p.scope_kind,p.scope_key,p.province,p.district))
 THEN RAISE EXCEPTION 'area visit permission denied'; END IF;
 INSERT INTO public.field_area_visits(id,day_route_stop_id,owner_sub,checkin_at,
  latitude,longitude,accuracy_m,note)
 VALUES(p_ref,p_stop,p_actor,p_when,p_lat,p_lon,p_accuracy,coalesce(p_note,''))
 ON CONFLICT(id) DO NOTHING RETURNING * INTO saved;
 IF NOT FOUND THEN RAISE EXCEPTION 'visit ref conflict'; END IF;
 IF p_lead_name IS NOT NULL THEN
  INSERT INTO public.field_prospects(area_visit_id,owner_sub,name,address_line)
   VALUES(p_ref,p_actor,btrim(p_lead_name),btrim(p_lead_address))
   RETURNING id INTO prospect_id;
 END IF;
 RETURN to_jsonb(saved)||jsonb_build_object('prospect_id',prospect_id);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_area_visit(text,uuid,uuid,timestamptz,double precision,double precision,double precision,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_area_visit(text,uuid,uuid,timestamptz,double precision,double precision,double precision,text,text,text) TO sales_api;
GRANT SELECT ON public.field_area_visits,public.field_prospects TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_area_visits,public.field_prospects FROM sales_api;
-- Existing field_visits and survey sessions retain their own original security.
