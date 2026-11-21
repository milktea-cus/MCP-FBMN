-- 156 | 2026-11-21 | Round 2 P1 sparse old districts: Chau Thanh Hau Giang, O Mon, Thot Not.
-- 4 Map-listed public research prospects, not verified physical visits or current storefronts.
-- Historical administrative verification for ap Phu Hoa in Dong Phu, Chau Thanh Hau Giang:
-- https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/De-an-02-DA-UBND-2024-thanh-lap-thi-tran-Dong-Phu-thuoc-huyen-Chau-Thanh-Hau-Giang-640934.aspx
-- Explicitly EXCLUDE Minh Thu bookshop of Chau Thanh: source/place ID already exists in field_prospects.
-- Do not write customer/visit/coordinates/verified operation flags.
WITH src AS (
 SELECT x.*,md5('fbmn:old13:round02:156:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"province":"Hậu Giang","district":"Huyện Châu Thành","name":"Văn phòng phẩm Song Di","address_line":"Plus code WRPH+J7F, ấp Phú Hòa, xã Đông Phú cũ, huyện Châu Thành, Hậu Giang (nay TP Cần Thơ)","category":"van_phong_pham","phone":"0982712923","tax_code":null,"source_key":"gmap:ChIJc28OuGVhoDERHW9U74kck2E","note":"Maps xếp loại Stationery store, 7 đánh giá và số điện thoại công khai; ấp Phú Hòa thuộc xã Đông Phú cũ, huyện Châu Thành Hậu Giang (tham chiếu Đề án 02/ĐA-UBND 2024), không nhầm với Châu Thành An Giang. Chưa xác minh còn cửa hàng năm 2026.","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Song%20Di%20Huy%E1%BB%87n%20Ch%C3%A2u%20Th%C3%A0nh%20H%E1%BA%ADu%20Giang&query_place_id=ChIJc28OuGVhoDERHW9U74kck2E"},{"province":"Cần Thơ","district":"Quận Ô Môn","name":"Văn phòng phẩm Trí Tuệ","address_line":"64A ấp Thới Bình A2, khu Ô Môn cũ, quận Ô Môn, Cần Thơ","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJD95MMX-FoDERbD52q9cHw6o","note":"Maps tên VPP Trí Tuệ, Book store, không có số điện thoại; giờ ghi 24/7 trên Maps không thể coi là xác minh thực tế. Cần Sales kiểm tra loại hình và địa điểm.","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Tr%C3%AD%20Tu%E1%BB%87%20Qu%E1%BA%ADn%20%C3%94%20M%C3%B4n%20C%E1%BA%A7n%20Th%C6%A1&query_place_id=ChIJD95MMX-FoDERbD52q9cHw6o"},{"province":"Cần Thơ","district":"Quận Ô Môn","name":"Cửa hàng Văn phòng phẩm Minh Lợi","address_line":"67 đường 26 Tháng 3, quận Ô Môn cũ, Cần Thơ","category":"van_phong_pham","phone":"02923862056","tax_code":null,"source_key":"gmap:ChIJHeGPxOCEoDERLGxd41-iQm8","note":"Maps tên Cửa hàng VPP Minh Lợi tại 67 đường 26 Tháng 3, số điện thoại công khai, phân loại Novelty store. Chưa xác minh còn kinh doanh năm 2026, giờ Maps 24h không được coi là thật.","source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Minh%20L%E1%BB%A3i%20Qu%E1%BA%ADn%20%C3%94%20M%C3%B4n%20C%E1%BA%A7n%20Th%C6%A1&query_place_id=ChIJHeGPxOCEoDERLGxd41-iQm8"},{"province":"Cần Thơ","district":"Quận Thốt Nốt","name":"Nhà sách Xuân Châu","address_line":"89 Quốc lộ 91, khu vực Long, quận Thốt Nốt cũ, Cần Thơ","category":"nha_sach","phone":"02923851342","tax_code":null,"source_key":"gmap:ChIJ4eHbAEV2CjERfCLg7DqTZ1s","note":"Maps Book store tại 89 QL91 Thốt Nốt, có đánh giá đề cập sách giáo khoa, bút mực, giấy và điện thoại. Cần Sales gọi xác minh cửa hàng đang hoạt động và vị trí.","source_url":"https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20s%C3%A1ch%20Xu%C3%A2n%20Ch%C3%A2u%20Qu%E1%BA%ADn%20Th%E1%BB%91t%20N%E1%BB%91t%20C%E1%BA%A7n%20Th%C6%A1&query_place_id=ChIJ4eHbAEV2CjERfCLg7DqTZ1s"}]'::jsonb)
 x(province text,district text,name text,address_line text,category text,phone text,tax_code text,
   source_key text,source_url text,note text)
), ins AS (
 INSERT INTO public.field_prospects (
  id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,
  status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
  NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,
  s.province,s.district,s.category,s.phone,s.tax_code,
  'Vòng 2 P1 nghiên cứu online 21/11/2026; CHƯA GHÉ; chưa xác minh GPS/bán hàng trực tiếp. '||s.note||' Nguồn: '||s.source_url,
  'new','manual',s.source_key,s.source_url,'2026-11-21-old13-round02-p1-sparse-156'
 FROM src s
 WHERE (s.province,s.district) IN (
  ('Hậu Giang','Huyện Châu Thành'),('Cần Thơ','Quận Ô Môn'),('Cần Thơ','Quận Thốt Nốt'))
 AND s.source_url LIKE 'https://%'
 AND NOT EXISTS (SELECT 1 FROM public.customers c
   WHERE (c.province=s.province AND c.district=s.district AND lower(trim(c.name))=lower(trim(s.name)))
     OR (s.phone IS NOT NULL AND c.phone IS NOT NULL AND
          regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p
   WHERE p.research_source_key=s.source_key
    OR (p.province=s.province AND p.district=s.district AND lower(trim(p.name))=lower(trim(s.name)))
    OR (s.phone IS NOT NULL AND p.phone IS NOT NULL AND
         regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
    OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING province,district,name,category)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
