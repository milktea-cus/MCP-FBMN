-- 151 | 2026-11-21 | Round 2 P0 old-district gaps, Trần Đề (Sóc Trăng cũ).
-- Only one sourced candidate; NO fabricated or inferred points in Vĩnh Lợi, Long Mỹ (huyện), Kiên Hải.
-- Maps business: ChIJ0YmJgMa1oTERPo9-ZHru8ws. The public listing is categorized as PRINT SHOP;
-- stationery is in its public business name only: Sales MUST verify actual stationery sales.
-- Lịch Hội Thượng belonged to huyện Trần Đề, Sóc Trăng cũ; current Maps uses Cần Thơ after 2025.
-- Research-only lead, NOT visited/verified/customer, and NO GPS or selling flag assigned.
WITH src AS (
  SELECT x.*, md5('fbmn:old13:round02:151:' || x.source_key) AS dg
  FROM jsonb_to_recordset('[{"province":"Sóc Trăng","district":"Huyện Trần Đề","name":"Cơ sở In Ấn - Văn Phòng Phẩm Thầy Đông","address_line":"417 Khu 3, ấp Châu Thành, xã Lịch Hội Thượng cũ, huyện Trần Đề, Sóc Trăng (địa chỉ Maps mới: Cần Thơ)","category":"van_phong_pham","phone":"0914578063","tax_code":null,"source_key":"gmap:ChIJ0YmJgMa1oTERPo9-ZHru8ws","source_url":"https://www.google.com/maps/search/?api=1&query=C%C6%A1%20s%E1%BB%9F%20In%20%E1%BA%A4n%20V%C4%83n%20Ph%C3%B2ng%20Ph%E1%BA%A9m%20Th%E1%BA%A7y%20%C4%90%C3%B4ng&query_place_id=ChIJ0YmJgMa1oTERPo9-ZHru8ws","verification_note":"Google Maps có cơ sở tên in ấn - văn phòng phẩm, địa chỉ 417 Khu 3 ấp Châu Thành, Lịch Hội Thượng và số điện thoại công khai; phân loại bản đồ là print shop. Chưa chứng minh thực tế còn bán VPP hoặc mở cửa năm 2026; Sales gọi trước và xác minh trực tiếp. Lịch Hội Thượng thuộc huyện Trần Đề cũ (không dùng địa giới Cần Thơ mới)."}]'::jsonb)
  AS x(province text,district text,name text,address_line text,category text,phone text,
       tax_code text,source_key text,source_url text,verification_note text)
), ins AS (
  INSERT INTO public.field_prospects (
    id, area_visit_id, owner_sub, name, address_line, province, district,
    category, phone, tax_code, note, status, source_kind,
    research_source_key, research_source_url, research_batch
  )
  SELECT
    (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
    NULL, 'ef943de4-18f7-49ef-8340-eefb18855534',
    s.name, s.address_line, s.province, s.district, s.category, s.phone, s.tax_code,
    'Vòng 2 P0 nghiên cứu nguồn công khai 21/11/2026; CHƯA GHÉ; GPS chưa xác minh; chưa xác minh còn bán lẻ VPP. '
      || s.verification_note || ' Nguồn bản đồ: ' || s.source_url,
    'new', 'manual', s.source_key, s.source_url,
    '2026-11-21-old13-round02-p0-tran-de-151'
  FROM src s
  WHERE (s.province,s.district) IN (('Sóc Trăng','Huyện Trần Đề'))
    AND s.source_url LIKE 'https://%'
    AND NOT EXISTS (
      SELECT 1 FROM public.customers c
      WHERE c.province=s.province AND c.district=s.district
        AND (lower(trim(c.name))=lower(trim(s.name))
          OR (s.phone IS NOT NULL AND c.phone IS NOT NULL
            AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.field_prospects p
      WHERE p.research_source_key=s.source_key
        OR (p.province=s.province AND p.district=s.district AND (
          (lower(trim(p.name))=lower(trim(s.name)) AND lower(trim(p.address_line))=lower(trim(s.address_line)))
          OR (s.phone IS NOT NULL AND p.phone IS NOT NULL
            AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
          OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code)
        ))
    )
  ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
  RETURNING province,district,name,category
)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
