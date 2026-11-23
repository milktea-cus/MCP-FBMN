-- 220 | 2026-11-23 | Reconcile normal route customer creation with researched leads.
-- Additive, atomic, permission-checked. Does not synthesize prospect visits/GPS.
-- A converted prospect stays in history; its converted_customer_id links one
-- canonical customer. No existing rows are rewritten by this migration.

CREATE OR REPLACE FUNCTION public.sales_outlet_match_key(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,public AS $fn$
 SELECT regexp_replace(lower(btrim(coalesce(p_value,''))), '[[:space:][:punct:]]', '', 'g');
$fn$;

CREATE OR REPLACE FUNCTION public.sales_outlet_name_key(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path=pg_catalog,public AS $fn$
 SELECT public.sales_outlet_match_key(regexp_replace(
   btrim(coalesce(p_value,'')),
   '^(nhà sách|văn phòng phẩm|vpp|cửa hàng)[[:space:]]+', '', 'i'));
$fn$;

CREATE OR REPLACE FUNCTION public.sales_customer_create_reconcile_prospect(
 p_actor text, p_data jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public AS $fn$
DECLARE
 lead public.field_prospects%ROWTYPE;
 saved public.customers%ROWTYPE;
 v_ref uuid;
 v_name text;
 v_address text;
 v_province text;
 v_district text;
 v_phone text;
 v_name_key text;
 v_address_key text;
 v_phone_key text;
 v_category text;
 v_lat double precision;
 v_lon double precision;
 v_accuracy double precision;
 v_source text;
 v_status text;
 v_note text;
 v_consent boolean;
 v_prospect_id uuid;
BEGIN
 IF p_actor IS NULL OR jsonb_typeof(p_data)<>'object'
   OR nullif(p_data->>'client_ref','') IS NULL
 THEN RAISE EXCEPTION 'customer_reconcile_invalid'; END IF;

 v_ref:=(p_data->>'client_ref')::uuid;
 v_name:=btrim(coalesce(p_data->>'name',''));
 v_address:=btrim(coalesce(p_data->>'address_line',''));
 v_province:=p_data->>'province';
 v_district:=p_data->>'district';
 v_phone:=nullif(btrim(coalesce(p_data->>'phone','')),'');
 v_category:=coalesce(nullif(p_data->>'category',''),'tap_hoa');
 v_status:=coalesce(nullif(p_data->>'status',''),'active');
 v_lat:=nullif(p_data->>'latitude','')::double precision;
 v_lon:=nullif(p_data->>'longitude','')::double precision;
 v_accuracy:=nullif(p_data->>'location_accuracy_m','')::double precision;
 v_consent:=coalesce((p_data->>'location_consent')::boolean,false);
 v_source:=nullif(p_data->>'location_source','');
 v_note:=nullif(btrim(coalesce(p_data->>'note','')),'');
 IF length(v_name)<2 OR length(v_name)>240
    OR length(v_address)<3 OR length(v_address)>500
    OR v_province IS NULL OR v_district IS NULL
    OR v_category NOT IN ('tap_hoa','sieu_thi','dai_ly','npp','nha_sach','van_phong_pham',
       'cua_hang','truong_hoc','khach_le','khac')
    OR v_status NOT IN ('active','inactive','potential')
    OR (v_lat IS NULL) <> (v_lon IS NULL)
    OR (v_lat IS NOT NULL AND (v_lat NOT BETWEEN -90 AND 90
      OR v_lon NOT BETWEEN -180 AND 180 OR NOT v_consent))
    OR (v_source IS NOT NULL AND (v_lat IS NULL OR v_source NOT IN ('gps','manual','map_link')))
    OR (v_accuracy IS NOT NULL AND (v_lat IS NULL OR v_accuracy NOT BETWEEN 0 AND 10000
      OR v_source IS DISTINCT FROM 'gps'))
 THEN RAISE EXCEPTION 'customer_reconcile_invalid'; END IF;
 IF NOT public.sales_can_access(p_actor,p_actor,v_province,v_district)
 THEN RAISE EXCEPTION 'customer_reconcile_forbidden'; END IF;

 v_name_key:=public.sales_outlet_name_key(v_name);
 v_address_key:=public.sales_outlet_match_key(v_address);
 v_phone_key:=nullif(regexp_replace(coalesce(v_phone,''),'[^0-9]','','g'),'');
 -- Lock by geographical outlet identity, not by request UUID. Two assigned
 -- sales synchronizing the same researched store cannot each convert it.
 PERFORM pg_advisory_xact_lock(hashtextextended(
   v_province||'|'||v_district||'|'||v_name_key,0));

 -- A retried offline POST must return the exact first result, without
 -- writing another customer, visit, audit row or lead conversion.
 SELECT * INTO saved FROM public.customers
 WHERE owner_sub=p_actor AND client_ref=v_ref FOR UPDATE;
 IF FOUND THEN
  SELECT p.id INTO v_prospect_id FROM public.field_prospects p
   WHERE p.converted_customer_id=saved.id LIMIT 1;
  RETURN jsonb_build_object('item',to_jsonb(saved),'idempotent',true,
    'converted_from_prospect',v_prospect_id,'reused_existing',false);
 END IF;

 -- High confidence only: same legacy province/district + store name plus
 -- same street address (full or abbreviated prefix), OR a unique matching
 -- telephone for that named store in this district. Never match on name alone.
 SELECT p.* INTO lead
 FROM public.field_prospects p
 WHERE p.province=v_province AND p.district=v_district
   AND p.status IN ('new','converted')
   AND public.sales_market_prospect_allowed(p_actor,p.id)
   AND length(v_name_key)>=4
   AND public.sales_outlet_name_key(p.name)=v_name_key
   AND (
     (
      char_length(v_address_key)>=10
      AND char_length(public.sales_outlet_match_key(p.address_line))>=10
      AND (
       left(public.sales_outlet_match_key(p.address_line),length(v_address_key))=v_address_key
       OR left(v_address_key,length(public.sales_outlet_match_key(p.address_line)))
           =public.sales_outlet_match_key(p.address_line)
      )
     )
     OR (
      v_phone_key IS NOT NULL AND length(v_phone_key)>=9
      AND regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=v_phone_key
      AND (SELECT count(*) FROM public.field_prospects q
        WHERE q.province=v_province AND q.district=v_district
          AND public.sales_outlet_name_key(q.name)=v_name_key
          AND regexp_replace(coalesce(q.phone,''),'[^0-9]','','g')=v_phone_key)=1
     )
   )
 ORDER BY CASE WHEN p.status='converted' THEN 0 ELSE 1 END,
          p.created_at,p.id
 LIMIT 1 FOR UPDATE;

 IF FOUND AND lead.status='converted' THEN
  -- Do not create a second customer just because another sales found the
  -- same store. Existing customer permissions are still enforced.
  SELECT * INTO saved FROM public.customers
  WHERE id=lead.converted_customer_id
    AND public.sales_customer_allowed(p_actor,id,'view');
  IF NOT FOUND THEN RAISE EXCEPTION 'customer_reconcile_existing_forbidden'; END IF;
  RETURN jsonb_build_object('item',to_jsonb(saved),'idempotent',false,
    'converted_from_prospect',lead.id,'reused_existing',true);
 END IF;

 -- Preserve researched source fields when the salesperson has not supplied
 -- them. Keep genuine GPS only from the explicitly confirmed customer form.
 IF lead.id IS NOT NULL THEN
  v_prospect_id:=lead.id;
  IF v_note IS NULL THEN v_note:=left(nullif(lead.note,''),2000); END IF;
  IF v_phone IS NULL THEN v_phone:=lead.phone; END IF;
  IF v_category='tap_hoa' AND lead.category IN ('nha_sach','van_phong_pham')
    THEN v_category:=lead.category; END IF;
 END IF;
 INSERT INTO public.customers
  (client_ref,owner_sub,created_by_sub,name,code,category,contact_name,phone,
   address_line,province,district,latitude,longitude,location_accuracy_m,
   location_consent,location_source,location_recorded_by,location_recorded_at,
   note,status,is_selling,vat_tax_code)
 VALUES
  (v_ref,p_actor,p_actor,v_name,nullif(p_data->>'code',''),v_category,
   nullif(p_data->>'contact_name',''),v_phone,v_address,v_province,v_district,
   v_lat,v_lon,v_accuracy,v_consent,v_source,
   CASE WHEN v_lat IS NOT NULL THEN p_actor ELSE NULL END,
   CASE WHEN v_lat IS NOT NULL THEN now() ELSE NULL END,
   v_note,v_status,false,
   coalesce(nullif(p_data->>'vat_tax_code',''),
            CASE WHEN v_prospect_id IS NOT NULL THEN lead.tax_code ELSE NULL END))
 ON CONFLICT(owner_sub,client_ref) DO NOTHING RETURNING * INTO saved;

 IF NOT FOUND THEN
  SELECT * INTO saved FROM public.customers WHERE owner_sub=p_actor AND client_ref=v_ref;
  IF NOT FOUND THEN RAISE EXCEPTION 'customer_reconcile_conflict'; END IF;
  RETURN jsonb_build_object('item',to_jsonb(saved),'idempotent',true,
    'converted_from_prospect',NULL,'reused_existing',false);
 END IF;

 INSERT INTO public.field_audit_events(actor_sub,action,entity_type,entity_id)
 VALUES(p_actor,'create','customer',saved.id);
 IF v_prospect_id IS NOT NULL THEN
  UPDATE public.field_prospects
   SET status='converted',converted_customer_id=saved.id,
       updated_at=now(),version=version+1
   WHERE id=v_prospect_id AND status='new';
  IF NOT FOUND THEN RAISE EXCEPTION 'customer_reconcile_conflict'; END IF;
  INSERT INTO public.field_prospect_events(prospect_id,actor_sub,action,customer_id)
   VALUES(v_prospect_id,p_actor,'convert',saved.id);
  INSERT INTO public.field_market_prospect_audit(prospect_id,actor_sub,action,customer_id)
   VALUES(v_prospect_id,p_actor,'convert',saved.id);
 END IF;
 RETURN jsonb_build_object('item',to_jsonb(saved),'idempotent',false,
   'converted_from_prospect',v_prospect_id,'reused_existing',false);
END $fn$;

REVOKE ALL ON FUNCTION public.sales_customer_create_reconcile_prospect(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_create_reconcile_prospect(text,jsonb) TO sales_api;
