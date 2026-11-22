-- 170 | 2026-11-22 | Two small, map-anchored storefront prospects in old HCM territorial scope.
-- Ngô Thoại Hoa name from tax/site, Google map displays generic 'Văn Phòng Phẩm'.
-- 77 Nguyen Thai Binh shop sign/name UNKNOWN; do NOT invent a brand.
-- Source dates are old; status remains unvisited; no GPS coordinates, check-in, customer.
WITH src AS (
 SELECT * FROM jsonb_to_recordset('[{"ward":"Sài Gòn","name":"Văn phòng phẩm Ngô Thoại Hoa","street":"54 Lê Lợi","old":"Bến Nghé","phone":"02838297695","place":"ChIJW599XkcvdTERf2RlfwBxKQk","source":"https://trangvangdoanhnghiep.vn/0300148511-cua-hang-van-phong-pham-ngo-thoai-hoa","description":"Trang Vàng Doanh Nghiệp định danh cửa hàng VPP Ngô Thoại Hoa tại 54 Lê Lợi, phường Bến Nghé cũ (nay Sài Gòn); Google Maps có hồ sơ VPP tại đúng 54 Lê Lợi nhưng tên hiển thị chung Văn Phòng Phẩm và 0 đánh giá. Số điện thoại từ danh bạ lâu năm, chưa xác minh gọi được; CHƯA GHÉ.","key":"gmaps:ChIJW599XkcvdTERf2RlfwBxKQk","maps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Ng%C3%B4%20Tho%E1%BA%A1i%20Hoa%2054%20L%C3%AA%20L%E1%BB%A3i&query_place_id=ChIJW599XkcvdTERf2RlfwBxKQk","new_address":"54 Lê Lợi, phường Sài Gòn, TP. Hồ Chí Minh","old_address":"54 Lê Lợi, phường Bến Nghé cũ, Quận 1, TP.HCM cũ"},{"ward":"Bến Thành","name":"Cửa hàng văn phòng phẩm 77 Nguyễn Thái Bình (chưa rõ tên bảng hiệu)","street":"77 Nguyễn Thái Bình","old":"Nguyễn Thái Bình","phone":"02838218232","place":"ChIJh1tqm0AvdTERqP3qkYcQCrk","source":"https://tim-dia-diem.blogspot.com/2017/08/cua-hang-van-phong-pham-o-tphcm-quan-1.html","description":"Hồ sơ Google Maps hiện phân loại Office equipment supplier tại 77 Nguyễn Thái Bình, phường Bến Thành, 1 review, cùng phone 02838218232 với danh bạ 2017. Không biết tên bảng hiệu thật; website được Google gắn có địa chỉ khác nên KHÔNG dùng để xác minh. CHƯA GHÉ.","key":"gmaps:ChIJh1tqm0AvdTERqP3qkYcQCrk","maps":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20v%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%2077%20Nguy%E1%BB%85n%20Th%C3%A1i%20B%C3%ACnh%20(ch%C6%B0a%20r%C3%B5%20t%C3%AAn%20b%E1%BA%A3ng%20hi%E1%BB%87u)%2077%20Nguy%E1%BB%85n%20Th%C3%A1i%20B%C3%ACnh&query_place_id=ChIJh1tqm0AvdTERqP3qkYcQCrk","new_address":"77 Nguyễn Thái Bình, phường Bến Thành, TP. Hồ Chí Minh","old_address":"77 Nguyễn Thái Bình, phường Nguyễn Thái Bình cũ, Quận 1, TP.HCM cũ"}]'::jsonb) AS s(
 ward text,name text,street text,old text,phone text,place text,
 source text,description text,key text,maps text,new_address text,old_address text
 )
), vetted AS (
 SELECT s.* FROM src s WHERE
  s.ward IN ('Sài Gòn','Tân Định','Bến Thành')
  AND s.place ~ '^ChIJ[A-Za-z0-9_-]{20,}$'
  AND s.phone ~ '^[0-9]{8,11}$'
  AND s.new_address ILIKE '%phường '||s.ward||'%'
  AND NOT EXISTS (
   SELECT 1 FROM public.field_prospects p WHERE
    p.research_source_key=s.key OR p.google_place_id=s.place
    OR lower(btrim(p.address_line))=lower(btrim(s.new_address))
    OR (p.province='TP Hồ Chí Minh' AND p.ward_new=s.ward AND lower(btrim(p.name))=lower(btrim(s.name)))
    OR regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=s.phone
  )
  AND NOT EXISTS (
   SELECT 1 FROM public.customers c WHERE
    lower(btrim(c.address_line))=lower(btrim(s.new_address))
    OR (c.province='TP Hồ Chí Minh' AND lower(btrim(c.name))=lower(btrim(s.name)))
    OR regexp_replace(coalesce(c.phone,''),'[^0-9]','','g')=s.phone
  )
), inserted AS (
 INSERT INTO public.field_prospects(
  id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,address_legacy,
  category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,
  research_batch,google_maps_url,google_place_id
 )
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
 s.name,s.new_address,'TP Hồ Chí Minh','Quận 1',s.ward,s.old_address,
 'van_phong_pham',s.phone,NULL,
 'Tra cứu địa điểm và nguồn cũ 22/11/2026; CHƯA GHÉ / CHƯA XÁC MINH bán lẻ hiện tại. '||
 s.description||' Nguồn: '||s.source,
 'new','manual',s.key,s.source,'2026-11-22-hcm-old-three-wards-small-vpp-170',
 s.maps,s.place
 FROM vetted s
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING ward_new,name,category,phone,google_place_id
)
SELECT * FROM inserted ORDER BY ward_new,name;