-- 186 | 2026-11-22 | TP.HCM cũ, Quận 6 đợt 3: phường Bình Tây & Bình Tiên.
-- 8 researched stationery/mixed retail storefront leads; name/address/shop-category evidence from
-- business listings, current Maps metadata, named directories and the shop's recruitment notice.
-- Keep old districts for ACL, new wards for display. Exclude Bình Dương/BR-VT origins.
-- Excluded: Tập Bút Cầu (manufacturer), Lý Thiên Lộc / VPP GOTEK (not proved walk-in point),
-- VPP 201 Gia Phú (current Maps grocery), băng keo-only, overlapping 23 Tháp Mười VPP Nga,
-- and 805 Hồng Bàng / 146 Minh Phụng existing bookshops.
-- Especially VPP Vàng Đào and Quỳnh Anh are older directory-only listings; UNVERIFIED trading.
-- Never set GPS, visit markers, converted customer status or claim in-person verification.
WITH candidates AS (
  SELECT * FROM jsonb_to_recordset('[{"n":"Nhà Của Chúi - Đồ chơi và văn phòng phẩm","street":"131-133 Ngô Nhân Tịnh","ward":"Bình Tây","category":"van_phong_pham","phone":"0933182222","pid":"ChIJMSyX1FMvdTERFiRrsR7K2hs","source":"https://www.vieclamtot.com/viec-lam-quan-6-tp-ho-chi-minh/135736131.htm","note":"Tin tuyển nhân viên tại cửa hàng 131-133 Ngô Nhân Tịnh P2 cũ ghi cửa hàng bán văn phòng phẩm, đồ chơi và dụng cụ thể thao; Google Maps gắn ngành Stationery store.","old":"Phường 2","maps":"https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20C%E1%BB%A7a%20Ch%C3%BAi%20-%20%C4%90%E1%BB%93%20ch%C6%A1i%20v%C3%A0%20v%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20131-133%20Ng%C3%B4%20Nh%C3%A2n%20T%E1%BB%8Bnh%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJMSyX1FMvdTERFiRrsR7K2hs","key":"gmaps:ChIJMSyX1FMvdTERFiRrsR7K2hs","research_source":"https://www.vieclamtot.com/viec-lam-quan-6-tp-ho-chi-minh/135736131.htm"},{"n":"Văn phòng phẩm Kim Quyền Vinh","street":"181 Phan Văn Khỏe","ward":"Bình Tây","category":"van_phong_pham","phone":"0938441911","pid":"ChIJy_Qxgd8vdTERwtUwHZ5Bdws","source":null,"note":"Hồ sơ điểm bán trên bản đồ phân loại stationery store tại 181 Phan Văn Khỏe, chưa có review người mua và catalog xác nhận từng SKU.","old":null,"maps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Kim%20Quy%E1%BB%81n%20Vinh%20181%20Phan%20V%C4%83n%20Kh%E1%BB%8Fe%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJy_Qxgd8vdTERwtUwHZ5Bdws","key":"gmaps:ChIJy_Qxgd8vdTERwtUwHZ5Bdws","research_source":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Kim%20Quy%E1%BB%81n%20Vinh%20181%20Phan%20V%C4%83n%20Kh%E1%BB%8Fe%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJy_Qxgd8vdTERwtUwHZ5Bdws"},{"n":"Wawi stationery","street":"47/4 Bửu Đình","ward":"Bình Tây","category":"van_phong_pham","phone":"0908043644","pid":"ChIJ_7HSHPwvdTERLCx4QhGoa1w","source":"https://sites.google.com/view/wawi-stationery","note":"Bản đồ phân loại Office supply store, nhiều đánh giá; sản phẩm có quà tặng/decor, chưa xác nhận bán lẻ trực tiếp tại số nhà này.","old":null,"maps":"https://www.google.com/maps/search/?api=1&query=Wawi%20stationery%2047%2F4%20B%E1%BB%ADu%20%C4%90%C3%ACnh%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJ_7HSHPwvdTERLCx4QhGoa1w","key":"gmaps:ChIJ_7HSHPwvdTERLCx4QhGoa1w","research_source":"https://sites.google.com/view/wawi-stationery"},{"n":"Cửa hàng VPP 175","street":"175 Cao Văn Lầu","ward":"Bình Tây","category":"van_phong_pham","phone":null,"pid":"ChIJc1RLdooudTERtFHg2-Ipagg","source":"https://dvn.com.vn/cua-hang-van-phong-pham-gan-day-1647649772/","note":"Nguồn danh sách cửa hàng và hồ sơ bản đồ đều ghi VPP 175 Cao Văn Lầu P2 cũ; không có điện thoại niêm yết.","old":"Phường 2","maps":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20VPP%20175%20175%20Cao%20V%C4%83n%20L%E1%BA%A7u%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJc1RLdooudTERtFHg2-Ipagg","key":"gmaps:ChIJc1RLdooudTERtFHg2-Ipagg","research_source":"https://dvn.com.vn/cua-hang-van-phong-pham-gan-day-1647649772/"},{"n":"Văn phòng phẩm Thiên Hưng","street":"751/5H Hồng Bàng","ward":"Bình Tây","category":"van_phong_pham","phone":null,"pid":"ChIJSSTsJwAvdTERPKgQXbEYyAM","source":null,"note":"Bản đồ có tên Văn phòng phẩm Thiên Hưng 751/5H Hồng Bàng, phân loại Book Shop; chưa có nguồn riêng về tình trạng hoạt động và bán lẻ.","old":null,"maps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Thi%C3%AAn%20H%C6%B0ng%20751%2F5H%20H%E1%BB%93ng%20B%C3%A0ng%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJSSTsJwAvdTERPKgQXbEYyAM","key":"gmaps:ChIJSSTsJwAvdTERPKgQXbEYyAM","research_source":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Thi%C3%AAn%20H%C6%B0ng%20751%2F5H%20H%E1%BB%93ng%20B%C3%A0ng%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJSSTsJwAvdTERPKgQXbEYyAM"},{"n":"Cửa hàng VPP Vàng Đào","street":"98 Tháp Mười","ward":"Bình Tây","category":"van_phong_pham","phone":"02839604477","pid":null,"source":"https://www.yellowpages.vn/cls/224510/van-phong-pham-cong-ty-van-phong-pham.html?page=25","note":"Trang Vàng và danh bạ 2017 đều ghi cửa hàng VPP Vàng Đào, 98 Tháp Mười P2 cũ, 02839604477; hồ sơ lâu không cập nhật, Sales bắt buộc kiểm tra bảng hiệu/còn kinh doanh.","old":"Phường 2","maps":null,"key":"directory:hcm:q6:btay:98-thap-muoi:vpp-vang-dao","research_source":"https://www.yellowpages.vn/cls/224510/van-phong-pham-cong-ty-van-phong-pham.html?page=25"},{"n":"Shop Gia Hân Q6","street":"508 Gia Phú","ward":"Bình Tiên","category":"van_phong_pham","phone":"0797601647","pid":"ChIJ43n2JagvdTERQonPq8Rmbyw","source":null,"note":"Google Maps phân loại Office supply store 508 Gia Phú, 1 đánh giá khách về giá; listing còn ghi mã P3Q6 cũ nhưng bản đồ ghi Bình Tiên, cần đối chiếu hành chính thực địa.","old":null,"maps":"https://www.google.com/maps/search/?api=1&query=Shop%20Gia%20H%C3%A2n%20Q6%20508%20Gia%20Ph%C3%BA%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJ43n2JagvdTERQonPq8Rmbyw","key":"gmaps:ChIJ43n2JagvdTERQonPq8Rmbyw","research_source":"https://www.google.com/maps/search/?api=1&query=Shop%20Gia%20H%C3%A2n%20Q6%20508%20Gia%20Ph%C3%BA%20Qu%E1%BA%ADn%206%20Th%C3%A0nh%20ph%E1%BB%91%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJ43n2JagvdTERQonPq8Rmbyw"},{"n":"Cửa hàng VPP Quỳnh Anh","street":"119 Văn Thân","ward":"Bình Tiên","category":"van_phong_pham","phone":null,"pid":null,"source":"https://tim-dia-diem.blogspot.com/2017/08/cua-hang-van-phong-pham-o-tphcm-quan-6.html","note":"Danh bạ 2017 ghi cửa hàng VPP Quỳnh Anh 119 Văn Thân P8 cũ; không có Place ID, điện thoại hoặc cập nhật hoạt động gần đây; cần xác minh thực địa trước khi Sales tiếp cận.","old":"Phường 8","maps":null,"key":"directory:hcm:q6:btien:119-van-than:vpp-quynh-anh","research_source":"https://tim-dia-diem.blogspot.com/2017/08/cua-hang-van-phong-pham-o-tphcm-quan-6.html"}]'::jsonb)
  AS c(n text,street text,ward text,category text,phone text,pid text,source text,note text,old text,maps text,key text,research_source text)
), vetted AS (
 SELECT c.*
 FROM candidates c
 JOIN public.sales_hcm_old_wards w
 ON w.ward_new=c.ward AND w.legacy_district='Quận 6' AND w.province='TP Hồ Chí Minh' AND w.active
 WHERE c.ward IN ('Bình Tây','Bình Tiên')
   AND c.category IN ('nha_sach','van_phong_pham')
   AND c.research_source LIKE 'https://%'
   AND NOT EXISTS (
     SELECT 1 FROM public.field_prospects p
     WHERE p.research_source_key=c.key
       OR (c.pid IS NOT NULL AND p.google_place_id=c.pid)
       OR (c.phone IS NOT NULL AND p.phone IS NOT NULL AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
       OR (p.province='TP Hồ Chí Minh' AND p.district='Quận 6'
           AND (lower(btrim(p.name))=lower(btrim(c.n))
           OR lower(btrim(split_part(p.address_line,', phường',1)))=lower(btrim(c.street))
           OR lower(p.address_line) LIKE lower(c.street||',%')))
   )
   AND NOT EXISTS (
     SELECT 1 FROM public.customers k
     WHERE (c.phone IS NOT NULL AND k.phone IS NOT NULL AND regexp_replace(k.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
       OR (k.province='TP Hồ Chí Minh' AND k.district='Quận 6'
            AND (lower(btrim(k.name))=lower(btrim(c.n)) OR lower(k.address_line) LIKE lower(c.street||',%')))
   )
), inserted AS (
 INSERT INTO public.field_prospects
 (owner_sub,name,address_line,province,district,category,phone,note,status,source_kind,
 research_source_key,research_source_url,research_batch,ward_new,address_legacy,google_maps_url,google_place_id)
 SELECT 'ef943de4-18f7-49ef-8340-eefb18855534',v.n,
 v.street||', phường '||v.ward||', TP. Hồ Chí Minh',
 'TP Hồ Chí Minh','Quận 6',v.category,v.phone,
 'Rà online ngày 22/11/2026; '||v.note||
 ' CHƯA GHÉ - CHƯA XÁC MINH hoạt động, quầy bán, bảng hiệu và GPS. Listing/Maps không phải check-in Sales. Nguồn: '||v.research_source,
 'new','manual',v.key,v.research_source,'2026-11-22-hcm-old-q6-round3-186',
 v.ward,v.street||', '||coalesce(v.old||', ','')||'Quận 6 cũ, TP.HCM cũ',
 v.maps,v.pid
 FROM vetted v
 ON CONFLICT DO NOTHING
 RETURNING name,ward_new,category
)
SELECT ward_new,category,count(*)::int AS inserted,string_agg(name,'; ' ORDER BY name) AS shops
FROM inserted GROUP BY ward_new,category ORDER BY ward_new,category;