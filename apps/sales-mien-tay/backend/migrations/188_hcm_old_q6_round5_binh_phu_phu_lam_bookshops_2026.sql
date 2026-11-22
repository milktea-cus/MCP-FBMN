-- 188 | 2026-11-22 | Quận 6 cũ đợt 5: rà bù Bình Phú và Phú Lâm.
-- 2 nhà sách có tên + số nhà + nguồn mô tả bán sách, nhưng CHƯA ghé và
-- chưa xác minh còn hoạt động. KHÔNG tự bổ sung cửa hàng cùng tên ở Bình Tân.
-- Loại: Đại lý Ngân 2 đường số 1 Chợ Phú Lâm do hồ sơ VPP và cửa hàng balo/vali
-- cùng số nhà mâu thuẫn; Trọng Tiến Phát, Kim Kim Thanh là doanh nghiệp cung ứng
-- chưa chứng minh quầy bán lẻ; Cửa hàng Đại Hưng danh bạ quá cũ.
-- Chạy lại idempotent, giữ nguyên bảng customers và GPS/visit.
WITH candidates AS (
 SELECT * FROM jsonb_to_recordset('[{"name":"Nhà sách Lạc Việt – Nguyễn Văn Luông","street":"354 Nguyễn Văn Luông","ward":"Phú Lâm","cat":"nha_sach","phone":null,"oldward":"Phường 12","key":"research:hcm:q6:r5:lac-viet:354-nguyen-van-luong","source":"https://phuchy.vn/blogs/sach/nha-sach-quan-6","secondary":"https://thuvienphapluat.vn/ma-so-thue/chi-nhanh-cong-ty-tnhh-kinh-doanh-dich-vu-tri-minh-nha-sach-lac-viet-mst-0313271671-001.html","note":"Bài giới thiệu nhà sách Quận 6 nêu điểm bán ở 354 Nguyễn Văn Luông, phường 12 cũ; đăng ký chi nhánh tên NHÀ SÁCH LẠC VIỆT cùng số nhà, dữ liệu thuế quy đổi Phú Lâm. Chưa có hồ sơ Google Maps chứng minh còn mở ở 354; có một cơ sở mang tên Lạc Việt tại 198-200 Vành Đai Trong (Quận Bình Tân cũ), không coi là cùng cửa hàng hay tạo thêm lead Quận 6. Cần Sales gọi/xác minh trực tiếp bảng hiệu tại 354."},{"name":"Lạc Thi Thư Quán","street":"387A Hậu Giang","ward":"Bình Phú","cat":"nha_sach","phone":"0988632584","oldward":"Phường 11","key":"research:hcm:q6:r5:lac-thi-thu-quan:387a-hau-giang","source":"https://www.viet-biz.com/l%E1%BA%A1c-thi-th%C6%B0-qu%C3%A1n-0988-632-584","secondary":"https://vietnam.worldplaces.me/vi/review/98213443-lac-thi-thu-quan.html","note":"VietBiz phân loại hiệu sách, niêm yết 387A Hậu Giang phường 11 cũ và số 0988 632 584; WorldPlaces ghi cùng tên/số nhà. Nguồn không cung cấp hoạt động năm 2026, chưa có Place ID hoặc ảnh mặt tiền xác nhận; cần gọi trước khi ghé."}]'::jsonb)
 AS c(name text,street text,ward text,cat text,phone text,oldward text,key text,source text,secondary text,note text)
), verified_scope AS (
 SELECT c.* FROM candidates c JOIN public.sales_hcm_old_wards w
 ON w.ward_new=c.ward AND w.legacy_district='Quận 6' AND w.province='TP Hồ Chí Minh' AND w.active
 WHERE c.ward IN ('Bình Phú','Phú Lâm')
 AND c.cat IN ('nha_sach','van_phong_pham')
 AND c.source LIKE 'https://%' AND c.secondary LIKE 'https://%'
 AND NOT EXISTS (
 SELECT 1 FROM public.field_prospects p WHERE p.research_source_key=c.key
 OR (c.phone IS NOT NULL AND p.phone IS NOT NULL AND
 regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
 OR (p.province='TP Hồ Chí Minh' AND p.district='Quận 6' AND
 (lower(btrim(p.name))=lower(btrim(c.name))
 OR lower(btrim(split_part(p.address_line,', phường',1)))=lower(btrim(c.street))
 OR lower(p.address_line) LIKE lower(c.street||',%')))
 ) AND NOT EXISTS (
 SELECT 1 FROM public.customers k WHERE
 (c.phone IS NOT NULL AND k.phone IS NOT NULL AND
 regexp_replace(k.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
 OR (k.province='TP Hồ Chí Minh' AND k.district='Quận 6' AND
 (lower(btrim(k.name))=lower(btrim(c.name)) OR
 lower(k.address_line) LIKE lower(c.street||',%')))
 )
), added AS (
 INSERT INTO public.field_prospects
 (owner_sub,name,address_line,province,district,category,phone,note,status,source_kind,
 research_source_key,research_source_url,research_batch,ward_new,address_legacy,google_maps_url,google_place_id)
 SELECT 'ef943de4-18f7-49ef-8340-eefb18855534',c.name,
 c.street||', phường '||c.ward||', TP. Hồ Chí Minh',
 'TP Hồ Chí Minh','Quận 6',c.cat,c.phone,
 'Nghiên cứu ngày 22/11/2026. '||c.note||
 ' CHƯA GHÉ / CHƯA XÁC MINH hoạt động hoặc GPS; không được xem đây là khách hàng đã xác minh. Nguồn chính: '||c.source||' ; nguồn bổ sung: '||c.secondary,
 'new','manual',c.key,c.source,'2026-11-22-hcm-old-q6-round5-188',
 c.ward,c.street||', '||c.oldward||', Quận 6 cũ, TP.HCM cũ',NULL,NULL
 FROM verified_scope c ON CONFLICT DO NOTHING
 RETURNING ward_new,name,category
)
SELECT ward_new,category,count(*)::int AS added,string_agg(name,'; ' ORDER BY name) AS names
FROM added GROUP BY ward_new,category ORDER BY ward_new,category;
