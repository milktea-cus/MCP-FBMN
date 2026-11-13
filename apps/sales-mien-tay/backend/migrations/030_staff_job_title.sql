-- 030_staff_job_title.sql
-- Additive: arbitrary display title remains separate from fixed auth roles.
-- Retain old ten-argument entry point for existing clients.
CREATE OR REPLACE FUNCTION public.sales_save_staff(
 actor text, subject text, code text, fullname text, telephone text,
 new_role text, enabled boolean, manager text, scopes jsonb,
 expected_revision bigint, title text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog', 'public'
AS $fbmn$
DECLARE payload jsonb; clean_title text;
BEGIN
 clean_title := nullif(btrim(coalesce(title,'')),'');
 IF length(coalesce(clean_title,'')) > 120 THEN RAISE EXCEPTION 'invalid title'; END IF;
 -- The ten-argument function already checks admin, identity, manager cycles and revision.
 payload := public.sales_save_staff(actor,subject,code,fullname,telephone,
                                    new_role,enabled,manager,scopes,expected_revision);
 UPDATE public.staff_members SET job_title=clean_title WHERE user_sub=subject;
 RETURN jsonb_set(payload,'{staff,job_title}',coalesce(to_jsonb(clean_title),'null'::jsonb),true);
END
$fbmn$;

REVOKE ALL ON FUNCTION public.sales_save_staff(text,text,text,text,text,text,boolean,text,jsonb,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_save_staff(text,text,text,text,text,text,boolean,text,jsonb,bigint,text) TO sales_api;
