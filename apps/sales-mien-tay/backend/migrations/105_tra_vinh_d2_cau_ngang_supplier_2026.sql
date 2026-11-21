-- 105 | 2026-11-21 | Additional map-identified VPP wholesale lead, Cầu Ngang old, Trà Vinh.
-- Does not claim retail operation; no fake GPS, check-in or customer conversion.
WITH s AS (
 SELECT x.*,md5('fbmn:tv-wave2-extra:'||x.source_key) dg FROM
 jsonb_to_recordset('[{"district":"Huyện Cầu Ngang","name":"VPP Thiên Tường","address_line":"Ấp Mai Hương, huyện Cầu Ngang cũ (Plus Code QFM7+6MC)","category":"van_phong_pham","phone":"0327204436","tax_code":null,"source_key":"gmap:ChIJ1YadmmchoDERpwgYZG2VyAE","source_url":"https://www.google.com/maps/search/?api=1&query=VPP%20Thi%C3%AAn%20T%C6%B0%E1%BB%9Dng%20%E1%BA%A4p%20Mai%20H%C6%B0%C6%A1ng%20C%E1%BA%A7u%20Ngang&query_place_id=ChIJ1YadmmchoDERpwgYZG2VyAE","verification_note":"Bản đồ phân loại là đầu mối bán sỉ VPP (wholesaler); chưa xác minh có bán lẻ hoặc địa chỉ số nhà. Chỉ ghé sau khi gọi kiểm tra."}]'::jsonb) AS x(
 district text,name text,address_line text,category text,phone text,tax_code text,
 source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects (
 id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,
 note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,'Trà Vinh',s.district,s.category,s.phone,s.tax_code,
 'Nguồn Google Maps 21/11/2026; Chưa ghé; GPS chưa xác minh. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-tra-vinh-old-wave-02-supplement'
 FROM s WHERE s.district='Huyện Cầu Ngang' AND s.source_url LIKE 'https://%'
 AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE c.province='Trà Vinh' AND c.district=s.district AND lower(btrim(c.name))=lower(btrim(s.name)))
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE p.province='Trà Vinh' AND p.district=s.district
 AND (p.research_source_key=s.source_key OR (lower(btrim(p.name))=lower(btrim(s.name)) AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING RETURNING district,name,phone
) SELECT district,count(*)::int inserted FROM ins GROUP BY district;