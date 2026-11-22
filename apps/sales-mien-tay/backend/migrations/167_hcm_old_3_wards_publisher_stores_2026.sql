-- 167 | 2026-11-22 | HCM old territory: verified independent bookstores and publishers' customer-facing shops.
-- Same three 2025 new wards ONLY (Sài Gòn, Tân Định, Bến Thành).
-- Companies/headquarters alone are excluded: NXB Tổng hợp 62 NTMK qualifies
-- because publisher's official site explicitly labels it "Nhà sách Tổng hợp 1".
-- FirstNews/Alpha kiosk numbers remain unknown and are NOT fabricated.
-- Van Lang 40-42 NTMK: 2026 publisher article, Maps and tax address say Sài Gòn,
-- whereas stale/inconsistent footer says Tân Định; preserve discrepancy in note.
WITH src AS (
 SELECT * FROM jsonb_to_recordset('[{"ward":"Sài Gòn","name":"Nhà sách NXB Trẻ - Nguyễn Văn Bình","street":"Gian M16-17, đường Nguyễn Văn Bình","oldward":"Bến Nghé","phone":"02839141579","place":null,"key":"nxbtre:nguyenvanbinh:m16-17","source":"https://www.nxbtre.com.vn/lien-he/","evidence":"Trang liên hệ chính thức NXB Trẻ xác nhận Cửa hàng sách Nguyễn Văn Bình, M16-17, phường Sài Gòn, số trực tiếp (028) 39141579. Không nhầm với trụ sở 161B Lý Chính Thắng ngoài 3 phường.","address_line":"Gian M16-17, đường Nguyễn Văn Bình, phường Sài Gòn, TP. Hồ Chí Minh","address_legacy":"Gian M16-17, đường Nguyễn Văn Bình, phường Bến Nghé cũ, Quận 1, TP.HCM cũ","google_maps_url":null},{"ward":"Sài Gòn","name":"Gian hàng First News - Trí Việt Đường sách","street":"Gian hàng First News, đường sách Nguyễn Văn Bình","oldward":"Bến Nghé","phone":"0909815139","place":"ChIJR_em0DcvdTERJI_gC6gxNlY","key":"firstnews:duongsach-nguyenvanbinh","source":"https://firstnews.vn/lien-he","evidence":"Website First News xác nhận cửa hàng trực tiếp tại Đường sách Nguyễn Văn Bình, phường Sài Gòn (Bến Nghé cũ) và hotline riêng gian hàng 0909815139. Chưa tìm được số kiosk nên không tự gán gian số.","address_line":"Gian hàng First News, đường sách Nguyễn Văn Bình, phường Sài Gòn, TP. Hồ Chí Minh","address_legacy":"Gian hàng First News, đường sách Nguyễn Văn Bình, phường Bến Nghé cũ, Quận 1, TP.HCM cũ","google_maps_url":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJR_em0DcvdTERJI_gC6gxNlY&query=Gian%20h%C3%A0ng%20First%20News%20-%20Tr%C3%AD%20Vi%E1%BB%87t%20%C4%90%C6%B0%E1%BB%9Dng%20s%C3%A1ch%20Gian%20h%C3%A0ng%20First%20News%2C%20%C4%91%C6%B0%E1%BB%9Dng%20s%C3%A1ch%20Nguy%E1%BB%85n%20V%C4%83n%20B%C3%ACnh"},{"ward":"Sài Gòn","name":"Gian hàng Alpha Books - Đường sách","street":"Gian hàng Alpha Books, đường sách Nguyễn Văn Bình","oldward":"Bến Nghé","phone":"02838251789","place":null,"key":"alphabooks:duongsach-nguyenvanbinh","source":"https://www.alphabooks.vn/he-thong-nha-sach","evidence":"Danh sách hệ thống nhà sách chính thức Alpha Books liệt kê gian sách tại Nguyễn Văn Bình Q1 và điện thoại (08) 3825 1789. Chưa xác định số kiosk cụ thể; không lấy văn phòng hay kho online.","address_line":"Gian hàng Alpha Books, đường sách Nguyễn Văn Bình, phường Sài Gòn, TP. Hồ Chí Minh","address_legacy":"Gian hàng Alpha Books, đường sách Nguyễn Văn Bình, phường Bến Nghé cũ, Quận 1, TP.HCM cũ","google_maps_url":null},{"ward":"Sài Gòn","name":"Nhà sách Tổng hợp 1 - Nguyễn Thị Minh Khai","street":"62 Nguyễn Thị Minh Khai","oldward":"Bến Nghé","phone":"02838256804","place":null,"key":"nxbhcm:62-nguyenthiminhkhai","source":"https://nxbhcm.com.vn/lien-he","evidence":"NXB Tổng hợp TP.HCM liệt kê riêng Nhà sách Tổng hợp 1 tại 62 Nguyễn Thị Minh Khai, phường Sài Gòn và số 02838256804. Cùng địa chỉ trụ sở nhưng xác nhận có điểm bán trực tiếp.","address_line":"62 Nguyễn Thị Minh Khai, phường Sài Gòn, TP. Hồ Chí Minh","address_legacy":"62 Nguyễn Thị Minh Khai, phường Bến Nghé cũ, Quận 1, TP.HCM cũ","google_maps_url":null},{"ward":"Bến Thành","name":"Nhà sách Tổng hợp 3 - Ký Con","street":"88-90 Ký Con","oldward":"Nguyễn Thái Bình","phone":"02838216009","place":null,"key":"nxbhcm:88-90-ky-con","source":"https://nxbhcm.com.vn/lien-he","evidence":"Trang chính thức NXB Tổng hợp TP.HCM liệt kê Nhà sách Tổng hợp 3, 88-90 Ký Con, phường Bến Thành, điện thoại riêng 02838216009; khác nhà sách M01 Đường sách.","address_line":"88-90 Ký Con, phường Bến Thành, TP. Hồ Chí Minh","address_legacy":"88-90 Ký Con, phường Nguyễn Thái Bình cũ, Quận 1, TP.HCM cũ","google_maps_url":null},{"ward":"Sài Gòn","name":"Nhà sách Hải An","street":"2B Nguyễn Thị Minh Khai","oldward":"Đa Kao","phone":"02822299261","place":null,"key":"haian:2b-nguyenthiminhkhai","source":"https://www.megabizdir.com/VN/Ho-Chi-Minh-City/107859820817329/Nh%C3%A0-S%C3%A1ch-H%E1%BA%A3i-An","evidence":"Trang cửa hàng có hoạt động ngày 15/8/2026, địa chỉ cũ 2B Nguyễn Thị Minh Khai phường Đa Kao; thông tin địa điểm và nhiều bài viết cập nhật 2026 xác nhận phường Sài Gòn; cửa hàng bán sách nhiều tầng và VPP.","address_line":"2B Nguyễn Thị Minh Khai, phường Sài Gòn, TP. Hồ Chí Minh","address_legacy":"2B Nguyễn Thị Minh Khai, phường Đa Kao cũ, Quận 1, TP.HCM cũ","google_maps_url":null},{"ward":"Sài Gòn","name":"Nhà sách Văn Lang","street":"40-42 Nguyễn Thị Minh Khai","oldward":"Đa Kao","phone":"02838233022","place":"ChIJyx6R_DUvdTERdeb1HNL2DxM","key":"vanlangbooks:40-42-nguyenthiminhkhai","source":"https://vanlang.vn/blogs/review-sach/sach-hoi-hoa","evidence":"Website VanLangBooks bài 2026 nêu chi nhánh 40-42 Nguyễn Thị Minh Khai, phường Sài Gòn, số 02838233022; Google Maps và địa chỉ thuế cũng ghi phường Sài Gòn. Một số footer website lại ghi Tân Định, ghi chú khác biệt địa danh; cần đối soát thực địa khi Sales ghé.","address_line":"40-42 Nguyễn Thị Minh Khai, phường Sài Gòn, TP. Hồ Chí Minh","address_legacy":"40-42 Nguyễn Thị Minh Khai, phường Đa Kao cũ, Quận 1, TP.HCM cũ","google_maps_url":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJyx6R_DUvdTERdeb1HNL2DxM&query=Nh%C3%A0%20s%C3%A1ch%20V%C4%83n%20Lang%2040-42%20Nguy%E1%BB%85n%20Th%E1%BB%8B%20Minh%20Khai"}]'::jsonb) x(
  ward text,name text,street text,oldward text,phone text,place text,
  key text,source text,evidence text,address_line text,address_legacy text,
  google_maps_url text
 )
), vetted AS (
 SELECT s.* FROM src s
 WHERE s.ward IN ('Sài Gòn','Tân Định','Bến Thành')
  AND s.source LIKE 'https://%' AND s.address_line ILIKE '%phường '||s.ward||'%'
  AND length(btrim(s.name)) BETWEEN 2 AND 240
  AND length(btrim(s.address_line)) BETWEEN 3 AND 500
  AND (s.phone IS NULL OR s.phone ~ '^[0-9]{8,11}$')
  AND NOT EXISTS (
   SELECT 1 FROM public.customers c
   WHERE lower(btrim(c.address_line))=lower(btrim(s.address_line))
    OR (c.province='TP Hồ Chí Minh' AND lower(btrim(c.name))=lower(btrim(s.name)))
    OR (s.phone IS NOT NULL AND regexp_replace(coalesce(c.phone,''),'[^0-9]','','g')=s.phone)
  )
  AND NOT EXISTS (
   SELECT 1 FROM public.field_prospects p
   WHERE p.research_source_key=s.key
    OR (s.place IS NOT NULL AND p.google_place_id=s.place)
    OR lower(btrim(p.address_line))=lower(btrim(s.address_line))
    OR (p.province='TP Hồ Chí Minh' AND p.district='Quận 1' AND lower(btrim(p.name))=lower(btrim(s.name)))
    OR (s.phone IS NOT NULL AND regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=s.phone)
  )
), inserted AS (
 INSERT INTO public.field_prospects(
  id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,address_legacy,
  category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,
  research_batch,google_maps_url,google_place_id
 )
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
  s.name,s.address_line,'TP Hồ Chí Minh','Quận 1',s.ward,s.address_legacy,
  'nha_sach',s.phone,NULL,
  'Tra cứu nguồn công khai 22/11/2026; CHƯA GHÉ, chưa xác minh GPS/hoạt động thực địa. '||s.evidence||
  ' Nguồn: '||s.source,
  'new','manual',s.key,s.source,'2026-11-22-hcm-old-three-wards-publisher-167',
  s.google_maps_url,s.place
 FROM vetted s
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING ward_new,name,category,phone,google_place_id
)
SELECT * FROM inserted ORDER BY ward_new,name;