-- 162 | 2026-11-22 | Tiền Giang OLD, focused scope ONLY 2 former cities: Thành phố Mỹ Tho, Thành phố Gò Công.
-- Three research-only bookshop/stationery candidates, with concrete shop names/addresses and public contact/source.
-- VPP Quang Chính website advertises current 676 Ap Bac and older 351A Ap Bac: SAME store; only ONE prospect.
-- DO NOT add Lê Phương (customer NPP Lê Phương, Nam Ky Khoi Nghia), Nhật Minh (customer NS-Nhật Minh, Go Cong), or existing FAHASA/Hung Vuong/LABOCO.
-- NO GPS/visit/verification/selling/customer mutation, and don't infer 2026 operational status from public listings.
WITH src AS (
 SELECT x.*,md5('fbmn:old13:round02:162:'||x.source_key) AS dg
 FROM jsonb_to_recordset('[{"province":"Tiền Giang","district":"Thành phố Mỹ Tho","name":"Văn phòng phẩm Quang Chính","address_line":"676 đường Ấp Bắc, khu vực TP Mỹ Tho cũ, nay phường Trung An, tỉnh Đồng Tháp (cơ sở từng ghi 351A Ấp Bắc, phường 10 cũ)","category":"van_phong_pham","phone":"0971041708","tax_code":null,"source_key":"gmap:ChIJuQFWdQCwCjERydbe-ftCh7M","source_url":"https://vanphongphamquangchinh.com/lien-he/","verification_note":"Website chính thức ghi địa chỉ mới 676 Ấp Bắc, số 0971041708 và 0978411307, giới thiệu bán sỉ và lẻ văn phòng phẩm, dụng cụ học sinh, sách; nguồn Google Maps là Nhà Sách Quang Chính (Stationery store), place id ChIJuQFWdQCwCjERydbe-ftCh7M. Trang chính thức ghi địa chỉ cũ 351A Ấp Bắc, phường 10 (không tạo hai lead). Chưa ghé, chưa xác minh GPS/tình trạng bán hàng thực tế."},{"province":"Tiền Giang","district":"Thành phố Mỹ Tho","name":"Nhà sách Gioan 23","address_line":"32 đường Hùng Vương, phường 7 cũ, thành phố Mỹ Tho, Tiền Giang","category":"nha_sach","phone":"02733976123","tax_code":null,"source_key":"vietbiz:gioan23:32-hungvuong-mytho","source_url":"https://www.viet-biz.com/gioan-bookstore-0273-3976-123","verification_note":"Viet-Biz ghi Gioan 23 Bookstore tại 32 Hùng Vương, phường 7 TP Mỹ Tho cũ, số 02733976123, ngành Book stores/newsstands; Sổ Tay Vàng cùng tên/số/địa chỉ https://sotayvang.com/nha-sach-gioan-23-phuong-7/ . Nguồn danh bạ có thể cũ; chưa xác minh cửa hàng còn hoạt động trong tháng 11/2026."},{"province":"Tiền Giang","district":"Thành phố Gò Công","name":"Nhà sách Minh Anh GC","address_line":"26 đường Thủ Khoa Huân, khu vực Long Thuận, thành phố Gò Công cũ, Tiền Giang (nay Đồng Tháp)","category":"nha_sach","phone":"0369147909","tax_code":null,"source_key":"gmap:ChIJO_kuXwRPdTER7UiYn4fyI0g","source_url":"https://www.google.com/maps/search/?api=1&query=Nha%20sach%20Minh%20Anh%20GC%20Go%20Cong&query_place_id=ChIJO_kuXwRPdTER7UiYn4fyI0g","verification_note":"Google Maps liệt kê Nhà sách Minh Anh GC, danh mục Stationery store tại 26 Thủ Khoa Huân, khu Long Thuận, Gò Công; số 0369147909. Danh bạ HappyNew.Day cũng ghi tên và số 26 Thủ Khoa Huân. Chưa có phản hồi xác minh mặt hàng/giờ mở cửa và thực tế hoạt động trong tháng 11/2026, Sales cần gọi."}]'::jsonb) x (
  province text,district text,name text,address_line text,category text,phone text,tax_code text,
  source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects
  (id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,s.province,s.district,s.category,s.phone,s.tax_code,
 'Tiền Giang cũ / Mỹ Tho và Gò Công / online 22-11-2026; CHƯA GHÉ; không có GPS hoặc xác minh kinh doanh trực tiếp. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-22-old13-round02-tiengiang-mytho-gocong-162'
 FROM src s
 WHERE s.province='Tiền Giang' AND s.district IN ('Thành phố Mỹ Tho','Thành phố Gò Công') AND s.source_url LIKE 'https://%'
 AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE
 (c.province=s.province AND c.district=s.district AND lower(trim(c.name))=lower(trim(s.name)))
 OR (s.phone IS NOT NULL AND c.phone IS NOT NULL AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE
 p.research_source_key=s.source_key
 OR (p.province=s.province AND p.district=s.district AND lower(trim(p.name))=lower(trim(s.name)))
 OR (s.phone IS NOT NULL AND p.phone IS NOT NULL AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
 OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING province,district,name,category
)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
