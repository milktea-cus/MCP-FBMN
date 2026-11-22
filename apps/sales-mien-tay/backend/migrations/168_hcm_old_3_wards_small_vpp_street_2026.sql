-- 168 | 22 November 2026 | Street-by-street small retailers, old HCM city 3 wards.
-- Each entry has an identifiable physical retail location (not registration-only).
-- Low-review listings remain UNVISITED research prospects, never validated customers.
-- Map ward must be checked at visit, especially when split former Da Kao/N.T.Binh.
-- Re-running safe: both source key and place id are deduplicated across all provinces.
WITH src AS (
 SELECT * FROM jsonb_to_recordset('[{"ward":"Sài Gòn","name":"Văn phòng phẩm Nguyễn Thị Hồng Duyên","street":"60 Ngô Đức Kế","legacy":"Bến Nghé","phone":"0903923648","place":"ChIJTRfsSEEvdTERkybespaRs4E","source":"https://thienphuc.vn/cua-hang-van-phong-pham-gan-day/","proof":"VPP mang tên cá nhân được liệt kê ở địa chỉ bán lẻ 60 Ngô Đức Kế (Bến Nghé cũ); Google Maps ghi tên, số ĐT và phường Sài Gòn. Ít review, cần Sales ghé xác minh.","gmaps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Nguy%E1%BB%85n%20Th%E1%BB%8B%20H%E1%BB%93ng%20Duy%C3%AAn%2060%20Ng%C3%B4%20%C4%90%E1%BB%A9c%20K%E1%BA%BF%20TP%20HCM&query_place_id=ChIJTRfsSEEvdTERkybespaRs4E","address_new":"60 Ngô Đức Kế, phường Sài Gòn, TP. Hồ Chí Minh","address_old":"60 Ngô Đức Kế, phường Bến Nghé cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJTRfsSEEvdTERkybespaRs4E"},{"ward":"Tân Định","name":"VPP - Dụng cụ học sinh Phạm Xuân Hòa","street":"2A Đinh Tiên Hoàng","legacy":"Đa Kao","phone":"0938825309","place":"ChIJmyBysMsodTERzqlQ6nmdkgA","source":"https://sotayvang.com/cua-hang-van-phong-pham-dung-cu-hoc-sinh-pham-xuan-hoa-da-kao/","proof":"Sổ Tay Vàng xác định cửa hàng VPP dụng cụ học sinh tại số 2A Đinh Tiên Hoàng, Đa Kao cũ; Google Maps hiện ghi phường Tân Định và điện thoại. Ranh giới Đa Kao chia hai phường mới nên phải đối chiếu điểm thực địa.","gmaps":"https://www.google.com/maps/search/?api=1&query=VPP%20-%20D%E1%BB%A5ng%20c%E1%BB%A5%20h%E1%BB%8Dc%20sinh%20Ph%E1%BA%A1m%20Xu%C3%A2n%20H%C3%B2a%202A%20%C4%90inh%20Ti%C3%AAn%20Ho%C3%A0ng%20TP%20HCM&query_place_id=ChIJmyBysMsodTERzqlQ6nmdkgA","address_new":"2A Đinh Tiên Hoàng, phường Tân Định, TP. Hồ Chí Minh","address_old":"2A Đinh Tiên Hoàng, phường Đa Kao cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJmyBysMsodTERzqlQ6nmdkgA"},{"ward":"Tân Định","name":"Văn phòng phẩm Lê Khanh","street":"16 Nguyễn Văn Giai","legacy":"Đa Kao","phone":null,"place":"ChIJTVXcEwApdTERthWhjnYas5Q","source":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJTVXcEwApdTERthWhjnYas5Q","proof":"Google Maps có vị trí VPP Lê Khanh tại 16 Nguyễn Văn Giai, phường Tân Định, có nhận xét về bán VPP; 3 reviews, chưa có số điện thoại công khai.","gmaps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20L%C3%AA%20Khanh%2016%20Nguy%E1%BB%85n%20V%C4%83n%20Giai%20TP%20HCM&query_place_id=ChIJTVXcEwApdTERthWhjnYas5Q","address_new":"16 Nguyễn Văn Giai, phường Tân Định, TP. Hồ Chí Minh","address_old":"16 Nguyễn Văn Giai, phường Đa Kao cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJTVXcEwApdTERthWhjnYas5Q"},{"ward":"Bến Thành","name":"Văn phòng phẩm Thu","street":"111 Ký Con","legacy":"Nguyễn Thái Bình","phone":"0906633329","place":"ChIJ17vFuT8vdTERbKjjW-D5JbQ","source":"https://top3.vn/top-3-cua-hang-van-phong-pham-uy-tin-quan-1-gia-tot-phuc-vu-chuyen-nghiep","proof":"Cửa hàng bán VPP được nhiều nguồn độc lập ghi tại 111 Ký Con, Nguyễn Thái Bình cũ; Google Maps ghi phường Bến Thành, số 0906633329; có thông tin bán giấy, bút, băng keo.","gmaps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Thu%20111%20K%C3%BD%20Con%20TP%20HCM&query_place_id=ChIJ17vFuT8vdTERbKjjW-D5JbQ","address_new":"111 Ký Con, phường Bến Thành, TP. Hồ Chí Minh","address_old":"111 Ký Con, phường Nguyễn Thái Bình cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJ17vFuT8vdTERbKjjW-D5JbQ"},{"ward":"Bến Thành","name":"Văn hóa phẩm Bình Minh","street":"110 Lê Lai","legacy":"Bến Thành","phone":null,"place":"ChIJEZjuVwAvdTERphcyB4Ua3wk","source":"https://vietwave.com.vn/thiepbinhminh/vi/san-pham/thiep-moi-mot-mau-456","proof":"Website Thiệp Bình Minh xác nhận Cửa hàng Văn hóa phẩm Bình Minh tại 110 Lê Lai, Bến Thành, kinh doanh thiệp và đồ giấy; Google Maps ghi stationery store. Chưa có số điện thoại riêng được kiểm.","gmaps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20h%C3%B3a%20ph%E1%BA%A9m%20B%C3%ACnh%20Minh%20110%20L%C3%AA%20Lai%20TP%20HCM&query_place_id=ChIJEZjuVwAvdTERphcyB4Ua3wk","address_new":"110 Lê Lai, phường Bến Thành, TP. Hồ Chí Minh","address_old":"110 Lê Lai, phường Bến Thành cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJEZjuVwAvdTERphcyB4Ua3wk"},{"ward":"Bến Thành","name":"VPP Tri Thức","street":"27 Lê Công Kiều","legacy":"Nguyễn Thái Bình","phone":"0906737167","place":"ChIJOQF7xVUvdTERQshlFu4mjT4","source":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJOQF7xVUvdTERQshlFu4mjT4","proof":"Google Maps định danh VPP Tri Thức tại 27 Lê Công Kiều, Bến Thành, số 0906737167; danh mục giấy, bút và đồ văn phòng được nêu ở hồ sơ. Chưa có đánh giá công khai; cần kiểm tra bảng hiệu.","gmaps":"https://www.google.com/maps/search/?api=1&query=VPP%20Tri%20Th%E1%BB%A9c%2027%20L%C3%AA%20C%C3%B4ng%20Ki%E1%BB%81u%20TP%20HCM&query_place_id=ChIJOQF7xVUvdTERQshlFu4mjT4","address_new":"27 Lê Công Kiều, phường Bến Thành, TP. Hồ Chí Minh","address_old":"27 Lê Công Kiều, phường Nguyễn Thái Bình cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJOQF7xVUvdTERQshlFu4mjT4"},{"ward":"Bến Thành","name":"Văn phòng phẩm Duy Hùng","street":"71 Nguyễn Thái Bình","legacy":"Nguyễn Thái Bình","phone":null,"place":"ChIJJdqNUQAvdTERI9m4jHZUMvw","source":"https://thuvienphapluat.vn/ma-so-thue/cong-ty-tnhh-mot-thanh-vien-van-phong-pham-duy-hung-mst-0310527565.html","proof":"Google Maps có địa điểm VPP Duy Hùng tại 71 Nguyễn Thái Bình, phường Bến Thành, 4 nhận xét; cơ sở kinh doanh có địa chỉ trùng trong hồ sơ thuế. Có thể cửa hàng nhỏ/đơn vị thương mại; cần Sales xác minh có quầy bán lẻ.","gmaps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Duy%20H%C3%B9ng%2071%20Nguy%E1%BB%85n%20Th%C3%A1i%20B%C3%ACnh%20TP%20HCM&query_place_id=ChIJJdqNUQAvdTERI9m4jHZUMvw","address_new":"71 Nguyễn Thái Bình, phường Bến Thành, TP. Hồ Chí Minh","address_old":"71 Nguyễn Thái Bình, phường Nguyễn Thái Bình cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJJdqNUQAvdTERI9m4jHZUMvw"},{"ward":"Bến Thành","name":"Văn phòng phẩm Hùng","street":"135 Nguyễn Thái Bình","legacy":"Nguyễn Thái Bình","phone":null,"place":"ChIJazsHRQAvdTERbRnTnrqN1Wc","source":"https://dauthau.asia/businesslistings/detail/Cua-hang-van-phong-pham-Hung-63898/","proof":"Cửa hàng VPP Hùng 135 Nguyễn Thái Bình được ghi trong hồ sơ nhà thầu bán vật dụng hành chính; Google Maps ghi phường Bến Thành, có hồ sơ bán lẻ và một nhận xét. Chưa có điện thoại riêng xác minh.","gmaps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20H%C3%B9ng%20135%20Nguy%E1%BB%85n%20Th%C3%A1i%20B%C3%ACnh%20TP%20HCM&query_place_id=ChIJazsHRQAvdTERbRnTnrqN1Wc","address_new":"135 Nguyễn Thái Bình, phường Bến Thành, TP. Hồ Chí Minh","address_old":"135 Nguyễn Thái Bình, phường Nguyễn Thái Bình cũ, Quận 1, TP.HCM cũ","key":"gmaps:ChIJazsHRQAvdTERbRnTnrqN1Wc"}]'::jsonb) AS s(
   ward text,name text,street text,legacy text,phone text,place text,source text,
   proof text,gmaps text,address_new text,address_old text,key text
 )
), vetted AS (
 SELECT s.* FROM src s
 WHERE s.ward IN ('Sài Gòn','Tân Định','Bến Thành')
   AND s.place ~ '^ChIJ[A-Za-z0-9_-]{20,}$'
   AND s.source LIKE 'https://%' AND s.gmaps LIKE 'https://www.google.com/maps/%'
   AND s.address_new LIKE '%phường '||s.ward||'%'
   AND (s.phone IS NULL OR s.phone ~ '^[0-9]{8,11}$')
   AND NOT EXISTS (
     SELECT 1 FROM public.field_prospects p
     WHERE p.google_place_id=s.place OR p.research_source_key=s.key
       OR (p.province='TP Hồ Chí Minh' AND p.ward_new=s.ward
           AND lower(btrim(p.name))=lower(btrim(s.name)))
       OR lower(btrim(p.address_line))=lower(btrim(s.address_new))
       OR (s.phone IS NOT NULL AND regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=s.phone)
   )
   AND NOT EXISTS (
     SELECT 1 FROM public.customers c
     WHERE lower(btrim(c.address_line))=lower(btrim(s.address_new))
       OR (c.province='TP Hồ Chí Minh' AND lower(btrim(c.name))=lower(btrim(s.name)))
       OR (s.phone IS NOT NULL AND regexp_replace(coalesce(c.phone,''),'[^0-9]','','g')=s.phone)
   )
), inserted AS (
 INSERT INTO public.field_prospects (
   id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,
   address_legacy,category,phone,tax_code,note,status,source_kind,
   research_source_key,research_source_url,research_batch,google_maps_url,google_place_id
 )
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
   s.name,s.address_new,'TP Hồ Chí Minh','Quận 1',s.ward,
   s.address_old,'van_phong_pham',s.phone,NULL,
   'Nguồn tra cứu 22/11/2026; CHƯA GHÉ / CHƯA XÁC MINH thực địa và GPS. '||
   s.proof||' Link: '||s.source,
   'new','manual',s.key,s.source,
   '2026-11-22-hcm-old-three-wards-small-vpp-168',s.gmaps,s.place
 FROM vetted s
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING ward_new,name,category,phone,google_place_id
)
SELECT * FROM inserted ORDER BY ward_new,name;