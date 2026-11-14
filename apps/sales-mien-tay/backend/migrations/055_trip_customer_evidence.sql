-- P0-T2: preserve route/customer evidence and extend write authorization to trips.
ALTER TABLE public.field_customer_work_actions
 ADD COLUMN IF NOT EXISTS trip_id uuid REFERENCES public.field_trips(id) ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS field_customer_work_trip_date ON public.field_customer_work_actions(trip_id,captured_at DESC)
 WHERE trip_id IS NOT NULL;
CREATE OR REPLACE FUNCTION public.field_customer_work_trip_link()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF NEW.trip_id IS NULL THEN
  SELECT id INTO NEW.trip_id FROM public.field_trips WHERE day_route_id=NEW.day_route_id;
 END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS field_customer_work_trip_link_trigger ON public.field_customer_work_actions;
CREATE TRIGGER field_customer_work_trip_link_trigger BEFORE INSERT ON public.field_customer_work_actions
 FOR EACH ROW EXECUTE FUNCTION public.field_customer_work_trip_link();

CREATE OR REPLACE FUNCTION public.sales_work_session_write_allowed(p_actor text,p_route uuid,p_event timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE t public.field_trips%ROWTYPE; w public.field_work_sessions%ROWTYPE;
BEGIN
 SELECT * INTO t FROM public.field_trips WHERE day_route_id=p_route AND owner_sub=p_actor;
 IF t.id IS NOT NULL THEN
  RETURN p_event IS NOT NULL AND
   (p_event AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN t.start_date AND t.end_date
   AND (t.closed_at IS NULL OR p_event<=t.closed_at);
 END IF;
 SELECT * INTO w FROM public.field_work_sessions WHERE day_route_id=p_route AND owner_sub=p_actor;
 IF w.id IS NULL THEN RETURN true; END IF;
 IF w.state='ongoing' THEN RETURN true; END IF;
 RETURN p_event IS NOT NULL AND p_event>=w.opened_at-interval '1 minute' AND p_event<=w.ended_at;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_work_session_write_allowed(text,uuid,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_work_session_write_allowed(text,uuid,timestamptz) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_add_trip_customer_stop(
 p_actor text,p_trip uuid,p_ref uuid,p_customer uuid,p_sequence integer,p_purpose text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE t public.field_trips%ROWTYPE; old public.field_route_stops%ROWTYPE;
 saved public.field_route_stops%ROWTYPE;
BEGIN
 IF p_trip IS NULL OR p_ref IS NULL OR p_customer IS NULL OR
 p_sequence NOT BETWEEN 1 AND 9999 OR length(coalesce(p_purpose,''))>500
 OR p_at IS NULL OR p_at>now()+interval '1 minute' OR p_at<now()-interval '30 days'
 THEN RAISE EXCEPTION 'TRIP_INVALID'; END IF;
 SELECT * INTO t FROM public.field_trips WHERE id=p_trip FOR UPDATE;
 IF NOT FOUND OR t.owner_sub<>p_actor OR (t.closed_at IS NOT NULL AND p_at>t.closed_at) OR
 (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date NOT BETWEEN t.start_date AND t.end_date OR
 NOT public.sales_trip_customer_allowed(p_actor,t.id,p_customer)
 THEN RAISE EXCEPTION 'TRIP_SCOPE_REVOKED'; END IF;
 SELECT * INTO old FROM public.field_route_stops WHERE id=p_ref FOR UPDATE;
 IF FOUND THEN
  IF old.day_route_id=t.day_route_id AND old.customer_id=p_customer
   AND old.owner_sub=p_actor AND old.stop_kind='customer' AND old.is_unplanned
   AND old.sequence=p_sequence AND old.purpose=coalesce(p_purpose,'')
  THEN RETURN to_jsonb(old)||jsonb_build_object('already_saved',true); END IF;
  RAISE EXCEPTION 'TRIP_MUTATION_REPLAY_MISMATCH';
 END IF;
 IF EXISTS(SELECT 1 FROM public.field_route_stops s
  WHERE s.day_route_id=t.day_route_id AND s.customer_id=p_customer)
 THEN RAISE EXCEPTION 'TRIP_CUSTOMER_ALREADY_ADDED'; END IF;
 INSERT INTO public.field_route_stops(id,day_route_id,owner_sub,stop_kind,customer_id,sequence,purpose,
  last_mutation_ref,is_unplanned)
 VALUES(p_ref,t.day_route_id,p_actor,'customer',p_customer,p_sequence,coalesce(p_purpose,''),p_ref,true)
 RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_add_trip_customer_stop(text,uuid,uuid,uuid,integer,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_add_trip_customer_stop(text,uuid,uuid,uuid,integer,text,timestamptz) TO sales_api;


-- Single existing customer-work flow accepts trip days and scopes.
CREATE OR REPLACE FUNCTION public.sales_save_customer_work(
 p_actor text,p_ref uuid,p_route uuid,p_stop uuid,p_customer uuid,
 p_kind text,p_template uuid,p_answers jsonb,p_brands jsonb,
 p_note text,p_at timestamptz
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
DECLARE
 existing public.field_customer_work_actions%ROWTYPE;
 saved public.field_customer_work_actions%ROWTYPE;
 area record;
 item jsonb; normalized text; brand uuid;
BEGIN
 IF p_actor IS NULL OR p_ref IS NULL OR p_route IS NULL OR p_stop IS NULL
  OR p_customer IS NULL OR p_kind NOT IN ('form','photo','order')
  OR p_at IS NULL OR p_at>now()+interval '1 minute'
  OR p_at<now()-interval '30 days' OR length(coalesce(p_note,''))>2000
  OR p_answers IS NULL OR jsonb_typeof(p_answers)<>'object'
  OR (p_brands IS NOT NULL AND
   (jsonb_typeof(p_brands)<>'array' OR jsonb_array_length(p_brands)>50))
  OR (p_kind='form' AND length(btrim(coalesce(p_note,'')))=0 AND
   p_answers='{}'::jsonb AND p_brands IS NULL)
 THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.staff_members staff WHERE staff.user_sub=p_actor AND staff.active
  AND public.sales_identity_exists(staff.user_sub))
  OR NOT public.sales_customer_fieldwork_allowed(p_actor,p_customer)
 THEN RAISE EXCEPTION 'CUSTOMER_WORK_FORBIDDEN'; END IF;
 SELECT a.* INTO existing FROM public.field_customer_work_actions a WHERE a.id=p_ref;
 IF FOUND THEN
  IF existing.owner_sub=p_actor AND existing.day_route_id=p_route
   AND existing.route_stop_id=p_stop AND existing.customer_id=p_customer
   AND existing.kind=p_kind AND existing.template_id IS NOT DISTINCT FROM p_template
   AND existing.answers=p_answers AND existing.market_brand_names IS NOT DISTINCT FROM p_brands
   AND existing.note=coalesce(p_note,'') AND existing.captured_at=p_at
  THEN RETURN to_jsonb(existing)||jsonb_build_object('already_saved',true); END IF;
  RAISE EXCEPTION 'CUSTOMER_WORK_CONFLICT';
 END IF;
 SELECT r.id,r.route_date,r.owner_sub,p.status AS plan_status,p.scope_kind,p.scope_key,
  p.province,p.district INTO area
 FROM public.field_day_routes r
 JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
 WHERE r.id=p_route AND r.owner_sub=p_actor
  AND r.status='ready' AND p.status='planned'
  AND public.sales_work_session_write_allowed(p_actor,r.id,p_at)
  AND public.sales_monthly_plan_scope_allowed(p_actor,p.scope_kind,p.scope_key,p.province,p.district)
  AND public.sales_customer_fieldwork_allowed(p_actor,p_customer)
  AND (
    ((p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=r.route_date
      AND NOT EXISTS(SELECT 1 FROM public.field_trips t WHERE t.day_route_id=r.id))
    OR EXISTS(SELECT 1 FROM public.field_trips t WHERE t.day_route_id=r.id
      AND (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date BETWEEN t.start_date AND t.end_date
      AND (t.closed_at IS NULL OR p_at<=t.closed_at)
      AND public.sales_trip_customer_allowed(p_actor,t.id,p_customer))
   )
  AND EXISTS(SELECT 1 FROM public.field_route_stops st WHERE st.id=p_stop
    AND st.day_route_id=r.id AND st.customer_id=p_customer AND st.stop_kind='customer'
    AND st.missed_code IS NULL)
 LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'CUSTOMER_WORK_FORBIDDEN'; END IF;
 IF p_template IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM public.field_survey_templates t
   JOIN public.customers c ON c.id=p_customer
   WHERE t.id=p_template AND t.province=c.province)
 THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
 IF p_kind='form' AND p_template IS NULL AND p_answers<>'{}'::jsonb
 THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
 IF p_kind='photo' THEN
  IF coalesce(p_answers->>'photo_id','') !~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
   OR NOT EXISTS(SELECT 1 FROM public.customer_photos ph
    WHERE ph.id=(p_answers->>'photo_id')::uuid AND ph.customer_id=p_customer)
  THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
 END IF;
 IF p_kind='order' THEN
  IF coalesce(p_answers->>'order_id','') !~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
   OR NOT EXISTS(SELECT 1 FROM public.field_orders o
    WHERE o.id=(p_answers->>'order_id')::uuid AND o.customer_id=p_customer
      AND o.owner_sub=p_actor AND o.status NOT IN ('cancelled','superseded'))
  THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
 END IF;
 IF p_brands IS NOT NULL THEN
  IF p_template IS NULL THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(p_brands) LOOP
   IF jsonb_typeof(item)<>'string' THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
   normalized=regexp_replace(btrim(item #>> '{}'),'[[:space:]]+',' ','g');
   IF length(normalized) NOT BETWEEN 1 AND 100 OR normalized ~ '[[:cntrl:]]'
   THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.field_survey_templates t
     WHERE t.id=p_template AND EXISTS(
      SELECT 1 FROM jsonb_array_elements(t.questions) q
       WHERE q->>'catalog_source'='brands' AND
        (q->'options') ? normalized
     ))
   THEN RAISE EXCEPTION 'CUSTOMER_WORK_INVALID'; END IF;
  END LOOP;
 END IF;
 INSERT INTO public.field_customer_work_actions(
  id,day_route_id,route_stop_id,customer_id,owner_sub,kind,template_id,
  answers,market_brand_names,note,captured_at)
 VALUES(p_ref,p_route,p_stop,p_customer,p_actor,p_kind,p_template,
  p_answers,p_brands,coalesce(p_note,''),p_at)
 RETURNING * INTO saved;
 IF p_brands IS NOT NULL THEN
  FOR item IN SELECT DISTINCT value FROM jsonb_array_elements(p_brands) LOOP
   normalized=regexp_replace(btrim(item #>> '{}'),'[[:space:]]+',' ','g');
   INSERT INTO public.market_brands(name) VALUES(normalized)
    ON CONFLICT(normalized_name) DO NOTHING;
   SELECT id INTO brand FROM public.market_brands
    WHERE normalized_name=lower(normalized);
   IF brand IS NULL THEN
    RAISE EXCEPTION 'CUSTOMER_WORK_INVALID';
   END IF;
   INSERT INTO public.market_customer_work_brands(
    customer_id,brand_id,present,first_seen_at,last_seen_at,last_action_id,updated_by)
   VALUES(p_customer,brand,true,p_at,p_at,p_ref,p_actor)
   ON CONFLICT(customer_id,brand_id) DO UPDATE SET
    present=true,last_seen_at=EXCLUDED.last_seen_at,
    last_action_id=EXCLUDED.last_action_id,updated_by=EXCLUDED.updated_by
   WHERE public.market_customer_work_brands.last_seen_at<=EXCLUDED.last_seen_at;
  END LOOP;
  UPDATE public.market_customer_work_brands current SET
   present=false,last_seen_at=p_at,last_action_id=p_ref,updated_by=p_actor
  WHERE current.customer_id=p_customer AND current.present
   AND current.last_seen_at<=p_at
   AND NOT EXISTS(
     SELECT 1 FROM jsonb_array_elements_text(p_brands) chosen
     JOIN public.market_brands b ON b.normalized_name=lower(
       regexp_replace(btrim(chosen.value),'[[:space:]]+',' ','g'))
     WHERE b.id=current.brand_id);
 END IF;
 RETURN to_jsonb(saved);
END $fbmn$;
