-- 094: Publicly researched potential outlets in former Ben Tre City.
-- Additive metadata for reproducible, idempotent ingestion. Never fake visits/GPS.
BEGIN;
ALTER TABLE public.field_prospects
 ADD COLUMN IF NOT EXISTS research_source_key text,
 ADD COLUMN IF NOT EXISTS research_source_url text,
 ADD COLUMN IF NOT EXISTS research_batch text;
-- Source kind remains 'manual' for compatibility with existing mobile v12.
-- The dedicated research_source_key/url fields distinguish discovered listings.
ALTER TABLE public.field_prospects ADD CONSTRAINT field_market_prospects_research_url_check
 CHECK (research_source_url IS NULL OR research_source_url LIKE 'https://%');
CREATE UNIQUE INDEX IF NOT EXISTS field_market_prospects_research_key
 ON public.field_prospects (research_source_key)
 WHERE research_source_key IS NOT NULL;
COMMIT;
