-- P3: versioned plan updates; retain all existing rows.
ALTER TABLE public.sales_records ADD COLUMN IF NOT EXISTS version integer NOT NULL DEFAULT 1;
ALTER TABLE public.sales_records ADD COLUMN IF NOT EXISTS last_mutation_ref uuid;
