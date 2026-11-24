-- 236 N4 Resend inbox.email.received events. Metadata only; no mail content or sender.
CREATE TABLE IF NOT EXISTS public.field_mail_inbound_events (
 mailbox text NOT NULL,
 email_id uuid NOT NULL,
 thread_id uuid NOT NULL,
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 notification_id bigint REFERENCES public.field_notifications(id),
 received_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(mailbox,email_id),
 CONSTRAINT field_mail_inbound_address CHECK (mailbox ~ '^[a-z0-9._+-]+@fbmn[.]vn$')
);
CREATE INDEX IF NOT EXISTS field_mail_inbound_owner_thread_idx
 ON public.field_mail_inbound_events(recipient_sub,thread_id,received_at DESC);
GRANT SELECT ON public.field_mail_inbound_events TO sales_api;

CREATE OR REPLACE FUNCTION public.sales_mail_received(
 p_mailbox text,p_email_id uuid,p_thread_id uuid,p_received timestamptz
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO pg_catalog,public AS $n4$
DECLARE v_owner text;v_revision bigint;v_mode text;v_prev bigint;v_event bigint;v_notice bigint;
 v_quiet_start int;v_quiet_end int;v_min int;v_local timestamp;v_available timestamptz;
BEGIN
 IF p_mailbox IS NULL OR p_mailbox!~'^[a-z0-9._+-]+@fbmn[.]vn$'
  OR p_email_id IS NULL OR p_thread_id IS NULL OR p_received IS NULL
  OR p_received>now()+interval '5 minutes' OR p_received<now()-interval '24 hours'
 THEN RETURN NULL;END IF;
 SELECT s.user_sub,s.scope_revision INTO v_owner,v_revision
  FROM public.staff_mailboxes mb JOIN public.staff_members s ON s.user_sub=mb.user_sub
  WHERE mb.mailbox=p_mailbox AND s.active AND public.sales_identity_exists(s.user_sub);
 IF v_owner IS NULL THEN RETURN NULL;END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('mail:'||v_owner||':'||p_thread_id::text,47));
 SELECT notification_id INTO v_prev FROM public.field_mail_inbound_events
  WHERE mailbox=p_mailbox AND email_id=p_email_id;
 IF FOUND THEN RETURN v_prev;END IF;
 INSERT INTO public.field_mail_inbound_events(mailbox,email_id,thread_id,recipient_sub,received_at)
 VALUES(p_mailbox,p_email_id,p_thread_id,v_owner,p_received);
 IF NOT EXISTS(SELECT 1 FROM public.field_notification_categories c
  WHERE c.category='email' AND c.producer_enabled) THEN RETURN NULL;END IF;
 SELECT coalesce(p.mode,c.default_mode) INTO v_mode
  FROM public.field_notification_categories c
  LEFT JOIN public.field_notification_preferences p
   ON p.recipient_sub=v_owner AND p.category=c.category
  WHERE c.category='email';
 IF v_mode IS NULL OR v_mode='off' THEN RETURN NULL;END IF;
 INSERT INTO public.field_notification_events(event_key,category,entity_key,actor_sub,occurred_at)
 VALUES('email:'||p_email_id::text,'email','mail:'||p_thread_id::text,v_owner,p_received)
 ON CONFLICT(event_key) DO NOTHING RETURNING id INTO v_event;
 IF v_event IS NULL THEN
  SELECT id INTO v_event FROM public.field_notification_events
    WHERE event_key='email:'||p_email_id::text AND category='email'
      AND actor_sub=v_owner AND entity_key='mail:'||p_thread_id::text;
  IF v_event IS NULL THEN RETURN NULL;END IF;
 END IF;
 SELECT id INTO v_notice FROM public.field_notifications
  WHERE recipient_sub=v_owner AND category='email' AND entity_key='mail:'||p_thread_id::text
   AND scope_revision=v_revision AND created_at>now()-interval '15 minutes'
  ORDER BY id DESC LIMIT 1 FOR UPDATE;
 IF v_notice IS NOT NULL THEN
  UPDATE public.field_notifications SET group_count=group_count+1,updated_at=now(),
   read_at=NULL WHERE id=v_notice;
 ELSE
  INSERT INTO public.field_notifications(recipient_sub,event_key,title,body,category,
    entity_key,scope_revision,created_at,updated_at)
  VALUES(v_owner,'email:'||p_email_id::text,'Có email mới',
   'Có thư mới trong hộp thư được giao. Mở Email để đọc nội dung.',
   'email','mail:'||p_thread_id::text,v_revision,now(),now())
  RETURNING id INTO v_notice;
 END IF;
 UPDATE public.field_mail_inbound_events SET notification_id=v_notice
   WHERE mailbox=p_mailbox AND email_id=p_email_id;
 INSERT INTO public.field_notification_event_recipients(event_id,recipient_sub,notification_id)
 VALUES(v_event,v_owner,v_notice) ON CONFLICT(event_id,recipient_sub) DO NOTHING;
 -- One push per 15-minute thread group; additional messages only update inbox.
 IF EXISTS(SELECT 1 FROM public.field_notification_outbox o WHERE o.notification_id=v_notice)
    OR v_mode='in_app' THEN RETURN v_notice;END IF;
 v_available:=now();
 IF v_mode='digest' THEN
  v_local:=now() AT TIME ZONE 'Asia/Ho_Chi_Minh';
  v_available:=(date_trunc('day',v_local)+interval '18 hours') AT TIME ZONE 'Asia/Ho_Chi_Minh';
  IF v_available<=now() THEN v_available:=v_available+interval '1 day';END IF;
 END IF;
 SELECT coalesce(q.quiet_start,1260),coalesce(q.quiet_end,420)
 INTO v_quiet_start,v_quiet_end FROM (SELECT 1) n LEFT JOIN public.field_notification_settings q
  ON q.recipient_sub=v_owner;
 v_local:=v_available AT TIME ZONE 'Asia/Ho_Chi_Minh';
 v_min:=extract(hour from v_local)::int*60+extract(minute from v_local)::int;
 IF v_quiet_start<>v_quiet_end AND (
   (v_quiet_start<v_quiet_end AND v_min>=v_quiet_start AND v_min<v_quiet_end)
   OR (v_quiet_start>v_quiet_end AND (v_min>=v_quiet_start OR v_min<v_quiet_end))) THEN
  v_available:=(date_trunc('day',v_local)+make_interval(mins=>v_quiet_end)+
    CASE WHEN v_quiet_start>v_quiet_end AND v_min>=v_quiet_start
     THEN interval '1 day' ELSE interval '0' END)
     AT TIME ZONE 'Asia/Ho_Chi_Minh';
 END IF;
 INSERT INTO public.field_notification_outbox(event_id,recipient_sub,scope_revision,mode,
    available_at,expires_at,notification_id)
 VALUES(v_event,v_owner,v_revision,v_mode,v_available,v_available+interval '36 hours',v_notice)
 ON CONFLICT DO NOTHING;
 RETURN v_notice;
END
$n4$;
REVOKE ALL ON FUNCTION public.sales_mail_received(text,uuid,uuid,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_mail_received(text,uuid,uuid,timestamptz) TO sales_api;
