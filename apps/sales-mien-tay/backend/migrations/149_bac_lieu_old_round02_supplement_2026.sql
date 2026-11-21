-- 149 | 2026-11-21 | Bạc Liêu OLD round 2 supplementary sourced prospect.
-- Append-only, no fake GPS/check-ins. Phone and exact-name duplicate guards against customers and prospects.
WITH src AS(SELECT x.*,md5('fbmn:bac_lieu-old:round02:'||x.source_key) dg
 FROM jsonb_to_recordset('[{"district":"Thành phố Bạc Liêu","name":"Cửa hàng Văn phòng phẩm Tiến Phát","address_line":"17 Hòa Bình, Phường 3 cũ, TP Bạc Liêu","category":"van_phong_pham","phone":"02913822223","tax_code":null,"source_key":"gmap:ChIJu2Ai9mQJoTERPRHUO-av0RM","source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Ti%E1%BA%BFn%20Ph%C3%A1t%2017%20H%C3%B2a%20B%C3%ACnh%20B%E1%BA%A1c%20Li%C3%AAu&query_place_id=ChIJu2Ai9mQJoTERPRHUO-av0RM","verification_note":"Địa điểm Maps ghi cửa hàng VPP tại 17 Hòa Bình, điện thoại 02913822223; chưa Sales ghé. Không thuộc hai huyện Vĩnh Lợi, Đông Hải còn thiếu."}]'::jsonb) AS x(district text,name text,address_line text,category text,phone text,tax_code text,source_key text,source_url text,verification_note text)),
 ins AS(INSERT INTO public.field_prospects(id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,'Bạc Liêu',s.district,s.category,s.phone,s.tax_code,
 'Vòng rà bù nguồn công khai 21/11/2026; CHƯA GHÉ; GPS chưa xác minh; chưa xác minh hoạt động bán lẻ. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-bac-lieu-old-round02-city-01'
 FROM src s WHERE s.district IN ('Thành phố Bạc Liêu') AND s.source_url LIKE 'https://%'
 AND NOT EXISTS(SELECT 1 FROM customers c WHERE c.province='Bạc Liêu' AND c.district=s.district AND
 (lower(trim(c.name))=lower(trim(s.name)) OR (c.phone IS NOT NULL AND s.phone IS NOT NULL AND c.phone=s.phone)))
 AND NOT EXISTS(SELECT 1 FROM field_prospects p WHERE p.province='Bạc Liêu' AND p.district=s.district AND
 (p.research_source_key=s.source_key OR (lower(trim(p.name))=lower(trim(s.name)) AND lower(trim(p.address_line))=lower(trim(s.address_line)))
 OR (p.phone IS NOT NULL AND s.phone IS NOT NULL AND p.phone=s.phone) OR (p.tax_code IS NOT NULL AND s.tax_code IS NOT NULL AND p.tax_code=s.tax_code)))
 ON CONFLICT(research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING RETURNING district,category,phone)
 SELECT district,count(*)::int inserted,count(*) FILTER(WHERE category='nha_sach')::int bookstores FROM ins GROUP BY district ORDER BY district;