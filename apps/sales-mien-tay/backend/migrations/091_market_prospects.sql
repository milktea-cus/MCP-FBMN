-- 091: standalone potential stores; extend the existing prospect ledger rather than
-- duplicating prospects from daily routes. Additive only; zero historical edits.
BEGIN;
ALTER TABLE public.field_prospects ALTER COLUMN area_visit_id DROP NOT NULL;
ALTER TABLE public.field_prospects
  ADD COLUMN IF NOT EXISTS province text,
  ADD COLUMN IF NOT EXISTS district text,
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'khac',
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS tax_code text,
  ADD COLUMN IF NOT EXISTS note text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS school_id uuid REFERENCES public.schools(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS source_kind text NOT NULL DEFAULT 'route',
  ADD COLUMN IF NOT EXISTS last_visit_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_visit_latitude double precision,
  ADD COLUMN IF NOT EXISTS last_visit_longitude double precision,
  ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE public.field_prospects
  ADD CONSTRAINT field_market_prospects_category_check CHECK (
   category IN ('tap_hoa','sieu_thi','dai_ly','npp','nha_sach','van_phong_pham','cua_hang','khac')),
  ADD CONSTRAINT field_market_prospects_source_check CHECK (source_kind IN ('route','manual','school')),
  ADD CONSTRAINT field_market_prospects_tax_check CHECK (tax_code IS NULL OR tax_code ~ '^[0-9]{10}([0-9]{3})?$'),
  ADD CONSTRAINT field_market_prospects_version_check CHECK (version>0);
CREATE INDEX IF NOT EXISTS field_market_prospects_geo ON public.field_prospects(province,district,status,created_at DESC);
CREATE INDEX IF NOT EXISTS field_market_prospects_tax ON public.field_prospects(tax_code) WHERE tax_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.field_prospect_visits(
 id uuid PRIMARY KEY,
 prospect_id uuid NOT NULL REFERENCES public.field_prospects(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 checked_at timestamptz NOT NULL,
 latitude double precision NOT NULL CHECK(latitude BETWEEN -90 AND 90),
 longitude double precision NOT NULL CHECK(longitude BETWEEN -180 AND 180),
 accuracy_m double precision NOT NULL CHECK(accuracy_m BETWEEN 0 AND 100),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=2000),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_prospect_visits_lead ON public.field_prospect_visits(prospect_id,checked_at DESC);

CREATE TABLE IF NOT EXISTS public.field_market_prospect_audit(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 prospect_id uuid NOT NULL REFERENCES public.field_prospects(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK(action IN ('create','visit','close','convert')),
 customer_id uuid REFERENCES public.customers(id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_market_prospect_audit_lead ON public.field_market_prospect_audit(prospect_id,created_at DESC);

CREATE OR REPLACE FUNCTION public.sales_market_prospect_create(
 p_actor text,p_ref uuid,p_name text,p_address text,p_province text,p_district text,
 p_category text,p_phone text,p_tax text,p_note text,p_school uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE saved public.field_prospects%ROWTYPE;
BEGIN
 IF p_ref IS NULL OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 240
  OR length(btrim(coalesce(p_address,''))) NOT BETWEEN 3 AND 500
  OR p_province IS NULL OR p_district IS NULL
  OR p_category NOT IN ('tap_hoa','sieu_thi','dai_ly','npp','nha_sach','van_phong_pham','cua_hang','khac')
  OR length(coalesce(p_note,''))>2000
  OR (p_phone IS NOT NULL AND (length(p_phone)>20 OR length(p_phone)<8))
  OR (p_tax IS NOT NULL AND p_tax !~ '^[0-9]{10}([0-9]{3})?$')
 THEN RAISE EXCEPTION 'market_invalid'; END IF;
 IF NOT public.sales_can_access(p_actor,p_actor,p_province,p_district) OR
   NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor AND s.active)
 THEN RAISE EXCEPTION 'market_forbidden'; END IF;
 IF p_school IS NOT NULL AND NOT EXISTS(
   SELECT 1 FROM public.schools s WHERE s.id=p_school
    AND s.province_old=p_province AND s.district_old=p_district
 ) THEN RAISE EXCEPTION 'market_school_mismatch'; END IF;
 INSERT INTO public.field_prospects
   (id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,school_id,source_kind)
 VALUES(p_ref,NULL,p_actor,btrim(p_name),btrim(p_address),p_province,p_district,p_category,
   p_phone,p_tax,coalesce(p_note,''),p_school,CASE WHEN p_school IS NULL THEN 'manual' ELSE 'school' END)
 ON CONFLICT(id) DO NOTHING RETURNING * INTO saved;
 IF FOUND THEN
  INSERT INTO public.field_market_prospect_audit(prospect_id,actor_sub,action)
  VALUES(saved.id,p_actor,'create');
 ELSE
  SELECT * INTO saved FROM public.field_prospects WHERE id=p_ref;
  IF NOT FOUND OR saved.owner_sub<>p_actor OR saved.area_visit_id IS NOT NULL OR
    saved.name<>btrim(p_name) OR saved.address_line<>btrim(p_address) OR
    saved.province IS DISTINCT FROM p_province OR saved.district IS DISTINCT FROM p_district OR
    saved.category<>p_category OR saved.phone IS DISTINCT FROM p_phone OR
    saved.tax_code IS DISTINCT FROM p_tax OR saved.note<>coalesce(p_note,'') OR
    saved.school_id IS DISTINCT FROM p_school
  THEN RAISE EXCEPTION 'market_conflict'; END IF;
 END IF;
 RETURN to_jsonb(saved);
END $fn$;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_visit(
 p_actor text,p_prospect uuid,p_ref uuid,p_checked timestamptz,
 p_lat double precision,p_lon double precision,p_accuracy double precision,p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE lead public.field_prospects%ROWTYPE;
 saved public.field_prospect_visits%ROWTYPE;
BEGIN
 IF p_ref IS NULL OR p_prospect IS NULL OR p_checked IS NULL OR
   p_checked < now()-interval '30 days' OR p_checked > now()+interval '1 minute'
   OR p_lat NOT BETWEEN -90 AND 90 OR p_lon NOT BETWEEN -180 AND 180 OR
   p_accuracy NOT BETWEEN 0 AND 100 OR length(coalesce(p_note,''))>2000
 THEN RAISE EXCEPTION 'market_invalid'; END IF;
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR lead.owner_sub<>p_actor OR lead.province IS NULL OR
   NOT public.sales_can_access(p_actor,lead.owner_sub,lead.province,lead.district)
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
END $fn$;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_close(p_actor text,p_prospect uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE lead public.field_prospects%ROWTYPE;
BEGIN
 SELECT * INTO lead FROM public.field_prospects WHERE id=p_prospect FOR UPDATE;
 IF NOT FOUND OR lead.owner_sub<>p_actor OR lead.province IS NULL
  OR NOT public.sales_can_access(p_actor,lead.owner_sub,lead.province,lead.district)
 THEN RAISE EXCEPTION 'market_forbidden'; END IF;
 IF lead.status='closed' THEN RETURN to_jsonb(lead);END IF;
 IF lead.status='converted' THEN RAISE EXCEPTION 'market_conflict'; END IF;
 UPDATE public.field_prospects SET status='closed',updated_at=now(),version=version+1
 WHERE id=p_prospect RETURNING * INTO lead;
 INSERT INTO public.field_market_prospect_audit(prospect_id,actor_sub,action)
 VALUES(p_prospect,p_actor,'close');
 RETURN to_jsonb(lead);
END $fn$;

CREATE OR REPLACE FUNCTION public.sales_market_prospect_convert(
 p_actor text,p_prospect uuid,p_customer uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
DECLARE lead public.field_prospects%ROWTYPE;
 customer public.customers%ROWTYPE;
 new_customer uuid;
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
 IF lead.status<>'new' OR NOT EXISTS(
  SELECT 1 FROM public.field_prospect_visits v WHERE v.prospect_id=p_prospect
 ) THEN RAISE EXCEPTION 'market_visit_required';END IF;
 IF p_customer IS NOT NULL THEN
  SELECT * INTO customer FROM public.customers WHERE id=p_customer
    AND public.sales_customer_allowed(p_actor,id,'view');
  IF NOT FOUND OR customer.province<>lead.province OR customer.district<>lead.district
  THEN RAISE EXCEPTION 'market_forbidden'; END IF;
  new_customer:=customer.id;
 ELSE
  INSERT INTO public.customers
    (client_ref,owner_sub,created_by_sub,name,category,contact_name,phone,address_line,
     province,district,note,status,is_selling,vat_tax_code)
  VALUES(lead.id,lead.owner_sub,p_actor,lead.name,lead.category,NULL,lead.phone,
     lead.address_line,lead.province,lead.district,lead.note,'potential',FALSE,lead.tax_code)
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

REVOKE ALL ON FUNCTION public.sales_market_prospect_create(text,uuid,text,text,text,text,text,text,text,text,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_market_prospect_visit(text,uuid,uuid,timestamptz,double precision,double precision,double precision,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_market_prospect_close(text,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_market_prospect_convert(text,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_create(text,uuid,text,text,text,text,text,text,text,text,uuid) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_visit(text,uuid,uuid,timestamptz,double precision,double precision,double precision,text) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_close(text,uuid) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_convert(text,uuid,uuid) TO sales_api;
GRANT SELECT ON public.field_prospect_visits,public.field_market_prospect_audit TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_prospect_visits,public.field_market_prospect_audit FROM sales_api;
COMMIT;
