-- 160 | 2026-11-22 | ROUND 2: Hậu Giang old, exactly 3 old districts: Huyện Châu Thành A, Huyện Châu Thành, Thị xã Long Mỹ.
-- 4 ONLINE prospects only; unvisited, unverifiable current operation; never write customer/GPS/check-in/selling.
-- Trường Tín: Maps provider says Châu Thành A, but historical xã Đông Thạnh belongs HUYỆN CHÂU THÀNH; old administrative law controls.
-- Sao Mai at Chợ Bảy Ngàn is already a primary customer, do not duplicate as prospect.
-- Do not duplicate Nhà sách Ngọc Tiến, Minh Thư, Song Di, Nhà sách Long Mỹ, Thể Minh, existing source keys.
WITH src AS (
 SELECT x.*,md5('fbmn:old13:round02:160:'||x.source_key) dg
 FROM jsonb_to_recordset('[{"province":"Hậu Giang","district":"Huyện Châu Thành A","name":"Nhà sách Anh Thư","address_line":"Quốc lộ 1A, thị trấn Cái Tắc cũ, huyện Châu Thành A, Hậu Giang","category":"nha_sach","phone":"0985228303","tax_code":null,"source_key":"sotayvang:nhasach-anhthu:caitac-chau-thanh-a","source_url":"https://sotayvang.com/nha-sach-anh-thu-thi-tran-cai-tac/","verification_note":"Sổ Tay Vàng ghi tên Nhà sách Anh Thư, QL1A TT Cái Tắc, số 0985228303; dữ liệu điểm đăng cũ, chưa xác minh còn hoạt động trong năm 2026. Thị trấn Cái Tắc thuộc huyện Châu Thành A cũ theo Nghị định 34/2007/NĐ-CP: https://chinhphu.vn/default.aspx?docid=20997&pageid=27160 ."},{"province":"Hậu Giang","district":"Huyện Châu Thành A","name":"Cửa hàng Văn phòng phẩm Thái Ngân","address_line":"38 Quốc lộ 61, ấp Thị Tứ, thị trấn Rạch Gòi cũ, huyện Châu Thành A, Hậu Giang","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"contactpage:vn-vi422679:vpp-thai-ngan-rach-goi","source_url":"https://vn-vi422679-cu-a-ha-ng-va-n-pho-ng-pha-m-tha-i-nga-n.contact.page/galleries","verification_note":"Danh bạ Contact.page nêu tên VPP Thái Ngân, 38 QL61, ấp Thị Tứ, TT Rạch Gòi, phân loại VPP và thiệp cưới/in ấn. SĐT trên trang bị che bớt, không ghi số suy đoán. Chưa xác minh trực tiếp quầy bán lẻ và còn hoạt động 2026. Rạch Gòi thuộc Châu Thành A cũ: https://chinhphu.vn/default.aspx?docid=20997&pageid=27160 ."},{"province":"Hậu Giang","district":"Huyện Châu Thành","name":"Văn phòng phẩm Trường Tín","address_line":"WPMF+C9H, đường Nguyễn Văn Quang, xã Đông Thạnh cũ, huyện Châu Thành, Hậu Giang","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJ8yU0X6-LoDERHZ-VrrQHv_w","source_url":"https://www.google.com/maps/search/?api=1&query=Van%20phong%20pham%20Truong%20Tin%20Dong%20Thanh%20Hau%20Giang&query_place_id=ChIJ8yU0X6-LoDERHZ-VrrQHv_w","verification_note":"Google Maps gọi Văn phòng phẩm Trường Tín tại WPMF+C9H, Nguyễn Văn Quang, khu Đông Thạnh; Maps/business provider GẮN SAI Châu Thành A. Xã Đông Thạnh thuộc HUYỆN CHÂU THÀNH Hậu Giang cũ theo Nghị định 06/2004/NĐ-CP: https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Nghi-dinh-06-2004-ND-CP-dieu-chinh-dia-gioi-hanh-chinh-xa-thuoc-huyen-Chau-Thanh-A-thuoc-tinh-Hau-Giang-52395.aspx . Cần Sales xác minh tên, đường, địa giới thực địa; chưa có số điện thoại hoặc chứng cứ hàng bán thực."},{"province":"Hậu Giang","district":"Thị xã Long Mỹ","name":"Văn phòng phẩm Móm","address_line":"1 đường Chiêm Thành Tấn, khu phường Thuận An cũ, thị xã Long Mỹ, Hậu Giang","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJjyIHLQDloDERNfsifd2KxFE","source_url":"https://www.google.com/maps/search/?api=1&query=Van%20phong%20pham%20Mom%20Chiem%20Thanh%20Tan%20Long%20My&query_place_id=ChIJjyIHLQDloDERNfsifd2KxFE","verification_note":"Google Maps liệt kê Văn phòng phẩm Móm, Stationery store, số 1 Chiêm Thành Tấn; tuyến Chiêm Thành Tấn ở phường Long Mỹ mới, trước là phường Thuận An THỊ XÃ Long Mỹ cũ, không phải huyện Long Mỹ: https://infodoanhnghiep.com/Can-Tho/Phuong-Long-My/ . Chưa có SĐT hoặc xác minh hoạt động năm 2026."}]'::jsonb)
 x(province text,district text,name text,address_line text,category text,phone text,tax_code text,source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects
 (id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,s.province,s.district,s.category,s.phone,s.tax_code,
 'Hậu Giang cũ vòng 2 / 3 huyện / 22/11/2026; CHƯA GHÉ; chưa xác minh GPS, tình trạng hoạt động, nguồn mặt hàng bán thực. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-22-old13-round02-haugiang-3districts-160'
 FROM src s
 WHERE s.province='Hậu Giang' AND s.district IN ('Huyện Châu Thành A','Huyện Châu Thành','Thị xã Long Mỹ') AND s.source_url LIKE 'https://%'
 AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE
   (c.province=s.province AND c.district=s.district AND lower(trim(c.name))=lower(trim(s.name)))
   OR (s.phone IS NOT NULL AND c.phone IS NOT NULL AND regexp_replace(c.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g')))
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE p.research_source_key=s.source_key
   OR (p.province=s.province AND p.district=s.district AND lower(trim(p.name))=lower(trim(s.name)))
   OR (s.phone IS NOT NULL AND p.phone IS NOT NULL AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(s.phone,'[^0-9]','','g'))
   OR (s.tax_code IS NOT NULL AND p.tax_code=s.tax_code))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING province,district,name,category
)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
