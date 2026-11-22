-- 175 | 2026-11-22 | Extend OLD TP.HCM 2025 ward whitelist by 3 legally grounded central wards.
-- Official source: NQ 1685/NQ-UBTVQH15, Article 1, Clauses 4, 5, 6.
-- Scope: ONLY old Quận 1/Quận 3. No Bình Dương/BR-VT, no fake visit.
-- Preserve legacy district ACL and original 3 wards; append only.
WITH district_added AS (
  INSERT INTO public.territory_catalog (code,name,level,parent_code)
  VALUES ('hcm-old-q3','Quận 3','district','hcm-old-province')
  ON CONFLICT (code) DO NOTHING
  RETURNING code
), wards_added AS (
  INSERT INTO public.sales_hcm_old_wards (province,ward_new,legacy_district,legal_source,active)
  VALUES
    ('TP Hồ Chí Minh','Cầu Ông Lãnh','Quận 1','1685/NQ-UBTVQH15',true),
    ('TP Hồ Chí Minh','Bàn Cờ','Quận 3','1685/NQ-UBTVQH15',true),
    ('TP Hồ Chí Minh','Xuân Hòa','Quận 3','1685/NQ-UBTVQH15',true)
  ON CONFLICT (province,ward_new) DO NOTHING
  RETURNING ward_new,legacy_district
)
SELECT ward_new,legacy_district FROM wards_added ORDER BY ward_new;