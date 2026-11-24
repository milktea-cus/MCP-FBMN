-- 228 N2: transactional, audit-backed action notification producers.
-- Installed with all producers DISABLED. Each is enabled only after DB negative tests.
-- Never create a trigger on imported school/stock/catalog data or general row edits.
CREATE OR REPLACE FUNCTION public.sales_notification_enqueue(
 p_event_key text,p_category text,p_entity_key text,p_actor text,p_recipient text,
 p_title text,p_body text,p_occurred_at timestamptz DEFAULT now()
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $function$
DECLARE
 v_category public.field_notification_categories%ROWTYPE;
 v_recipient public.staff_members%ROWTYPE;
 v_mode text;
 v_event bigint;
 v_new bigint;
 v_group bigint;
 v_minute integer;
 v_quiet_start integer;
 v_quiet_end integer;
 v_local timestamp;
 v_available timestamptz;
BEGIN
 IF char_length(p_event_key) NOT BETWEEN 1 AND 160 OR char_length(p_entity_key) NOT BETWEEN 1 AND 160
  OR char_length(p_title) NOT BETWEEN 1 AND 160 OR char_length(p_body) NOT BETWEEN 1 AND 500
  OR p_occurred_at IS NULL OR p_occurred_at>now()+interval '5 minutes'
  OR p_actor=p_recipient OR NOT EXISTS (
   SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor AND s.active AND public.sales_identity_exists(s.user_sub)
  ) THEN RETURN NULL; END IF;
 SELECT * INTO v_category FROM public.field_notification_categories WHERE category=p_category AND producer_enabled;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT * INTO v_recipient FROM public.staff_members WHERE user_sub=p_recipient AND active AND public.sales_identity_exists(user_sub);
 IF NOT FOUND THEN RETURN NULL; END IF;
 -- N1 denies every producer without a concrete module-level recipient resolver.
 -- Target's existing DB ACL is the only business-action resolver enabled here.
 IF p_category='target' THEN
   IF NOT public.sales_staff_action_allowed(p_actor,p_recipient,'target') THEN RETURN NULL; END IF;
 ELSIF p_category IN ('assignment','security') THEN
   -- Staff mutation audit is admin-only; a recipient must be the actual subject.
   IF NOT EXISTS (SELECT 1 FROM public.staff_members s WHERE s.user_sub=p_actor AND
     s.role='admin' AND s.active AND public.sales_identity_exists(s.user_sub))
   THEN RETURN NULL; END IF;
 ELSIF p_category='support' THEN
   -- The only cross-owner support editor in the existing RPC is Admin.
   -- Never guess an assignee from a free-text department or a province.
   IF NOT EXISTS (SELECT 1 FROM public.sales_records r JOIN public.staff_members a
      ON a.user_sub=p_actor AND a.active AND a.role='admin'
      WHERE r.kind='support' AND r.id::text=p_entity_key AND r.owner_sub=p_recipient
        AND public.sales_staff_action_allowed(p_actor,r.owner_sub,'view'))
   THEN RETURN NULL; END IF;
 ELSIF p_category='order_action' THEN
   -- Both sides must still be allowed to see the actual order's customer.
   IF NOT EXISTS (SELECT 1 FROM public.field_orders o
      JOIN public.customers c ON c.id=o.customer_id AND c.owner_sub=o.owner_sub
      WHERE o.id::text=p_entity_key AND o.owner_sub=p_recipient
        AND public.sales_can_access(p_actor,o.owner_sub,c.province,c.district)
        AND public.sales_can_access(p_recipient,o.owner_sub,c.province,c.district)
        AND o.status IN ('cancelled','superseded','imported'))
   THEN RETURN NULL; END IF;
 ELSE
   -- Plans/trips remain self-owned in today's app; other categories fail closed.
   RETURN NULL;
 END IF;
 SELECT coalesce(p.mode,v_category.default_mode) INTO v_mode
 FROM (SELECT 1) a LEFT JOIN public.field_notification_preferences p
 ON p.recipient_sub=p_recipient AND p.category=p_category;
 IF v_category.mandatory AND v_mode='off' THEN v_mode:='in_app'; END IF;
 IF v_mode='off' THEN RETURN NULL; END IF;
 -- All recipients for a canonical event share one immutable event key.
 INSERT INTO public.field_notification_events(event_key,category,entity_key,actor_sub,occurred_at)
 VALUES(p_event_key,p_category,p_entity_key,p_actor,p_occurred_at)
 ON CONFLICT(event_key) DO NOTHING RETURNING id INTO v_event;
 IF v_event IS NULL THEN
  SELECT id INTO v_event FROM public.field_notification_events
   WHERE event_key=p_event_key AND category=p_category AND entity_key=p_entity_key AND actor_sub=p_actor;
  IF v_event IS NULL THEN RETURN NULL; END IF;
 END IF;
 -- Prevent concurrent retries and multiple events from racing the group counter.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_recipient||':'||p_category||':'||p_entity_key,33));
 INSERT INTO public.field_notification_event_recipients(event_id,recipient_sub)
 VALUES(v_event,p_recipient) ON CONFLICT DO NOTHING RETURNING event_id INTO v_new;
 IF v_new IS NULL THEN
  SELECT notification_id INTO v_new FROM public.field_notification_event_recipients
   WHERE event_id=v_event AND recipient_sub=p_recipient;
  RETURN v_new;
 END IF;
 SELECT id INTO v_group FROM public.field_notifications WHERE recipient_sub=p_recipient AND category=p_category
  AND entity_key=p_entity_key AND scope_revision=v_recipient.scope_revision
  AND created_at>now()-interval '15 minutes' ORDER BY created_at DESC,id DESC LIMIT 1 FOR UPDATE;
 IF v_group IS NOT NULL THEN
  UPDATE public.field_notifications SET group_count=group_count+1,updated_at=now(),body=p_body
   WHERE id=v_group;
  UPDATE public.field_notification_event_recipients SET notification_id=v_group
   WHERE event_id=v_event AND recipient_sub=p_recipient;
  RETURN v_group;
 END IF;
 INSERT INTO public.field_notifications(recipient_sub,event_key,title,body,category,entity_key,scope_revision,updated_at)
 VALUES(p_recipient,p_event_key,p_title,p_body,p_category,p_entity_key,v_recipient.scope_revision,now())
 ON CONFLICT(recipient_sub,event_key) DO NOTHING RETURNING id INTO v_group;
 IF v_group IS NULL THEN
  SELECT id INTO v_group FROM public.field_notifications
  WHERE recipient_sub=p_recipient AND event_key=p_event_key;
 END IF;
 UPDATE public.field_notification_event_recipients SET notification_id=v_group
 WHERE event_id=v_event AND recipient_sub=p_recipient;
 IF v_mode='in_app' OR p_occurred_at<now()-interval '24 hours' THEN RETURN v_group; END IF;
 SELECT coalesce(s.quiet_start,1260),coalesce(s.quiet_end,420)
 INTO v_quiet_start,v_quiet_end FROM (SELECT 1) a LEFT JOIN public.field_notification_settings s
 ON s.recipient_sub=p_recipient;
 v_local:=now() AT TIME ZONE 'Asia/Ho_Chi_Minh';
 v_available:=now();
 IF v_mode='digest' THEN
  v_available:=(date_trunc('day',v_local)+interval '18 hours') AT TIME ZONE 'Asia/Ho_Chi_Minh';
  IF v_available<=now() THEN v_available:=v_available+interval '1 day'; END IF;
 END IF;
 -- Check quiet hours at the actual scheduled dispatch slot (18:00 for digest),
 -- not the original enqueue time. Otherwise a custom quiet period can be bypassed.
 v_local:=v_available AT TIME ZONE 'Asia/Ho_Chi_Minh';
 v_minute:=extract(hour from v_local)::int*60+extract(minute from v_local)::int;
 IF v_quiet_start<>v_quiet_end AND (
   (v_quiet_start<v_quiet_end AND v_minute>=v_quiet_start AND v_minute<v_quiet_end)
   OR (v_quiet_start>v_quiet_end AND (v_minute>=v_quiet_start OR v_minute<v_quiet_end))) THEN
  v_available:=greatest(v_available,(
   date_trunc('day',v_local)+make_interval(mins=>v_quiet_end)
   + CASE WHEN v_quiet_start>v_quiet_end AND v_minute>=v_quiet_start
     THEN interval '1 day' ELSE interval '0' END
  ) AT TIME ZONE 'Asia/Ho_Chi_Minh');
 END IF;
 INSERT INTO public.field_notification_outbox(event_id,recipient_sub,scope_revision,mode,available_at,expires_at,notification_id)
 VALUES(v_event,p_recipient,v_recipient.scope_revision,v_mode,v_available,v_available+interval '6 hours',v_group)
 ON CONFLICT DO NOTHING;
 RETURN v_group;
END
$function$;

CREATE OR REPLACE FUNCTION public.sales_n2_target_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n2$
DECLARE changed boolean;
BEGIN
 IF NEW.actor_sub=NEW.owner_sub OR NEW.actor_sub IS NULL OR NEW.owner_sub IS NULL
   OR jsonb_typeof(NEW.after_data)<>'array' OR jsonb_array_length(NEW.after_data)=0
 THEN RETURN NEW; END IF;
 -- Ignore no-op amount updates even when the legacy RPC increments version.
 SELECT EXISTS(
  SELECT 1 FROM jsonb_array_elements(NEW.after_data) WITH ORDINALITY a(item,pos)
  LEFT JOIN jsonb_array_elements(coalesce(NEW.before_data,'[]'::jsonb)) WITH ORDINALITY b(item,pos)
    ON b.pos=a.pos
  WHERE b.item IS NULL OR (b.item->>'amount') IS DISTINCT FROM (a.item->>'amount')
 ) INTO changed;
 IF NOT changed THEN RETURN NEW; END IF;
 PERFORM public.sales_notification_enqueue('target:'||NEW.id::text,'target',
  'target:'||NEW.owner_sub||':'||coalesce(NEW.request->>'year',''),
  NEW.actor_sub,NEW.owner_sub,'Chỉ tiêu đã thay đổi',
  'Có cập nhật chỉ tiêu cần xem trong Field Work.',NEW.created_at);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 RAISE WARNING 'N2 target audit notification failed (SQLSTATE %)',SQLSTATE;
 RETURN NEW;
END $n2$;

CREATE OR REPLACE FUNCTION public.sales_n2_staff_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n2$
DECLARE kind text; old_staff jsonb;new_staff jsonb; target_active boolean;
BEGIN
 IF NEW.actor_sub IS NULL OR NEW.target_sub IS NULL OR NEW.actor_sub=NEW.target_sub
  OR NEW.action NOT IN ('save','reassign_direct_report') THEN RETURN NEW; END IF;
 IF NEW.action='reassign_direct_report' THEN
   IF NEW.before_state->>'manager_sub' IS NOT DISTINCT FROM NEW.after_state->>'manager_sub'
     THEN RETURN NEW; END IF;
   kind:='assignment';
 ELSE
   old_staff:=NEW.before_state->'staff';
   new_staff:=NEW.after_state->'staff';
   IF new_staff IS NULL THEN RETURN NEW; END IF;
   IF (old_staff->>'role') IS DISTINCT FROM (new_staff->>'role')
      OR (old_staff->>'active') IS DISTINCT FROM (new_staff->>'active') THEN
     kind:='security';
   ELSIF (old_staff->>'manager_sub') IS DISTINCT FROM (new_staff->>'manager_sub')
      OR coalesce(NEW.before_state->'scopes','[]'::jsonb)
         IS DISTINCT FROM coalesce(NEW.after_state->'scopes','[]'::jsonb) THEN
     kind:='assignment';
   ELSE RETURN NEW;
   END IF;
 END IF;
 SELECT s.active AND public.sales_identity_exists(s.user_sub) INTO target_active
  FROM public.staff_members s WHERE s.user_sub=NEW.target_sub;
 IF NOT coalesce(target_active,false) THEN RETURN NEW; END IF;
 PERFORM public.sales_notification_enqueue('staff:'||NEW.id::text,kind,
  'staff:'||NEW.target_sub,NEW.actor_sub,NEW.target_sub,
  'Quyền hoặc phân công đã thay đổi',
  'Mở Field Work để cập nhật phạm vi làm việc.',NEW.happened_at);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 RAISE WARNING 'N2 staff audit notification failed (SQLSTATE %)',SQLSTATE;
 RETURN NEW;
END $n2$;

CREATE OR REPLACE FUNCTION public.sales_n2_support_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n2$
DECLARE recipient text;
BEGIN
 IF NEW.operation<>'update' OR NEW.before_state IS NULL THEN RETURN NEW; END IF;
 -- Only meaningful actionable transitions, not edits to title, notes, attachments.
 IF (NEW.before_state->'data'->>'status') IS NOT DISTINCT FROM
    (NEW.after_state->'data'->>'status')
  AND (NEW.before_state->'data'->>'priority') IS NOT DISTINCT FROM
    (NEW.after_state->'data'->>'priority')
  AND (NEW.before_state->'data'->>'dueDate') IS NOT DISTINCT FROM
    (NEW.after_state->'data'->>'dueDate') THEN RETURN NEW; END IF;
 SELECT r.owner_sub INTO recipient FROM public.sales_records r
 WHERE r.id=NEW.record_id AND r.kind='support' AND r.version=(NEW.after_state->>'version')::integer;
 IF recipient IS NULL OR recipient=NEW.actor_sub THEN RETURN NEW; END IF;
 PERFORM public.sales_notification_enqueue('support:'||NEW.id::text,'support',
  NEW.record_id::text,NEW.actor_sub,recipient,
  'Đề xuất hỗ trợ được cập nhật','Có cập nhật cần xem trong Field Work.',NEW.created_at);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 RAISE WARNING 'N2 support audit notification failed (SQLSTATE %)',SQLSTATE;
 RETURN NEW;
END $n2$;

CREATE OR REPLACE FUNCTION public.sales_n2_order_audit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n2$
DECLARE recipient text; act text;
BEGIN
 act:=NEW.request_data->>'action';
 IF act NOT IN ('cancel','replace') OR NEW.before_data IS NULL
  OR NEW.before_data->>'status' NOT IN ('exported','imported')
 THEN RETURN NEW; END IF;
 SELECT o.owner_sub INTO recipient FROM public.field_orders o
 WHERE o.id=NEW.order_id AND o.version>(NEW.before_data->>'version')::integer;
 IF recipient IS NULL OR recipient=NEW.actor_sub THEN RETURN NEW; END IF;
 PERFORM public.sales_notification_enqueue('order_action:'||NEW.op_id::text,'order_action',
  NEW.order_id::text,NEW.actor_sub,recipient,'Đơn hàng cần kiểm tra',
  'Đơn hàng đã hủy hoặc điều chỉnh sau xuất. Mở Field Work để xem.',NEW.created_at);
 RETURN NEW;
EXCEPTION WHEN OTHERS THEN
 RAISE WARNING 'N2 order audit notification failed (SQLSTATE %)',SQLSTATE;
 RETURN NEW;
END $n2$;

DROP TRIGGER IF EXISTS trg_n2_target_notification ON public.sales_target_mutations;
CREATE TRIGGER trg_n2_target_notification AFTER INSERT ON public.sales_target_mutations
 FOR EACH ROW EXECUTE FUNCTION public.sales_n2_target_audit();
DROP TRIGGER IF EXISTS trg_n2_staff_notification ON public.staff_permission_events;
CREATE TRIGGER trg_n2_staff_notification AFTER INSERT ON public.staff_permission_events
 FOR EACH ROW EXECUTE FUNCTION public.sales_n2_staff_audit();
DROP TRIGGER IF EXISTS trg_n2_support_notification ON public.sales_scoped_record_audit;
CREATE TRIGGER trg_n2_support_notification AFTER INSERT ON public.sales_scoped_record_audit
 FOR EACH ROW EXECUTE FUNCTION public.sales_n2_support_audit();
DROP TRIGGER IF EXISTS trg_n2_order_notification ON public.field_order_ops;
CREATE TRIGGER trg_n2_order_notification AFTER INSERT ON public.field_order_ops
 FOR EACH ROW EXECUTE FUNCTION public.sales_n2_order_audit();

REVOKE ALL ON FUNCTION public.sales_n2_target_audit(),public.sales_n2_staff_audit(),
 public.sales_n2_support_audit(),public.sales_n2_order_audit() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_notification_enqueue(text,text,text,text,text,text,text,timestamptz) TO sales_api;
-- No producer_enabled update here. Owner-controlled feature rollout only.
