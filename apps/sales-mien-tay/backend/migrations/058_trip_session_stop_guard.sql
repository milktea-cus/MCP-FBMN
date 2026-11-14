-- P0-T4: legacy work-session guard must also allow canonical trip execution.
CREATE OR REPLACE FUNCTION public.field_guard_work_session_stop()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $fbmn$
DECLARE work_state text; trip public.field_trips%ROWTYPE;
BEGIN
 SELECT state INTO work_state FROM public.field_work_sessions WHERE day_route_id=NEW.day_route_id;
 IF work_state IS NULL THEN RETURN NEW; END IF;
 SELECT * INTO trip FROM public.field_trips WHERE day_route_id=NEW.day_route_id;
 IF TG_OP='INSERT' THEN
  IF trip.id IS NOT NULL AND NEW.is_unplanned AND NEW.stop_kind='customer' THEN
   -- The scoped sales_add_trip_customer_stop RPC validates ownership,
   -- active dates, capture time, replay and duplicate customer before insert.
   RETURN NEW;
  END IF;
  IF NOT NEW.is_unplanned OR work_state<>'ongoing' THEN
   RAISE EXCEPTION 'SESSION_ALREADY_STARTED'; END IF;
  RETURN NEW;
 END IF;
 IF work_state<>'ongoing' AND
  (NEW.missed_code IS DISTINCT FROM OLD.missed_code OR
   NEW.missed_note IS DISTINCT FROM OLD.missed_note)
 THEN
  IF trip.id IS NULL OR NEW.missed_at IS NULL
   OR (NEW.missed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date NOT BETWEEN trip.start_date AND trip.end_date
   OR (trip.closed_at IS NOT NULL AND NEW.missed_at>trip.closed_at)
  THEN RAISE EXCEPTION 'SESSION_CLOSED'; END IF;
 END IF;
 IF NEW.sequence IS DISTINCT FROM OLD.sequence OR
  NEW.purpose IS DISTINCT FROM OLD.purpose OR
  NEW.stop_kind IS DISTINCT FROM OLD.stop_kind OR
  NEW.customer_id IS DISTINCT FROM OLD.customer_id OR
  NEW.chain_id IS DISTINCT FROM OLD.chain_id
 THEN RAISE EXCEPTION 'SESSION_ALREADY_STARTED'; END IF;
 RETURN NEW;
END $fbmn$;
