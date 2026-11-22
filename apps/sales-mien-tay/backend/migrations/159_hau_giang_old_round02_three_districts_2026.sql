-- Migration 159 | 2026-11-22 | Hậu Giang cũ round 2, 3 districts only: Huyện Long Mỹ, Huyện Vị Thủy, Huyện Phụng Hiệp.
-- Huyện Long Mỹ: 0 qualified physical book/stationery candidate; DO NOT conflate with Thị xã Long Mỹ (Nhà sách Long Mỹ at 142K 30/4).
-- Four public map-listed online RESEARCH prospects in the other two districts, unvisited and NOT verified operating in 2026.
-- Deliberately exclude Sáu Nên (77 QL61, Kinh Cùng) because map place at that address is titled Hương Giang; name mismatch awaiting call.
-- No customers, GPS, actual visits, selling status or verified location created.
WITH src AS (
 SELECT x.*,md5('fbmn:old13:round02:159:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"province":"Hậu Giang","district":"Huyện Vị Thủy","name":"Photo - VPP Phương Phương","address_line":"177 đường Nguyễn Tri Phương, khu vực Nàng Mau cũ, huyện Vị Thủy, Hậu Giang (nay Cần Thơ)","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJa4wGDwDvoDERYM6aK9UIS6A","source_url":"https://www.google.com/maps/search/?api=1&query=Photo%20VPP%20Phuong%20Phuong%20Vi%20Thuy&query_place_id=ChIJa4wGDwDvoDERYM6aK9UIS6A","verification_note":"Google Maps ghi Photo-VPP, xếp Stationery store tại 177 Nguyễn Tri Phương Vị Thủy. Hộ kinh doanh PHƯƠNG PHƯƠNG có đăng ký cũ tại ấp 3 TT Nàng Mau, ngành bán lẻ sách báo VPP và từng trúng thầu in ấn/phô tô, nhưng chưa xác nhận hai hồ sơ là cùng địa điểm: https://dauthau.asia/businesslistings/detail/HO-KINH-DOANH-PHUONG-PHUONG-158349/ . Không dùng hộ kinh doanh làm GPS xác minh, gọi/ghé thực tế."},{"province":"Hậu Giang","district":"Huyện Vị Thủy","name":"Văn phòng phẩm Sáu Cáo","address_line":"Đường Lê Hồng Phong, khu vực Vị Thủy cũ, huyện Vị Thủy, Hậu Giang (nay Cần Thơ)","category":"van_phong_pham","phone":"0969913698","tax_code":null,"source_key":"gmap:ChIJVS9aCRjvoDERybCFNONbDqM","source_url":"https://www.google.com/maps/search/?api=1&query=Van%20Phong%20Pham%20Sau%20Cao%20Vi%20Thuy&query_place_id=ChIJVS9aCRjvoDERybCFNONbDqM","verification_note":"Google Maps liệt kê VPP SÁU CÁO trên đường Lê Hồng Phong Vị Thủy, danh mục School supply store, có số điện thoại công khai. Cần xác minh vị trí xã cũ chính xác và cửa hàng đang hoạt động trước khi Sales ghé."},{"province":"Hậu Giang","district":"Huyện Phụng Hiệp","name":"Văn phòng phẩm Vân Duyên","address_line":"96 Quốc lộ 61, thị trấn Kinh Cùng cũ, huyện Phụng Hiệp, Hậu Giang","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJ31E9w9HzoDERrbOFUqXbKI4","source_url":"https://www.google.com/maps/search/?api=1&query=Van%20Phong%20Pham%20Van%20Duyen%20Kinh%20Cung&query_place_id=ChIJ31E9w9HzoDERrbOFUqXbKI4","verification_note":"Google Maps niêm yết tên VPP Vân Duyên tại 96 QL61, TT Kinh Cùng; chưa công khai danh mục hàng/số điện thoại/ảnh xác minh hoạt động. TT Kinh Cùng thuộc huyện Phụng Hiệp cũ theo tài liệu địa giới: https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/De-an-01-DA-UBND-2024-thanh-lap-thi-tran-Tan-Long-thuoc-huyen-Phung-Hiep-Hau-Giang-620152.aspx ."},{"province":"Hậu Giang","district":"Huyện Phụng Hiệp","name":"Cửa hàng văn phòng phẩm Việt Chương","address_line":"391 Quốc lộ 61, ấp Tân Phú, xã Tân Bình cũ, huyện Phụng Hiệp, Hậu Giang (nay Cần Thơ)","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJd4fPriXzoDEROQxT2gCsHQA","source_url":"https://www.google.com/maps/search/?api=1&query=Van%20Phong%20Pham%20Viet%20Chuong%20Tan%20Binh&query_place_id=ChIJd4fPriXzoDEROQxT2gCsHQA","verification_note":"Google Maps ghi Stationery store tại 391 QL61, ấp Tân Phú, xã Tân Bình cũ, Phụng Hiệp; chưa có điện thoại/danh mục sản phẩm được xác minh thực tế. Xã Tân Bình thuộc Phụng Hiệp trước 2025: https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/De-an-01-DA-UBND-2024-thanh-lap-thi-tran-Tan-Long-thuoc-huyen-Phung-Hiep-Hau-Giang-620152.aspx ."}]'::jsonb)
 x(province text,district text,name text,address_line text,category text,phone text,tax_code text,source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects (
  id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,
  status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
  NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,s.province,s.district,s.category,s.phone,s.tax_code,
  'Hậu Giang cũ / vòng 2 / 3 huyện / 22-11-2026; CHƯA GHÉ; chưa xác minh GPS, cửa hàng hiện hữu hoặc mặt hàng bán thực tế. '||s.verification_note||' Nguồn: '||s.source_url,
  'new','manual',s.source_key,s.source_url,'2026-11-22-old13-round02-haugiang-3districts-159'
 FROM src s
 WHERE s.province='Hậu Giang' AND s.district IN ('Huyện Long Mỹ','Huyện Vị Thủy','Huyện Phụng Hiệp')
  AND s.source_url LIKE 'https://%'
  AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE
    (c.province=s.province AND c.district=s.district AND lower(trim(c.name))=lower(trim(s.name)))
    OR (s.phone IS NOT NULL AND c.phone IS NOT NULL AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
  AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE
    p.research_source_key=s.source_key
    OR (p.province=s.province AND p.district=s.district AND lower(trim(p.name))=lower(trim(s.name)))
    OR (s.phone IS NOT NULL AND p.phone IS NOT NULL AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
    OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING province,district,name,category)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
