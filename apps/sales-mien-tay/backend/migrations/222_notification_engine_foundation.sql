-- 222: N1 foundation. Additive; no backfill of business events or push.
BEGIN;
ALTER TABLE public.field_notifications
 ADD COLUMN IF NOT EXISTS category text,
 ADD COLUMN IF NOT EXISTS scope_revision bigint,
 ADD COLUMN IF NOT EXISTS group_count integer NOT NULL DEFAULT 1 CHECK (group_count > 0),
 ADD COLUMN IF NOT EXISTS updated_at timestamptz;
CREATE INDEX IF NOT EXISTS field_notifications_page_idx ON public.field_notifications(recipient_sub,id DESC);
CREATE TABLE IF NOT EXISTS public.field_notification_categories (
 category text PRIMARY KEY,
 default_mode text NOT NULL CHECK (default_mode IN ('immediate','digest','in_app','off')),
 producer_enabled boolean NOT NULL DEFAULT false,
 mandatory boolean NOT NULL DEFAULT false
);
INSERT INTO public.field_notification_categories(category,default_mode,mandatory) VALUES
 ('target','immediate',false),('actuals','digest',false),('monthly_plan','immediate',false),
 ('day_route','digest',false),('weekly_route','digest',false),('monthly_route','digest',false),
 ('trip','digest',false),('survey','digest',false),('customer','in_app',false),
 ('assignment','immediate',true),('prospect','digest',false),('school','off',false),
 ('support','immediate',false),('competitor','digest',false),('order_action','immediate',false),
 ('order_summary','digest',false),('catalog','off',false),('inventory','off',false),
 ('email','digest',false),('security','immediate',true),('sync','in_app',false),('release','in_app',false)
 ON CONFLICT(category) DO NOTHING;
CREATE TABLE IF NOT EXISTS public.field_notification_preferences (
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 category text NOT NULL REFERENCES public.field_notification_categories(category),
 mode text NOT NULL CHECK (mode IN ('immediate','digest','in_app','off')),
 PRIMARY KEY(recipient_sub,category)
);
CREATE TABLE IF NOT EXISTS public.field_notification_settings (
 recipient_sub text PRIMARY KEY REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 quiet_start integer NOT NULL DEFAULT 1260 CHECK (quiet_start BETWEEN 0 AND 1439),
 quiet_end integer NOT NULL DEFAULT 420 CHECK (quiet_end BETWEEN 0 AND 1439)
);
CREATE TABLE IF NOT EXISTS public.field_notification_test_gate (
 recipient_sub text PRIMARY KEY REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 next_at timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS public.field_notification_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 event_key text NOT NULL UNIQUE CHECK (char_length(event_key) BETWEEN 1 AND 160),
 category text NOT NULL REFERENCES public.field_notification_categories(category),
 entity_key text NOT NULL CHECK (char_length(entity_key) BETWEEN 1 AND 160),
 actor_sub text NOT NULL REFERENCES public.staff_members(user_sub),
 occurred_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.field_notification_outbox (
 event_id bigint NOT NULL REFERENCES public.field_notification_events(id),
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 scope_revision bigint NOT NULL,
 mode text NOT NULL CHECK (mode IN ('immediate','digest','in_app')),
 available_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL CHECK (expires_at > available_at),
 state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','processing','done','cancelled','dead')),
 lease_until timestamptz,
 lease_id uuid,
 PRIMARY KEY(event_id,recipient_sub),
 CHECK ((state='processing')=(lease_until IS NOT NULL AND lease_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS field_notification_outbox_due_idx ON public.field_notification_outbox(available_at) WHERE state IN ('pending','processing');
CREATE TABLE IF NOT EXISTS public.field_notification_delivery (
 notification_id bigint NOT NULL REFERENCES public.field_notifications(id) ON DELETE CASCADE,
 channel text NOT NULL CHECK (channel IN ('web','android')),
 device_key text NOT NULL CHECK (device_key ~ '^[0-9a-f]{64}$'),
 state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','processing','accepted','dead','cancelled')),
 attempts integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
 next_at timestamptz NOT NULL DEFAULT now(),
 lease_until timestamptz,
 lease_id uuid,
 error_code text CHECK (error_code ~ '^[A-Za-z0-9_]{1,80}$'),
 PRIMARY KEY(notification_id,channel,device_key),
 CHECK ((state='processing')=(lease_until IS NOT NULL AND lease_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS field_notification_delivery_due_idx ON public.field_notification_delivery(next_at) WHERE state IN ('pending','processing');
CREATE TABLE IF NOT EXISTS public.field_notification_daily_budget (
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 local_day date NOT NULL,
 kind text NOT NULL CHECK (kind IN ('normal','important')),
 used integer NOT NULL CHECK (used BETWEEN 0 AND 5),
 PRIMARY KEY(recipient_sub,local_day,kind)
);
CREATE TABLE IF NOT EXISTS public.field_notification_digest (
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 slot_key text NOT NULL CHECK (char_length(slot_key) BETWEEN 1 AND 80),
 notification_id bigint REFERENCES public.field_notifications(id),
 PRIMARY KEY(recipient_sub,slot_key)
);
-- No runtime grant to enable a producer. New business tables remain dormant until
-- mutation-specific authorization and dispatch are wired and verified.
GRANT SELECT ON public.field_notification_categories TO sales_api;
GRANT SELECT,INSERT,UPDATE ON public.field_notification_preferences,public.field_notification_settings,public.field_notification_test_gate TO sales_api;
COMMIT;
