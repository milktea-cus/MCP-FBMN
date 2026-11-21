-- 112 | Long An old wave 3 supplemental sources, 21 November 2026.
-- All records represent research candidates ONLY; a business registration is not proof of active retail.
-- Mixed/wholesale-only operations should be verified by Sales before field visits.
WITH src AS (
 SELECT x.*, md5('fbmn:longan-old:wave3-extra:'||x.source_key) dg FROM jsonb_to_recordset('[{"district":"Huyện Vĩnh Hưng","name":"Văn phòng phẩm Phước Quang","address_line":"Đường Cách Mạng Tháng Tám, khu phố 1, thị trấn Vĩnh Hưng cũ, huyện Vĩnh Hưng","category":"van_phong_pham","phone":null,"tax_code":"1100163553001","source_key":"tax:1100163553-001:vpp-phuoc-quang","source_url":"https://tracuunhanh.vn/1100163553-001-luu-phuoc-quang-van-phong-pham-phuoc-quang","verification_note":"Hồ sơ kinh doanh ghi tên VPP Phước Quang, không có số nhà; CHƯA xác minh quầy bán hoặc hoạt động thực tế. Khác VPP Hồng Gấm số 75 KP Bầu Sậy."},{"district":"Huyện Tân Hưng","name":"Thiết bị giáo dục Ánh Hà","address_line":"Khu phố Gò Thuyền, thị trấn Tân Hưng cũ, huyện Tân Hưng (nguồn danh bạ: 01 Lê Lai)","category":"van_phong_pham","phone":null,"tax_code":"1101811782","source_key":"tax:1101811782:anh-ha","source_url":"https://infodoanhnghiep.com/thong-tin/Cong-Ty-TNHH-Thiet-Bi-Giao-Duc-anh-Ha-11782.html","verification_note":"Nguồn đăng ký và hồ sơ thầu ngành thiết bị giáo dục; nguồn khác còn ghi 7 Phạm Ngọc Thạch/107 đường 3/2 cùng thị trấn. CHƯA rõ địa điểm giao dịch hay có quầy bán lẻ; cần đối chiếu trước khi đi."},{"district":"Huyện Vĩnh Hưng","name":"Tin học Tháp Mười (đăng ký bán lẻ sách - VPP)","address_line":"95 đường Tháp Mười, khu phố 2, thị trấn Vĩnh Hưng cũ, huyện Vĩnh Hưng","category":"van_phong_pham","phone":null,"tax_code":"1101752544","source_key":"tax:1101752544:thap-muoi","source_url":"https://thuvienphapluat.vn/Ma-SO-THuE/cong-ty-tnhh-mot-thanh-vien-thuong-mai-dich-vu-tin-hoc-thap-muoi-mst-1101752544.html","verification_note":"Doanh nghiệp có ngành đăng ký bán lẻ sách/VPP nhưng ngành chính kinh doanh thiết bị tin học; CHƯA xác minh có bán học phẩm tại quầy và đang hoạt động."}]'::jsonb) AS x (
  district text,name text,address_line text,category text,phone text,tax_code text,
  source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects (
  id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,
  note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT
 (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
 s.name,s.address_line,'Long An',s.district,s.category,s.phone,s.tax_code,
 'Nguồn tra cứu 21/11/2026; CHƯA GHÉ, GPS chưa xác minh, CHƯA chứng minh đang bán lẻ. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-long-an-old-wave-03-supplement'
 FROM src s
 WHERE s.district IN ('Huyện Vĩnh Hưng','Huyện Tân Hưng') AND s.source_url LIKE 'https://%'
  AND NOT EXISTS (
   SELECT 1 FROM public.customers c WHERE c.province='Long An' AND c.district=s.district
   AND lower(btrim(c.name))=lower(btrim(s.name)))
  AND NOT EXISTS (
   SELECT 1 FROM public.field_prospects p WHERE p.province='Long An' AND p.district=s.district
    AND (p.research_source_key=s.source_key
    OR (lower(btrim(p.name))=lower(btrim(s.name)) AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING district,name,phone,tax_code
)
SELECT district,count(*)::int inserted,count(*) FILTER (WHERE phone IS NOT NULL)::int phones,count(*) FILTER (WHERE tax_code IS NOT NULL)::int taxes
FROM ins GROUP BY district ORDER BY district;