-- 167 | 2026-11-22 | Lock HCMC old-ward registry and ward-aware prospect writer.
-- Prevent sales_api from modifying legal geography whitelist directly.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
 ON public.sales_hcm_old_wards FROM sales_api;
REVOKE ALL ON FUNCTION public.sales_market_prospect_create_with_ward(
 text,uuid,text,text,text,text,text,text,text,text,text,uuid
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sales_market_prospect_create_with_ward(
 text,uuid,text,text,text,text,text,text,text,text,text,uuid
) TO sales_api;
