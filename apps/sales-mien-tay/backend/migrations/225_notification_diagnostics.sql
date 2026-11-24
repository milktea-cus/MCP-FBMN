-- 225: account-owned delivery diagnostics; single bounded OAuth health probe.
ALTER TABLE public.field_notification_test_gate
 ADD COLUMN IF NOT EXISTS last_reason text CHECK(last_reason IS NULL OR last_reason ~ '^[A-Za-z0-9_]{1,80}$'),
 ADD COLUMN IF NOT EXISTS last_accepted integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS last_failed integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS last_tested_at timestamptz;
CREATE TABLE IF NOT EXISTS public.field_notification_runtime_checks(
 check_key text PRIMARY KEY CHECK(char_length(check_key) BETWEEN 1 AND 100),
 checked_at timestamptz NOT NULL DEFAULT now(),
 status text NOT NULL CHECK(status IN ('pending','ok','failed')),
 reason text CHECK(reason IS NULL OR reason ~ '^[A-Za-z0-9_]{1,80}$'),
 attempts integer NOT NULL DEFAULT 1 CHECK(attempts BETWEEN 1 AND 3)
);
GRANT SELECT,INSERT,UPDATE ON public.field_notification_runtime_checks TO sales_api;
