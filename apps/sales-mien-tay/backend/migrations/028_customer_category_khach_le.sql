-- P1-G: additive industry category, with no changes to customer records.
-- One ALTER TABLE is atomic and preserves every legacy category value.
ALTER TABLE public.customers
  DROP CONSTRAINT IF EXISTS customers_category_check,
  ADD CONSTRAINT customers_category_check
  CHECK (category IN (
    'tap_hoa', 'sieu_thi', 'dai_ly', 'npp', 'nha_sach',
    'van_phong_pham', 'cua_hang', 'truong_hoc', 'khach_le', 'khac'
  ));
