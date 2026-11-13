-- P0-K2: organization / customer responsibility ACL, additive and fail-closed.
-- Keep owner_sub and legacy staff_scopes unchanged. New grants require explicit customer bindings.
BEGIN;
ALTER TABLE public.staff_members ADD COLUMN IF NOT EXISTS job_title text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS created_by_sub text;
UPDATE public.customers SET created_by_sub=owner_sub WHERE created_by_sub IS NULL;
CREATE TABLE IF NOT EXISTS public.territory_catalog (
 code text PRIMARY KEY, name text NOT NULL, level text NOT NULL CHECK(level IN ('region','province','district','ward')),
 parent_code text REFERENCES public.territory_catalog(code), legacy_labels text[] NOT NULL DEFAULT '{}',
 active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS public.org_teams (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 160),
 created_by text NOT NULL REFERENCES public.staff_members(user_sub), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.org_team_members (
 team_id uuid NOT NULL REFERENCES public.org_teams(id) ON DELETE RESTRICT,
 user_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 PRIMARY KEY(team_id,user_sub)
);
CREATE TABLE IF NOT EXISTS public.customer_chains (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(btrim(name)) BETWEEN 2 AND 160),
 created_by text NOT NULL REFERENCES public.staff_members(user_sub), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.scope_grants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 grantee_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 scope_kind text NOT NULL CHECK(scope_kind IN ('territory','team','chain','staff','customer')),
 scope_key text NOT NULL CHECK(length(btrim(scope_key)) BETWEEN 1 AND 240),
 action text NOT NULL CHECK(action IN ('view','create','edit','transfer','approve','target','actuals','report','export','media','staff_manage')),
 active boolean NOT NULL DEFAULT true,
 granted_by text NOT NULL REFERENCES public.staff_members(user_sub),
 granted_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(grantee_sub,scope_kind,scope_key,action)
);
CREATE INDEX IF NOT EXISTS scope_grants_active_idx ON public.scope_grants(grantee_sub,action,scope_kind,scope_key) WHERE active;
CREATE TABLE IF NOT EXISTS public.customer_scope_bindings (
 customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
 scope_kind text NOT NULL CHECK(scope_kind IN ('territory','team','chain','staff')),
 scope_key text NOT NULL CHECK(length(btrim(scope_key)) BETWEEN 1 AND 240),
 active boolean NOT NULL DEFAULT true,
 assigned_by text NOT NULL REFERENCES public.staff_members(user_sub),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(customer_id,scope_kind,scope_key)
);
CREATE INDEX IF NOT EXISTS customer_scope_bindings_idx ON public.customer_scope_bindings(scope_kind,scope_key,customer_id) WHERE active;
CREATE TABLE IF NOT EXISTS public.scope_change_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, actor_sub text NOT NULL,
 subject_kind text NOT NULL, subject_key text NOT NULL, action text NOT NULL,
 before_state jsonb, after_state jsonb, happened_at timestamptz NOT NULL DEFAULT now()
);
-- Owner permissions are retained. A Manager's title, matching province or parent link alone
-- does NOT grant customer access. Explicit grants + responsibility bindings are mandatory.
CREATE OR REPLACE FUNCTION public.sales_customer_allowed(p_actor text,p_customer uuid,p_action text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $acl$
 SELECT EXISTS (
 SELECT 1 FROM public.staff_members a
 JOIN public.customers c ON c.id=p_customer
 WHERE a.user_sub=p_actor AND a.active AND public.sales_identity_exists(a.user_sub)
   AND (
     a.role='admin'
     OR (c.owner_sub=p_actor AND p_action IN ('view','create','edit','media','report','export','actuals','target'))
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
           OR (g.scope_kind='staff' AND g.scope_key=c.owner_sub AND EXISTS (
             SELECT 1 FROM public.staff_members o WHERE o.user_sub=c.owner_sub AND o.active
           ))
         )
     )
   )
 );
$acl$;
REVOKE ALL ON FUNCTION public.sales_customer_allowed(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_customer_allowed(text,uuid,text) TO sales_api;
-- All changes to scope are DB-checked and audited. No direct writes for sales_api.
CREATE OR REPLACE FUNCTION public.sales_set_scope_grant(p_actor text,p_grantee text,p_kind text,p_key text,p_action text,p_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $acl$
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
END;$acl$;
REVOKE ALL ON FUNCTION public.sales_set_scope_grant(text,text,text,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_set_scope_grant(text,text,text,text,text,boolean) TO sales_api;
CREATE OR REPLACE FUNCTION public.sales_set_customer_binding(p_actor text,p_customer uuid,p_kind text,p_key text,p_active boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $acl$
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
END;$acl$;
REVOKE ALL ON FUNCTION public.sales_set_customer_binding(text,uuid,text,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_set_customer_binding(text,uuid,text,text,boolean) TO sales_api;
GRANT SELECT ON public.territory_catalog,public.org_teams,public.org_team_members,public.customer_chains,public.scope_grants,public.customer_scope_bindings,public.scope_change_audit TO sales_api;
GRANT SELECT,INSERT ON public.org_teams,public.org_team_members,public.customer_chains TO sales_api;
GRANT USAGE,SELECT ON SEQUENCE public.scope_change_audit_id_seq TO sales_api;
COMMIT;
