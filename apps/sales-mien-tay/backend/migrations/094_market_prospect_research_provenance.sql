-- 094: Publicly researched potential outlets in former Ben Tre City.
-- Additive metadata for reproducible, idempotent ingestion. Never fake visits/GPS.
BEGIN;
ALTER TABLE public.field_prospects
 ADD COLUMN IF NOT EXISTS research_source_key text,
 ADD COLUMN IF NOT EXISTS research_source_url text,
 ADD COLUMN IF NOT EXISTS research_batch text;
ALTER TABLE public.field_prospects DROP CONSTRAINT IF EXISTS field_market_prospects_source_check;
ALTER TABLE public.field_prospects ADD CONSTRAINT field_market_prospects_source_check
 CHECK (source_kind IN ('route','manual','school','research'));
ALTER TABLE public.field_prospects ADD CONSTRAINT field_market_prospects_research_url_check
 CHECK (research_source_url IS NULL OR research_source_url LIKE 'https://%');
CREATE UNIQUE INDEX IF NOT EXISTS field_market_prospects_research_key
 ON public.field_prospects (research_source_key)
 WHERE research_source_key IS NOT NULL;
COMMIT;
