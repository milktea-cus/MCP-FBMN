-- 187 | 2026-11-22 | TP.HCM CŨ Quận 6 đợt 4, Bình Tiên sâu theo tuyến Gia Phú, Bãi Sậy và Phạm Văn Chí.
-- Địa danh mới tra NQ 1685/NQ-UBTVQH15: Bình Tiên thuộc TP.HCM cũ; P1/P7/P8 sau sắp xếp.
-- Chỉ điểm bán được định danh online, KHÔNG giả định có ghé thăm, đang mở cửa, hay có GPS của nhân viên.
-- Loại: 108 Bãi Sậy (tạp hóa chủ đạo); 516 Gia Phú (đầu mối bán sỉ); VPP GOTEK/Phú Khiết (chưa có căn cứ cửa hàng bán lẻ);
-- 195 Gia Phú, 508 Gia Phú, 331A Gia Phú, 321 Phạm Văn Chí (đã có trong DB), 119 Văn Thân (đã có);
-- 339 Gia Phú xuất hiện dưới hai tên VPP/quà lưu niệm và Lý Thiên Lộc, chỉ chèn một điểm và cảnh báo cần đối soát.
-- Migration idempotent: kiểm trùng khách hàng & lead theo Place ID, số điện thoại, tên và số nhà.
WITH candidates AS (
 SELECT * FROM jsonb_to_recordset('[{"name":"BINHMINHBOOKSHOP","street":"545 Gia Phú","ward":"Bình Tiên","category":"nha_sach","phone":"0981700644","place":"ChIJla3JwRIvdTERA4IusI9wSu8","source":null,"notes":"Hồ sơ địa điểm chuyên ngành book store tại số 545 Gia Phú, Bình Tiên; nguồn không có nhận xét chi tiết về quầy bán. Chưa xác minh hoạt động thực tế, không suy đoán danh mục sản phẩm.","old":"","maps":"https://www.google.com/maps/search/?api=1&query=BINHMINHBOOKSHOP%20545%20Gia%20Ph%C3%BA%20Qu%E1%BA%ADn%206%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJla3JwRIvdTERA4IusI9wSu8","key":"gmaps:ChIJla3JwRIvdTERA4IusI9wSu8","source_url":"https://www.google.com/maps/search/?api=1&query=BINHMINHBOOKSHOP%20545%20Gia%20Ph%C3%BA%20Qu%E1%BA%ADn%206%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJla3JwRIvdTERA4IusI9wSu8"},{"name":"Lufeil Shop","street":"80/1 Bãi Sậy","ward":"Bình Tiên","category":"van_phong_pham","phone":"0938050813","place":"ChIJRTD1BjYvdTERM8ov52ebGmI","source":null,"notes":"Hồ sơ địa điểm Stationery store tại 80/1 Bãi Sậy, Quận 6 cũ. Không có nhận xét khách mua; phường cũ cụ thể chưa đủ bằng chứng xác minh.","old":"","maps":"https://www.google.com/maps/search/?api=1&query=Lufeil%20Shop%2080%2F1%20B%C3%A3i%20S%E1%BA%ADy%20Qu%E1%BA%ADn%206%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJRTD1BjYvdTERM8ov52ebGmI","key":"gmaps:ChIJRTD1BjYvdTERM8ov52ebGmI","source_url":"https://www.google.com/maps/search/?api=1&query=Lufeil%20Shop%2080%2F1%20B%C3%A3i%20S%E1%BA%ADy%20Qu%E1%BA%ADn%206%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJRTD1BjYvdTERM8ov52ebGmI"},{"name":"Shop VPP và Phụ kiện Hải Yến","street":"40 Lô J, Phạm Văn Chí","ward":"Bình Tiên","category":"van_phong_pham","phone":null,"place":"ChIJO8mYv88vdTERaVYvvCYQfJo","source":null,"notes":"Hồ sơ địa điểm School supply store, tên ghi VPP và phụ kiện tại 40 Lô J, đường Phạm Văn Chí. Điểm bán và ngành hàng cần kiểm chứng khi Sales tiếp cận; không công khai số điện thoại.","old":"","maps":"https://www.google.com/maps/search/?api=1&query=Shop%20VPP%20v%C3%A0%20Ph%E1%BB%A5%20ki%E1%BB%87n%20H%E1%BA%A3i%20Y%E1%BA%BFn%2040%20L%C3%B4%20J%2C%20Ph%E1%BA%A1m%20V%C4%83n%20Ch%C3%AD%20Qu%E1%BA%ADn%206%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJO8mYv88vdTERaVYvvCYQfJo","key":"gmaps:ChIJO8mYv88vdTERaVYvvCYQfJo","source_url":"https://www.google.com/maps/search/?api=1&query=Shop%20VPP%20v%C3%A0%20Ph%E1%BB%A5%20ki%E1%BB%87n%20H%E1%BA%A3i%20Y%E1%BA%BFn%2040%20L%C3%B4%20J%2C%20Ph%E1%BA%A1m%20V%C4%83n%20Ch%C3%AD%20Qu%E1%BA%ADn%206%20H%E1%BB%93%20Ch%C3%AD%20Minh%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJO8mYv88vdTERaVYvvCYQfJo"},{"name":"Văn phòng phẩm Lý Thiên Lộc – Gia Phú","street":"339 Gia Phú","ward":"Bình Tiên","category":"van_phong_pham","phone":"0906947277","place":null,"source":"https://www.vpplythienloc.com/","notes":"Website chính thức công bố 339 Gia Phú Phường 1 cũ và mặt hàng dụng cụ học sinh/giấy photo. Danh bạ khác có cửa hàng VPP-quà lưu niệm 339 cùng số nhà, chưa xác nhận có cùng bảng hiệu. Không tạo thêm điểm bán thứ hai cùng số 339; xác minh retail walk-in tại chỗ trước khi chuyển khách hàng. Nguồn bổ sung: https://nganhang.appviet.org/cua-hang-qua-luu-niem-o-quan-6.html","old":"Phường 1 cũ","maps":null,"key":"official:hcm:q6:r4:ly-thien-loc:339-gia-phu","source_url":"https://www.vpplythienloc.com/"}]'::jsonb)
 AS c(name text,street text,ward text,category text,phone text,place text,source text,notes text,old text,maps text,key text,source_url text)
), eligible AS (
 SELECT c.*
 FROM candidates c
 JOIN public.sales_hcm_old_wards w
   ON w.province='TP Hồ Chí Minh' AND w.legacy_district='Quận 6' AND w.ward_new=c.ward AND w.active
 WHERE c.ward='Bình Tiên' AND c.category IN ('nha_sach','van_phong_pham') AND c.source_url LIKE 'https://%'
   AND NOT EXISTS (
    SELECT 1 FROM public.field_prospects p
    WHERE p.research_source_key=c.key OR (c.place IS NOT NULL AND p.google_place_id=c.place)
       OR (c.phone IS NOT NULL AND p.phone IS NOT NULL
           AND regexp_replace(p.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
       OR (p.province='TP Hồ Chí Minh' AND p.district='Quận 6'
           AND (lower(btrim(p.name))=lower(btrim(c.name))
                OR lower(btrim(split_part(p.address_line,', phường',1)))=lower(btrim(c.street))
                OR lower(p.address_line) LIKE lower(c.street||',%')))
   )
   AND NOT EXISTS (
    SELECT 1 FROM public.customers k
    WHERE (c.phone IS NOT NULL AND k.phone IS NOT NULL
           AND regexp_replace(k.phone,'[^0-9]','','g')=regexp_replace(c.phone,'[^0-9]','','g'))
       OR (k.province='TP Hồ Chí Minh' AND k.district='Quận 6'
           AND (lower(btrim(k.name))=lower(btrim(c.name))
                OR lower(k.address_line) LIKE lower(c.street||',%')))
   )
), inserted AS (
 INSERT INTO public.field_prospects
 (owner_sub,name,address_line,province,district,category,phone,note,status,source_kind,
 research_source_key,research_source_url,research_batch,ward_new,address_legacy,google_maps_url,google_place_id)
 SELECT
 'ef943de4-18f7-49ef-8340-eefb18855534',v.name,
 v.street||', phường '||v.ward||', TP. Hồ Chí Minh',
 'TP Hồ Chí Minh','Quận 6',v.category,v.phone,
 'Rà nguồn trực tuyến 22/11/2026. '||v.notes||
 ' CHƯA GHÉ / CHƯA XÁC MINH quầy, bảng hiệu, hoạt động hoặc GPS thực địa. Map Place ID là tư liệu nghiên cứu, không phải check-in. Nguồn: '||v.source_url,
 'new','manual',v.key,v.source_url,'2026-11-22-hcm-old-q6-round4-binh-tien-187',
 v.ward,v.street||', '||CASE WHEN v.old='' THEN '' ELSE v.old||', ' END||'Quận 6 cũ, TP.HCM cũ',
 v.maps,v.place
 FROM eligible v
 ON CONFLICT DO NOTHING
 RETURNING name,category,ward_new
)
SELECT ward_new,category,count(*)::int AS added,string_agg(name,'; ' ORDER BY name) AS shops
FROM inserted GROUP BY ward_new,category ORDER BY ward_new,category;