-- 185 | 2026-11-22 | TP.HCM cũ, Quận 6, đợt 2: Bình Phú & Phú Lâm.
-- Chỉ lead nghiên cứu, không phải khách hàng đã xác minh / ghé thực địa.
-- Cảnh báo: 807 Hậu Giang nguồn P11/P12 mâu thuẫn; ưu tiên địa giới Maps Bình Phú nhưng đánh dấu cần đối chiếu.
-- Cảnh báo: 14 Đường 11 có hai tên Tiến Hưng và Hưng Hưng Thịnh, chỉ chèn một địa chỉ.
-- Không chèn 185 Kinh Dương Vương (đã có nhà sách Thanh Tuyền); loại 820 Hậu Giang (xung đột ngành cửa hàng patin),
-- Mọt Books (chưa có bằng chứng quầy walk-in), Nhất Thiên Tuấn / Kim Kim Thanh (chỉ hồ sơ công ty).
WITH candidates AS (
 SELECT * FROM jsonb_to_recordset('[{"name":"Nhà sách Dũ Thảo","street":"807 Hậu Giang","ward":"Bình Phú","category":"nha_sach","phone":"0916277718","old_ward":"Phường 11","pid":"ChIJUz1mAuovdTERTcWAYHilVvc","source":"https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-d%C5%A9-th%E1%BA%A3o-091-627-77-18","note":"VietBiz, Sổ Tay Vàng và danh bạ contact.page ghi P11 cũ; Địa điểm 247 ghi P12 cũ (mâu thuẫn). Hồ sơ Maps hiện hành định vị phường Bình Phú; chưa xác minh ranh thực địa. Không tạo thêm điểm theo địa chỉ phường 12.","maps":"https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20s%C3%A1ch%20D%C5%A9%20Th%E1%BA%A3o%20807%20H%E1%BA%ADu%20Giang%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJUz1mAuovdTERTcWAYHilVvc","key":"gmaps:ChIJUz1mAuovdTERTcWAYHilVvc","research_source_url":"https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-d%C5%A9-th%E1%BA%A3o-091-627-77-18"},{"name":"Cửa hàng VPP 827 Hậu Giang (chưa rõ bảng hiệu)","street":"827 Hậu Giang","ward":"Bình Phú","category":"van_phong_pham","phone":"02838750555","old_ward":"Phường 11","pid":null,"source":"https://sotayvang.com/cua-hang-van-phong-pham-phuong-11/","note":"Sổ Tay Vàng ghi rõ điểm bán VPP tại 827 Hậu Giang P11 cũ, có số điện thoại nhưng không nêu tên bảng hiệu; tên dùng tạm theo số nhà, Sales cần xác minh và sửa bảng hiệu. Không đồng nhất với nhà sách Dũ Thảo 807.","maps":null,"key":"directory:hcm:q6:r2:vpp:827-hau-giang","research_source_url":"https://sotayvang.com/cua-hang-van-phong-pham-phuong-11/"},{"name":"Văn phòng phẩm Kim Ngoan","street":"240/83 Nguyễn Văn Luông","ward":"Bình Phú","category":"van_phong_pham","phone":"0907574173","old_ward":"Phường 11","pid":"ChIJn1khpAQvdTERyq1dDpCI6T0","source":null,"note":"Hồ sơ địa điểm Stationery store và số điện thoại tại hẻm 240/83 Nguyễn Văn Luông, P11 cũ. Chưa có đánh giá người mua, phải xác minh bảng hiệu và việc bán lẻ tại quầy.","maps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Kim%20Ngoan%20240%2F83%20Nguy%E1%BB%85n%20V%C4%83n%20Lu%C3%B4ng%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJn1khpAQvdTERyq1dDpCI6T0","key":"gmaps:ChIJn1khpAQvdTERyq1dDpCI6T0","research_source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Kim%20Ngoan%20240%2F83%20Nguy%E1%BB%85n%20V%C4%83n%20Lu%C3%B4ng%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJn1khpAQvdTERyq1dDpCI6T0"},{"name":"Yennie Shop","street":"Chung cư Starlight, 241/42 Nguyễn Văn Luông","ward":"Bình Phú","category":"van_phong_pham","phone":"0778127867","old_ward":"Phường 11 (cần đối chiếu)","pid":"ChIJWywhmq8vdTER6mPI7W_2k3M","source":null,"note":"Hồ sơ địa điểm Stationery store tại chung cư Starlight, địa chỉ 241/42 Nguyễn Văn Luông, phường Bình Phú. Chưa xác minh có quầy walk-in hay chỉ bán trong chung cư; cần gọi/xác nhận trước khi Sales ghé.","maps":"https://www.google.com/maps/search/?api=1&query=Yennie%20Shop%20Chung%20c%C6%B0%20Starlight%2C%20241%2F42%20Nguy%E1%BB%85n%20V%C4%83n%20Lu%C3%B4ng%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJWywhmq8vdTER6mPI7W_2k3M","key":"gmaps:ChIJWywhmq8vdTER6mPI7W_2k3M","research_source_url":"https://www.google.com/maps/search/?api=1&query=Yennie%20Shop%20Chung%20c%C6%B0%20Starlight%2C%20241%2F42%20Nguy%E1%BB%85n%20V%C4%83n%20Lu%C3%B4ng%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJWywhmq8vdTER6mPI7W_2k3M"},{"name":"Văn phòng phẩm Đề An","street":"15-17 Trần Văn Kiểu","ward":"Bình Phú","category":"van_phong_pham","phone":"0989041525","old_ward":"Phường 10","pid":"ChIJT0CCklgtdTER1J8cHJcA-0k","source":"https://www.vppdean.vn/lien-he/","note":"Website chính thức xác nhận ĐỊA CHỈ KINH DOANH 15-17 Trần Văn Kiểu Q6 (khác trụ sở chính ở Bình Tân), cung cấp giấy và VPP. Hồ sơ Maps xếp corporate office; chưa có chứng cứ khách walk-in, phải xác minh trước khi coi là cửa hàng bán lẻ.","maps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20%C4%90%E1%BB%81%20An%2015-17%20Tr%E1%BA%A7n%20V%C4%83n%20Ki%E1%BB%83u%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJT0CCklgtdTER1J8cHJcA-0k","key":"gmaps:ChIJT0CCklgtdTER1J8cHJcA-0k","research_source_url":"https://www.vppdean.vn/lien-he/"},{"name":"Văn phòng phẩm Lâm Phương","street":"556 Hậu Giang","ward":"Phú Lâm","category":"van_phong_pham","phone":"02837508147","old_ward":"Phường 12","pid":"ChIJF09q7n0udTERQJ7hpifRAiU","source":null,"note":"Hồ sơ địa điểm Stationery store tại 556 Hậu Giang, P12 cũ nay Phú Lâm; công ty VPP, chưa xác minh hoạt động bán lẻ tại quầy.","maps":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20L%C3%A2m%20Ph%C6%B0%C6%A1ng%20556%20H%E1%BA%ADu%20Giang%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJF09q7n0udTERQJ7hpifRAiU","key":"gmaps:ChIJF09q7n0udTERQJ7hpifRAiU","research_source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20L%C3%A2m%20Ph%C6%B0%C6%A1ng%20556%20H%E1%BA%ADu%20Giang%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJF09q7n0udTERQJ7hpifRAiU"},{"name":"Cửa hàng VPP Tiến Hưng (14 Đường số 11)","street":"14 Đường số 11, Cư xá Đài Ra Đa","ward":"Phú Lâm","category":"van_phong_pham","phone":"02822421188","old_ward":"Phường 13","pid":"ChIJtTugWiosdTERlvEcmj1c0ho","source":"https://vanphong-pham.com/van-phong-pham-quan-6/","note":"Hồ sơ Maps gọi Tiến Hưng, danh sách cửa hàng khác gọi Hưng Hưng Thịnh cùng số 14 Đường 11 Cư xá Đài Ra Đa, P13 cũ. Tính một địa điểm duy nhất; chưa xác minh bảng hiệu, số điện thoại và quầy bán thực địa.","maps":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20VPP%20Ti%E1%BA%BFn%20H%C6%B0ng%20(14%20%C4%90%C6%B0%E1%BB%9Dng%20s%E1%BB%91%2011)%2014%20%C4%90%C6%B0%E1%BB%9Dng%20s%E1%BB%91%2011%2C%20C%C6%B0%20x%C3%A1%20%C4%90%C3%A0i%20Ra%20%C4%90a%20Qu%E1%BA%ADn%206%20TP%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJtTugWiosdTERlvEcmj1c0ho","key":"gmaps:ChIJtTugWiosdTERlvEcmj1c0ho","research_source_url":"https://vanphong-pham.com/van-phong-pham-quan-6/"}]'::jsonb)
 AS c(name text,street text,ward text,category text,phone text,old_ward text,pid text,source text,note text,maps text,key text,research_source_url text)
), safe AS (
 SELECT c.*
 FROM candidates c
 JOIN public.sales_hcm_old_wards w
   ON w.province='TP Hồ Chí Minh' AND w.legacy_district='Quận 6' AND w.ward_new=c.ward AND w.active
 WHERE c.category IN ('nha_sach','van_phong_pham')
  AND c.research_source_url LIKE 'https://%'
  AND NOT EXISTS (
    SELECT 1 FROM public.field_prospects p
    WHERE p.research_source_key=c.key OR (c.pid IS NOT NULL AND p.google_place_id=c.pid)
    OR (c.phone IS NOT NULL AND p.phone IS NOT NULL AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
    OR (p.province='TP Hồ Chí Minh' AND p.district='Quận 6'
      AND (lower(btrim(p.name))=lower(btrim(c.name))
        OR lower(btrim(split_part(p.address_line,', phường',1)))=lower(btrim(c.street))
        OR lower(p.address_line) LIKE lower(c.street||',%')))
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.customers k
    WHERE (c.phone IS NOT NULL AND k.phone IS NOT NULL AND regexp_replace(k.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
      OR (k.province='TP Hồ Chí Minh' AND k.district='Quận 6'
         AND (lower(btrim(k.name))=lower(btrim(c.name)) OR lower(k.address_line) LIKE lower(c.street||',%')))
  )
), inserted AS (
 INSERT INTO public.field_prospects (
 owner_sub,name,address_line,province,district,category,phone,note,status,source_kind,
 research_source_key,research_source_url,research_batch,ward_new,address_legacy,google_maps_url,google_place_id
 ) SELECT
 'ef943de4-18f7-49ef-8340-eefb18855534',s.name,
 s.street||', phường '||s.ward||', TP. Hồ Chí Minh',
 'TP Hồ Chí Minh','Quận 6',s.category,s.phone,
 'Rà nguồn trực tuyến ngày 22/11/2026. '||s.note||
 ' CHƯA GHÉ / CHƯA XÁC MINH bảng hiệu, hoạt động, tình trạng bán lẻ tại quầy và GPS. Place ID chỉ là định danh nguồn nghiên cứu, không phải check-in. Nguồn: '||s.research_source_url,
 'new','manual',s.key,s.research_source_url,'2026-11-22-hcm-old-q6-round2-185',
 s.ward,s.street||', '||s.old_ward||', Quận 6 cũ, TP.HCM cũ',s.maps,s.pid
 FROM safe s
 ON CONFLICT DO NOTHING
 RETURNING ward_new,category,name,phone
)
SELECT ward_new,category,count(*)::int AS inserted, count(phone)::int AS phones FROM inserted
GROUP BY ward_new,category ORDER BY ward_new,category;