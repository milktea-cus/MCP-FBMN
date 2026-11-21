-- 103 | 2026-11-21 | Research supplement for Trà Vinh old, wave 1.
-- Legal business entries need on-site verification; never imply confirmed operations.
-- Idempotent by source key; never alter customers, GPS, visit status or selling.
WITH src AS (
 SELECT x.*,md5('fbmn:tv-d1-supplement:'||x.source_key) AS digest
 FROM jsonb_to_recordset('[{"district":"Huyện Cầu Kè","name":"Văn phòng phẩm Ông Bảy","address_line":"Quốc lộ 54, khu vực Cầu Kè cũ (Plus Code W34G+QXG)","category":"van_phong_pham","phone":"0907046267","tax_code":null,"source_key":"gmap:ChIJqRN6CABroDERQwRFqtlj1rs","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20%C3%94ng%20B%E1%BA%A3y%20C%E1%BA%A7u%20K%C3%A8&query_place_id=ChIJqRN6CABroDERQwRFqtlj1rs","verification_note":"Google Maps có điểm QL54, chưa có số nhà; cần xác minh vị trí thật trước ghé."},{"district":"Thành phố Trà Vinh","name":"Văn phòng phẩm Mỹ Duyên","address_line":"31 Tô Thị Huỳnh, khóm 2, TP Trà Vinh cũ","category":"van_phong_pham","phone":"0906837093","tax_code":null,"source_key":"gmap:ChIJYbc1Uo8RoDERc5BGvIPZNWY","source_url":"https://www.google.com/maps/search/?api=1&query=VPP%20M%E1%BB%B9%20Duy%C3%AAn%20Tr%C3%A0%20Vinh&query_place_id=ChIJYbc1Uo8RoDERc5BGvIPZNWY","verification_note":"Địa bàn cũ được gán theo tuyến Tô Thị Huỳnh, cần xác minh phường khi ghé."},{"district":"Thành phố Trà Vinh","name":"Văn phòng phẩm An Khang","address_line":"14 Điện Biên Phủ, khóm 2, phường 6 cũ, TP Trà Vinh","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"web:vpp-an-khang-14-dbp","source_url":"https://vn-vi426969-cu-a-ha-ng-va-n-pho-ng-pha-m-an-khang.contact.page/","verification_note":"Nguồn danh bạ cũ; số điện thoại bị che, tình trạng hoạt động cần xác minh."},{"district":"Thành phố Trà Vinh","name":"Văn phòng phẩm Thanh Trúc","address_line":"412/27/10 Võ Văn Kiệt, khóm 8, phường 7 cũ, TP Trà Vinh","category":"van_phong_pham","phone":null,"tax_code":"2100625785","source_key":"web:vpp-thanh-truc-2100625785","source_url":"https://dauthau.asia/businesslistings/detail/VAN-PHONG-PHAM-THANH-TRUC-193814/","verification_note":"Nguồn hồ sơ ngành nghề bán lẻ sách/VPP; công bố ngừng giao dịch thầu do phí quá hạn không đồng nghĩa ngừng cửa hàng. Chưa xác minh có quầy bán lẻ."},{"district":"Thành phố Trà Vinh","name":"Doanh nghiệp TN Ngân Khang","address_line":"Khóm 4, phường 1 cũ, TP Trà Vinh (chưa có số nhà)","category":"van_phong_pham","phone":"0945042797","tax_code":"2100537458","source_key":"web:dntn-ngan-khang-2100537458","source_url":"https://thongtindoanhnghiep.co/2100537458-doanh-nghiep-tn-ngan-khang","verification_note":"Đăng ký bán lẻ sách, báo, văn phòng phẩm; cần xác minh có cửa hàng thực tế và địa chỉ chính xác."}]'::jsonb) AS x(
 district text,name text,address_line text,category text,phone text,
 tax_code text,source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects
 (id,area_visit_id,owner_sub,name,address_line,province,district,category,
  phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT
 (substr(s.digest,1,8)||'-'||substr(s.digest,9,4)||'-5'||substr(s.digest,14,3)||'-8'||substr(s.digest,18,3)||'-'||substr(s.digest,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
 s.name,s.address_line,'Trà Vinh',s.district,s.category,s.phone,s.tax_code,
 'Nguồn nghiên cứu công khai 2026-11-21. Chưa ghé, GPS chưa xác minh. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-tra-vinh-old-wave-01-supplement'
 FROM src s
 WHERE s.district IN ('Thành phố Trà Vinh','Huyện Càng Long','Huyện Cầu Kè')
  AND s.source_url LIKE 'https://%'
  AND NOT EXISTS(SELECT 1 FROM public.customers c
    WHERE c.province='Trà Vinh' AND c.district=s.district AND lower(btrim(c.name))=lower(btrim(s.name)))
  AND NOT EXISTS(SELECT 1 FROM public.field_prospects p
    WHERE p.province='Trà Vinh' AND p.district=s.district
    AND (p.research_source_key=s.source_key OR
    (lower(btrim(p.name))=lower(btrim(s.name)) AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING district,name,phone,tax_code
)
SELECT district,count(*)::int inserted,
 COUNT(*) FILTER (WHERE phone IS NOT NULL)::int phones,
 COUNT(*) FILTER (WHERE tax_code IS NOT NULL)::int tax_codes
 FROM ins GROUP BY district ORDER BY district;