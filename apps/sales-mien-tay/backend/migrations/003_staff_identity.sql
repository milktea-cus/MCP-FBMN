-- P1: additive staff principals, authorization and permission audit. No business data removed.
BEGIN;
CREATE TABLE IF NOT EXISTS public.staff_members (
 user_sub text PRIMARY KEY,
 employee_code text NOT NULL UNIQUE CHECK(length(btrim(employee_code)) BETWEEN 1 AND 80),
 full_name text NOT NULL CHECK(length(btrim(full_name)) BETWEEN 1 AND 240),
 email text NOT NULL,
 phone text,
 role text NOT NULL CHECK(role IN ('admin','manager','sales')),
 active boolean NOT NULL DEFAULT true,
 manager_sub text REFERENCES public.staff_members(user_sub),
 scope_revision bigint NOT NULL DEFAULT 1 CHECK(scope_revision > 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(manager_sub IS DISTINCT FROM user_sub)
);

CREATE TABLE IF NOT EXISTS public.staff_permission_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_sub text NOT NULL,
 target_sub text NOT NULL,
 action text NOT NULL,
 before_state jsonb,
 after_state jsonb,
 happened_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS staff_manager_idx ON public.staff_members(manager_sub);

CREATE OR REPLACE FUNCTION public.sales_can_access(actor text, owner_id text, p text, d text)
RETURNS boolean LANGUAGE sql STABLE SET search_path = pg_catalog, public AS $$
 SELECT EXISTS (
 SELECT 1 FROM public.staff_members a WHERE a.user_sub=actor AND a.active AND (
 a.role='admin' OR (
 (a.user_sub=owner_id OR (a.role='manager' AND EXISTS (
 SELECT 1 FROM public.staff_members m WHERE m.user_sub=owner_id AND m.manager_sub=a.user_sub AND m.role='sales'
 ))) AND (
 (p IS NULL AND a.user_sub=owner_id) OR
 EXISTS (SELECT 1 FROM public.staff_scopes s WHERE s.user_sub=a.user_sub AND s.province=p AND (s.district='' OR s.district=d))
 )
 )))
$$;

REVOKE ALL ON FUNCTION public.sales_can_access(text,text,text,text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.sales_can_access(text,text,text,text) TO sales_api;

GRANT SELECT,INSERT,UPDATE ON public.staff_members TO sales_api;

GRANT SELECT,INSERT ON public.staff_permission_events TO sales_api;

GRANT USAGE,SELECT ON SEQUENCE public.staff_permission_events_id_seq TO sales_api;

GRANT SELECT,INSERT,UPDATE,DELETE ON public.staff_scopes TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_identity_exists(subject text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT 1 FROM neon_auth."user" u WHERE u.id::text=subject AND u."emailVerified" AND NOT coalesce(u.banned,false))
$$;

REVOKE ALL ON FUNCTION public.sales_identity_exists(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.sales_identity_exists(text) TO sales_api;
COMMIT;
