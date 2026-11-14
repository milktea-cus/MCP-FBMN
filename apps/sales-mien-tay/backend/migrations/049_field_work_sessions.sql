-- P0-B. State of the fieldwork visit, separate from survey sessions.
-- Additive; keeps all existing routes, stops and survey history.
CREATE TABLE IF NOT EXISTS public.field_work_sessions(
 id uuid PRIMARY KEY,
 day_route_id uuid NOT NULL UNIQUE REFERENCES public.field_day_routes(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 state text NOT NULL CHECK (state IN ('ongoing','done','cancelled')),
 opened_at timestamptz NOT NULL,
 ended_at timestamptz,
 close_note text NOT NULL DEFAULT '' CHECK (length(close_note)<=2000),
 close_ref uuid,
 last_mutation_ref uuid NOT NULL,
 version integer NOT NULL DEFAULT 1 CHECK (version>0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT work_session_end_shape CHECK (
  (state='ongoing' AND ended_at IS NULL AND close_ref IS NULL)
  OR (state IN ('done','cancelled') AND ended_at IS NOT NULL AND close_ref IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS field_work_sessions_actor_active
 ON public.field_work_sessions(owner_sub) WHERE state='ongoing';
CREATE INDEX IF NOT EXISTS field_work_sessions_owner_date
 ON public.field_work_sessions(owner_sub,opened_at DESC);
CREATE TABLE IF NOT EXISTS public.field_work_session_audit(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 session_id uuid NOT NULL,
 day_route_id uuid NOT NULL REFERENCES public.field_day_routes(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK (action IN ('start','end','cancel','delete_empty')),
 mutation_ref uuid NOT NULL,
 captured_at timestamptz NOT NULL,
 details jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(session_id,mutation_ref)
);
CREATE INDEX IF NOT EXISTS field_work_session_audit_route
 ON public.field_work_session_audit(day_route_id,created_at DESC);
REVOKE ALL ON public.field_work_sessions,public.field_work_session_audit FROM PUBLIC;
GRANT SELECT ON public.field_work_sessions,public.field_work_session_audit TO sales_api;

CREATE OR REPLACE FUNCTION public.field_guard_work_session_route()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
BEGIN
 IF (NEW.route_date IS DISTINCT FROM OLD.route_date OR
     NEW.status IS DISTINCT FROM OLD.status) AND
  EXISTS(SELECT 1 FROM public.field_work_sessions w WHERE w.day_route_id=OLD.id)
 THEN RAISE EXCEPTION 'SESSION_ALREADY_STARTED'; END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS field_work_session_route_guard ON public.field_day_routes;
CREATE TRIGGER field_work_session_route_guard
 BEFORE UPDATE ON public.field_day_routes FOR EACH ROW
 EXECUTE FUNCTION public.field_guard_work_session_route();

-- Permit retried writes captured during a completed session. Earlier
-- offline clients without a session keep using their prior API contract.
CREATE OR REPLACE FUNCTION public.sales_work_session_write_allowed(
 p_actor text,p_route uuid,p_event timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE w public.field_work_sessions%ROWTYPE;
BEGIN
 SELECT * INTO w FROM public.field_work_sessions
 WHERE day_route_id=p_route AND owner_sub=p_actor;
 IF w.id IS NULL THEN RETURN true; END IF;
 IF w.state='ongoing' THEN RETURN true; END IF;
 RETURN p_event IS NOT NULL AND
  p_event>=w.opened_at-interval '1 minute' AND p_event<=w.ended_at;
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_work_session_write_allowed(text,uuid,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_work_session_write_allowed(text,uuid,timestamptz) TO sales_api;
