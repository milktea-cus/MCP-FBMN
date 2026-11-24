-- 221: additive native Android FCM enrollment. Browser Web Push stays unchanged.
CREATE TABLE IF NOT EXISTS public.field_android_push_devices (
 token text PRIMARY KEY CHECK (char_length(token) BETWEEN 32 AND 2048),
 binding_id uuid NOT NULL,
 recipient_sub text NOT NULL REFERENCES public.staff_members(user_sub) ON DELETE CASCADE,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS field_android_push_recipient_idx ON public.field_android_push_devices(recipient_sub,updated_at DESC);
CREATE INDEX IF NOT EXISTS field_android_push_binding_idx ON public.field_android_push_devices(recipient_sub,binding_id);
