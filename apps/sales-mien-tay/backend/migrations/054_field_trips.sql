-- P0-T1: one canonical trip, many dates and assigned scopes.
CREATE TABLE IF NOT EXISTS public.field_trips (
 id uuid PRIMARY KEY,
 day_route_id uuid NOT NULL UNIQUE REFERENCES public.field_day_routes(id) ON DELETE RESTRICT,
 owner_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 start_date date NOT NULL,
 end_date date NOT NULL,
 purpose text NOT NULL CHECK (length(btrim(purpose)) BETWEEN 2 AND 500),
 note text NOT NULL DEFAULT '' CHECK(length(note)<=2000),
 priority_customer_ids jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(priority_customer_ids)='array'),
 closed_at timestamptz,
 close_note text NOT NULL DEFAULT '' CHECK(length(close_note)<=2000),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 last_mutation_ref uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT field_trip_date_range CHECK(end_date>=start_date AND end_date<=start_date+90)
);
CREATE INDEX IF NOT EXISTS field_trips_owner_dates ON public.field_trips(owner_sub,start_date,end_date);
CREATE TABLE IF NOT EXISTS public.field_trip_scopes(
 trip_id uuid NOT NULL REFERENCES public.field_trips(id) ON DELETE RESTRICT,
 scope_kind text NOT NULL CHECK(scope_kind IN ('territory','chain','customer')),
 scope_key text NOT NULL CHECK(length(scope_key) BETWEEN 1 AND 240),
 province text,district text,
 PRIMARY KEY(trip_id,scope_kind,scope_key),
 CONSTRAINT field_trip_scope_shape CHECK(
 (scope_kind='territory' AND province IS NOT NULL AND district IS NOT NULL AND scope_key=province||'|'||district)
 OR (scope_kind IN ('chain','customer') AND province IS NULL AND district IS NULL))
);
CREATE TABLE IF NOT EXISTS public.field_trip_audit(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 trip_id uuid NOT NULL REFERENCES public.field_trips(id) ON DELETE RESTRICT,
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 action text NOT NULL CHECK(action IN ('create','extend','close')),
 mutation_ref uuid NOT NULL,
 request_state jsonb NOT NULL,
 after_state jsonb NOT NULL,
 happened_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(trip_id,mutation_ref)
);
CREATE INDEX IF NOT EXISTS field_trip_audit_trip_time ON public.field_trip_audit(trip_id,happened_at DESC);
REVOKE ALL ON public.field_trips,public.field_trip_scopes,public.field_trip_audit FROM PUBLIC;
GRANT SELECT ON public.field_trips,public.field_trip_scopes,public.field_trip_audit TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_trip_customer_allowed(p_actor text,p_trip uuid,p_customer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
 SELECT public.sales_customer_fieldwork_allowed(p_actor,p_customer)
 AND EXISTS(
 SELECT 1 FROM public.field_trips t JOIN public.field_trip_scopes s ON s.trip_id=t.id
 JOIN public.customers c ON c.id=p_customer WHERE t.id=p_trip AND t.owner_sub=p_actor
 AND public.sales_monthly_plan_scope_allowed(p_actor,s.scope_kind,s.scope_key,s.province,s.district)
 AND ((s.scope_kind='territory' AND c.province=s.province AND (s.district='' OR c.district=s.district))
 OR (s.scope_kind='customer' AND c.id::text=s.scope_key)
 OR (s.scope_kind='chain' AND EXISTS(
 SELECT 1 FROM public.customer_scope_bindings b WHERE b.customer_id=c.id AND b.active
 AND b.scope_kind='chain' AND b.scope_key=s.scope_key))));
$fbmn$;
REVOKE ALL ON FUNCTION public.sales_trip_customer_allowed(text,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_trip_customer_allowed(text,uuid,uuid) TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_create_trip(
 p_actor text,p_id uuid,p_route uuid,p_start date,p_end date,
 p_purpose text,p_note text,p_scopes jsonb,p_priorities jsonb,p_ref uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE route_row record; scope_row jsonb; saved public.field_trips%ROWTYPE;
 prior record; payload jsonb; has_primary boolean:=false; priority_id text;
BEGIN
 IF p_actor IS NULL OR p_id IS NULL OR p_route IS NULL OR p_ref IS NULL
 OR p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end>p_start+90
 OR length(btrim(coalesce(p_purpose,''))) NOT BETWEEN 2 AND 500
 OR length(coalesce(p_note,''))>2000
 OR jsonb_typeof(p_scopes)<>'array' OR jsonb_array_length(p_scopes) NOT BETWEEN 1 AND 50
 OR jsonb_typeof(p_priorities)<>'array' OR jsonb_array_length(p_priorities)>500
 THEN RAISE EXCEPTION 'TRIP_INVALID'; END IF;
 payload:=jsonb_build_object('route',p_route,'start',p_start,'end',p_end,
  'purpose',btrim(p_purpose),'note',coalesce(p_note,''),
  'scopes',p_scopes,'priorities',p_priorities);
 PERFORM pg_advisory_xact_lock(1846190,hashtext(p_actor));
 SELECT * INTO prior FROM public.field_trip_audit WHERE trip_id=p_id AND mutation_ref=p_ref;
 IF FOUND THEN
  IF prior.action='create' AND prior.request_state=payload
  THEN RETURN prior.after_state||jsonb_build_object('already_saved',true); END IF;
  RAISE EXCEPTION 'TRIP_MUTATION_REPLAY_MISMATCH';
 END IF;
 IF EXISTS(SELECT 1 FROM public.field_trips WHERE id=p_id) THEN RAISE EXCEPTION 'TRIP_ALREADY_EXISTS'; END IF;
 SELECT r.id,r.owner_sub,r.route_date,r.status,p.status AS plan_status,p.scope_kind,p.scope_key
 INTO route_row FROM public.field_day_routes r JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
 WHERE r.id=p_route FOR UPDATE OF r;
 IF NOT FOUND OR route_row.owner_sub<>p_actor OR route_row.route_date<>p_start
 OR route_row.status<>'ready' OR route_row.plan_status<>'planned'
 THEN RAISE EXCEPTION 'TRIP_ROUTE_INVALID'; END IF;
 IF EXISTS(SELECT 1 FROM public.field_trips WHERE day_route_id=p_route)
 THEN RAISE EXCEPTION 'TRIP_ROUTE_IN_USE'; END IF;
 IF EXISTS(SELECT 1 FROM public.field_trips t WHERE t.owner_sub=p_actor AND t.closed_at IS NULL
 AND daterange(t.start_date,t.end_date,'[]') && daterange(p_start,p_end,'[]'))
 THEN RAISE EXCEPTION 'TRIP_DATES_OVERLAP'; END IF;
 FOR scope_row IN SELECT value FROM jsonb_array_elements(p_scopes) LOOP
  IF jsonb_typeof(scope_row)<>'object'
   OR coalesce(scope_row->>'scope_kind','') NOT IN ('territory','chain','customer')
   OR length(coalesce(scope_row->>'scope_key','')) NOT BETWEEN 1 AND 240
   OR NOT public.sales_monthly_plan_scope_allowed(p_actor,scope_row->>'scope_kind',
       scope_row->>'scope_key',scope_row->>'province',scope_row->>'district')
  THEN RAISE EXCEPTION 'TRIP_SCOPE_REVOKED'; END IF;
  IF scope_row->>'scope_kind'=route_row.scope_kind AND scope_row->>'scope_key'=route_row.scope_key
   THEN has_primary:=true; END IF;
 END LOOP;
 IF NOT has_primary THEN RAISE EXCEPTION 'TRIP_PRIMARY_SCOPE_REQUIRED'; END IF;
 INSERT INTO public.field_trips(id,day_route_id,owner_sub,start_date,end_date,
 purpose,note,priority_customer_ids,last_mutation_ref)
 VALUES(p_id,p_route,p_actor,p_start,p_end,btrim(p_purpose),coalesce(p_note,''),p_priorities,p_ref)
 RETURNING * INTO saved;
 FOR scope_row IN SELECT value FROM jsonb_array_elements(p_scopes) LOOP
  INSERT INTO public.field_trip_scopes(trip_id,scope_kind,scope_key,province,district)
   VALUES(p_id,scope_row->>'scope_kind',scope_row->>'scope_key',
    scope_row->>'province',scope_row->>'district');
 END LOOP;
 FOR priority_id IN SELECT jsonb_array_elements_text(p_priorities) LOOP
  IF priority_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  OR NOT public.sales_trip_customer_allowed(p_actor,p_id,priority_id::uuid)
  THEN RAISE EXCEPTION 'TRIP_PRIORITY_FORBIDDEN'; END IF;
 END LOOP;
 IF (SELECT count(DISTINCT x.value) FROM jsonb_array_elements_text(p_priorities) x(value))
 <>jsonb_array_length(p_priorities) THEN RAISE EXCEPTION 'TRIP_PRIORITY_DUPLICATE'; END IF;
 INSERT INTO public.field_trip_audit(trip_id,actor_sub,action,mutation_ref,request_state,after_state)
 VALUES(p_id,p_actor,'create',p_ref,payload,to_jsonb(saved));
 RETURN to_jsonb(saved);
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'TRIP_SCOPE_DUPLICATE';
END $fbmn$;

CREATE OR REPLACE FUNCTION public.sales_mutate_trip(
 p_actor text,p_id uuid,p_ref uuid,p_expected integer,p_action text,p_end date,
 p_note text,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fbmn$
DECLARE saved public.field_trips%ROWTYPE; prior record; payload jsonb;
BEGIN
 IF p_actor IS NULL OR p_id IS NULL OR p_ref IS NULL OR p_expected<1
 OR p_action NOT IN ('extend','close') OR length(coalesce(p_note,''))>2000
 OR p_at IS NULL OR p_at>now()+interval '1 minute' OR p_at<now()-interval '30 days'
 THEN RAISE EXCEPTION 'TRIP_INVALID'; END IF;
 payload:=jsonb_build_object('action',p_action,'expected',p_expected,'end',p_end,
   'note',coalesce(p_note,''),'at',p_at);
 PERFORM pg_advisory_xact_lock(1846190,hashtext(p_actor));
 SELECT * INTO prior FROM public.field_trip_audit WHERE trip_id=p_id AND mutation_ref=p_ref;
 IF FOUND THEN
  IF prior.request_state=payload THEN RETURN prior.after_state||jsonb_build_object('already_saved',true); END IF;
  RAISE EXCEPTION 'TRIP_MUTATION_REPLAY_MISMATCH';
 END IF;
 SELECT * INTO saved FROM public.field_trips WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR saved.owner_sub<>p_actor THEN RAISE EXCEPTION 'TRIP_FORBIDDEN'; END IF;
 IF saved.closed_at IS NOT NULL THEN RAISE EXCEPTION 'TRIP_CLOSED'; END IF;
 IF saved.version<>p_expected THEN RAISE EXCEPTION 'TRIP_VERSION_CONFLICT'; END IF;
 IF p_action='extend' THEN
  IF p_end IS NULL OR p_end<=saved.end_date OR p_end>saved.start_date+90
  THEN RAISE EXCEPTION 'TRIP_INVALID_EXTENSION'; END IF;
  IF EXISTS(SELECT 1 FROM public.field_trips other WHERE other.id<>p_id AND other.owner_sub=p_actor
    AND other.closed_at IS NULL AND daterange(other.start_date,other.end_date,'[]') &&
      daterange(saved.start_date,p_end,'[]'))
  THEN RAISE EXCEPTION 'TRIP_DATES_OVERLAP'; END IF;
  UPDATE public.field_trips SET end_date=p_end,version=version+1,last_mutation_ref=p_ref,updated_at=now()
   WHERE id=p_id RETURNING * INTO saved;
 ELSE
  IF p_end IS NOT NULL THEN RAISE EXCEPTION 'TRIP_INVALID'; END IF;
  UPDATE public.field_trips SET closed_at=p_at,close_note=coalesce(p_note,''),
   version=version+1,last_mutation_ref=p_ref,updated_at=now()
   WHERE id=p_id RETURNING * INTO saved;
  UPDATE public.field_work_sessions SET state='done',ended_at=p_at,close_note=coalesce(p_note,''),
    close_ref=p_ref,last_mutation_ref=p_ref,version=version+1,updated_at=now()
   WHERE day_route_id=saved.day_route_id AND owner_sub=p_actor AND state='ongoing';
 END IF;
 INSERT INTO public.field_trip_audit(trip_id,actor_sub,action,mutation_ref,request_state,after_state)
 VALUES(p_id,p_actor,p_action,p_ref,payload,to_jsonb(saved));
 RETURN to_jsonb(saved);
END $fbmn$;
REVOKE ALL ON FUNCTION public.sales_create_trip(text,uuid,uuid,date,date,text,text,jsonb,jsonb,uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sales_mutate_trip(text,uuid,uuid,integer,text,date,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_create_trip(text,uuid,uuid,date,date,text,text,jsonb,jsonb,uuid) TO sales_api;
GRANT EXECUTE ON FUNCTION public.sales_mutate_trip(text,uuid,uuid,integer,text,date,text,timestamptz) TO sales_api;

