-- P0-L6: versioned, account-owned reusable route templates. No fixed weekly scheduling.
CREATE TABLE IF NOT EXISTS public.field_route_templates(
 id uuid PRIMARY KEY,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 120),
 scope_kind text NOT NULL CHECK(scope_kind IN ('territory','chain')),
 scope_key text NOT NULL CHECK(length(scope_key) BETWEEN 1 AND 160),
 province text,district text,
 stops jsonb NOT NULL CHECK(jsonb_typeof(stops)='array' AND jsonb_array_length(stops) BETWEEN 1 AND 100),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_route_templates_owner ON public.field_route_templates(owner_sub,scope_kind,scope_key,updated_at DESC);
CREATE TABLE IF NOT EXISTS public.field_route_template_audit(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 template_id uuid NOT NULL REFERENCES public.field_route_templates(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 before_state jsonb,
 after_state jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_route_template_audit_ref ON public.field_route_template_audit(template_id,created_at DESC);

CREATE OR REPLACE FUNCTION public.sales_save_route_template(
 p_actor text,p_id uuid,p_mutation uuid,p_version integer,
 p_name text,p_kind text,p_key text,p_province text,p_district text,p_stops jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE old public.field_route_templates%ROWTYPE;
 saved public.field_route_templates%ROWTYPE;
 stop jsonb;
 serial integer;
 identities text[]:=ARRAY[]::text[];
 identifier text;
 kind text;
 customer uuid;
 chain uuid;
BEGIN
 IF p_id IS NULL OR p_mutation IS NULL OR p_version IS NULL OR p_version<0 OR
  length(btrim(coalesce(p_name,''))) NOT BETWEEN 2 AND 120 OR
  p_kind NOT IN ('territory','chain') OR
  NOT public.sales_monthly_plan_scope_allowed(p_actor,p_kind,p_key,p_province,p_district) OR
  p_stops IS NULL OR jsonb_typeof(p_stops)<>'array' OR
  jsonb_array_length(p_stops) NOT BETWEEN 1 AND 100
 THEN RAISE EXCEPTION 'route template permission or data invalid'; END IF;
 FOR stop IN SELECT value FROM jsonb_array_elements(p_stops)
 LOOP
  IF jsonb_typeof(stop)<>'object' OR
   NOT (stop ? 'sequence') OR (stop->>'sequence') !~ '^[0-9]{1,4}$' OR
   (stop->>'sequence')::int NOT BETWEEN 1 AND 9999 OR
   length(coalesce(stop->>'purpose',''))>500
  THEN RAISE EXCEPTION 'route template item invalid'; END IF;
  serial:=(stop->>'sequence')::integer;
  IF serial::text=ANY(identities) THEN RAISE EXCEPTION 'route template duplicate sequence'; END IF;
  identities:=array_append(identities,serial::text);
  kind:=stop->>'stop_kind';
  IF kind='customer' THEN
   IF (stop->>'customer_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   OR NOT public.sales_customer_plannable(p_actor,(stop->>'customer_id')::uuid)
   OR NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.id=(stop->>'customer_id')::uuid AND
    ((p_kind='territory' AND c.province=p_province AND (p_district='' OR c.district=p_district))
      OR(p_kind='chain' AND EXISTS(SELECT 1 FROM public.customer_scope_bindings b
       WHERE b.customer_id=c.id AND b.active AND b.scope_kind='chain' AND b.scope_key=p_key))))
   THEN RAISE EXCEPTION 'route template customer permission'; END IF;
  ELSIF kind='area' THEN
   IF p_kind<>'territory' OR stop->>'province' IS DISTINCT FROM p_province
     OR stop->>'district' IS DISTINCT FROM p_district
   THEN RAISE EXCEPTION 'route template area permission'; END IF;
  ELSIF kind='chain' THEN
   IF p_kind<>'chain' OR stop->>'chain_id' IS DISTINCT FROM p_key
   THEN RAISE EXCEPTION 'route template chain permission'; END IF;
  ELSE RAISE EXCEPTION 'route template kind invalid';
  END IF;
  identifier:=CASE kind WHEN 'customer' THEN stop->>'customer_id'
   WHEN 'chain' THEN stop->>'chain_id'
   ELSE stop->>'province'||'/'||stop->>'district' END;
  IF (kind||':'||identifier)=ANY(identities) THEN RAISE EXCEPTION 'route template duplicate stop'; END IF;
  identities:=array_append(identities,kind||':'||identifier);
 END LOOP;
 SELECT * INTO old FROM public.field_route_templates WHERE id=p_id FOR UPDATE;
 IF FOUND THEN
  IF old.owner_sub<>p_actor OR old.scope_kind<>p_kind OR old.scope_key<>p_key
    OR old.province IS DISTINCT FROM p_province OR old.district IS DISTINCT FROM p_district
  THEN RAISE EXCEPTION 'route template permission denied'; END IF;
  IF old.last_mutation_ref=p_mutation THEN RETURN to_jsonb(old); END IF;
  IF p_version=0 OR old.version<>p_version THEN RAISE EXCEPTION 'route template stale'; END IF;
  UPDATE public.field_route_templates SET name=btrim(p_name),stops=p_stops,
    version=version+1,last_mutation_ref=p_mutation,updated_at=now()
    WHERE id=p_id RETURNING * INTO saved;
 ELSE
  IF p_version<>0 THEN RAISE EXCEPTION 'route template stale'; END IF;
  INSERT INTO public.field_route_templates(id,owner_sub,name,scope_kind,scope_key,province,district,stops,last_mutation_ref)
   VALUES(p_id,p_actor,btrim(p_name),p_kind,p_key,p_province,p_district,p_stops,p_mutation)
   RETURNING * INTO saved;
 END IF;
 INSERT INTO public.field_route_template_audit(template_id,actor_sub,before_state,after_state)
  VALUES(p_id,p_actor,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(saved));
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_save_route_template(text,uuid,uuid,integer,text,text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_route_template(text,uuid,uuid,integer,text,text,text,text,text,jsonb) TO sales_api;
GRANT SELECT ON public.field_route_templates TO sales_api;
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON public.field_route_templates FROM sales_api;
REVOKE ALL ON public.field_route_template_audit FROM sales_api;
