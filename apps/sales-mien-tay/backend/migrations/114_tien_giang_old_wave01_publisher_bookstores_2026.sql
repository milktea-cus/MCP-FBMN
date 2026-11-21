-- 114 | 2026-11-21 | Tien Giang old wave 1: 2 extra publisher-listed Hung Vuong branches.
-- Source: NXB Giáo dục Việt Nam, Hệ thống cửa hàng 2025-2026, page 14.
-- Distinct physical addresses from the existing 04 Lê Văn Duyệt main store; no GPS/visit inference.
WITH src AS (
 SELECT x.*,md5('fbmn:tiengiang-old:wave01-publisher:'||x.source_key) dg
 FROM jsonb_to_recordset('[{"district":"Thành phố Mỹ Tho","name":"Nhà sách Hùng Vương - 171 Lý Thường Kiệt","address_line":"171 Lý Thường Kiệt, phường 5 cũ, TP Mỹ Tho","category":"nha_sach","phone":"02733898989","tax_code":null,"source_key":"nxbgd:2025-2026:tiengiang:hungvuong:171-lythuongkiet","source_url":"https://nxbgd.vn/Attachments/files/PDF/He%20thong%20cua%20hang%20toan%20quoc%202025-2026.pdf","verification_note":"Nguồn NXB Giáo dục Việt Nam 2025–2026, trang 14, ghi số điện thoại chung 0273 3898989 - máy lẻ 05. Địa chỉ riêng với 4 Lê Văn Duyệt; chưa ghé thực địa."},{"district":"Huyện Châu Thành","name":"Nhà sách Hùng Vương - Thân Cửu Nghĩa","address_line":"909/5 ấp Cửu Hòa, xã Thân Cửu Nghĩa cũ, huyện Châu Thành, Tiền Giang","category":"nha_sach","phone":"0378201919","tax_code":null,"source_key":"nxbgd:2025-2026:tiengiang:hungvuong:909-5-cuuhoa","source_url":"https://nxbgd.vn/Attachments/files/PDF/He%20thong%20cua%20hang%20toan%20quoc%202025-2026.pdf","verification_note":"Nguồn NXB Giáo dục Việt Nam 2025–2026, trang 14. Khác chi nhánh Hùng Vương Mỹ Tho. Chưa ghé thực địa."}]'::jsonb) AS x(
 district text,name text,address_line text,category text,phone text,tax_code text,
 source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects(
 id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,
 status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT
 (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,
 'Tiền Giang',s.district,s.category,s.phone,s.tax_code,
 'Nguồn NXB Giáo dục 2025–2026 trang 14; chưa ghé, GPS chưa xác minh. '||
 s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,
 '2026-11-21-tien-giang-old-wave-01-publisher-supplement'
 FROM src s WHERE s.district IN ('Thành phố Mỹ Tho','Huyện Châu Thành')
 AND s.source_url LIKE 'https://%'
 AND NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.province='Tiền Giang' AND c.district=s.district
 AND lower(btrim(c.name))=lower(btrim(s.name)))
 AND NOT EXISTS(SELECT 1 FROM public.field_prospects p WHERE p.province='Tiền Giang' AND p.district=s.district
 AND (p.research_source_key=s.source_key OR (lower(btrim(p.name))=lower(btrim(s.name))
 AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))))
 ON CONFLICT(research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING district,name,phone
)
SELECT district,count(*)::int inserted,count(*) FILTER(WHERE phone IS NOT NULL)::int phones FROM ins GROUP BY district ORDER BY district;