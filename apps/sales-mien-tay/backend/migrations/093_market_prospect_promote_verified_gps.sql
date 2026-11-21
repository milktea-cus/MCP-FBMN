-- 093: promotion inherits verified check-in coordinates only for newly-created
-- customer records. Existing customer links never overwrite verified GPS.
-- Preserves original lead, photos, visit evidence and is_selling=false.
BEGIN;
CREATE OR REPLACE FUNCTION public.sales_market_prospect_convert(
 p_actor text,p_prospect uuid,p_customer uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE lead public.field_prospects%ROWTYPE;
 customer public.customers%ROWTYPE;
 new_customer uuid;
 position_lat double precision;
 position_lon double precision;
 position_acc double precision;
 position_at timestamptz;
BEGIN
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR lead.owner_sub<>p_actor OR lead.province IS NULL
  OR NOT public.sales_can_access(p_actor,lead.owner_sub,lead.province,lead.district)
 THEN RAISE EXCEPTION 'market_forbidden'; END IF;
 IF lead.status='converted' THEN
  IF p_customer IS NOT NULL AND p_customer<>lead.converted_customer_id
   THEN RAISE EXCEPTION 'market_conflict'; END IF;
  RETURN to_jsonb(lead);
 END IF;
 IF lead.status<>'new' OR (
  NOT EXISTS(SELECT 1 FROM public.field_prospect_visits v WHERE v.prospect_id=p_prospect)
  AND lead.area_visit_id IS NULL
 ) THEN RAISE EXCEPTION 'market_visit_required';END IF;
 IF p_customer IS NOT NULL THEN
  SELECT * INTO customer FROM public.customers WHERE id=p_customer
   AND public.sales_customer_allowed(p_actor,id,'view');
  IF NOT FOUND OR customer.province<>lead.province OR customer.district<>lead.district
  THEN RAISE EXCEPTION 'market_forbidden'; END IF;
  new_customer:=customer.id;
 ELSE
  SELECT v.latitude,v.longitude,v.accuracy_m,v.checked_at
   INTO position_lat,position_lon,position_acc,position_at
  FROM public.field_prospect_visits v
  WHERE v.prospect_id=p_prospect
  ORDER BY v.checked_at DESC,v.id DESC LIMIT 1;
  IF position_lat IS NULL AND lead.area_visit_id IS NOT NULL THEN
   SELECT a.latitude,a.longitude,a.accuracy_m,a.checkin_at
    INTO position_lat,position_lon,position_acc,position_at
   FROM public.field_area_visits a WHERE a.id=lead.area_visit_id;
  END IF;
  INSERT INTO public.customers
   (client_ref,owner_sub,created_by_sub,name,category,contact_name,phone,address_line,
    province,district,note,status,is_selling,vat_tax_code,latitude,longitude,
    location_accuracy_m,location_consent,location_source,location_recorded_by,location_recorded_at)
  VALUES(lead.id,lead.owner_sub,p_actor,lead.name,lead.category,NULL,lead.phone,
   lead.address_line,lead.province,lead.district,lead.note,'potential',FALSE,lead.tax_code,
   position_lat,position_lon,position_acc,position_lat IS NOT NULL,
   CASE WHEN position_lat IS NOT NULL THEN 'gps' ELSE NULL END,
   CASE WHEN position_lat IS NOT NULL THEN p_actor ELSE NULL END,position_at)
  RETURNING id INTO new_customer;
  INSERT INTO public.field_audit_events(actor_sub,action,entity_type,entity_id)
    VALUES(p_actor,'create','customer',new_customer);
 END IF;
 UPDATE public.field_prospects SET status='converted',converted_customer_id=new_customer,
  updated_at=now(),version=version+1 WHERE id=p_prospect RETURNING * INTO lead;
 INSERT INTO public.field_prospect_events(prospect_id,actor_sub,action,customer_id)
  VALUES(p_prospect,p_actor,'convert',new_customer);
 INSERT INTO public.field_market_prospect_audit(prospect_id,actor_sub,action,customer_id)
  VALUES(p_prospect,p_actor,'convert',new_customer);
 RETURN to_jsonb(lead);
END $fn$;
REVOKE ALL ON FUNCTION public.sales_market_prospect_convert(text,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_convert(text,uuid,uuid) TO sales_api;
COMMIT;
