-- 020: Authenticated user-scoped notification inbox and browser push subscriptions.
-- Additive only. No existing sales/customer data is modified.
CREATE TABLE IF NOT EXISTS public.field_notifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
  event_key text NOT NULL CHECK (char_length(event_key) BETWEEN 1 AND 160),
  title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 160),
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  UNIQUE(recipient_sub,event_key)
);
CREATE INDEX IF NOT EXISTS idx_field_notifications_unread
 ON public.field_notifications(recipient_sub,created_at DESC) WHERE read_at IS NULL;
CREATE TABLE IF NOT EXISTS public.field_push_subscriptions (
  endpoint text PRIMARY KEY CHECK(char_length(endpoint) BETWEEN 32 AND 2048),
  recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
  p256dh text NOT NULL CHECK(char_length(p256dh) BETWEEN 80 AND 100),
  auth text NOT NULL CHECK(char_length(auth) BETWEEN 16 AND 35),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_field_push_subscriptions_recipient
 ON public.field_push_subscriptions(recipient_sub,updated_at DESC);
