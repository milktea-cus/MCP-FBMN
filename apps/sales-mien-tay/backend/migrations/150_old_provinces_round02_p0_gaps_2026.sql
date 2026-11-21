-- 150 | 2026-11-21 | ROUND 2 P0: 4 of 8 old-district gaps, public research leads only.
-- 7 sourced points: Kien Giang Giang Thanh (2), Soc Trang Cu Lao Dung (2),
-- Hau Giang Vi Thuy (2), Bac Lieu Dong Hai (1).
-- DO NOT mark visited, verified location, operating store, or official customer.
-- Sau Cao/VPP Sau Cao omitted: source not sufficiently independently verified.
-- Remaining old-district gaps: Kien Hai, Long My (huyen), Tran De, Vinh Loi.
-- Old provincial/district identifiers are intentional; some Maps addresses now show
-- the 2025+ administrative provinces, which must not replace these stored identifiers.
WITH src AS (
  SELECT x.*, md5('fbmn:old13:round02:150:' || x.source_key) AS dg
  FROM jsonb_to_recordset('[{"province":"Kiên Giang","district":"Huyện Giang Thành","name":"Văn phòng phẩm - hoa kiểng Phú Mỹ","address_line":"Tổ 1, ấp Trà Phô, xã Phú Mỹ cũ, huyện Giang Thành, Kiên Giang","category":"van_phong_pham","phone":null,"tax_code":"1702222774","verification_note":"Google Maps có điểm bán VPP/hoa kiểng tại khu vực Trà Phô. Hồ sơ hộ kinh doanh ghi MST 1702222774, địa chỉ tổ 1 ấp Trà Phô; hồ sơ thuế KHÔNG xác nhận quầy còn bán lẻ. Hồ sơ: https://tracuunhanh.vn/1702222774-ho-kinh-doanh-van-phong-pham-hoa-kieng-phu-my","source_key":"gmap:ChIJC23cYgDdCTEROpBh34VjX0c","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20-%20hoa%20ki%E1%BB%83ng%20Ph%C3%BA%20M%E1%BB%B9%20Huy%E1%BB%87n%20Giang%20Th%C3%A0nh&query_place_id=ChIJC23cYgDdCTEROpBh34VjX0c"},{"province":"Kiên Giang","district":"Huyện Giang Thành","name":"Cửa hàng văn phòng phẩm Giang Thành","address_line":"GJ9P+558, khu vực Khánh Hòa, huyện Giang Thành, Kiên Giang cũ (địa chỉ Maps mới: An Giang)","category":"van_phong_pham","phone":null,"tax_code":null,"verification_note":"Điểm Maps mang tên văn phòng phẩm, phân loại tạp hóa; CHƯA chứng minh thực tế có bán VPP, cần Sales khảo sát.","source_key":"gmap:ChIJ-zStGsHDCTER9aRsG_SmtvU","source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20v%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Giang%20Th%C3%A0nh%20Huy%E1%BB%87n%20Giang%20Th%C3%A0nh&query_place_id=ChIJ-zStGsHDCTER9aRsG_SmtvU"},{"province":"Sóc Trăng","district":"Huyện Cù Lao Dung","name":"Photocopy - Văn phòng phẩm Linh Châu","address_line":"Đường huyện 8 (ĐH8), plus code H7C3+R4J, huyện Cù Lao Dung, Sóc Trăng cũ","category":"van_phong_pham","phone":"0989904980","tax_code":null,"verification_note":"Maps ghi dịch vụ photocopy kèm VPP, ĐH8, Cù Lao Dung; số điện thoại công khai. PHÂN LOẠI tiệm photo kèm VPP, không tự coi là nhà sách; chưa đến điểm.","source_key":"gmap:ChIJZXoC-4kzoDER8qtmqIAdYdo","source_url":"https://www.google.com/maps/search/?api=1&query=Photocopy%20-%20V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Linh%20Ch%C3%A2u%20Huy%E1%BB%87n%20C%C3%B9%20Lao%20Dung&query_place_id=ChIJZXoC-4kzoDER8qtmqIAdYdo"},{"province":"Sóc Trăng","district":"Huyện Cù Lao Dung","name":"Văn phòng phẩm Minh Vy","address_line":"Plus code J5WG+2HC, huyện Cù Lao Dung, Sóc Trăng cũ (nay Cần Thơ)","category":"van_phong_pham","phone":null,"tax_code":null,"verification_note":"Maps có điểm tên VPP Minh Vy ở Cù Lao Dung nhưng không có địa chỉ số nhà và điện thoại; cần Sales xác minh ngành hàng và cửa hàng.","source_key":"gmap:ChIJ_e99egA3oDERGdymg_DX4tE","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Minh%20Vy%20Huy%E1%BB%87n%20C%C3%B9%20Lao%20Dung&query_place_id=ChIJ_e99egA3oDERGdymg_DX4tE"},{"province":"Hậu Giang","district":"Huyện Vị Thủy","name":"Hiệu sách Minh Trí","address_line":"Khu vực huyện Vị Thủy, Hậu Giang cũ (Maps hiện ghi Cần Thơ); chưa có số nhà","category":"nha_sach","phone":null,"tax_code":null,"verification_note":"Maps xác định tên hiệu sách và khu vực Vị Thủy, chưa có số nhà/điện thoại; KHÔNG phải NS Thích đang là khách chính.","source_key":"gmap:ChIJVzK9MxrvoDERCZDrUJeJCzI","source_url":"https://www.google.com/maps/search/?api=1&query=Hi%E1%BB%87u%20s%C3%A1ch%20Minh%20Tr%C3%AD%20Huy%E1%BB%87n%20V%E1%BB%8B%20Th%E1%BB%A7y&query_place_id=ChIJVzK9MxrvoDERCZDrUJeJCzI"},{"province":"Hậu Giang","district":"Huyện Vị Thủy","name":"Hiệu sách Quỳnh Như","address_line":"Khu vực huyện Vị Thủy, Hậu Giang cũ (Maps hiện ghi Cần Thơ); chưa có số nhà","category":"nha_sach","phone":null,"tax_code":null,"verification_note":"Maps có điểm mang tên Hiệu sách Quỳnh Như ở Vị Thủy, chưa có số nhà/điện thoại; cần khảo sát không nhầm NS Thích.","source_key":"gmap:ChIJ18IjNBrvoDERUG0_BJHLNwc","source_url":"https://www.google.com/maps/search/?api=1&query=Hi%E1%BB%87u%20s%C3%A1ch%20Qu%E1%BB%B3nh%20Nh%C6%B0%20Huy%E1%BB%87n%20V%E1%BB%8B%20Th%E1%BB%A7y&query_place_id=ChIJ18IjNBrvoDERUG0_BJHLNwc"},{"province":"Bạc Liêu","district":"Huyện Đông Hải","name":"Cửa hàng văn phòng phẩm Huy","address_line":"92 Ngọc Điền, Gành Hào, huyện Đông Hải, Bạc Liêu cũ (Maps hiện ghi Cà Mau)","category":"van_phong_pham","phone":"02913845295","tax_code":null,"verification_note":"Maps ghi cửa hàng VPP tại 92 Ngọc Điền, Gành Hào, có điện thoại; cần Sales xác minh còn hoạt động và bán học phẩm.","source_key":"gmap:ChIJqbcvMeVnoTERmXjTWjcL_Qs","source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20v%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Huy%20Huy%E1%BB%87n%20%C4%90%C3%B4ng%20H%E1%BA%A3i&query_place_id=ChIJqbcvMeVnoTERmXjTWjcL_Qs"}]'::jsonb) AS x(province text,district text,name text,address_line text,category text,phone text,tax_code text,source_key text,source_url text,verification_note text)
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
    'Vòng 2 P0 nghiên cứu nguồn công khai 21/11/2026; CHƯA GHÉ; GPS chưa xác minh; chưa chứng minh cửa hàng đang hoạt động. '
       || s.verification_note || ' Nguồn bản đồ: ' || s.source_url,
    'new', 'manual', s.source_key, s.source_url,
    '2026-11-21-old13-round02-p0-gaps-150'
  FROM src s
  WHERE (s.province,s.district) IN (
    ('Kiên Giang','Huyện Giang Thành'),('Sóc Trăng','Huyện Cù Lao Dung'),
    ('Hậu Giang','Huyện Vị Thủy'),('Bạc Liêu','Huyện Đông Hải')
  )
    AND s.source_url LIKE 'https://%'
    AND NOT EXISTS (
      SELECT 1 FROM public.customers c
      WHERE c.province=s.province AND c.district=s.district
        AND (
          lower(trim(c.name))=lower(trim(s.name))
          OR (s.phone IS NOT NULL AND c.phone IS NOT NULL
              AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
        )
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.field_prospects p
      WHERE p.province=s.province AND p.district=s.district
        AND (
          p.research_source_key=s.source_key
          OR (lower(trim(p.name))=lower(trim(s.name)) AND lower(trim(p.address_line))=lower(trim(s.address_line)))
          OR (s.phone IS NOT NULL AND p.phone IS NOT NULL
              AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
          OR (s.tax_code IS NOT NULL AND p.tax_code IS NOT NULL AND p.tax_code=s.tax_code)
        )
    )
  ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
  RETURNING province,district,category,phone
)
SELECT province,district,count(*)::int AS inserted,
       count(*) FILTER(WHERE category='nha_sach')::int AS bookstores
FROM ins GROUP BY province,district ORDER BY province,district;
