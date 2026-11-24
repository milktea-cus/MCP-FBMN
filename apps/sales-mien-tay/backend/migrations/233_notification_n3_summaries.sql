-- 233: N3 single actionable 07:00 / 18:00 digest in Asia/Ho_Chi_Minh.
-- No broadcast, no rows for empty slots, no historical replay.
-- New producer is OFF until rollback/CI/production smoke have succeeded.
INSERT INTO public.field_notification_categories(category,default_mode,producer_enabled,mandatory)
VALUES('daily_digest','immediate',false,false) ON CONFLICT(category) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sales_n3_counts(p_owner text,p_at timestamptz,p_slot text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO pg_catalog,public AS $n3$
 WITH clock AS (
   SELECT (p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS d,
    (date_trunc('day',p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')
      AT TIME ZONE 'Asia/Ho_Chi_Minh') AS start_at,
    ((date_trunc('day',p_at AT TIME ZONE 'Asia/Ho_Chi_Minh')+interval '1 day')
      AT TIME ZONE 'Asia/Ho_Chi_Minh') AS stop_at
 ), figures AS (
 SELECT
  (SELECT count(*)::int FROM public.field_day_routes r
    JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
    WHERE p_slot='morning' AND r.owner_sub=p_owner AND p.owner_sub=p_owner
      AND r.route_date=c.d AND r.status='ready' AND p.status='planned') AS day_routes,
  (SELECT count(*)::int FROM public.field_day_routes r
    JOIN public.field_monthly_plans p ON p.id=r.monthly_plan_id
    WHERE p_slot='morning' AND r.owner_sub=p_owner AND p.owner_sub=p_owner
      AND r.route_date BETWEEN c.d-7 AND c.d-1
      AND r.status='ready' AND p.status='planned'
      AND NOT EXISTS(SELECT 1 FROM public.field_work_sessions w
       WHERE w.day_route_id=r.id AND w.state='done')) AS overdue_routes,
  (SELECT count(*)::int FROM public.field_local_route_rules r
    WHERE p_slot='morning' AND extract(isodow from c.d)=1
      AND r.owner_sub=p_owner AND r.mode='week' AND r.active AND r.start_on<=c.d
      AND public.sales_local_scopes_allowed(p_owner,r.scopes)) AS weekly_routes,
  (SELECT count(*)::int FROM public.field_local_monthly_routes r
    WHERE p_slot='morning' AND extract(day from c.d)::int IN (1,8,15,22,29)
      AND r.owner_sub=p_owner AND r.active
      AND r.week_no=1+((extract(day from c.d)::int-1)/7)
      AND public.sales_local_scopes_allowed(p_owner,r.scopes)) AS monthly_routes,
  (SELECT count(*)::int FROM public.field_trips t WHERE p_slot='morning'
      AND t.owner_sub=p_owner AND t.closed_at IS NULL
      AND t.end_date BETWEEN c.d-7 AND c.d+1) AS trips_due,
  (SELECT count(*)::int FROM public.field_visits v WHERE p_slot='evening'
      AND v.owner_sub=p_owner AND v.checkin_at>=c.start_at AND v.checkin_at<c.stop_at) AS visits,
  (SELECT count(*)::int FROM public.field_area_visits v WHERE p_slot='evening'
      AND v.owner_sub=p_owner AND v.checkin_at>=c.start_at AND v.checkin_at<c.stop_at) AS area_visits,
  (SELECT count(*)::int FROM public.field_survey_sessions se WHERE p_slot='evening'
      AND se.owner_sub=p_owner AND se.status='completed'
      AND se.ended_at>=c.start_at AND se.ended_at<c.stop_at) AS surveys,
  (SELECT count(*)::int FROM public.field_prospect_visits pv WHERE p_slot='evening'
      AND pv.owner_sub=p_owner AND pv.checked_at>=c.start_at AND pv.checked_at<c.stop_at) AS prospect_visits,
  (SELECT count(*)::int FROM public.field_prospect_events e
     JOIN public.field_prospects pr ON pr.id=e.prospect_id
     WHERE p_slot='evening' AND e.actor_sub=p_owner AND pr.owner_sub=p_owner
       AND e.action IN ('convert','converted','close','closed')
       AND e.created_at>=c.start_at AND e.created_at<c.stop_at) AS prospect_changes,
  (SELECT count(*)::int FROM public.field_customer_work_actions w WHERE p_slot='evening'
      AND w.owner_sub=p_owner AND w.captured_at>=c.start_at AND w.captured_at<c.stop_at) AS customer_work,
  (SELECT count(*)::int FROM public.field_orders o WHERE p_slot='evening'
      AND o.owner_sub=p_owner AND o.status IN ('exported','imported')
      AND (o.exported_at>=c.start_at AND o.exported_at<c.stop_at
           OR o.imported_at>=c.start_at AND o.imported_at<c.stop_at)) AS orders,
  (SELECT count(*)::int FROM public.sales_actuals a WHERE p_slot='evening'
      AND a.owner_sub=p_owner AND a.status='active' AND a.sale_date=c.d
      AND a.created_at>=c.start_at AND a.created_at<c.stop_at
      AND EXISTS(SELECT 1 FROM public.customers customer
        WHERE customer.id=a.customer_id AND customer.owner_sub=p_owner
          AND public.sales_customer_allowed(p_owner,customer.id,'actuals'))) AS actuals,
  (SELECT count(*)::int FROM public.sales_records v WHERE p_slot='evening'
      AND v.owner_sub=p_owner AND v.kind='competitor'
      AND v.updated_at>=c.start_at AND v.updated_at<c.stop_at) AS competitor,
  (SELECT count(*)::int FROM public.field_trips t WHERE p_slot='evening'
      AND t.owner_sub=p_owner AND t.closed_at>=c.start_at AND t.closed_at<c.stop_at) AS closed_trips,
  (SELECT count(*)::int FROM public.field_visits v
    JOIN public.customers customer ON customer.id=v.customer_id AND customer.owner_sub=v.owner_sub
    JOIN public.staff_members direct ON direct.user_sub=v.owner_sub AND direct.active
    JOIN public.staff_members mgr ON mgr.user_sub=p_owner AND mgr.active AND mgr.role='manager'
    WHERE p_slot='evening' AND direct.manager_sub=p_owner
      AND public.sales_staff_action_allowed(p_owner,direct.user_sub,'report')
      AND public.sales_customer_allowed(p_owner,customer.id,'view')
      AND v.checkin_at>=c.start_at AND v.checkin_at<c.stop_at) AS direct_reports
 FROM clock c)
 SELECT to_jsonb(figures) FROM figures
$n3$;

-- Only the DB owner can call arbitrary-clock fixtures. The Worker is allowed
-- to invoke the clock-safe public.sales_n3_tick() wrapper below.
CREATE OR REPLACE FUNCTION public.sales_n3_run_at(p_at timestamptz)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n3$
DECLARE
 v_local timestamp; v_day date;v_slot text;v_slot_key text;
 v_owner record; v_metrics jsonb;v_total integer;v_due integer;
 v_body text;v_mode text;v_title text;v_entity text;v_event bigint;v_notification bigint;
 v_available timestamptz;v_local_due timestamp;v_start int;v_end int;v_min int;
 v_push text;v_count integer:=0;
BEGIN
 IF p_at IS NULL THEN RETURN 0;END IF;
 v_local:=p_at AT TIME ZONE 'Asia/Ho_Chi_Minh';
 v_day:=v_local::date;
 IF extract(hour from v_local)::int=7 AND extract(minute from v_local)::int<15
 THEN v_slot:='morning';
 ELSIF extract(hour from v_local)::int=18 AND extract(minute from v_local)::int<15
 THEN v_slot:='evening';
 ELSE RETURN 0; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.field_notification_categories c
  WHERE c.category='daily_digest' AND c.producer_enabled) THEN RETURN 0;END IF;
 v_slot_key:=v_slot||':'||v_day::text;
 -- Exactly one scheduler creates each slot even across Workers/retries.
 IF NOT pg_try_advisory_xact_lock(hashtextextended('n3:'||v_slot_key,43))
 THEN RETURN 0; END IF;
 FOR v_owner IN
  SELECT s.user_sub,s.scope_revision FROM public.staff_members s
   WHERE s.active AND public.sales_identity_exists(s.user_sub)
    AND NOT EXISTS (SELECT 1 FROM public.field_notification_digest d
      WHERE d.recipient_sub=s.user_sub AND d.slot_key=v_slot_key)
   ORDER BY s.user_sub
 LOOP
  SELECT coalesce(p.mode,c.default_mode) INTO v_mode
   FROM public.field_notification_categories c
   LEFT JOIN public.field_notification_preferences p
    ON p.category=c.category AND p.recipient_sub=v_owner.user_sub
   WHERE c.category='daily_digest';
  IF v_mode='off' THEN CONTINUE;END IF;
  v_metrics:=public.sales_n3_counts(v_owner.user_sub,p_at,v_slot);
  SELECT coalesce(sum(value::int),0) INTO v_total
   FROM jsonb_each_text(v_metrics);
  v_due:=0;
  IF v_slot='evening' THEN
   SELECT count(*)::int INTO v_due
    FROM public.field_notification_outbox b
    JOIN public.field_notification_events e ON e.id=b.event_id
    JOIN public.field_notification_categories cat ON cat.category=e.category
    LEFT JOIN public.field_notification_preferences pref
       ON pref.recipient_sub=b.recipient_sub AND pref.category=e.category
    WHERE b.recipient_sub=v_owner.user_sub
      AND b.scope_revision=v_owner.scope_revision AND b.mode='digest'
      AND b.state='pending' AND b.expires_at>p_at
      AND e.occurred_at>=p_at-interval '24 hours' AND e.occurred_at<=p_at
      AND coalesce(pref.mode,cat.default_mode)='digest';
  END IF;
  IF v_total+v_due=0 THEN CONTINUE;END IF;
  v_title:=CASE WHEN v_slot='morning' THEN 'Việc cần làm hôm nay'
     ELSE 'Tổng kết công việc hôm nay' END;
  -- Only category counts in inbox; never names, amounts, email/notes or customer PII.
  IF v_slot='morning' THEN
   v_body:=concat_ws('; ',
    CASE WHEN (v_metrics->>'day_routes')::int>0 THEN
      'Tuyến hôm nay: '||(v_metrics->>'day_routes') ELSE NULL END,
    CASE WHEN (v_metrics->>'overdue_routes')::int>0 THEN
      'Tuyến cần chốt: '||(v_metrics->>'overdue_routes') ELSE NULL END,
    CASE WHEN (v_metrics->>'weekly_routes')::int>0 THEN
      'Tuyến tuần: '||(v_metrics->>'weekly_routes') ELSE NULL END,
    CASE WHEN (v_metrics->>'monthly_routes')::int>0 THEN
      'Tuyến tháng tuần '||(1+((extract(day from v_day)::int-1)/7))||': '||
        (v_metrics->>'monthly_routes') ELSE NULL END,
    CASE WHEN (v_metrics->>'trips_due')::int>0 THEN
      'Chuyến cần xử lý: '||(v_metrics->>'trips_due') ELSE NULL END);
  ELSE
   v_body:=concat_ws('; ',
    CASE WHEN (v_metrics->>'visits')::int>0 THEN 'Ghé thăm: '||(v_metrics->>'visits') ELSE NULL END,
    CASE WHEN (v_metrics->>'area_visits')::int>0 THEN 'Điểm tuyến: '||(v_metrics->>'area_visits') ELSE NULL END,
    CASE WHEN (v_metrics->>'surveys')::int>0 THEN 'Khảo sát: '||(v_metrics->>'surveys') ELSE NULL END,
    CASE WHEN (v_metrics->>'prospect_visits')::int>0 OR (v_metrics->>'prospect_changes')::int>0
      THEN 'Điểm tiềm năng xử lý: '||((v_metrics->>'prospect_visits')::int+
        (v_metrics->>'prospect_changes')::int) ELSE NULL END,
    CASE WHEN (v_metrics->>'customer_work')::int>0 THEN 'Công việc khách: '||(v_metrics->>'customer_work') ELSE NULL END,
    CASE WHEN (v_metrics->>'orders')::int>0 THEN 'Đơn xuất/nhập: '||(v_metrics->>'orders') ELSE NULL END,
    CASE WHEN (v_metrics->>'actuals')::int>0 THEN 'Dòng doanh số hôm nay: '||(v_metrics->>'actuals') ELSE NULL END,
    CASE WHEN (v_metrics->>'competitor')::int>0 THEN 'Đối thủ: '||(v_metrics->>'competitor') ELSE NULL END,
    CASE WHEN (v_metrics->>'closed_trips')::int>0 THEN 'Chuyến đã chốt: '||(v_metrics->>'closed_trips') ELSE NULL END,
    CASE WHEN (v_metrics->>'direct_reports')::int>0 THEN 'Ghé thăm cấp dưới được quyền xem: '||(v_metrics->>'direct_reports') ELSE NULL END,
    CASE WHEN v_due>0 THEN 'Thông báo gom: '||v_due ELSE NULL END);
  END IF;
  v_body:=left(v_body,500);
  v_entity:='daily:'||v_day::text||':'||v_slot;
  -- Event is immutable and globally unique per account + date + slot.
  INSERT INTO public.field_notification_events(event_key,category,entity_key,actor_sub,occurred_at)
   VALUES('n3:'||v_slot_key||':'||md5(v_owner.user_sub),'daily_digest',
    v_entity,v_owner.user_sub,p_at)
   ON CONFLICT(event_key) DO NOTHING RETURNING id INTO v_event;
  IF v_event IS NULL THEN CONTINUE;END IF;
  INSERT INTO public.field_notifications(recipient_sub,event_key,title,body,category,
    scope_revision,entity_key,group_count,created_at,updated_at)
   VALUES(v_owner.user_sub,'n3:'||v_slot_key||':'||md5(v_owner.user_sub),
    v_title,v_body,'daily_digest',v_owner.scope_revision,v_entity,
    greatest(1,v_total+v_due),p_at,p_at) RETURNING id INTO v_notification;
  INSERT INTO public.field_notification_event_recipients(event_id,recipient_sub,notification_id)
   VALUES(v_event,v_owner.user_sub,v_notification);
  INSERT INTO public.field_notification_digest(recipient_sub,slot_key,notification_id)
   VALUES(v_owner.user_sub,v_slot_key,v_notification);
  -- Per-category 'digest' items are represented exactly once by this slot.
  -- Do not silently mark them done if no real digest is produced.
  IF v_due>0 THEN
   UPDATE public.field_notification_outbox b SET state='done',lease_id=NULL,lease_until=NULL
    FROM public.field_notification_events e
    JOIN public.field_notification_categories cat ON cat.category=e.category
    LEFT JOIN public.field_notification_preferences pref
       ON pref.recipient_sub=v_owner.user_sub AND pref.category=e.category
    WHERE b.event_id=e.id AND b.recipient_sub=v_owner.user_sub
      AND b.scope_revision=v_owner.scope_revision AND b.mode='digest'
      AND b.state='pending' AND b.expires_at>p_at
      AND e.occurred_at>=p_at-interval '24 hours' AND e.occurred_at<=p_at
      AND coalesce(pref.mode,cat.default_mode)='digest';
  END IF;
  IF v_mode NOT IN ('in_app','off') THEN
   v_available:=p_at;
   SELECT coalesce(x.quiet_start,1260),coalesce(x.quiet_end,420)
      INTO v_start,v_end FROM (SELECT 1) k LEFT JOIN public.field_notification_settings x
         ON x.recipient_sub=v_owner.user_sub;
   v_local_due:=v_available AT TIME ZONE 'Asia/Ho_Chi_Minh';
   v_min:=extract(hour from v_local_due)::int*60+extract(minute from v_local_due)::int;
   IF v_start<>v_end AND (
       (v_start<v_end AND v_min>=v_start AND v_min<v_end)
       OR (v_start>v_end AND (v_min>=v_start OR v_min<v_end))) THEN
    v_available:=(date_trunc('day',v_local_due)+make_interval(mins=>v_end)
      +CASE WHEN v_start>v_end AND v_min>=v_start
        THEN interval '1 day' ELSE interval '0' END)
      AT TIME ZONE 'Asia/Ho_Chi_Minh';
   END IF;
   INSERT INTO public.field_notification_outbox(event_id,recipient_sub,scope_revision,
    mode,available_at,expires_at,notification_id)
   VALUES(v_event,v_owner.user_sub,v_owner.scope_revision,'immediate',
    v_available,v_available+interval '6 hours',v_notification);
  END IF;
  v_count:=v_count+1;
 END LOOP;
 RETURN v_count;
END
$n3$;

CREATE OR REPLACE FUNCTION public.sales_n3_tick()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n3$
BEGIN
 RETURN public.sales_n3_run_at(now());
END
$n3$;

REVOKE ALL ON FUNCTION public.sales_n3_counts(text,timestamptz,text),
 public.sales_n3_run_at(timestamptz),public.sales_n3_tick() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_n3_tick() TO sales_api;
GRANT SELECT,INSERT ON public.field_notification_digest TO sales_api;
