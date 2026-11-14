-- P0-B. DB-side mutation guards: do not rely only on a hidden Flutter button.
-- Legacy routes with no work-session row retain their existing write contract.
CREATE OR REPLACE FUNCTION public.field_guard_work_session_evidence()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
DECLARE route_id uuid;
        event_at timestamptz;
BEGIN
 IF TG_TABLE_NAME='field_visits' THEN
  IF NEW.day_route_stop_id IS NULL THEN RETURN NEW; END IF;
  SELECT day_route_id INTO route_id FROM public.field_route_stops
    WHERE id=NEW.day_route_stop_id;
  event_at:=NEW.checkin_at;
 ELSIF TG_TABLE_NAME='field_area_visits' THEN
  route_id:=NEW.day_route_id;
  IF route_id IS NULL THEN
   SELECT day_route_id INTO route_id FROM public.field_route_stops
    WHERE id=NEW.day_route_stop_id;
  END IF;
  event_at:=NEW.checkin_at;
 ELSIF TG_TABLE_NAME='field_survey_sessions' THEN
  IF NEW.day_route_stop_id IS NULL THEN RETURN NEW; END IF;
  SELECT day_route_id INTO route_id FROM public.field_route_stops
    WHERE id=NEW.day_route_stop_id;
  event_at:=coalesce(NEW.ended_at,NEW.started_at);
 ELSE
  RETURN NEW;
 END IF;
 IF route_id IS NOT NULL AND
   NOT public.sales_work_session_write_allowed(NEW.owner_sub,route_id,event_at)
 THEN RAISE EXCEPTION 'SESSION_CLOSED'; END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS field_work_visit_guard ON public.field_visits;
CREATE TRIGGER field_work_visit_guard BEFORE INSERT OR UPDATE ON public.field_visits
 FOR EACH ROW EXECUTE FUNCTION public.field_guard_work_session_evidence();
DROP TRIGGER IF EXISTS field_work_area_guard ON public.field_area_visits;
CREATE TRIGGER field_work_area_guard BEFORE INSERT OR UPDATE ON public.field_area_visits
 FOR EACH ROW EXECUTE FUNCTION public.field_guard_work_session_evidence();
DROP TRIGGER IF EXISTS field_work_survey_guard ON public.field_survey_sessions;
CREATE TRIGGER field_work_survey_guard BEFORE INSERT OR UPDATE ON public.field_survey_sessions
 FOR EACH ROW EXECUTE FUNCTION public.field_guard_work_session_evidence();

CREATE OR REPLACE FUNCTION public.field_guard_work_session_stop()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
DECLARE work_state text;
BEGIN
 SELECT state INTO work_state FROM public.field_work_sessions
 WHERE day_route_id=NEW.day_route_id;
 IF work_state IS NULL THEN RETURN NEW; END IF;
 IF TG_OP='INSERT' THEN
  IF NOT NEW.is_unplanned OR work_state<>'ongoing' THEN
   RAISE EXCEPTION 'SESSION_ALREADY_STARTED'; END IF;
  RETURN NEW;
 END IF;
 IF work_state<>'ongoing' AND
  (NEW.missed_code IS DISTINCT FROM OLD.missed_code OR
   NEW.missed_note IS DISTINCT FROM OLD.missed_note)
 THEN RAISE EXCEPTION 'SESSION_CLOSED'; END IF;
 IF NEW.sequence IS DISTINCT FROM OLD.sequence OR
  NEW.purpose IS DISTINCT FROM OLD.purpose OR
  NEW.stop_kind IS DISTINCT FROM OLD.stop_kind OR
  NEW.customer_id IS DISTINCT FROM OLD.customer_id OR
  NEW.chain_id IS DISTINCT FROM OLD.chain_id
 THEN RAISE EXCEPTION 'SESSION_ALREADY_STARTED'; END IF;
 RETURN NEW;
END $fbmn$;
DROP TRIGGER IF EXISTS field_work_stop_guard ON public.field_route_stops;
CREATE TRIGGER field_work_stop_guard BEFORE INSERT OR UPDATE ON public.field_route_stops
 FOR EACH ROW EXECUTE FUNCTION public.field_guard_work_session_stop();
