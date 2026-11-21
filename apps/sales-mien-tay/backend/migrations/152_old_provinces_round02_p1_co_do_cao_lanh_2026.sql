-- 152 | 2026-11-21 | Round 2 P1: 3 research-only sources in sparse old districts.
-- Huyen Co Do (Can Tho cu): Cuong Quyen and Dai Quang, both Google Maps-only listings.
-- Huyen Cao Lanh (Dong Thap cu): Co Duyen, listed by stationery manufacturer Hong Ha.
-- Source classifications are not proof that the outlets remain active / sell stationery in 2026.
-- Deliberately EXCLUDES "Nhuan Dien" in Co Do: its exact address overlaps an existing
-- misnamed Hong Ha-sourced lead "Nha sach Minh Thu" from an earlier migration.
-- That source-mapping discrepancy requires separate explicit data cleanup approval;
-- never import another duplicate at that address to mask the problem.
-- No visits, GPS, customer edits, or is_selling flags.
WITH src AS (
  SELECT x.*, md5('fbmn:old13:round02:152:' || x.source_key) AS dg
  FROM jsonb_to_recordset('[{"province":"Đồng Tháp","district":"Huyện Cao Lãnh","name":"Văn phòng phẩm Cô Duyên","address_line":"Chợ đầu mối trái cây, xã Mỹ Hiệp cũ, huyện Cao Lãnh, Đồng Tháp","category":"van_phong_pham","phone":"0939917100","tax_code":null,"source_key":"hongha:gaga:co-duyen:cho-dau-moi-my-hiep","source_url":"https://vpphongha.com.vn/vi/gaga","verification_note":"Danh sách điểm bán công khai trên website chính thức VPP Hồng Hà ghi Văn phòng phẩm Cô Duyên, Chợ Đầu Mối, Xã Mỹ Hiệp, điện thoại 0939917100. Chợ đầu mối Mỹ Hiệp thuộc huyện Cao Lãnh cũ theo dữ liệu quy hoạch tỉnh. Chưa xác minh năm 2026 cửa hàng còn bán lẻ và còn hoạt động; ưu tiên gọi điện trước."},{"province":"Cần Thơ","district":"Huyện Cờ Đỏ","name":"Văn phòng phẩm Cường Quyên","address_line":"Plus code 3CVJ+GC4, Đường số 12, khu vực Cờ Đỏ, huyện Cờ Đỏ cũ, Cần Thơ","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJhR-1vaKZoDERk4xN_5zpbus","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20C%C6%B0%E1%BB%9Dng%20Quy%C3%AAn%20%C4%90%C6%B0%E1%BB%9Dng%20S%E1%BB%91%2012%20C%E1%BB%9D%20%C4%90%E1%BB%8F%20C%E1%BA%A7n%20Th%C6%A1&query_place_id=ChIJhR-1vaKZoDERk4xN_5zpbus","verification_note":"Google Maps có điểm tên Văn phòng phẩm Cường Quyên trên Đường số 12 Cờ Đỏ (plus code 3CVJ+GC4), danh mục bản đồ Book store. Chưa có điện thoại công khai và chưa xác minh hàng hóa hoặc tình trạng mở cửa tại điểm bán; không dùng số sao đánh giá để xác nhận."},{"province":"Cần Thơ","district":"Huyện Cờ Đỏ","name":"Văn phòng phẩm - Sửa chữa vi tính Đại Quang","address_line":"Plus code 3CRM+M3M, Đường Hà Huy Giáp, ấp Thới Bình, huyện Cờ Đỏ cũ, Cần Thơ","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJO-01r2eZoDERyFg2RRfywOU","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20s%E1%BB%ADa%20ch%E1%BB%AFa%20vi%20t%C3%ADnh%20%C4%90%E1%BA%A1i%20Quang%20%E1%BA%A4p%20Th%E1%BB%9Bi%20B%C3%ACnh%20C%E1%BB%9D%20%C4%90%E1%BB%8F%20C%E1%BA%A7n%20Th%C6%A1&query_place_id=ChIJO-01r2eZoDERyFg2RRfywOU","verification_note":"Google Maps ghi tên kết hợp văn phòng phẩm và sửa vi tính, vị trí đường Hà Huy Giáp, ấp Thới Bình (plus code 3CRM+M3M). Danh mục bản đồ chính là thiết bị camera, không chứng minh cửa hàng thực tế đang bán học phẩm; Sales phải gọi hoặc khảo sát trước khi chuyển khách."}]'::jsonb)
  AS x(province text,district text,name text,address_line text,category text,phone text,
       tax_code text,source_key text,source_url text,verification_note text)
), ins AS (
  INSERT INTO public.field_prospects (
    id, area_visit_id, owner_sub, name, address_line, province, district,
    category, phone, tax_code, note, status, source_kind,
    research_source_key, research_source_url, research_batch
  )
  SELECT
    (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
    NULL, 'ef943de4-18f7-49ef-8340-eefb18855534',
    s.name, s.address_line, s.province, s.district, s.category, s.phone, s.tax_code,
    'Vòng 2 P1 nghiên cứu nguồn công khai 21/11/2026; CHƯA GHÉ; GPS chưa xác minh; chưa xác minh còn hoạt động và ngành hàng thực tế. '
      || s.verification_note || ' Nguồn: ' || s.source_url,
    'new', 'manual', s.source_key, s.source_url,
    '2026-11-21-old13-round02-p1-codo-caolanh-152'
  FROM src s
  WHERE (s.province,s.district) IN (
     ('Cần Thơ','Huyện Cờ Đỏ'),('Đồng Tháp','Huyện Cao Lãnh'))
    AND s.source_url LIKE 'https://%'
    AND NOT EXISTS (
      SELECT 1 FROM public.customers c
      WHERE c.province=s.province AND c.district=s.district
        AND (lower(trim(c.name))=lower(trim(s.name))
          OR (s.phone IS NOT NULL AND c.phone IS NOT NULL
            AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.field_prospects p
      WHERE p.research_source_key=s.source_key
        OR (p.province=s.province AND p.district=s.district AND (
          (lower(trim(p.name))=lower(trim(s.name))
            AND lower(trim(p.address_line))=lower(trim(s.address_line)))
          OR (s.phone IS NOT NULL AND p.phone IS NOT NULL
            AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
          OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code)
        ))
    )
  ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
  RETURNING province,district,name,category
)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
