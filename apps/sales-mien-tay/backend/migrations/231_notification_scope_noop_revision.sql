-- 231: prevent no-op assignment saves from invalidating offline scope revisions.
CREATE OR REPLACE FUNCTION public.sales_set_staff_territories(p_actor text, p_staff text, p_scopes jsonb, p_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
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
 -- The offline scope_revision must NOT be invalidated by an identical
 -- territory save. Compare the fully normalized requested set first.
 IF previous IS NOT DISTINCT FROM (
   SELECT coalesce(jsonb_agg(jsonb_build_object('province',x.province,'district',x.district)
     ORDER BY x.province,x.district),'[]'::jsonb)
   FROM (SELECT DISTINCT btrim(z.province) AS province,btrim(z.district) AS district
     FROM jsonb_to_recordset(p_scopes) AS z(province text,district text)) x
   WHERE x.district='' OR NOT EXISTS(
     SELECT 1 FROM jsonb_to_recordset(p_scopes) whole(province text,district text)
     WHERE btrim(whole.province)=x.province AND btrim(whole.district)='')
 ) THEN
   RETURN jsonb_build_object('scopes',previous,
     'scope_revision',(SELECT scope_revision FROM public.staff_members WHERE user_sub=p_staff));
 END IF;
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
$function$


CREATE OR REPLACE FUNCTION public.sales_set_staff_business_assignment(p_actor text, p_staff text, p_kind text, p_key text, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE previous jsonb; saved public.staff_business_assignments%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(74162904);
 IF NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor AND s.active AND s.role='admin' AND public.sales_identity_exists(s.user_sub))
 THEN RAISE EXCEPTION 'admin required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_staff AND s.active)
 THEN RAISE EXCEPTION 'invalid recipient'; END IF;
 IF (p_kind NOT IN ('chain','customer') OR
    (p_kind='chain' AND NOT EXISTS(SELECT 1 FROM public.customer_chains WHERE id::text=p_key)) OR
    (p_kind='customer' AND NOT EXISTS(SELECT 1 FROM public.customers WHERE id::text=p_key)))
 THEN RAISE EXCEPTION 'invalid assignment'; END IF;
 SELECT to_jsonb(x) INTO previous FROM public.staff_business_assignments x
 WHERE x.user_sub=p_staff AND x.scope_kind=p_kind AND x.scope_key=p_key;
 -- A repeated active flag is not a business action. Preserve scope_revision,
 -- the existing assignment metadata and account-separated offline state.
 IF previous IS NOT NULL AND previous->>'active' IS NOT DISTINCT FROM p_active::text
 THEN RETURN previous; END IF;
 INSERT INTO public.staff_business_assignments(user_sub,scope_kind,scope_key,active,assigned_by)
 VALUES(p_staff,p_kind,p_key,p_active,p_actor)
 ON CONFLICT(user_sub,scope_kind,scope_key) DO UPDATE
 SET active=excluded.active,assigned_by=excluded.assigned_by,updated_at=now()
 RETURNING * INTO saved;
 IF previous IS DISTINCT FROM to_jsonb(saved) THEN
   WITH RECURSIVE supervisors(id,path) AS (
     SELECT p_staff,ARRAY[p_staff]
     UNION ALL SELECT s.manager_sub,v.path||s.manager_sub FROM supervisors v
       JOIN public.staff_members s ON s.user_sub=v.id
       WHERE s.manager_sub IS NOT NULL AND NOT s.manager_sub=ANY(v.path)
   ) UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now()
     WHERE user_sub IN(SELECT id FROM supervisors);
   INSERT INTO public.scope_change_audit(actor_sub,subject_kind,subject_key,action,before_state,after_state)
   VALUES(p_actor,'business_assignment',saved.id::text,
     CASE WHEN p_active THEN 'assign' ELSE 'unassign' END,previous,to_jsonb(saved));
 END IF;
 RETURN to_jsonb(saved);
END $function$


CREATE OR REPLACE FUNCTION public.sales_set_scope_grant(p_actor text, p_grantee text, p_kind text, p_key text, p_action text, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE previous jsonb; next_row public.scope_grants%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(74162902);
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=p_actor AND active AND role='admin' AND public.sales_identity_exists(user_sub))
 THEN RAISE EXCEPTION 'admin required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=p_grantee AND active AND role IN ('manager','sales'))
 THEN RAISE EXCEPTION 'invalid recipient'; END IF;
 IF p_kind NOT IN ('territory','team','chain','staff','customer') OR
    p_action NOT IN ('view','create','edit','transfer','approve','target','actuals','report','export','media','staff_manage')
    OR length(btrim(p_key)) NOT BETWEEN 1 AND 240 THEN RAISE EXCEPTION 'invalid grant'; END IF;
 IF (p_kind='team' AND NOT EXISTS(SELECT 1 FROM public.org_teams WHERE id::text=p_key))
 OR (p_kind='chain' AND NOT EXISTS(SELECT 1 FROM public.customer_chains WHERE id::text=p_key))
 OR (p_kind='staff' AND NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=p_key AND active))
 OR (p_kind='customer' AND NOT EXISTS(SELECT 1 FROM public.customers WHERE id::text=p_key))
 THEN RAISE EXCEPTION 'invalid scope key'; END IF;
 SELECT to_jsonb(g) INTO previous FROM public.scope_grants g
 WHERE grantee_sub=p_grantee AND scope_kind=p_kind AND scope_key=p_key AND action=p_action;
 -- A repeated active flag is not a business action. Preserve scope_revision,
 -- the existing assignment metadata and account-separated offline state.
 IF previous IS NOT NULL AND previous->>'active' IS NOT DISTINCT FROM p_active::text
 THEN RETURN previous; END IF;
 INSERT INTO public.scope_grants(grantee_sub,scope_kind,scope_key,action,active,granted_by)
 VALUES(p_grantee,p_kind,p_key,p_action,p_active,p_actor)
 ON CONFLICT(grantee_sub,scope_kind,scope_key,action)
 DO UPDATE SET active=EXCLUDED.active,granted_by=p_actor,updated_at=now()
 RETURNING * INTO next_row;
 IF previous IS DISTINCT FROM to_jsonb(next_row) THEN
   UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now() WHERE user_sub=p_grantee;
   INSERT INTO public.scope_change_audit(actor_sub,subject_kind,subject_key,action,before_state,after_state)
   VALUES(p_actor,'grant',next_row.id::text,CASE WHEN p_active THEN 'grant' ELSE 'revoke' END,previous,to_jsonb(next_row));
 END IF;
 RETURN to_jsonb(next_row);
END;$function$


CREATE OR REPLACE FUNCTION public.sales_set_customer_binding(p_actor text, p_customer uuid, p_kind text, p_key text, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE previous jsonb; next_row public.customer_scope_bindings%ROWTYPE; c public.customers%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(74162903);
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=p_actor AND active AND role='admin' AND public.sales_identity_exists(user_sub))
 THEN RAISE EXCEPTION 'admin required'; END IF;
 SELECT * INTO c FROM public.customers WHERE id=p_customer;
 IF NOT FOUND THEN RAISE EXCEPTION 'customer not found'; END IF;
 IF p_kind NOT IN ('territory','team','chain','staff') OR length(btrim(p_key)) NOT BETWEEN 1 AND 240
 THEN RAISE EXCEPTION 'invalid binding'; END IF;
 IF (p_kind='territory' AND p_key NOT IN (c.province||'|',c.province||'|'||c.district))
 OR (p_kind='team' AND NOT EXISTS(SELECT 1 FROM public.org_teams WHERE id::text=p_key))
 OR (p_kind='chain' AND NOT EXISTS(SELECT 1 FROM public.customer_chains WHERE id::text=p_key))
 OR (p_kind='staff' AND NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=p_key AND active))
 THEN RAISE EXCEPTION 'invalid binding key'; END IF;
 SELECT to_jsonb(b) INTO previous FROM public.customer_scope_bindings b
 WHERE customer_id=p_customer AND scope_kind=p_kind AND scope_key=p_key;
 -- A repeated active flag is not a business action. Preserve scope_revision,
 -- the existing assignment metadata and account-separated offline state.
 IF previous IS NOT NULL AND previous->>'active' IS NOT DISTINCT FROM p_active::text
 THEN RETURN previous; END IF;
 INSERT INTO public.customer_scope_bindings(customer_id,scope_kind,scope_key,active,assigned_by)
 VALUES(p_customer,p_kind,p_key,p_active,p_actor)
 ON CONFLICT(customer_id,scope_kind,scope_key)
 DO UPDATE SET active=EXCLUDED.active,assigned_by=p_actor,updated_at=now()
 RETURNING * INTO next_row;
 IF previous IS DISTINCT FROM to_jsonb(next_row) THEN
   UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now()
   WHERE user_sub IN (SELECT DISTINCT grantee_sub FROM public.scope_grants
     WHERE active AND scope_kind=p_kind AND scope_key=p_key);
   INSERT INTO public.scope_change_audit(actor_sub,subject_kind,subject_key,action,before_state,after_state)
   VALUES(p_actor,'customer_binding',p_customer::text,CASE WHEN p_active THEN 'assign' ELSE 'unassign' END,previous,to_jsonb(next_row));
 END IF;
 RETURN to_jsonb(next_row);
END;$function$

