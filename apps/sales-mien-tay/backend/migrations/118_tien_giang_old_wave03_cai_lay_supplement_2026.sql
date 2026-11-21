-- 118 | 2026-11-21 | Tien Giang old wave-3 supplemental researched VPP at TX Cai Lay.
-- Directory evidence for existence/name/address, not field verified or confirmed retail.
WITH src AS (
 SELECT x.*,md5('fbmn:tiengiang-old:wave03-extra:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"district":"Thị xã Cai Lậy","name":"Cơ sở in và cung cấp VPP Tấn Đạt","address_line":"Tổ 28, đường Mai Thị Út, khu phố 1, phường 1 cũ, TX Cai Lậy","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"directory:tratencongty:tandat-maithiut-kp1-cailay","source_url":"https://www.tratencongty.com/tinh-tien-giang/?page=238","verification_note":"Danh bạ doanh nghiệp ghi rõ tên cơ sở cung cấp VPP và địa chỉ tổ 28 Mai Thị Út; tình trạng bán lẻ tại quầy chưa kiểm chứng, MST/điện thoại không được công khai. Không đánh dấu là cửa hàng đã ghé."}]'::jsonb) AS x(
 district text,name text,address_line text,category text,phone text,tax_code text,
 source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects(
 id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,
 note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT
 (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,'Tiền Giang',s.district,
 s.category,s.phone,s.tax_code,'Nguồn danh bạ 21/11/2026; chưa ghé, GPS chưa xác minh. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-tien-giang-old-wave-03-supplement'
 FROM src s
 WHERE s.district='Thị xã Cai Lậy' AND s.source_url LIKE 'https://%'
 AND NOT EXISTS(SELECT 1 FROM public.customers c WHERE c.province='Tiền Giang' AND c.district=s.district
  AND lower(btrim(c.name))=lower(btrim(s.name)))
 AND NOT EXISTS(SELECT 1 FROM public.field_prospects p WHERE p.province='Tiền Giang' AND p.district=s.district
 AND (p.research_source_key=s.source_key OR (lower(btrim(p.name))=lower(btrim(s.name)) AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))))
 ON CONFLICT(research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING district,name
)
SELECT district,count(*)::int inserted FROM ins GROUP BY district;