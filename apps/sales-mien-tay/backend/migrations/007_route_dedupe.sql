-- P3: one planned stop per employee/customer/date; legacy free-text visits unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS sales_route_stop_unique ON public.sales_records(owner_sub,(data->>'customerId'),(data->>'plannedDate')) WHERE kind='visit' AND data ? 'customerId' AND data ? 'plannedDate';
