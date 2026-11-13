-- P0-3 audit reader: signed-in viewer may read only customers within scope.
-- Keep raw audit table inaccessible to the shared runtime DB role.
CREATE OR REPLACE FUNCTION public.sales_customer_brand_audit(
 p_actor text,p_customer uuid)
RETURNS TABLE(
 actor_sub text,action text,reason text,
 created_at timestamptz,brand_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor
    AND s.active AND public.sales_identity_exists(s.user_sub))
    OR NOT public.sales_customer_allowed(p_actor,p_customer,'view')
 THEN RAISE EXCEPTION 'brand_customer_forbidden'; END IF;
 RETURN QUERY SELECT a.actor_sub,a.action,a.reason,a.created_at,b.name
  FROM public.customer_brand_verification_audit a
  JOIN public.catalog_brands b ON b.id=a.brand_id
  WHERE a.customer_id=p_customer
  ORDER BY a.created_at DESC,a.id DESC LIMIT 50;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_customer_brand_audit(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_brand_audit(text,uuid) TO sales_api;
