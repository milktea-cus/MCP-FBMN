-- P2: additive stable client operation identifier; existing rows unchanged.
ALTER TABLE public.sales_records ADD COLUMN IF NOT EXISTS client_ref uuid;
CREATE UNIQUE INDEX IF NOT EXISTS sales_records_owner_client_ref ON public.sales_records(owner_sub,client_ref) WHERE client_ref IS NOT NULL;
