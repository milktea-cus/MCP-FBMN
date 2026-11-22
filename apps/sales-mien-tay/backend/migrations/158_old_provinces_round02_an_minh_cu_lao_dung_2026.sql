-- 158 | 2026-11-22 | Online research only; old district keys (An Minh/Kien Giang, Cu Lao Dung/Soc Trang).
-- Two distinct Maps place IDs, checked against field_prospects and customers 2026-11-22.
-- DO NOT infer storefront currently operates, add GPS, mark visits, sales or create customer records.
-- Hue Minh: bookshop name, Google Maps category Grocery store => Sales must verify actual book/stationery sales.
WITH src AS (
 SELECT x.*,md5('fbmn:old13:round02:158:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"province":"Kiên Giang","district":"Huyện An Minh","name":"Tiệm Sách Huệ Minh","address_line":"Plus code JW6V+8V9, khu vực thị trấn Thứ Mười Một cũ, huyện An Minh, Kiên Giang (Maps mới ghi An Giang)","category":"nha_sach","phone":"0398694325","tax_code":null,"source_key":"gmap:ChIJdUYyjWMrpzERzKzmP-i3JYg","source_url":"https://www.google.com/maps/search/?api=1&query=Ti%E1%BB%87m%20S%C3%A1ch%20Hu%E1%BB%87%20Minh%20An%20Minh&query_place_id=ChIJdUYyjWMrpzERzKzmP-i3JYg","verification_note":"Tên Google Maps ghi Tiệm Sách, nhưng danh mục hiện là Grocery store (tạp hóa); chưa thể xác nhận có quầy sách/VPP bán lẻ và hoạt động 2026. Đây là ứng viên cần Sales gọi xác minh trước, không phải cửa hàng đã xác nhận."},{"province":"Sóc Trăng","district":"Huyện Cù Lao Dung","name":"Cửa hàng văn phòng phẩm Cô Trâm","address_line":"Plus code M572+P42, đường Đoàn Thế Trung, khu vực An Thạnh, huyện Cù Lao Dung cũ, Sóc Trăng (Maps mới ghi An Thạnh)","category":"van_phong_pham","phone":"0939835194","tax_code":null,"source_key":"gmap:ChIJSUM0MQBJoDERTIfR6fnxeqw","source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20v%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20C%C3%B4%20Tr%C3%A2m%20C%C3%B9%20Lao%20Dung&query_place_id=ChIJSUM0MQBJoDERTIfR6fnxeqw","verification_note":"Google Maps xếp Stationery store, có đánh giá đề cập khách ghé mua dụng cụ học tập, tên quầy VPP; có bán nước/đồ ăn đi kèm. Chưa có ảnh/GPS Sales xác minh hoặc xác nhận hoạt động trong năm 2026."}]'::jsonb) x(
   province text,district text,name text,address_line text,category text,phone text,tax_code text,
   source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects (
  id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,
  status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
  NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,s.province,s.district,s.category,s.phone,s.tax_code,
  'Vòng 2 online 22/11/2026; CHƯA GHÉ; không có GPS; không xác minh tồn tại/hoạt động 2026. '||s.verification_note||' Nguồn: '||s.source_url,
  'new','manual',s.source_key,s.source_url,'2026-11-22-old13-round02-p1-158'
 FROM src s
 WHERE (s.province,s.district) IN (('Kiên Giang','Huyện An Minh'),('Sóc Trăng','Huyện Cù Lao Dung'))
  AND s.source_url LIKE 'https://%'
  AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE
    (c.province=s.province AND c.district=s.district AND lower(trim(c.name))=lower(trim(s.name)))
    OR (s.phone IS NOT NULL AND c.phone IS NOT NULL AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
  AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE
    p.research_source_key=s.source_key
    OR (p.province=s.province AND p.district=s.district AND lower(trim(p.name))=lower(trim(s.name)))
    OR (s.phone IS NOT NULL AND p.phone IS NOT NULL AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
    OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING province,district,name,category
)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
