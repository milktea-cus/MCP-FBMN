-- 223: atomic canonical event receiver, scope-safe outbox linkage, 15-minute grouping.
ALTER TABLE public.field_notifications
 ADD COLUMN IF NOT EXISTS entity_key text CHECK (entity_key IS NULL OR char_length(entity_key) BETWEEN 1 AND 160);
ALTER TABLE public.field_notification_outbox
 ADD COLUMN IF NOT EXISTS notification_id bigint REFERENCES public.field_notifications(id),
 ADD COLUMN IF NOT EXISTS budget_reserved boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS public.field_notification_event_recipients (
 event_id bigint NOT NULL REFERENCES public.field_notification_events(id),
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 notification_id bigint REFERENCES public.field_notifications(id),
 PRIMARY KEY(event_id,recipient_sub)
);
CREATE INDEX IF NOT EXISTS field_notifications_group_window_idx ON public.field_notifications
 (recipient_sub,category,entity_key,created_at DESC)
 WHERE entity_key IS NOT NULL;
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
 v_minute:=extract(hour from v_local)::int*60+extract(minute from v_local)::int;
 v_available:=now();
 IF v_mode='digest' THEN
  v_available:=(date_trunc('day',v_local)+interval '18 hours') AT TIME ZONE 'Asia/Ho_Chi_Minh';
  IF v_available<=now() THEN v_available:=v_available+interval '1 day'; END IF;
 END IF;
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
REVOKE ALL ON FUNCTION public.sales_notification_enqueue(text,text,text,text,text,text,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_notification_enqueue(text,text,text,text,text,text,text,timestamptz) TO sales_api;
GRANT SELECT,INSERT,UPDATE ON public.field_notification_events,public.field_notification_event_recipients,
 public.field_notification_outbox,public.field_notification_delivery,public.field_notification_daily_budget,
 public.field_notification_digest TO sales_api;
GRANT USAGE,SELECT ON SEQUENCE public.field_notification_events_id_seq TO sales_api;
