-- 066: Customer selling activity is separate from account operational status.
-- Unknown historical selling activity is intentionally false until a Sales
-- owner verifies it. Never infer sales from status='active', visits or orders.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS is_selling boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.customers.is_selling IS
  'Explicit Field Work sales confirmation; independent of active/inactive status. False means not confirmed selling.';

-- Existing RLS / public.sales_customer_allowed gates remain authoritative.
-- No historical records or offline payloads are changed by this migration.
