-- Atomic staff updates. Authorization is rechecked inside the database transaction.
BEGIN;
CREATE OR REPLACE FUNCTION public.sales_save_staff(actor text, subject text, code text, fullname text, telephone text, new_role text, enabled boolean, manager text, scopes jsonb, expected_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $$
DECLARE old_row public.staff_members%ROWTYPE; saved public.staff_members%ROWTYPE; verified_email text; before_json jsonb; after_json jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(74162901);
 IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=actor AND active AND role='admin') THEN RAISE EXCEPTION 'admin required'; END IF;
 SELECT * INTO old_row FROM public.staff_members WHERE user_sub=subject;
 IF coalesce(old_row.scope_revision,0)<>expected_revision THEN RAISE EXCEPTION 'stale revision'; END IF;
 SELECT u.email INTO verified_email FROM neon_auth."user" u WHERE u.id::text=subject AND u."emailVerified" AND NOT coalesce(u.banned,false);
 IF verified_email IS NULL THEN RAISE EXCEPTION 'verified identity required'; END IF;
 IF manager IS NOT NULL AND (new_role<>'sales' OR NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub=manager AND role='manager' AND active)) THEN RAISE EXCEPTION 'invalid manager'; END IF;
 IF old_row.role='admin' AND old_row.active AND (NOT enabled OR new_role<>'admin') AND NOT EXISTS(SELECT 1 FROM public.staff_members WHERE user_sub<>subject AND role='admin' AND active) THEN RAISE EXCEPTION 'last admin'; END IF;
 SELECT jsonb_build_object('staff',to_jsonb(old_row),'scopes',coalesce(jsonb_agg(to_jsonb(s)) FILTER(WHERE s.user_sub IS NOT NULL),'[]'::jsonb)) INTO before_json FROM public.staff_scopes s WHERE s.user_sub=subject;
 INSERT INTO public.staff_members(user_sub,employee_code,full_name,email,phone,role,active,manager_sub)
 VALUES(subject,code,fullname,verified_email,nullif(telephone,''),new_role,enabled,manager)
 ON CONFLICT(user_sub) DO UPDATE SET employee_code=excluded.employee_code,full_name=excluded.full_name,email=excluded.email,phone=excluded.phone,role=excluded.role,active=excluded.active,manager_sub=excluded.manager_sub,scope_revision=staff_members.scope_revision+1,updated_at=now()
 RETURNING * INTO saved;
 DELETE FROM public.staff_scopes WHERE user_sub=subject;
 INSERT INTO public.staff_scopes(user_sub,province,district) SELECT subject,x.province,x.district FROM jsonb_to_recordset(scopes) AS x(province text,district text);
 after_json=jsonb_build_object('staff',to_jsonb(saved),'scopes',scopes);
 INSERT INTO public.staff_permission_events(actor_sub,target_sub,action,before_state,after_state) VALUES(actor,subject,'save',before_json,after_json);
 RETURN after_json;
END;
$$;
REVOKE ALL ON FUNCTION public.sales_save_staff(text,text,text,text,text,text,boolean,text,jsonb,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_staff(text,text,text,text,text,text,boolean,text,jsonb,bigint) TO sales_api;
COMMIT;
