-- 011: optional thumbnail metadata preserves existing uploads.
BEGIN;
ALTER TABLE public.field_survey_photos ADD COLUMN IF NOT EXISTS thumbnail_key text;
ALTER TABLE public.field_survey_photos ADD COLUMN IF NOT EXISTS thumbnail_bytes integer CHECK(thumbnail_bytes BETWEEN 1 AND 153600);
ALTER TABLE public.field_survey_photos ADD COLUMN IF NOT EXISTS thumbnail_sha256 text CHECK(thumbnail_sha256 ~ '^[0-9a-f]{64}$');
COMMIT;
