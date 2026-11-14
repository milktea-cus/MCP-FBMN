-- 047: Fix the production schedule deletion failure (SQLSTATE 23514).
-- Migration 046 emits field_route_audit.action='cancel', but migration 042
-- allowed only 'create'/'update'. The resulting constraint violation rolled
-- back BOTH the route and monthly plan archive, returning a 503 to the app.
-- Keep the audit event distinct from a regular edit.
ALTER TABLE public.field_route_audit
 DROP CONSTRAINT IF EXISTS field_route_audit_action_check;
ALTER TABLE public.field_route_audit
 ADD CONSTRAINT field_route_audit_action_check
 CHECK (action IN ('create','update','cancel'));

-- Audit constraints must support every action that DB functions can emit.
DO $fbmn$
BEGIN
 IF NOT EXISTS (
  SELECT 1 FROM pg_constraint
  WHERE conrelid='public.field_route_audit'::regclass
    AND conname='field_route_audit_action_check'
    AND pg_get_constraintdef(oid) LIKE '%cancel%'
 ) THEN
  RAISE EXCEPTION 'route audit cancel action is not allowed';
 END IF;
END $fbmn$;
