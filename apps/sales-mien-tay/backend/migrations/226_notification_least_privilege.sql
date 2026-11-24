-- 226: override broad default privileges on newly created notification tables.
-- Only the DB owner can activate business producers.
REVOKE INSERT,UPDATE,DELETE ON TABLE public.field_notification_categories FROM sales_api;
REVOKE DELETE ON TABLE
 public.field_notification_preferences,public.field_notification_settings,
 public.field_notification_test_gate,public.field_notification_events,
 public.field_notification_event_recipients,public.field_notification_outbox,
 public.field_notification_delivery,public.field_notification_daily_budget,
 public.field_notification_digest,public.field_notification_runtime_checks
 FROM sales_api;
GRANT SELECT ON TABLE public.field_notification_categories TO sales_api;
