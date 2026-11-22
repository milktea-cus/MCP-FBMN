-- 163 | 2026-11-22 | HCMC (pre-2025 territory): additive ward/address provenance for researched shops.
-- district REMAINS the legacy quận/huyện for ACL, routing and 738 existing Mekong prospects.
-- ward_new is the contemporary ward, NEVER placed into district.
-- Only the 3-ward pilot batch is researched here. All legacy rows remain NULL in these fields.
ALTER TABLE public.field_prospects
  ADD COLUMN IF NOT EXISTS ward_new text,
  ADD COLUMN IF NOT EXISTS address_legacy text,
  ADD COLUMN IF NOT EXISTS google_maps_url text,
  ADD COLUMN IF NOT EXISTS google_place_id text;

CREATE INDEX IF NOT EXISTS idx_field_prospects_new_ward
  ON public.field_prospects(province,ward_new,status,created_at DESC)
  WHERE ward_new IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_field_prospects_google_place_id
  ON public.field_prospects(google_place_id)
  WHERE google_place_id IS NOT NULL;

COMMENT ON COLUMN public.field_prospects.ward_new IS
  'Administrative ward effective at collection date, separate from legacy district ACL.';
COMMENT ON COLUMN public.field_prospects.address_legacy IS
  'Legacy street/ward/district description for source cross-check; never geocoded or GPS proof.';
COMMENT ON COLUMN public.field_prospects.google_maps_url IS
  'Observed public Google Maps listing URL; not verified field check-in.';
COMMENT ON COLUMN public.field_prospects.google_place_id IS
  'Google Maps place ID if independently verified; source deduplication, not a visit proof.';
