-- 031_staff_business_assignments_auto_read.sql
-- Personnel hierarchy and business coverage are separate. Only view is automatic.
CREATE TABLE IF NOT EXISTS public.staff_business_assignments (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 scope_kind text NOT NULL CHECK (scope_kind IN ('chain','customer')),
 scope_key text NOT NULL,
 active boolean NOT NULL DEFAULT true,
 assigned_by text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_sub,scope_kind,scope_key)
);

CREATE OR REPLACE FUNCTION public.sales_set_staff_business_assignment(
 p_actor text,p_staff text,p_kind text,p_key text,p_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
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
END $fbmn$;

REVOKE ALL ON FUNCTION public.sales_set_staff_business_assignment(text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_set_staff_business_assignment(text,text,text,text,boolean) TO sales_api;
GRANT SELECT ON public.staff_business_assignments TO sales_api;
GRANT USAGE,SELECT ON SEQUENCE public.staff_business_assignments_id_seq TO sales_api;

-- Business scopes belong to employees, not their supervisors. Hierarchy only widens read visibility.
CREATE OR REPLACE FUNCTION public.sales_staff_business_matches_customer(p_staff text,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
 SELECT EXISTS(
  SELECT 1 FROM public.staff_members s JOIN public.customers c ON c.id=p_customer
  WHERE s.user_sub=p_staff AND s.active
    AND (
      c.owner_sub=s.user_sub
      OR EXISTS(SELECT 1 FROM public.customer_scope_bindings b
                WHERE b.customer_id=c.id AND b.active AND b.scope_kind='staff' AND b.scope_key=s.user_sub)
      OR EXISTS(SELECT 1 FROM public.staff_scopes geo
                WHERE geo.user_sub=s.user_sub AND geo.province=c.province
                  AND (geo.district='' OR geo.district=c.district))
      OR EXISTS(SELECT 1 FROM public.staff_business_assignments x
         WHERE x.user_sub=s.user_sub AND x.active AND
           ((x.scope_kind='customer' AND x.scope_key=c.id::text)
           OR (x.scope_kind='chain' AND EXISTS(
              SELECT 1 FROM public.customer_scope_bindings b
              WHERE b.customer_id=c.id AND b.active AND b.scope_kind='chain' AND b.scope_key=x.scope_key))))
    )
 );
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_staff_business_matches_customer(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_staff_business_matches_customer(text,uuid) TO sales_api;

-- Peer managers see only the overlap of their two directly assigned geographic areas.
-- Descendants of a peer may be visible there, but not outside that common area.
CREATE OR REPLACE FUNCTION public.sales_auto_customer_view(p_actor text,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
 SELECT EXISTS(
  SELECT 1 FROM public.staff_members actor JOIN public.customers c ON c.id=p_customer
  WHERE actor.user_sub=p_actor AND actor.active AND public.sales_identity_exists(actor.user_sub)
  AND (
    EXISTS(SELECT 1 FROM public.staff_members member WHERE member.active
       AND public.sales_staff_in_subtree(actor.user_sub,member.user_sub)
       AND public.sales_staff_business_matches_customer(member.user_sub,c.id))
    OR (
      actor.role='manager' AND EXISTS(
        SELECT 1 FROM public.staff_members peer
        JOIN public.staff_scopes actor_geo ON actor_geo.user_sub=actor.user_sub
        JOIN public.staff_scopes peer_geo ON peer_geo.user_sub=peer.user_sub
        WHERE peer.role='manager' AND peer.active AND peer.user_sub<>actor.user_sub
          AND peer.manager_sub IS NOT DISTINCT FROM actor.manager_sub
          AND actor_geo.province=c.province AND peer_geo.province=c.province
          AND (actor_geo.district='' OR actor_geo.district=c.district)
          AND (peer_geo.district='' OR peer_geo.district=c.district)
          AND EXISTS(SELECT 1 FROM public.staff_members member WHERE member.active
            AND public.sales_staff_in_subtree(peer.user_sub,member.user_sub)
            AND public.sales_staff_business_matches_customer(member.user_sub,c.id))
      ))
  )
 );
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_auto_customer_view(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_auto_customer_view(text,uuid) TO sales_api;

-- Preserve every existing explicit action grant and self-owner permission. Only add automatic VIEW.
CREATE OR REPLACE FUNCTION public.sales_customer_allowed(p_actor text,p_customer uuid,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
 SELECT EXISTS (
 SELECT 1 FROM public.staff_members a JOIN public.customers c ON c.id=p_customer
 WHERE a.user_sub=p_actor AND a.active AND public.sales_identity_exists(a.user_sub)
   AND (
     a.role='admin'
     OR (c.owner_sub=p_actor AND p_action IN ('view','create','edit','media','report','export','actuals','target'))
     OR (p_action='view' AND public.sales_auto_customer_view(p_actor,c.id))
     OR EXISTS (
       SELECT 1 FROM public.scope_grants g
       WHERE g.grantee_sub=a.user_sub AND g.active AND g.action=p_action
         AND (
           (g.scope_kind='customer' AND g.scope_key=c.id::text)
           OR (g.scope_kind IN ('territory','team','chain','staff') AND EXISTS(
             SELECT 1 FROM public.customer_scope_bindings b
             WHERE b.customer_id=c.id AND b.active AND b.scope_kind=g.scope_kind AND b.scope_key=g.scope_key
               AND (b.scope_kind<>'territory' OR b.scope_key IN (c.province||'|',c.province||'|'||c.district))
           ))
           OR (g.scope_kind='staff' AND public.sales_staff_in_subtree(g.scope_key,c.owner_sub))
         )
     )
   )
 );
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_customer_allowed(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_allowed(text,uuid,text) TO sales_api;

-- Read staff reports through management ancestry; no new rights to edit/approve/transfer.
CREATE OR REPLACE FUNCTION public.sales_staff_action_allowed(p_actor text,p_owner text,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'pg_catalog','public'
AS $fbmn$
 SELECT EXISTS (
 SELECT 1 FROM public.staff_members actor JOIN public.staff_members owner
   ON owner.user_sub=p_owner AND owner.active
 WHERE actor.user_sub=p_actor AND actor.active AND public.sales_identity_exists(actor.user_sub)
 AND (actor.role='admin' OR (actor.user_sub=p_owner AND p_action IN ('view','target','actuals','report','export'))
      OR (p_action='view' AND public.sales_staff_in_subtree(p_actor,p_owner))
      OR EXISTS(SELECT 1 FROM public.scope_grants g
         WHERE g.grantee_sub=p_actor AND g.active AND g.action=p_action
           AND (
             (g.scope_kind='staff' AND public.sales_staff_in_subtree(g.scope_key,p_owner))
             OR (g.scope_kind='team' AND EXISTS(
               SELECT 1 FROM public.org_team_members tm WHERE tm.team_id::text=g.scope_key AND tm.user_sub=p_owner))
           ))));
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_staff_action_allowed(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_staff_action_allowed(text,text,text) TO sales_api;
