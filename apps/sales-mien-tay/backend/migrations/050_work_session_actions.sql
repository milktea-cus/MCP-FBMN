-- P0-B: fieldwork session RPCs, idempotent across devices, audited.
CREATE OR REPLACE FUNCTION public.sales_start_work_session(
 p_actor text,p_id uuid,p_route uuid,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE route_row public.field_day_routes%ROWTYPE;
        prior public.field_work_sessions%ROWTYPE;
        active_row public.field_work_sessions%ROWTYPE;
        saved public.field_work_sessions%ROWTYPE;
BEGIN
 IF p_actor IS NULL OR p_id IS NULL OR p_route IS NULL OR p_at IS NULL OR
    p_at>now()+interval '1 minute' OR p_at<now()-interval '30 days'
 THEN RAISE EXCEPTION 'INVALID_WORK_SESSION'; END IF;
 SELECT r.* INTO route_row FROM public.field_day_routes r
 JOIN public.field_monthly_plans m ON m.id=r.monthly_plan_id
 WHERE r.id=p_route AND r.owner_sub=p_actor
  AND r.status='ready' AND m.status='planned'
  AND public.sales_monthly_plan_scope_allowed(p_actor,m.scope_kind,m.scope_key,m.province,m.district)
 FOR UPDATE OF r;
 IF NOT FOUND THEN RAISE EXCEPTION 'SCOPE_REVOKED'; END IF;
 IF (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date<>route_row.route_date
 THEN RAISE EXCEPTION 'WORK_SESSION_WRONG_DAY'; END IF;
 PERFORM pg_advisory_xact_lock(1846169,hashtext(p_actor));
 SELECT * INTO prior FROM public.field_work_sessions
 WHERE day_route_id=p_route FOR UPDATE;
 IF prior.id IS NOT NULL THEN
  IF prior.owner_sub<>p_actor THEN RAISE EXCEPTION 'SCOPE_REVOKED'; END IF;
  IF prior.state<>'ongoing' THEN RAISE EXCEPTION 'SESSION_CLOSED'; END IF;
  RETURN to_jsonb(prior)||jsonb_build_object('already_saved',true);
 END IF;
 SELECT * INTO active_row FROM public.field_work_sessions
 WHERE owner_sub=p_actor AND state='ongoing' LIMIT 1;
 IF active_row.id IS NOT NULL THEN RAISE EXCEPTION 'SESSION_ACTIVE_OTHER_ROUTE'; END IF;
 INSERT INTO public.field_work_sessions(
  id,day_route_id,owner_sub,state,opened_at,last_mutation_ref)
 VALUES(p_id,p_route,p_actor,'ongoing',p_at,p_id) RETURNING * INTO saved;
 INSERT INTO public.field_work_session_audit(
  session_id,day_route_id,actor_sub,action,mutation_ref,captured_at)
 VALUES(p_id,p_route,p_actor,'start',p_id,p_at);
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_start_work_session(text,uuid,uuid,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_start_work_session(text,uuid,uuid,timestamptz) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_close_work_session(
 p_actor text,p_id uuid,p_ref uuid,p_version integer,p_action text,p_at timestamptz,p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE current_row public.field_work_sessions%ROWTYPE;
        saved public.field_work_sessions%ROWTYPE;
BEGIN
 IF p_actor IS NULL OR p_id IS NULL OR p_ref IS NULL OR
  p_action NOT IN ('done','cancelled') OR p_at IS NULL OR
  p_at>now()+interval '1 minute' OR p_at<now()-interval '30 days' OR
  length(coalesce(p_note,''))>2000
 THEN RAISE EXCEPTION 'INVALID_WORK_SESSION'; END IF;
 SELECT * INTO current_row FROM public.field_work_sessions
 WHERE id=p_id AND owner_sub=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SCOPE_REVOKED'; END IF;
 IF current_row.state<>'ongoing' THEN
  IF current_row.state=p_action AND current_row.close_ref=p_ref THEN
   RETURN to_jsonb(current_row)||jsonb_build_object('already_saved',true);
  END IF;
  RAISE EXCEPTION 'SESSION_CLOSED';
 END IF;
 IF current_row.version<>p_version THEN RAISE EXCEPTION 'WORK_SESSION_VERSION_CONFLICT'; END IF;
 IF p_at<current_row.opened_at THEN RAISE EXCEPTION 'INVALID_WORK_SESSION'; END IF;
 UPDATE public.field_work_sessions
 SET state=p_action,ended_at=p_at,close_ref=p_ref,close_note=coalesce(p_note,''),
  last_mutation_ref=p_ref,version=version+1,updated_at=now()
 WHERE id=p_id RETURNING * INTO saved;
 INSERT INTO public.field_work_session_audit(
  session_id,day_route_id,actor_sub,action,mutation_ref,captured_at,details)
 VALUES(p_id,saved.day_route_id,p_actor,
  CASE WHEN p_action='done' THEN 'end' ELSE 'cancel' END,p_ref,p_at,
  jsonb_build_object('note',coalesce(p_note,'')));
 RETURN to_jsonb(saved);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_close_work_session(
 text,uuid,uuid,integer,text,timestamptz,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_close_work_session(
 text,uuid,uuid,integer,text,timestamptz,text) TO sales_api;

-- User-confirmed deletion only for an ENDED session with no execution.
-- Do not delete route/stop/customer or audit. Pending device drafts cannot
-- be inspected by the server and MUST be checked by the UI before invoking.
CREATE OR REPLACE FUNCTION public.sales_delete_empty_work_session(
 p_actor text,p_id uuid,p_ref uuid,p_version integer,p_confirm text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE saved public.field_work_sessions%ROWTYPE;
BEGIN
 IF p_actor IS NULL OR p_id IS NULL OR p_ref IS NULL OR p_confirm<>'DELETE_EMPTY'
 THEN RAISE EXCEPTION 'INVALID_WORK_SESSION'; END IF;
 SELECT * INTO saved FROM public.field_work_sessions
 WHERE id=p_id AND owner_sub=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SCOPE_REVOKED'; END IF;
 IF saved.state='ongoing' THEN RAISE EXCEPTION 'SESSION_STILL_ACTIVE'; END IF;
 IF saved.version<>p_version THEN RAISE EXCEPTION 'WORK_SESSION_VERSION_CONFLICT'; END IF;
 IF EXISTS(SELECT 1 FROM public.field_route_stops st
     WHERE st.day_route_id=saved.day_route_id AND
      (st.is_unplanned OR st.missed_code IS NOT NULL))
 OR EXISTS(SELECT 1 FROM public.field_visits v
     JOIN public.field_route_stops st ON st.id=v.day_route_stop_id
     WHERE st.day_route_id=saved.day_route_id)
 OR EXISTS(SELECT 1 FROM public.field_survey_sessions ss
     JOIN public.field_route_stops st ON st.id=ss.day_route_stop_id
     WHERE st.day_route_id=saved.day_route_id)
 OR EXISTS(SELECT 1 FROM public.field_area_visits a
     LEFT JOIN public.field_route_stops st ON st.id=a.day_route_stop_id
     WHERE coalesce(a.day_route_id,st.day_route_id)=saved.day_route_id)
 THEN RAISE EXCEPTION 'SESSION_HAS_ACTIVITY'; END IF;
 INSERT INTO public.field_work_session_audit(
  session_id,day_route_id,actor_sub,action,mutation_ref,captured_at,details)
 VALUES(p_id,saved.day_route_id,p_actor,'delete_empty',p_ref,now(),
  jsonb_build_object('previous_state',saved.state));
 DELETE FROM public.field_work_sessions WHERE id=p_id;
 RETURN jsonb_build_object('deleted',true,'id',p_id,'day_route_id',saved.day_route_id);
END
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_delete_empty_work_session(
 text,uuid,uuid,integer,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_delete_empty_work_session(
 text,uuid,uuid,integer,text) TO sales_api;
