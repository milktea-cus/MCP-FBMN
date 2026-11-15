-- 064: Multi-province support/competitor intelligence, normalized relations and atomic optimistic writes.
-- Additive only: legacy records and all existing customer data remain untouched.
CREATE TABLE IF NOT EXISTS public.sales_record_areas (
  record_id uuid NOT NULL REFERENCES public.sales_records(id) ON DELETE RESTRICT,
  province text NOT NULL,
  district text NOT NULL DEFAULT '',
  PRIMARY KEY(record_id,province),
  CHECK(length(province) BETWEEN 2 AND 120),
  CHECK(length(district)<=120)
);
CREATE INDEX IF NOT EXISTS sales_record_areas_province_idx ON public.sales_record_areas(province,district,record_id);
CREATE TABLE IF NOT EXISTS public.sales_record_customers (
  record_id uuid NOT NULL REFERENCES public.sales_records(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  PRIMARY KEY(record_id,customer_id)
);
CREATE INDEX IF NOT EXISTS sales_record_customers_customer_idx ON public.sales_record_customers(customer_id,record_id);
CREATE TABLE IF NOT EXISTS public.sales_scoped_record_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id uuid NOT NULL REFERENCES public.sales_records(id) ON DELETE RESTRICT,
  actor_sub text NOT NULL,
  operation text NOT NULL CHECK(operation IN ('create','update')),
  before_state jsonb,
  after_state jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sales_scoped_audit_record_idx ON public.sales_scoped_record_audit(record_id,created_at DESC);
-- Populate scope records for historical single-province records if present.
INSERT INTO public.sales_record_areas(record_id,province,district)
 SELECT id,province,coalesce(district,'') FROM public.sales_records
 WHERE kind IN ('support','competitor') AND province IS NOT NULL
ON CONFLICT DO NOTHING;

-- Verify every write in one DB transaction; no independently committed record/area/customer rows.
-- Editors can update their own records; administrators can also update any record.
CREATE OR REPLACE FUNCTION public.sales_save_scoped_record(
 p_actor text,p_kind text,p_record uuid,p_ref uuid,p_version integer,
 p_provinces text[],p_district text,p_customer_ids uuid[],p_data jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,public AS $fbmn$
DECLARE original public.sales_records%ROWTYPE;
 saved public.sales_records%ROWTYPE;
 area_name text;
 c record;
 before_value jsonb;
 is_admin boolean;
 has_scope boolean;
 expected_count int;
 clean_district text:=coalesce(p_district,'');
BEGIN
 SELECT s.role='admin' INTO is_admin FROM public.staff_members s
 WHERE s.user_sub=p_actor AND s.active AND public.sales_identity_exists(s.user_sub);
 IF NOT FOUND THEN RAISE EXCEPTION 'SCOPED_FORBIDDEN'; END IF;
 IF p_kind NOT IN ('competitor','support') OR p_ref IS NULL OR p_data IS NULL
  OR jsonb_typeof(p_data)<>'object' OR p_record=p_ref
  OR p_version IS NULL OR p_version<0
  OR p_provinces IS NULL OR cardinality(p_provinces) NOT BETWEEN 1 AND 13
  OR p_customer_ids IS NULL OR cardinality(p_customer_ids)>1000
 THEN RAISE EXCEPTION 'SCOPED_INVALID'; END IF;
 IF (p_kind='support' AND cardinality(p_customer_ids)>0)
  OR (cardinality(p_provinces)>1 AND clean_district<>'')
  OR length(clean_district)>120
  OR (cardinality(p_provinces)<> (SELECT count(DISTINCT x) FROM unnest(p_provinces) x))
  OR (cardinality(p_customer_ids)<> (SELECT count(DISTINCT x) FROM unnest(p_customer_ids) x))
 THEN RAISE EXCEPTION 'SCOPED_INVALID'; END IF;
 IF length(btrim(coalesce(p_data->>'title',''))) NOT BETWEEN 1 AND 240
 THEN RAISE EXCEPTION 'SCOPED_TITLE_REQUIRED'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(p_provinces) x
  WHERE x IS NULL OR x NOT IN
   ('Long An','Tiền Giang','Bến Tre','Trà Vinh','Vĩnh Long','Đồng Tháp',
    'An Giang','Kiên Giang','Hậu Giang','Sóc Trăng','Bạc Liêu','Cà Mau','Cần Thơ'))
 THEN RAISE EXCEPTION 'SCOPED_INVALID_PROVINCE'; END IF;
 -- Serialize create/replay by operation reference, including lost-network retries.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_actor||':'||p_ref::text,0));
 SELECT * INTO saved FROM public.sales_records
 WHERE owner_sub=p_actor AND client_ref=p_ref AND kind=p_kind;
 IF FOUND THEN RETURN to_jsonb(saved) || jsonb_build_object('idempotent',true); END IF;

 IF p_record IS NOT NULL THEN
  SELECT * INTO original FROM public.sales_records WHERE id=p_record FOR UPDATE;
  IF NOT FOUND OR original.kind<>p_kind OR NOT (is_admin OR original.owner_sub=p_actor)
  THEN RAISE EXCEPTION 'SCOPED_FORBIDDEN'; END IF;
  IF original.last_mutation_ref=p_ref THEN
   RETURN to_jsonb(original)||jsonb_build_object('idempotent',true);
  END IF;
  IF original.version<>p_version THEN RAISE EXCEPTION 'SCOPED_VERSION_CONFLICT'; END IF;
  before_value:=to_jsonb(original)||jsonb_build_object(
    'provinces',coalesce((SELECT jsonb_agg(a.province ORDER BY a.province)
      FROM public.sales_record_areas a WHERE a.record_id=p_record),'[]'::jsonb),
    'customer_ids',coalesce((SELECT jsonb_agg(x.customer_id ORDER BY x.customer_id)
      FROM public.sales_record_customers x WHERE x.record_id=p_record),'[]'::jsonb));
 ELSE
  IF p_version<>0 THEN RAISE EXCEPTION 'SCOPED_INVALID'; END IF;
 END IF;
 -- All linked customers must belong to selected geography and be individually visible to actor.
 SELECT count(*) INTO expected_count FROM public.customers c
 WHERE c.id=ANY(p_customer_ids) AND c.province=ANY(p_provinces)
   AND (clean_district='' OR c.district=clean_district)
   AND public.sales_customer_allowed(p_actor,c.id,'view');
 IF expected_count<>cardinality(p_customer_ids)
 THEN RAISE EXCEPTION 'SCOPED_CUSTOMER_FORBIDDEN'; END IF;
 FOREACH area_name IN ARRAY p_provinces LOOP
  -- For country/region-wide claims require full territory scope. Customer-scoped
  -- chain managers can make linked-customer reports only where they can view customers.
  SELECT is_admin OR EXISTS(
    SELECT 1 FROM public.staff_scopes s WHERE s.user_sub=p_actor
       AND s.province=area_name
       AND (s.district='' OR (clean_district<>'' AND s.district=clean_district))
   ) OR EXISTS(
    SELECT 1 FROM public.scope_grants g WHERE g.grantee_sub=p_actor
      AND g.active AND g.action='create' AND g.scope_kind='territory'
      AND g.scope_key IN (
        area_name||'|',CASE WHEN clean_district<>'' THEN area_name||'|'||clean_district ELSE '' END)
   ) OR (
    p_kind='competitor' AND cardinality(p_customer_ids)>0 AND EXISTS(
      SELECT 1 FROM public.customers c
      WHERE c.id=ANY(p_customer_ids) AND c.province=area_name
        AND public.sales_customer_allowed(p_actor,c.id,'view'))
   ) INTO has_scope;
  IF NOT coalesce(has_scope,false) THEN RAISE EXCEPTION 'SCOPED_AREA_FORBIDDEN'; END IF;
 END LOOP;
 IF p_record IS NULL THEN
  INSERT INTO public.sales_records(kind,owner_sub,province,district,data,client_ref)
   VALUES(p_kind,p_actor,p_provinces[1],nullif(clean_district,''),p_data,p_ref)
  RETURNING * INTO saved;
 ELSE
  UPDATE public.sales_records SET province=p_provinces[1],
    district=nullif(clean_district,''),data=p_data,
    version=version+1,last_mutation_ref=p_ref,updated_at=now()
  WHERE id=p_record AND version=p_version RETURNING * INTO saved;
  IF NOT FOUND THEN RAISE EXCEPTION 'SCOPED_VERSION_CONFLICT'; END IF;
  DELETE FROM public.sales_record_areas WHERE record_id=p_record;
  DELETE FROM public.sales_record_customers WHERE record_id=p_record;
 END IF;
 INSERT INTO public.sales_record_areas(record_id,province,district)
 SELECT saved.id,x,clean_district FROM unnest(p_provinces) x;
 INSERT INTO public.sales_record_customers(record_id,customer_id)
 SELECT saved.id,x FROM unnest(p_customer_ids) x;
 INSERT INTO public.sales_scoped_record_audit(record_id,actor_sub,operation,before_state,after_state)
 VALUES(saved.id,p_actor,CASE WHEN p_record IS NULL THEN 'create' ELSE 'update' END,
  before_value,to_jsonb(saved)||jsonb_build_object('provinces',to_jsonb(p_provinces),'customer_ids',to_jsonb(p_customer_ids)));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON public.sales_record_areas,public.sales_record_customers,public.sales_scoped_record_audit FROM PUBLIC;
GRANT SELECT ON public.sales_record_areas,public.sales_record_customers TO sales_api;
REVOKE ALL ON FUNCTION public.sales_save_scoped_record(text,text,uuid,uuid,integer,text[],text,uuid[],jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_scoped_record(text,text,uuid,uuid,integer,text[],text,uuid[],jsonb) TO sales_api;
