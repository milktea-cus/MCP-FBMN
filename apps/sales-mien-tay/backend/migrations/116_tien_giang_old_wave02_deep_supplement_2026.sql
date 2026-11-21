-- 116 | 2026-11-21 | Tiền Giang cũ wave-2 rural supplement: Tân Thới (Tân Phú Đông) and Tân Đông (Gò Công Đông).
-- Two research candidates, NOT confirmed active retail shops; source-backed, field-validation flags included.
-- No GPS, customer conversion, visits, tax code, photos or selling flags fabricated.
WITH src AS (
  SELECT x.*, md5('fbmn:tiengiang-old:wave02-supplement:'||x.source_key) AS dg
  FROM jsonb_to_recordset('[{"district":"Huyện Tân Phú Đông","name":"Văn phòng phẩm Phu Sương","address_line":"Xã Tân Thới cũ, huyện Tân Phú Đông (Plus Code 7HFJ+7QC)","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJzx1Ab2dVdTERgx9tPQfGIbU","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Phu%20S%C6%B0%C6%A1ng%20T%C3%A2n%20Th%E1%BB%9Bi%20Ti%E1%BB%81n%20Giang&query_place_id=ChIJzx1Ab2dVdTERgx9tPQfGIbU","verification_note":"Nguồn địa điểm bản đồ có nhãn Book store, tên người bán dùng Văn phòng phẩm; chưa có số nhà/điện thoại. Thuộc Tân Thới của huyện Tân Phú Đông cũ. Cần Sales xác minh kinh doanh thực tế."},{"district":"Huyện Gò Công Đông","name":"Hoàng Anh Thư STORE","address_line":"Ấp 1, xã Tân Đông cũ, huyện Gò Công Đông","category":"van_phong_pham","phone":"0849011994","tax_code":null,"source_key":"gmap:ChIJuX2fWABPdTERRqbN0c6N0Ks","source_url":"https://diadiemgocong.com/place.jsp?id=127da7119d671ac99219158f027b8526","verification_note":"Nguồn địa điểm phân loại cửa hàng và dịch vụ photocopy; có tín hiệu bán văn phòng phẩm nhưng chưa chứng minh có quầy VPP thường xuyên. Chưa ghé."}]'::jsonb) AS x(
    district text,name text,address_line text,category text,phone text,tax_code text,
    source_key text,source_url text,verification_note text
  )
), ins AS (
 INSERT INTO public.field_prospects(
   id,area_visit_id,owner_sub,name,address_line,province,district,category,
   phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch
 )
 SELECT
   (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
   NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
   s.name,s.address_line,'Tiền Giang',s.district,s.category,s.phone,s.tax_code,
   'Nghiên cứu nguồn công khai 21/11/2026, Chưa ghé, GPS chưa xác minh. '||s.verification_note||' Nguồn: '||s.source_url,
   'new','manual',s.source_key,s.source_url,'2026-11-21-tien-giang-old-wave-02-supplement'
 FROM src s
 WHERE s.district IN ('Huyện Gò Công Đông','Huyện Tân Phú Đông')
   AND s.source_url LIKE 'https://%'
   AND NOT EXISTS (
    SELECT 1 FROM public.customers c WHERE c.province='Tiền Giang' AND c.district=s.district
      AND lower(btrim(c.name))=lower(btrim(s.name))
   )
   AND NOT EXISTS (
    SELECT 1 FROM public.field_prospects p WHERE p.province='Tiền Giang' AND p.district=s.district
      AND (p.research_source_key=s.source_key OR
        (lower(btrim(p.name))=lower(btrim(s.name)) AND lower(btrim(p.address_line))=lower(btrim(s.address_line))))
   )
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING district,name,phone
)
SELECT district,count(*)::int AS inserted,count(*) FILTER(WHERE phone IS NOT NULL)::int AS phones
FROM ins GROUP BY district ORDER BY district;