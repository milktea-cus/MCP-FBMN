-- 097 | Bình Đại old: second-pass locally sourced potential bookstores and stationery.
-- Sources & discrepancies: ../data/market_prospects_binh_dai_second_pass_2026_11_21.json
-- Idempotent, only additive. No visit, R2 photo, verified GPS or customer conversion.
WITH source_data AS (
 SELECT x.*, md5('fbmn:binh-dai:second-pass:2026:' || x.source_key) AS digest
 FROM jsonb_to_recordset('[{"source_key":"gmap:ChIJT8a8J9pXdTERnBhGmuxqnyU","name":"Văn phòng phẩm Nhân Vi","address_line":"Khu phố 2 (định vị 5MPR+W3M), thị trấn Bình Đại, huyện Bình Đại cũ","category":"van_phong_pham","phone":"02753741957","tax_code":null,"source_url":"https://www.google.com/maps/search/?api=1&query=VPP%20Nh%C3%A2n%20Vi%20B%C3%ACnh%20%C4%90%E1%BA%A1i%20B%E1%BA%BFn%20Tre&query_place_id=ChIJT8a8J9pXdTERnBhGmuxqnyU","evidence":"Google Maps địa điểm riêng, tên VPP, khu phố 2 và điện thoại công khai","confidence":"map_listed","verification_note":"Chưa xác minh mặt hàng và GPS thực địa; chỉ có plus code, chưa có số nhà."},{"source_key":"gmap:ChIJGw-VisDjnzERjjX4AImNPoY","name":"Văn phòng phẩm Huỳnh Thi","address_line":"Đường chưa đặt tên, xã Thừa Đức, huyện Bình Đại cũ (plus code 5Q77+PGX)","category":"van_phong_pham","phone":"0853993187","tax_code":null,"source_url":"https://sotayvang.com/van-phong-pham-huynh-thi-thua-duc/","evidence":"Danh bạ Sổ Tay Vàng có tên, số điện thoại, xã Thừa Đức và map place ID","confidence":"directory_mapped","verification_note":"Google Maps hiện ghi Thới Thuận tỉnh Vĩnh Long, danh bạ cũ ghi Thừa Đức huyện Bình Đại; xã/địa giới cần kiểm tra. Không xác nhận GPS thực địa."},{"source_key":"gmap:ChIJtQ1tTdlXdTERzJGnKXeSuw4","name":"Cửa hàng Bách hóa – Văn phòng phẩm Đông Chính","address_line":"ĐT883, khu vực Trần Trung, huyện Bình Đại cũ (plus code 5MPV+FHC)","category":"van_phong_pham","phone":"02753891083","tax_code":null,"source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20B%C3%A1ch%20h%C3%B3a%20V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20%C4%90%C3%B4ng%20Ch%C3%ADnh%20B%C3%ACnh%20%C4%90%E1%BA%A1i%20B%E1%BA%BFn%20Tre&query_place_id=ChIJtQ1tTdlXdTERzJGnKXeSuw4","evidence":"Google Maps doanh nghiệp có tên Văn phòng phẩm, số điện thoại, plus code","confidence":"map_listed","verification_note":"Cửa hàng hỗn hợp bách hóa/VPP, chưa xác minh thực tế tỷ trọng VPP; chưa xác định số nhà."},{"source_key":"tax:1301117028:vpp-ngoc-thu:96kp1","name":"Văn phòng phẩm Ngọc Thu","address_line":"Số 96, khu phố 1, thị trấn Bình Đại, huyện Bình Đại cũ","category":"van_phong_pham","phone":null,"tax_code":"1301117028","source_url":"https://dailychukyso.com.vn/mst/1301117028-doanh-nghiep-tu-nhan-van-phong-pham-ngoc-thu/","evidence":"Hồ sơ đăng ký doanh nghiệp 2022, tên ngành VPP, MST 1301117028, số nhà cũ và xã Bình Đại mới","confidence":"business_registration","verification_note":"Mới xác minh địa chỉ đăng ký kinh doanh, chưa có bằng chứng chắc chắn cửa hàng bán lẻ còn mở tại số 96."},{"source_key":"tax:1301017217:vpp-gia-phat:182locthoi","name":"Văn phòng phẩm Gia Phát","address_line":"Số 182, ấp Lộc Thới, xã Lộc Thuận, huyện Bình Đại cũ","category":"van_phong_pham","phone":null,"tax_code":"1301017217","source_url":"https://chogia.vn/ma-so-thue/doanh-nghiep/1301017217","evidence":"Đơn vị có tên chuyên văn phòng phẩm, MST 1301017217, địa chỉ Lộc Thuận từ hai nguồn đăng ký","confidence":"business_registration","verification_note":"Địa chỉ đăng ký doanh nghiệp chưa được kiểm chứng là cửa hàng bán lẻ, Sales cần xác minh trước khi đi."},{"source_key":"tax-reg:8755115112:minh-thao:143vinhhoi","name":"Nhà sách Minh Thảo","address_line":"Số 143, ấp Vinh Hội, xã Vang Quới Tây, huyện Bình Đại cũ (nay xã Lộc Thuận)","category":"nha_sach","phone":null,"tax_code":null,"source_url":"https://tracuunhanh.vn/8755115112-001-ho-kinh-doanh-nha-sach-minh-thao","evidence":"Hồ sơ hộ kinh doanh Nhà sách Minh Thảo, địa chỉ trước sáp nhập Vang Quới Tây, nguồn đấu thầu 2025–2026","confidence":"registered_household","verification_note":"Hai nguồn ghi MST dạng khác nhau 8755115112-001 / 083172002040, chưa điền MST tránh gắn nhầm. Chưa xác minh cửa hàng còn bán trực tiếp."}]'::jsonb) AS x(
  source_key text,name text,address_line text,category text,phone text,
  tax_code text,source_url text,evidence text,confidence text,verification_note text
 )
), inserted AS (
 INSERT INTO public.field_prospects(
   id,area_visit_id,owner_sub,name,address_line,province,district,
   category,phone,tax_code,note,status,source_kind,
   research_source_key,research_source_url,research_batch
 )
 SELECT
  (substr(s.digest,1,8)||'-'||substr(s.digest,9,4)||'-5'||substr(s.digest,14,3)
   ||'-8'||substr(s.digest,18,3)||'-'||substr(s.digest,21,12))::uuid,
  NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
  s.name,s.address_line,'Bến Tre','Huyện Bình Đại',s.category,s.phone,s.tax_code,
  'Nguồn công khai ('||s.confidence||'); chưa ghé, chưa xác minh GPS/thực tế. '
   ||s.verification_note||' Nguồn: '||s.source_url,
  'new','manual',s.source_key,s.source_url,
  '2026-11-21-binh-dai-second-pass-book-stationery-01'
 FROM source_data s
 WHERE s.category IN ('nha_sach','van_phong_pham')
  AND s.source_url LIKE 'https://%'
  AND NOT EXISTS(
   SELECT 1 FROM public.customers c
   WHERE c.province='Bến Tre' AND c.district='Huyện Bình Đại'
    AND (
      lower(btrim(c.name))=lower(btrim(s.name))
      OR (s.tax_code IS NOT NULL
       AND regexp_replace(coalesce(c.vat_tax_code,''),'[^0-9]','','g')=s.tax_code
       AND lower(btrim(c.address_line))=lower(btrim(s.address_line)))
    )
  )
  AND NOT EXISTS(
   SELECT 1 FROM public.field_prospects p
   WHERE p.province='Bến Tre' AND p.district='Huyện Bình Đại'
    AND (
      p.research_source_key=s.source_key
      OR (lower(btrim(p.name))=lower(btrim(s.name))
         AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))
    )
  )
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING name,category,district,research_source_key
)
SELECT * FROM inserted ORDER BY name;
