-- 157 | 2026-11-21 | Round 2 P1: Thoi Lai old district, one distinct public Maps research lead.
-- Store is not verified physically or as currently operating. No GPS, visits, customers, selling flags.
-- Prior checks confirmed previous Thoi Lai prospects Thu Hai and Huynh Chau already exist; do not duplicate.
-- Historical district key: Can Tho / Huyen Thoi Lai (before the 2025 administrative changes).
WITH src AS (
 SELECT x.*, md5('fbmn:old13:round02:157:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"province":"Cần Thơ","district":"Huyện Thới Lai","name":"VPP Cô Thảo","address_line":"Plus code 3H54+QVF, đường ĐT922, huyện Thới Lai cũ, Cần Thơ","category":"van_phong_pham","phone":"0917432459","tax_code":null,"source_key":"gmap:ChIJrVQLKQCRoDERsXJin0GU688","source_url":"https://www.google.com/maps/search/?api=1&query=VPP%20Co%20Thao%20Thoi%20Lai&query_place_id=ChIJrVQLKQCRoDERsXJin0GU688","verification_note":"Google Maps xếp loại Store, tên cửa hàng ghi VPP tại ĐT922, Thới Lai (plus code 3H54+QVF); chưa xác minh hiện có quầy bán VPP hay còn hoạt động năm 2026. Số điện thoại từ danh sách Maps; chỉ nghiên cứu online."}]'::jsonb)
 x(province text,district text,name text,address_line text,category text,phone text,tax_code text,source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects
  (id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,
   status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
  NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,s.province,s.district,s.category,s.phone,s.tax_code,
  'Vòng 2 P1 online 21/11/2026; CHƯA GHÉ; chưa xác minh GPS, hoạt động và hàng hóa thực bán. '||s.verification_note||' Nguồn: '||s.source_url,
  'new','manual',s.source_key,s.source_url,'2026-11-21-old13-round02-p1-thoilai-157'
 FROM src s
 WHERE s.province='Cần Thơ' AND s.district='Huyện Thới Lai' AND s.source_url LIKE 'https://%'
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
