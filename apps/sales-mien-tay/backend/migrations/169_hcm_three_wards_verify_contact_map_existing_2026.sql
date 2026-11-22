-- 169 | 2026-11-22 | Enrich existing 3-ward leads, NO NEW SHOPS.
-- Never overwrite non-null phone/place ID or already-verified GPS and visits.
-- A Map search URL without place ID is not promoted to a Place ID.
WITH src AS (
 SELECT * FROM jsonb_to_recordset('[{"key":"caydauto:35-nguyen-van-trang","phone":"0899314169","place":null,"maps":"https://www.google.com/maps/search/?api=1&query=CAY+DAU+TO+STATIONERY+35+Nguyen+Van+Trang+Ho+Chi+Minh","source":"Google Maps hồ sơ CAY DAU TO STATIONERY & LOCAL SOUVENIRS STORE, 35 Nguyễn Văn Tráng, ĐT 0899314169; Place ID Google không có trong kết quả, không đoán"},{"key":"trungtamvanphongpham:tan-tien:15e-nguyen-thi-minh-khai","phone":"02839118357","place":"ChIJnYPXZUovdTERnB8nY8BihpA","maps":"https://www.google.com/maps/search/?api=1&query=Van+phong+pham+Tan+Tien+15E+Nguyen+Thi+Minh+Khai&query_place_id=ChIJnYPXZUovdTERnB8nY8BihpA","source":"Website trungtamvanphongpham.vn + hồ sơ Google Maps cửa hàng Tân Tiến tại 15E Nguyễn Thị Minh Khai"},{"key":"taipoz:150-7-2-nguyen-trai","phone":"0346657079","place":"ChIJIzBUMjwvdTERAcKOz2Avjs8","maps":"https://www.google.com/maps/search/?api=1&query=Taipoz+150%2F7%2F2+Nguyen+Trai&query_place_id=ChIJIzBUMjwvdTERAcKOz2Avjs8","source":"Google Maps hồ sơ Taipoz tại hẻm 150/7/2 Nguyễn Trãi; đã có phone 0346657079"},{"key":"nxbhcm:88-90-ky-con","phone":"02838216009","place":"ChIJN5jNyigvdTER3YtD5xBBlew","maps":"https://www.google.com/maps/search/?api=1&query=Nha+sach+Tong+Hop+3+88+Ky+Con&query_place_id=ChIJN5jNyigvdTER3YtD5xBBlew","source":"Website NXB Tổng hợp + Google Maps cơ sở bán lẻ 88 Ký Con, Bến Thành"}]'::jsonb) x(
 key text, phone text, place text, maps text, source text
 )
), updated AS (
 UPDATE public.field_prospects p SET
  phone=COALESCE(p.phone,s.phone),
  google_place_id=COALESCE(p.google_place_id,s.place),
  google_maps_url=COALESCE(p.google_maps_url,s.maps)
 FROM src s
 WHERE p.research_source_key=s.key
  AND p.province='TP Hồ Chí Minh' AND p.district='Quận 1'
  AND p.ward_new IN ('Sài Gòn','Tân Định','Bến Thành')
  AND (p.phone IS NULL OR p.phone=s.phone)
  AND (p.google_place_id IS NULL OR p.google_place_id=s.place)
  AND (p.phone IS DISTINCT FROM s.phone AND p.phone IS NULL
       OR p.google_place_id IS DISTINCT FROM s.place AND p.google_place_id IS NULL
       OR p.google_maps_url IS NULL)
  AND (s.place IS NULL OR NOT EXISTS (
     SELECT 1 FROM public.field_prospects other
     WHERE other.google_place_id=s.place AND other.id<>p.id))
  AND (s.phone IS NULL OR NOT EXISTS (
     SELECT 1 FROM public.field_prospects other
     WHERE other.province='TP Hồ Chí Minh' AND
      regexp_replace(coalesce(other.phone,''),'[^0-9]','','g')=s.phone
      AND other.id<>p.id
  ))
 RETURNING p.name,p.ward_new,p.phone,p.google_place_id,p.google_maps_url
)
SELECT * FROM updated ORDER BY ward_new,name;