-- 019: Expand customer classifications for the stationery/book industry.
-- Retains every legacy category and all existing customer rows.
-- Safe, additive constraint replacement: no customer data is rewritten.
ALTER TABLE public.customers
  DROP CONSTRAINT IF EXISTS customers_category_check;

ALTER TABLE public.customers
  ADD CONSTRAINT customers_category_check
  CHECK (category IN (
    'tap_hoa', 'sieu_thi', 'dai_ly', 'npp', 'nha_sach',
    'van_phong_pham', 'cua_hang', 'truong_hoc', 'khac'
  ));
