-- FBMN P0-B school geography cleanup, 16/11/2026.
-- Schools were imported with short TP/TX abbreviations, while the canonical
-- 13-province / 134-district catalog uses 'Thành phố' / 'Thị xã'.
-- 43 existing school records across 15 district aliases were inaccessible
-- to most assigned Sales because staff_scopes.district uses canonical labels.
-- This non-destructive, idempotent UPDATE changes only the district label;
-- source_ref, name, original address, level, Maps URL and source are preserved.
-- Check: all 15 destination labels validated against districts_old.json.
-- PRECHECK Neon: 43 targeted, zero canonical-label collisions.
-- Do NOT modify staff_scopes; those already use the canonical catalog.
BEGIN;
WITH aliases(province_old,wrong_district,canonical_district) AS (
 VALUES
  ('An Giang', 'TP Châu Đốc', 'Thành phố Châu Đốc'),
  ('An Giang', 'TP Long Xuyên', 'Thành phố Long Xuyên'),
  ('Bạc Liêu', 'TP Bạc Liêu', 'Thành phố Bạc Liêu'),
  ('Bạc Liêu', 'TX Giá Rai', 'Thị xã Giá Rai'),
  ('Bến Tre', 'TP Bến Tre', 'Thành phố Bến Tre'),
  ('Cà Mau', 'TP Cà Mau', 'Thành phố Cà Mau'),
  ('Hậu Giang', 'TP Vị Thanh', 'Thành phố Vị Thanh'),
  ('Hậu Giang', 'TX Ngã Bảy', 'Thành phố Ngã Bảy'),
  ('Long An', 'TP Tân An', 'Thành phố Tân An'),
  ('Long An', 'TX Kiến Tường', 'Thị xã Kiến Tường'),
  ('Sóc Trăng', 'TX Vĩnh Châu', 'Thị xã Vĩnh Châu'),
  ('Vĩnh Long', 'TP Vĩnh Long', 'Thành phố Vĩnh Long'),
  ('Vĩnh Long', 'TX Bình Minh', 'Thị xã Bình Minh'),
  ('Đồng Tháp', 'TP Cao Lãnh', 'Thành phố Cao Lãnh'),
  ('Đồng Tháp', 'TP Sa Đéc', 'Thành phố Sa Đéc')
)
UPDATE public.schools s
SET district_old=a.canonical_district,
    updated_at=now()
FROM aliases a
WHERE s.province_old=a.province_old
  AND s.district_old=a.wrong_district;
COMMIT;
