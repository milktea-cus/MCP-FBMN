-- Customer header photo: explicit per-customer image, never a survey-session photo.
-- Additive, nullable and backwards-compatible with existing customer/photo records.
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS cover_photo_id uuid REFERENCES public.customer_photos(id) ON DELETE SET NULL;
