-- 232 N2: never revoke stale offline sessions or pending notifications for an identical staff save.
CREATE OR REPLACE FUNCTION public.sales_save_staff(actor text, subject text, code text, fullname text, telephone text, new_role text, enabled boolean, manager text, scopes jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE old_row public.staff_members%ROWTYPE; saved public.staff_members%ROWTYPE; verified_email text; before_json jsonb; after_json jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(74162901);
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=actor AND active AND role='admin' AND public.sales_identity_exists(user_sub)) THEN RAISE EXCEPTION 'admin required'; END IF;
 SELECT * INTO old_row FROM public.staff_members WHERE user_sub=subject;
 IF coalesce(old_row.scope_revision,0)<>expected_revision THEN RAISE EXCEPTION 'stale revision'; END IF;
 SELECT u.email INTO verified_email FROM neon_auth."user" u WHERE u.id::text=subject AND NOT coalesce(u.banned,false);
 IF verified_email IS NULL THEN RAISE EXCEPTION 'provisioned identity required'; END IF;
 IF manager IS NOT NULL AND (new_role NOT IN ('sales','manager') OR NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=manager AND role='manager' AND active)) THEN RAISE EXCEPTION 'invalid manager'; END IF;
 IF manager IS NOT NULL AND (manager=subject OR EXISTS(WITH RECURSIVE chain(id,path) AS (SELECT manager,ARRAY[manager] UNION ALL SELECT m.manager_sub,c.path||m.manager_sub FROM chain c JOIN public.staff_members m ON m.user_sub=c.id WHERE m.manager_sub IS NOT NULL AND NOT m.manager_sub=ANY(c.path)) SELECT 1 FROM chain WHERE id=subject)) THEN RAISE EXCEPTION 'invalid manager cycle'; END IF;
 IF old_row.role='admin' AND old_row.active AND (NOT enabled OR new_role<>'admin') AND NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub<>subject AND role='admin' AND active) THEN RAISE EXCEPTION 'last admin'; END IF;
 SELECT jsonb_build_object('staff',to_jsonb(old_row),'scopes',coalesce(jsonb_agg(to_jsonb(s)) FILTER(WHERE s.user_sub IS NOT NULL),'[]'::jsonb)) INTO before_json FROM public.staff_scopes s WHERE s.user_sub=subject;
 -- No-op staff saves must not invalidate offline scope_revision, suppressing
 -- already-queued legitimate notifications. Exact identity and manager checks
 -- above still apply before this branch; compare normalized scope sets.
 IF old_row.user_sub IS NOT NULL
  AND old_row.employee_code IS NOT DISTINCT FROM code
  AND old_row.full_name IS NOT DISTINCT FROM fullname
  AND old_row.email IS NOT DISTINCT FROM verified_email
  AND old_row.phone IS NOT DISTINCT FROM nullif(telephone,'')
  AND old_row.role IS NOT DISTINCT FROM new_role
  AND old_row.active IS NOT DISTINCT FROM enabled
  AND old_row.manager_sub IS NOT DISTINCT FROM manager
  AND (SELECT coalesce(jsonb_agg(jsonb_build_object('province',x.province,'district',x.district)
        ORDER BY x.province,x.district),'[]'::jsonb)
       FROM public.staff_scopes x WHERE x.user_sub=subject)
     IS NOT DISTINCT FROM
      (SELECT coalesce(jsonb_agg(jsonb_build_object('province',t.province,'district',t.district)
         ORDER BY t.province,t.district),'[]'::jsonb)
       FROM (SELECT DISTINCT btrim(z.province) AS province,btrim(z.district) AS district
          FROM jsonb_to_recordset(scopes) AS z(province text,district text)) t)
 THEN RETURN before_json; END IF;
 INSERT INTO public.staff_members(user_sub,employee_code,full_name,email,phone,role,active,manager_sub)
 VALUES(subject,code,fullname,verified_email,nullif(telephone,''),new_role,enabled,manager)
 ON CONFLICT(user_sub) DO UPDATE SET employee_code=excluded.employee_code,full_name=excluded.full_name,email=excluded.email,phone=excluded.phone,role=excluded.role,active=excluded.active,manager_sub=excluded.manager_sub,scope_revision=staff_members.scope_revision+1,updated_at=now()
 RETURNING * INTO saved;
 DELETE FROM public.staff_scopes WHERE user_sub=subject;
 INSERT INTO public.staff_scopes(user_sub,province,district) SELECT subject,x.province,x.district FROM jsonb_to_recordset(scopes) AS x(province text,district text);
 -- Invalidate the cached scope of all old/new ancestors even for territory-only edits.
 WITH RECURSIVE ancestors(id,path) AS (
  SELECT seed,ARRAY[seed] FROM unnest(ARRAY[old_row.manager_sub,manager]) seed WHERE seed IS NOT NULL
  UNION ALL SELECT m.manager_sub,a.path||m.manager_sub FROM ancestors a JOIN public.staff_members m ON m.user_sub=a.id WHERE m.manager_sub IS NOT NULL AND NOT m.manager_sub=ANY(a.path)
 ) UPDATE public.staff_members SET scope_revision=scope_revision+1,updated_at=now() WHERE user_sub IN (SELECT id FROM ancestors) AND user_sub<>subject;
 after_json=jsonb_build_object('staff',to_jsonb(saved),'scopes',scopes);
 INSERT INTO public.staff_permission_events(actor_sub,target_sub,action,before_state,after_state) VALUES(actor,subject,'save',before_json,after_json);
 RETURN after_json;
END;
$function$;
