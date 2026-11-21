-- 095: Publicly researched prospects are common territory opportunities.
-- No cross-province disclosure: staff must be active, possess real territory
-- permission, and record must bear server-imported source provenance.
-- Preserve owner-owned and manager/subtree private leads; never assign
-- Sales territories implicitly. All writes enforce the same ACL in DB.
BEGIN;
CREATE OR REPLACE FUNCTION public.sales_market_prospect_allowed(p_actor text,p_prospect uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public' AS $acl$
 SELECT EXISTS(
  SELECT 1 FROM public.staff_members a
  JOIN public.field_prospects p ON p.id=p_prospect
  WHERE a.user_sub=p_actor AND a.active AND public.sales_identity_exists(a.user_sub)
   AND p.province IS NOT NULL AND (
    a.role='admin'
    OR (
      public.sales_can_access(p_actor,p_actor,p.province,p.district)
      AND (
        p.owner_sub=p_actor
        OR (a.role='manager' AND public.sales_staff_in_subtree(p_actor,p.owner_sub))
        OR (
          p.research_source_key IS NOT NULL
          AND p.research_source_url IS NOT NULL
          AND p.research_batch IS NOT NULL
        )
      )
    )
   )
 );
$acl$;
REVOKE ALL ON FUNCTION public.sales_market_prospect_allowed(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_allowed(text,uuid) TO sales_api;
CREATE OR REPLACE FUNCTION public.sales_market_prospect_update(p_actor text, p_prospect uuid, p_version integer, p_name text, p_address text, p_category text, p_phone text, p_tax text, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE lead public.field_prospects%ROWTYPE;
BEGIN
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR NOT public.sales_market_prospect_allowed(p_actor,p_prospect)
 THEN RAISE EXCEPTION 'market_forbidden'; END IF;
 IF lead.status<>'new' OR lead.version<>p_version THEN
   RAISE EXCEPTION 'market_conflict';END IF;
 IF length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 240 OR
  length(btrim(coalesce(p_address,''))) NOT BETWEEN 3 AND 500 OR
  p_category NOT IN ('tap_hoa','sieu_thi','dai_ly','npp','nha_sach','van_phong_pham','cua_hang','khac') OR
  (p_phone IS NOT NULL AND length(p_phone) NOT BETWEEN 8 AND 20) OR
  (p_tax IS NOT NULL AND p_tax !~ '^[0-9]{10}([0-9]{3})?$') OR
  length(coalesce(p_note,''))>2000
 THEN RAISE EXCEPTION 'market_invalid';END IF;
 UPDATE public.field_prospects
 SET name=btrim(p_name),address_line=btrim(p_address),category=p_category,
  phone=p_phone,tax_code=p_tax,note=coalesce(p_note,''),
  updated_at=now(),version=version+1
 WHERE id=p_prospect RETURNING * INTO lead;
 RETURN to_jsonb(lead);
END $function$
;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_visit(p_actor text, p_prospect uuid, p_ref uuid, p_checked timestamp with time zone, p_lat double precision, p_lon double precision, p_accuracy double precision, p_note text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE lead public.field_prospects%ROWTYPE;
 saved public.field_prospect_visits%ROWTYPE;
BEGIN
 IF p_ref IS NULL OR p_prospect IS NULL OR p_checked IS NULL OR
   p_checked < now()-interval '30 days' OR p_checked > now()+interval '1 minute'
   OR p_lat NOT BETWEEN -90 AND 90 OR p_lon NOT BETWEEN -180 AND 180 OR
   p_accuracy NOT BETWEEN 0 AND 100 OR length(coalesce(p_note,''))>2000
 THEN RAISE EXCEPTION 'market_invalid'; END IF;
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR NOT public.sales_market_prospect_allowed(p_actor,p_prospect)
 THEN RAISE EXCEPTION 'market_forbidden'; END IF;
 SELECT * INTO saved FROM public.field_prospect_visits WHERE id=p_ref;
 IF FOUND THEN
  IF saved.prospect_id<>p_prospect OR saved.owner_sub<>p_actor OR
    saved.checked_at IS DISTINCT FROM p_checked OR
    saved.latitude IS DISTINCT FROM p_lat OR saved.longitude IS DISTINCT FROM p_lon OR
    saved.accuracy_m IS DISTINCT FROM p_accuracy OR saved.note<>coalesce(p_note,'')
  THEN RAISE EXCEPTION 'market_conflict';END IF;
  RETURN to_jsonb(saved);
 END IF;
 IF lead.status<>'new' THEN RAISE EXCEPTION 'market_conflict';END IF;
 INSERT INTO public.field_prospect_visits(id,prospect_id,owner_sub,checked_at,latitude,longitude,accuracy_m,note)
 VALUES(p_ref,p_prospect,p_actor,p_checked,p_lat,p_lon,p_accuracy,coalesce(p_note,''))
 RETURNING * INTO saved;
 UPDATE public.field_prospects SET last_visit_at=p_checked,
   last_visit_latitude=p_lat,last_visit_longitude=p_lon,
   updated_at=now(),version=version+1 WHERE id=p_prospect;
 INSERT INTO public.field_market_prospect_audit(prospect_id,actor_sub,action)
 VALUES(p_prospect,p_actor,'visit');
 RETURN to_jsonb(saved);
END $function$
;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_close(p_actor text, p_prospect uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE lead public.field_prospects%ROWTYPE;
BEGIN
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR NOT public.sales_market_prospect_allowed(p_actor,p_prospect)
 THEN RAISE EXCEPTION 'market_forbidden'; END IF;
 IF lead.status='closed' THEN RETURN to_jsonb(lead);END IF;
 IF lead.status='converted' THEN RAISE EXCEPTION 'market_conflict'; END IF;
 UPDATE public.field_prospects SET status='closed',updated_at=now(),version=version+1
 WHERE id=p_prospect RETURNING * INTO lead;
 INSERT INTO public.field_market_prospect_audit(prospect_id,actor_sub,action)
 VALUES(p_prospect,p_actor,'close');
 RETURN to_jsonb(lead);
END $function$
;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_convert(p_actor text, p_prospect uuid, p_customer uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE lead public.field_prospects%ROWTYPE;
 customer public.customers%ROWTYPE;
 new_customer uuid;
 position_lat double precision;
 position_lon double precision;
 position_acc double precision;
 position_at timestamptz;
BEGIN
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR NOT public.sales_market_prospect_allowed(p_actor,p_prospect)
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
  VALUES(lead.id,CASE WHEN lead.research_source_key IS NOT NULL THEN p_actor ELSE lead.owner_sub END,p_actor,lead.name,lead.category,NULL,lead.phone,
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
END $function$
;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_reserve_photo(p_actor text, p_prospect uuid, p_id uuid, p_kind text, p_captured timestamp with time zone, p_bytes integer, p_hash text, p_thumb_bytes integer, p_thumb_hash text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE lead public.field_prospects%ROWTYPE;
 saved public.field_market_prospect_photos%ROWTYPE;
 key text;
BEGIN
 IF p_id IS NULL OR p_prospect IS NULL OR p_kind NOT IN ('front','shelf','goods','other')
  OR p_captured IS NULL OR p_captured<now()-interval '30 days' OR p_captured>now()+interval '1 minute'
  OR p_bytes NOT BETWEEN 100 AND 2097152 OR p_thumb_bytes NOT BETWEEN 100 AND 153600
  OR p_hash !~ '^[a-f0-9]{64}$' OR p_thumb_hash !~ '^[a-f0-9]{64}$'
 THEN RAISE EXCEPTION 'market_photo_invalid';END IF;
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR NOT public.sales_market_prospect_allowed(p_actor,p_prospect)
 THEN RAISE EXCEPTION 'market_photo_forbidden';END IF;
 SELECT * INTO saved FROM public.field_market_prospect_photos WHERE id=p_id;
 IF FOUND THEN
  IF saved.prospect_id<>p_prospect OR saved.owner_sub<>p_actor OR saved.kind<>p_kind OR
   saved.captured_at IS DISTINCT FROM p_captured OR saved.bytes<>p_bytes OR
   saved.sha256<>p_hash OR saved.thumbnail_bytes<>p_thumb_bytes OR
   saved.thumbnail_sha256<>p_thumb_hash
  THEN RAISE EXCEPTION 'market_photo_conflict';END IF;
  RETURN to_jsonb(saved);
 END IF;
 IF lead.status<>'new' THEN RAISE EXCEPTION 'market_photo_conflict';END IF;
 IF (SELECT count(*) FROM public.field_market_prospect_photos WHERE prospect_id=p_prospect)>=12
 THEN RAISE EXCEPTION 'market_photo_limit';END IF;
 key:='market-prospects/'||p_prospect::text||'/'||p_id::text;
 INSERT INTO public.field_market_prospect_photos(id,prospect_id,owner_sub,kind,
  captured_at,object_key,thumbnail_key,bytes,sha256,thumbnail_bytes,thumbnail_sha256)
 VALUES(p_id,p_prospect,p_actor,p_kind,p_captured,key,key||'/thumbnail',
  p_bytes,p_hash,p_thumb_bytes,p_thumb_hash)
 RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $function$
;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_finalize_photo(p_actor text, p_id uuid, p_sha text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE saved public.field_market_prospect_photos%ROWTYPE;
BEGIN
 UPDATE public.field_market_prospect_photos p SET status='ready'
 WHERE p.id=p_id AND p.owner_sub=p_actor AND p.sha256=p_sha
   AND EXISTS(SELECT 1 FROM public.field_prospects l
     WHERE l.id=p.prospect_id AND public.sales_market_prospect_allowed(p_actor,l.id))
 RETURNING * INTO saved;
 IF NOT FOUND THEN RAISE EXCEPTION 'market_photo_forbidden';END IF;
 RETURN to_jsonb(saved);
END $function$
;
COMMIT;
