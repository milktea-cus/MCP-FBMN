-- 171 | 2026-11-22 | Tân Định: careful storefront follow-up on small book/paper shops.
-- Only old HCM city boundary, new ward Tân Định, legacy Quận 1 ACL.
-- Research only: no verified site visit, fake GPS, customers, or conversion.
-- So much closer sells notebooks/cards alongside gifts (specialty paper goods, not general VPP).
-- Tiệm sách nhỏ 159/14 Điện Biên Phủ is NOT the separately listed 159 Điện Biên Phủ in Bình Thạnh.
-- Google place IDs observed from public Maps results; null remains null when absent.
-- Re-run must return 0 rows; compare both prospects and customers before inserting.
WITH src AS (SELECT * FROM jsonb_to_recordset('[{"ward":"Tân Định","name":"Sách chuyên ngành Doc Store","street":"2 Trần Quý Khoách","old":"phường Tân Định cũ","category":"nha_sach","phone":"0907511929","place":"ChIJpYqMWsQvdTER9SiZPKbxmYk","key":"gmaps:ChIJpYqMWsQvdTER9SiZPKbxmYk","source":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJpYqMWsQvdTER9SiZPKbxmYk","maps":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJpYqMWsQvdTER9SiZPKbxmYk","evidence":"Google Maps liệt kê cửa hàng sách chuyên ngành ở số 2 Trần Quý Khoách với ít đánh giá và số điện thoại. Cần Sales xác minh bảng hiệu, loại sách và hoạt động tại quầy.","address_new":"2 Trần Quý Khoách, phường Tân Định, TP. Hồ Chí Minh","address_old":"2 Trần Quý Khoách, phường Tân Định cũ, Quận 1, TP.HCM cũ"},{"ward":"Tân Định","name":"Tiệm sách nhỏ","street":"159/14 Điện Biên Phủ","old":"phường Đa Kao cũ","category":"nha_sach","phone":null,"place":"ChIJ-XgPVQAvdTERHitC9J3i25k","key":"gmaps:ChIJ-XgPVQAvdTERHitC9J3i25k","source":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJ-XgPVQAvdTERHitC9J3i25k","maps":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJ-XgPVQAvdTERHitC9J3i25k","evidence":"Google Maps có hồ sơ tiệm bán sách cũ tại 159/14 Điện Biên Phủ, ít đánh giá; địa chỉ này theo phường Đa Kao cũ và dữ liệu công khai tháng 9/2025 xác định phường Tân Định mới. Không nhầm với số 159 Điện Biên Phủ của quận Bình Thạnh cũ.","address_new":"159/14 Điện Biên Phủ, phường Tân Định, TP. Hồ Chí Minh","address_old":"159/14 Điện Biên Phủ, phường Đa Kao cũ, Quận 1, TP.HCM cũ"},{"ward":"Tân Định","name":"so much closer Tân Định - sổ giấy, thiệp","street":"90E Thạch Thị Thanh","old":"phường Tân Định cũ","category":"van_phong_pham","phone":null,"place":null,"key":"somuchcloser:tan-dinh:90e-thach-thi-thanh","source":"https://somuchcloser.vn/cua-hang","maps":null,"evidence":"Website thương hiệu xác nhận cửa hàng bán lẻ tại số 90E Thạch Thị Thanh; thông tin cửa hàng 2026 ghi bán sổ tay, thiệp giấy và stationery bên cạnh quà tặng. VPP chuyên biệt về giấy/sổ/thiệp, không phải cửa hàng VPP tổng hợp; cần Sales kiểm tra mặt hàng khi ghé.","address_new":"90E Thạch Thị Thanh, phường Tân Định, TP. Hồ Chí Minh","address_old":"90E Thạch Thị Thanh, phường Tân Định cũ, Quận 1, TP.HCM cũ"}]'::jsonb) AS s(ward text,name text,street text,old text,category text,phone text,place text,key text,source text,maps text,evidence text,address_new text,address_old text)), vetted AS (
 SELECT s.* FROM src s WHERE s.ward='Tân Định' AND s.category IN ('nha_sach','van_phong_pham')
  AND s.source LIKE 'https://%' AND s.address_new LIKE '%phường Tân Định%'
  AND (s.place IS NULL OR s.place ~ '^ChIJ[A-Za-z0-9_-]{20,}$')
  AND (s.phone IS NULL OR s.phone ~ '^[0-9]{8,11}$')
  AND EXISTS(SELECT 1 FROM public.sales_hcm_old_wards w WHERE w.ward_new=s.ward AND w.province='TP Hồ Chí Minh' AND w.active)
  AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE p.research_source_key=s.key OR (s.place IS NOT NULL AND p.google_place_id=s.place)
   OR lower(btrim(p.address_line))=lower(btrim(s.address_new))
   OR (p.province='TP Hồ Chí Minh' AND p.ward_new=s.ward AND lower(btrim(p.name))=lower(btrim(s.name)))
   OR (s.phone IS NOT NULL AND regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=s.phone))
  AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE lower(btrim(c.address_line))=lower(btrim(s.address_new))
   OR (c.province='TP Hồ Chí Minh' AND lower(btrim(c.name))=lower(btrim(s.name)))
   OR (s.phone IS NOT NULL AND regexp_replace(coalesce(c.phone,''),'[^0-9]','','g')=s.phone))
), inserted AS (
 INSERT INTO public.field_prospects (id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,address_legacy,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch,google_maps_url,google_place_id)
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_new,'TP Hồ Chí Minh','Quận 1',s.ward,s.address_old,s.category,s.phone,NULL,
  'Nguồn tra cứu 22/11/2026; CHƯA GHÉ / CHƯA XÁC MINH tại quầy; không có GPS xác minh. '||s.evidence||' Nguồn: '||s.source,
  'new','manual',s.key,s.source,'2026-11-22-hcm-tan-dinh-street-book-paper-171',s.maps,s.place
 FROM vetted s
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING ward_new,name,category,phone,google_place_id
)
SELECT ward_new,name,category,phone,google_place_id FROM inserted ORDER BY name;
