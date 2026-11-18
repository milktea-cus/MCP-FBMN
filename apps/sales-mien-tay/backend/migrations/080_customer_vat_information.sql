-- 080_customer_vat_information.sql
-- Additive invoice metadata, independent of the employee who created the customer.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS vat_tax_code text,
  ADD COLUMN IF NOT EXISTS vat_company_name text,
  ADD COLUMN IF NOT EXISTS vat_address text,
  ADD COLUMN IF NOT EXISTS vat_email text;
COMMENT ON COLUMN public.customers.vat_tax_code IS 'Vietnamese tax identifier for VAT invoices';
COMMENT ON COLUMN public.customers.vat_company_name IS 'Legal entity name for VAT invoices';
COMMENT ON COLUMN public.customers.vat_address IS 'VAT invoice billing address';
COMMENT ON COLUMN public.customers.vat_email IS 'Email receiving VAT invoices';
