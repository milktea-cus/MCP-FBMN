-- 101: Two separate bookshops in former Mo Cay Nam (mapsourced).
-- Reproducible, research-only; no visits, GPS, photos, customers or selling.
WITH s AS (
 SELECT x.*,md5('fbmn:ben-tre:mocay-bookstores:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"district":"Huyện Mỏ Cày Nam","name":"Nhà sách Thanh Thủy","address_line":"Khu vực trung tâm thị trấn Mỏ Cày cũ, huyện Mỏ Cày Nam (plus code 38X2+XGP), gần Trường Tạ Thị Kiều","category":"nha_sach","phone":"02753848881","tax_code":null,"source_key":"gmap:ChIJDQBwOycPoDERqyrQZ10YHpM","source_url":"https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20s%C3%A1ch%20Thanh%20Th%E1%BB%A7y%20M%E1%BB%8F%20C%C3%A0y&query_place_id=ChIJDQBwOycPoDERqyrQZ10YHpM","confidence":"mapped_bookstore","evidence":"Google Maps book store with phone and distinct Plus Code","verification_note":"Chưa có số nhà theo địa chỉ hành chính cũ; có thể gọi điện kiểm tra trước khi ghé."},{"district":"Huyện Mỏ Cày Nam","name":"Nhà sách Thành Đạt","address_line":"241 đường Bùi Quang Chiêu, khu phố 2, thị trấn Mỏ Cày cũ, huyện Mỏ Cày Nam","category":"nha_sach","phone":"0338217917","tax_code":null,"source_key":"gmap:ChIJ42cYIwAJoDEROknZoFa2cUE","source_url":"https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20s%C3%A1ch%20Th%C3%A0nh%20%C4%90%E1%BA%A1t%20241%20B%C3%B9i%20Quang%20Chi%C3%AAu%20M%E1%BB%8F%20C%C3%A0y&query_place_id=ChIJ42cYIwAJoDEROknZoFa2cUE","confidence":"mapped_bookstore","evidence":"Google Maps book store with distinct address and phone","verification_note":"Địa danh thị trấn/huyện theo đơn vị cũ cần đối chiếu khi Sales đi thực địa."}]'::jsonb)
 AS x(district text,name text,address_line text,category text,phone text,
 tax_code text,source_key text,source_url text,confidence text,evidence text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects (
 id,area_visit_id,owner_sub,name,address_line,province,district,category,
 phone,tax_code,note,status,source_kind,
 research_source_key,research_source_url,research_batch)
 SELECT
 (substr(x.dg,1,8)||'-'||substr(x.dg,9,4)||'-5'||substr(x.dg,14,3)
 ||'-8'||substr(x.dg,18,3)||'-'||substr(x.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',x.name,x.address_line,
 'Bến Tre',x.district,'nha_sach',x.phone,NULL,
 'Nguồn Google Maps; Chưa ghé, GPS chưa xác minh. '||x.verification_note||' Nguồn: '||x.source_url,
 'new','manual',x.source_key,x.source_url,'2026-11-21-ben-tre-mocay-stores-sweep-03'
 FROM s x
 WHERE x.district='Huyện Mỏ Cày Nam' AND x.category='nha_sach'
  AND x.source_url LIKE 'https://%'
  AND NOT EXISTS (
   SELECT 1 FROM public.customers c WHERE c.province='Bến Tre' AND c.district=x.district
   AND lower(btrim(c.name))=lower(btrim(x.name))
  )
  AND NOT EXISTS (
   SELECT 1 FROM public.field_prospects p WHERE p.province='Bến Tre' AND p.district=x.district
   AND (p.research_source_key=x.source_key OR
        (lower(btrim(p.name))=lower(btrim(x.name)) AND lower(btrim(p.address_line))=lower(btrim(x.address_line))))
  )
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING id,name,district,category
)
SELECT * FROM ins ORDER BY name;