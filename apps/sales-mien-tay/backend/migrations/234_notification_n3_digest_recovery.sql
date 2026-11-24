-- 234 N3: completed-route suppression and stale digest outbox recovery.
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
      AND r.route_date=c.d AND r.status='ready' AND p.status='planned'
      AND NOT EXISTS(SELECT 1 FROM public.field_work_sessions w
       WHERE w.day_route_id=r.id AND w.state='done')) AS day_routes,
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

CREATE OR REPLACE FUNCTION public.sales_n3_tick()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n3$
BEGIN
 -- The N1 Worker used to mark digest outbox rows done without aggregating them.
 -- Recover abandoned leases and dead-letter only expired rows, never send
 -- an individual digest item or retry an already acknowledged device.
 UPDATE public.field_notification_outbox SET state='dead',lease_until=NULL,lease_id=NULL
   WHERE mode='digest' AND expires_at<=now()
     AND state IN ('pending','processing');
 UPDATE public.field_notification_outbox SET state='pending',lease_until=NULL,lease_id=NULL
   WHERE mode='digest' AND expires_at>now() AND state='processing'
     AND lease_until<now();
 RETURN public.sales_n3_run_at(now());
END
$n3$;
