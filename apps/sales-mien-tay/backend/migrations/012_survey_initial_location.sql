-- 012: distinguish initial location capture from an independently matched check-in.
ALTER TABLE public.field_survey_sessions ADD COLUMN IF NOT EXISTS location_initialized boolean NOT NULL DEFAULT false;
