-- 033: Direct territory assignment and own route planning are separate from staff hierarchy.
-- Additive; never grant edit, approve, customer ownership, or cross-team planning.
CREATE OR REPLACE FUNCTION public.sales_set_staff_territories(
 p_actor text,p_staff text,p_scopes jsonb,p_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $fbmn$
DECLARE previous jsonb; result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(74162901);
 IF NOT EXISTS(SELECT 1 FROM public.staff_members
   WHERE user_sub=p_actor AND role='admin' AND active AND public.sales_identity_exists(user_sub))
 THEN RAISE EXCEPTION 'admin required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.staff_members
   WHERE user_sub=p_staff AND active AND role IN('manager','sales'))
 THEN RAISE EXCEPTION 'invalid employee'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=p_staff AND scope_revision=p_revision)
 THEN RAISE EXCEPTION 'stale revision'; END IF;
 IF p_scopes IS NULL OR jsonb_typeof(p_scopes)<>'array' OR jsonb_array_length(p_scopes)>1000
 THEN RAISE EXCEPTION 'invalid territory data'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_scopes) e
    WHERE jsonb_typeof(e)<>'object'
      OR jsonb_typeof(e->'province')<>'string'
      OR jsonb_typeof(e->'district')<>'string'
      OR length(btrim(e->>'province')) NOT BETWEEN 2 AND 100
      OR length(e->>'district')>100
      OR e->>'province' LIKE '%|%'
      OR e->>'district' LIKE '%|%')
 THEN RAISE EXCEPTION 'invalid territory data'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('province',province,'district',district)
      ORDER BY province,district),'[]'::jsonb) INTO previous
 FROM public.staff_scopes WHERE user_sub=p_staff;
 DELETE FROM public.staff_scopes WHERE user_sub=p_staff;
 INSERT INTO public.staff_scopes(user_sub,province,district)
 SELECT p_staff,province,district FROM (
   SELECT DISTINCT btrim(t.province) AS province,btrim(t.district) AS district
   FROM jsonb_to_recordset(p_scopes) AS t(province text,district text)
 ) x
 WHERE district='' OR NOT EXISTS(
   SELECT 1 FROM jsonb_to_recordset(p_scopes) whole(province text,district text)
    WHERE btrim(whole.province)=x.province AND btrim(whole.district)=''
 );
 UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now()
 WHERE user_sub=p_staff;
 WITH RECURSIVE ancestors(id,path) AS (
   SELECT manager_sub,ARRAY[user_sub,manager_sub] FROM public.staff_members
   WHERE user_sub=p_staff AND manager_sub IS NOT NULL
   UNION ALL
   SELECT parent.manager_sub,anc.path||parent.manager_sub
   FROM ancestors anc JOIN public.staff_members parent ON parent.user_sub=anc.id
   WHERE parent.manager_sub IS NOT NULL AND NOT parent.manager_sub=ANY(anc.path)
 ) UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now()
   WHERE user_sub IN(SELECT id FROM ancestors);
 SELECT coalesce(jsonb_agg(jsonb_build_object('province',province,'district',district)
      ORDER BY province,district),'[]'::jsonb) INTO result
 FROM public.staff_scopes WHERE user_sub=p_staff;
 IF previous IS DISTINCT FROM result THEN
  INSERT INTO public.staff_permission_events(actor_sub,target_sub,action,before_state,after_state)
  VALUES(p_actor,p_staff,'assign_territories',previous,result);
 END IF;
 RETURN jsonb_build_object('scopes',result,
   'scope_revision',(SELECT scope_revision FROM public.staff_members WHERE user_sub=p_staff));
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_set_staff_territories(text,text,jsonb,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_set_staff_territories(text,text,jsonb,bigint) TO sales_api;

-- Planned route's owner is the planner, never automatically the customer creator.
-- A manager sees descendants, but may only plan their own direct allocations.
CREATE OR REPLACE FUNCTION public.sales_customer_plannable(p_staff text,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
 SELECT EXISTS(
  SELECT 1 FROM public.staff_members s
  JOIN public.customers c ON c.id=p_customer
  WHERE s.user_sub=p_staff AND s.active AND public.sales_identity_exists(s.user_sub)
    AND (s.role='admin' OR public.sales_staff_business_matches_customer(s.user_sub,c.id))
 );
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_customer_plannable(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_plannable(text,uuid) TO sales_api;
