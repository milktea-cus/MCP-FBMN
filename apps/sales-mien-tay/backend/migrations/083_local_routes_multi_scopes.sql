-- P0 local fixed routes: one template contains multiple territory/customer/chain
-- scopes. Legacy columns remain as the first scope for compatibility.
ALTER TABLE public.field_local_route_rules
 ADD COLUMN IF NOT EXISTS scopes jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.field_local_monthly_routes
 ADD COLUMN IF NOT EXISTS scopes jsonb NOT NULL DEFAULT '[]'::jsonb;
UPDATE public.field_local_route_rules
 SET scopes=jsonb_build_array(jsonb_build_object('scope_kind','territory',
  'scope_key',province||'|'||district,'province',province,'district',district,
  'label',CASE WHEN district='' THEN 'Toàn tỉnh · '||province
   ELSE district||' · '||province END))
 WHERE scopes='[]'::jsonb;
UPDATE public.field_local_monthly_routes
 SET scopes=jsonb_build_array(jsonb_build_object('scope_kind',scope_kind,
  'scope_key',scope_key,'province',province,'district',district,'label',scope_label))
 WHERE scopes='[]'::jsonb;
ALTER TABLE public.field_local_route_rules ALTER COLUMN province DROP NOT NULL;
ALTER TABLE public.field_local_route_rules ALTER COLUMN district DROP NOT NULL;
ALTER TABLE public.field_local_route_rules
 ADD CONSTRAINT field_local_weekly_scopes_shape
 CHECK(jsonb_typeof(scopes)='array' AND jsonb_array_length(scopes) BETWEEN 1 AND 50);
ALTER TABLE public.field_local_monthly_routes
 ADD CONSTRAINT field_local_monthly_scopes_shape
 CHECK(jsonb_typeof(scopes)='array' AND jsonb_array_length(scopes) BETWEEN 1 AND 50);

CREATE OR REPLACE FUNCTION public.sales_local_scopes_allowed(
 p_actor text,p_scopes jsonb
) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER
 SET search_path=pg_catalog,public AS $fbmn$
DECLARE part jsonb; kind text; key text; province text; district text;
 label text; seen text[]:=ARRAY[]::text[]; token text;
BEGIN
 IF p_actor IS NULL OR p_scopes IS NULL OR jsonb_typeof(p_scopes)<>'array'
 OR jsonb_array_length(p_scopes) NOT BETWEEN 1 AND 50 THEN RETURN false; END IF;
 FOR part IN SELECT value FROM jsonb_array_elements(p_scopes) LOOP
  IF jsonb_typeof(part)<>'object' THEN RETURN false; END IF;
  kind:=part->>'scope_kind'; key:=part->>'scope_key';
  label:=part->>'label'; province:=part->>'province'; district:=part->>'district';
  IF kind IS NULL OR kind NOT IN ('territory','chain','customer')
   OR length(coalesce(key,'')) NOT BETWEEN 1 AND 240
   OR length(btrim(coalesce(label,''))) NOT BETWEEN 1 AND 240
   OR (part ? 'id') THEN RETURN false; END IF;
  IF kind='territory' THEN
   IF length(btrim(coalesce(province,''))) NOT BETWEEN 1 AND 120
    OR length(coalesce(district,''))>120
    OR position('|' in province)>0 OR position('|' in district)>0
    OR key<>province||'|'||district
   THEN RETURN false; END IF;
  ELSE
   IF key !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    OR (part->'province') IS DISTINCT FROM 'null'::jsonb AND part ? 'province'
    OR (part->'district') IS DISTINCT FROM 'null'::jsonb AND part ? 'district'
   THEN RETURN false; END IF;
   province:=NULL; district:=NULL;
  END IF;
  token:=kind||':'||key;
  IF token=ANY(seen) THEN RETURN false; END IF;
  seen:=array_append(seen,token);
  IF public.sales_monthly_plan_scope_allowed(
   p_actor,kind,key,province,district) IS DISTINCT FROM true
   THEN RETURN false; END IF;
 END LOOP;
 RETURN true;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_local_scopes_allowed(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_local_scopes_allowed(text,jsonb) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_save_local_route_rule_v2(
 p_actor text,p_id uuid,p_mutation uuid,p_version integer,
 p_name text,p_mode text,p_days jsonb,p_scopes jsonb,
 p_start date,p_active boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.field_local_route_rules%ROWTYPE;
 saved public.field_local_route_rules%ROWTYPE; normalized smallint[];
 primary_scope jsonb; v_province text; v_district text;
BEGIN
 IF p_id IS NULL OR p_mutation IS NULL OR p_version IS NULL OR p_version<0
 OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120
 OR p_mode NOT IN ('day','week') OR p_start IS NULL OR p_active IS NULL
 OR NOT public.sales_local_scopes_allowed(p_actor,p_scopes)
 OR p_days IS NULL OR jsonb_typeof(p_days)<>'array'
 OR jsonb_array_length(p_days) NOT BETWEEN 1 AND 7
 THEN RAISE EXCEPTION 'LOCAL_ROUTE_PERMISSION_OR_INVALID'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_days) e
  WHERE jsonb_typeof(e.value)<>'number' OR e.value::text !~ '^[1-7]$')
 THEN RAISE EXCEPTION 'LOCAL_ROUTE_INVALID_DAYS'; END IF;
 SELECT array_agg(DISTINCT value::text::smallint ORDER BY value::text::smallint)
 INTO normalized FROM jsonb_array_elements(p_days);
 IF cardinality(normalized)<>jsonb_array_length(p_days)
 OR (p_mode='day' AND cardinality(normalized)<>1)
 THEN RAISE EXCEPTION 'LOCAL_ROUTE_INVALID_DAYS'; END IF;
 primary_scope:=p_scopes->0;
 v_province:=CASE WHEN primary_scope->>'scope_kind'='territory'
  THEN primary_scope->>'province' ELSE NULL END;
 v_district:=CASE WHEN primary_scope->>'scope_kind'='territory'
  THEN primary_scope->>'district' ELSE NULL END;
 SELECT * INTO old FROM public.field_local_route_rules WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor THEN RAISE EXCEPTION 'LOCAL_ROUTE_FORBIDDEN'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_version=0 OR old.version<>p_version THEN RAISE EXCEPTION 'LOCAL_ROUTE_STALE'; END IF;
  UPDATE public.field_local_route_rules SET name=btrim(p_name),mode=p_mode,
   weekdays=normalized,province=v_province,district=v_district,scopes=p_scopes,
   start_on=p_start,active=p_active,version=version+1,last_mutation_ref=p_mutation,
   updated_at=now() WHERE id=p_id RETURNING * INTO saved;
 ELSE
  IF p_version<>0 THEN RAISE EXCEPTION 'LOCAL_ROUTE_STALE'; END IF;
  INSERT INTO public.field_local_route_rules(
   id,owner_sub,name,mode,weekdays,province,district,scopes,start_on,active,last_mutation_ref)
  VALUES(p_id,p_actor,btrim(p_name),p_mode,normalized,v_province,v_district,p_scopes,
   p_start,p_active,p_mutation) RETURNING * INTO saved;
 END IF;
 INSERT INTO public.field_local_route_rule_audit(rule_id,actor_sub,before_state,after_state)
 VALUES(p_id,p_actor,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_local_route_rule_v2(text,uuid,uuid,integer,text,text,jsonb,jsonb,date,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_local_route_rule_v2(text,uuid,uuid,integer,text,text,jsonb,jsonb,date,boolean) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_save_local_monthly_route_v2(
 p_actor text,p_id uuid,p_mutation uuid,p_version integer,
 p_name text,p_week smallint,p_scopes jsonb,p_active boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
 SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.field_local_monthly_routes%ROWTYPE;
 saved public.field_local_monthly_routes%ROWTYPE;
 primary_scope jsonb; kind text; key text; v_province text; v_district text; label text;
BEGIN
 IF p_id IS NULL OR p_mutation IS NULL OR p_version IS NULL OR p_version<0
 OR length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120
 OR p_week IS NULL OR p_week NOT BETWEEN 1 AND 5 OR p_active IS NULL
 OR NOT public.sales_local_scopes_allowed(p_actor,p_scopes)
 THEN RAISE EXCEPTION 'LOCAL_MONTHLY_PERMISSION_OR_INVALID'; END IF;
 primary_scope:=p_scopes->0;
 kind:=primary_scope->>'scope_kind'; key:=primary_scope->>'scope_key';
 v_province:=primary_scope->>'province';v_district:=primary_scope->>'district';
 label:=primary_scope->>'label';
 SELECT * INTO old FROM public.field_local_monthly_routes WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor THEN RAISE EXCEPTION 'LOCAL_MONTHLY_FORBIDDEN'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_version=0 OR old.version<>p_version THEN RAISE EXCEPTION 'LOCAL_MONTHLY_STALE'; END IF;
  UPDATE public.field_local_monthly_routes SET name=btrim(p_name),week_no=p_week,
   scope_kind=kind,scope_key=key,province=v_province,district=v_district,
   scope_label=btrim(label),scopes=p_scopes,active=p_active,
   version=version+1,last_mutation_ref=p_mutation,updated_at=now()
  WHERE id=p_id RETURNING * INTO saved;
 ELSE
  IF p_version<>0 THEN RAISE EXCEPTION 'LOCAL_MONTHLY_STALE'; END IF;
  INSERT INTO public.field_local_monthly_routes(
   id,owner_sub,name,week_no,scope_kind,scope_key,province,district,
   scope_label,scopes,active,last_mutation_ref)
  VALUES(p_id,p_actor,btrim(p_name),p_week,kind,key,v_province,v_district,
   btrim(label),p_scopes,p_active,p_mutation) RETURNING * INTO saved;
 END IF;
 INSERT INTO public.field_local_monthly_route_audit(route_id,actor_sub,before_state,after_state)
 VALUES(p_id,p_actor,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_local_monthly_route_v2(text,uuid,uuid,integer,text,smallint,jsonb,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_local_monthly_route_v2(text,uuid,uuid,integer,text,smallint,jsonb,boolean) TO sales_api;
