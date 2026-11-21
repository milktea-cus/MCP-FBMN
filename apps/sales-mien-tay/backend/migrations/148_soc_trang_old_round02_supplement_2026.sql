-- 148 | 2026-11-21 | Sóc Trăng OLD round 2 supplementary sourced prospect.
-- Append-only, no fake GPS/check-ins. Phone and exact-name duplicate guards against customers and prospects.
WITH src AS(SELECT x.*,md5('fbmn:soc_trang-old:round02:'||x.source_key) dg
 FROM jsonb_to_recordset('[{"district":"Huyện Mỹ Tú","name":"Tạp hóa Bảy Tỷ (có đồ dùng học tập)","address_line":"140 Hùng Vương, ấp Nội Ô, thị trấn Huỳnh Hữu Nghĩa cũ, huyện Mỹ Tú, Sóc Trăng","category":"van_phong_pham","phone":"02993871807","tax_code":null,"source_key":"gmap:ChIJt2XHcGxWoDERm88ZJW4Vkb4","source_url":"https://www.viet-biz.com/en/c%E1%BB%ADa-h%C3%A0ng-t%E1%BA%A1p-h%C3%B3a-b%E1%BA%A3y-t%E1%BB%B7-0299-3871-807","verification_note":"Cửa hàng bách hóa tổng hợp với mặt hàng tập vở/bút/dụng cụ học sinh theo danh mục, KHÔNG mặc định là nhà sách chuyên doanh. Địa chỉ/số điện thoại từ danh bạ, chờ Sales kiểm chứng."}]'::jsonb) AS x(district text,name text,address_line text,category text,phone text,tax_code text,source_key text,source_url text,verification_note text)),
 ins AS(INSERT INTO public.field_prospects(id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,'Sóc Trăng',s.district,s.category,s.phone,s.tax_code,
 'Vòng rà bù nguồn công khai 21/11/2026; CHƯA GHÉ; GPS chưa xác minh; chưa xác minh hoạt động bán lẻ. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-soc-trang-old-round02-my-tu-02'
 FROM src s WHERE s.district IN ('Huyện Mỹ Tú') AND s.source_url LIKE 'https://%'
 AND NOT EXISTS(SELECT 1 FROM customers c WHERE c.province='Sóc Trăng' AND c.district=s.district AND
 (lower(trim(c.name))=lower(trim(s.name)) OR (c.phone IS NOT NULL AND s.phone IS NOT NULL AND c.phone=s.phone)))
 AND NOT EXISTS(SELECT 1 FROM field_prospects p WHERE p.province='Sóc Trăng' AND p.district=s.district AND
 (p.research_source_key=s.source_key OR (lower(trim(p.name))=lower(trim(s.name)) AND lower(trim(p.address_line))=lower(trim(s.address_line)))
 OR (p.phone IS NOT NULL AND s.phone IS NOT NULL AND p.phone=s.phone) OR (p.tax_code IS NOT NULL AND s.tax_code IS NOT NULL AND p.tax_code=s.tax_code)))
 ON CONFLICT(research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING RETURNING district,category,phone)
 SELECT district,count(*)::int inserted,count(*) FILTER(WHERE category='nha_sach')::int bookstores FROM ins GROUP BY district ORDER BY district;