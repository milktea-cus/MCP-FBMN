-- P0-F: preserve location provenance without rewriting historical coordinates.
-- NULL source on existing rows means legacy/unknown; those coordinates remain protected.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS location_source text CHECK (location_source IN ('gps','manual','map_link')),
  ADD COLUMN IF NOT EXISTS location_recorded_by text,
  ADD COLUMN IF NOT EXISTS location_recorded_at timestamptz;
