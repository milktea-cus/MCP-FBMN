-- 174 | 2026-11-22 | Tân Định new ward, Quận 1 legacy: two source-verified physical shops.
-- PM Arts & Crafts: stationery/art supplies, 146/5 Nguyễn Văn Thủ. Shop-owned contact: https://pmartcraft.com/lien-he/
-- Ổ Gallery & Shop: Le&De brand sold within same shop at 96E Võ Thị Sáu, counted as ONE retail point.
-- Sources: https://endlessvacation.vn/lede-gioi-thieu/ ; https://shop.endlessvacation.vn/pages/lien-he
-- No extra lead for Tuệ Minh/Meily at same 155 Trần Quang Khải; no fake GPS or visit; status research only.
-- Excluded unverified wholesale offices (39 Đinh Công Tráng / 4 Nguyễn Đình Chiểu) and old/out-of-ward addresses.
-- Idempotent by source_key, Google Place ID, name+address, phone; also checks customers.
WITH src AS (SELECT * FROM jsonb_to_recordset('[{"ward":"Tân Định","name":"PM Arts & Crafts - họa cụ và giấy nghệ thuật","address_new":"146/5 Nguyễn Văn Thủ, phường Tân Định, TP. Hồ Chí Minh","address_old":"146/5 Nguyễn Văn Thủ, phường Đa Kao cũ, Quận 1, TP.HCM cũ","category":"van_phong_pham","phone":"0939051814","place":"ChIJXwKPED4vdTERxBR90EBIQRo","source_key":"gmaps:ChIJXwKPED4vdTERxBR90EBIQRo","source_url":"https://pmartcraft.com/lien-he/","maps_url":"https://www.google.com/maps/search/?api=1&query_place_id=ChIJXwKPED4vdTERxBR90EBIQRo","proof":"Website chính chủ công bố cửa hàng 146/5 Nguyễn Văn Thủ (Đa Kao cũ), giờ mở cửa và 0939 051 814, bán bút, sổ giấy vẽ, giấy mỹ thuật, craft; hồ sơ Google Maps xác định Tân Định mới và cửa hàng riêng. Đặc thù họa cụ và VPP nghệ thuật; Sales cần kiểm hoạt động tại quầy."},{"ward":"Tân Định","name":"Ổ Gallery & Shop - Le&De Stationery","address_new":"96E Võ Thị Sáu, phường Tân Định, TP. Hồ Chí Minh","address_old":"96E Võ Thị Sáu, phường Tân Định cũ, Quận 1, TP.HCM cũ","category":"van_phong_pham","phone":"0938691200","place":null,"source_key":"o-gallery:96e-vo-thi-sau:lede","source_url":"https://endlessvacation.vn/lede-gioi-thieu/","maps_url":null,"proof":"Thương hiệu trực tiếp công bố Le&De Stationery bán lẻ tại Ổ Gallery & Shop, 96E Võ Thị Sáu: bút, bảng, giấy note, sticker, phụ kiện văn phòng phẩm. Website Ổ Gallery & Shop công bố địa chỉ và hotline 093 869 1200. Nghiêng về quà tặng và giấy sáng tạo, không phải VPP tổng hợp; không tách Le&De và Ổ thành hai cửa hàng. Google business có điện thoại khác, Sales cần xác minh hotline hoạt động."}]'::jsonb) AS s(ward text,name text,address_new text,address_old text,category text,phone text,place text,source_key text,source_url text,maps_url text,proof text)), vetted AS (
 SELECT s.* FROM src s WHERE s.ward='Tân Định' AND s.category IN ('nha_sach','van_phong_pham')
 AND s.source_url LIKE 'https://%' AND s.address_new LIKE '%phường Tân Định%'
 AND s.phone ~ '^[0-9]{10}$'
 AND (s.place IS NULL OR s.place ~ '^ChIJ[A-Za-z0-9_-]{20,}$')
 AND EXISTS (SELECT 1 FROM public.sales_hcm_old_wards w WHERE w.province='TP Hồ Chí Minh' AND w.ward_new=s.ward AND w.legacy_district='Quận 1' AND w.active)
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE p.research_source_key=s.source_key OR (s.place IS NOT NULL AND p.google_place_id=s.place)
    OR lower(btrim(p.address_line))=lower(btrim(s.address_new))
    OR (p.province='TP Hồ Chí Minh' AND p.ward_new=s.ward AND lower(btrim(p.name))=lower(btrim(s.name)))
    OR regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=s.phone)
 AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE lower(btrim(c.address_line))=lower(btrim(s.address_new))
    OR (c.province='TP Hồ Chí Minh' AND lower(btrim(c.name))=lower(btrim(s.name)))
    OR regexp_replace(coalesce(c.phone,''),'[^0-9]','','g')=s.phone)
), inserted AS (
 INSERT INTO public.field_prospects (id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,address_legacy,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch,google_maps_url,google_place_id)
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_new,'TP Hồ Chí Minh','Quận 1',s.ward,s.address_old,s.category,s.phone,NULL,
 'Nguồn công khai tra cứu 22/11/2026; CHƯA GHÉ, CHƯA XÁC MINH thực địa/GPS. '||s.proof||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-22-hcm-tan-dinh-pmarts-gallery-174',s.maps_url,s.place
 FROM vetted s
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING ward_new,name,category,phone,google_place_id
)
SELECT ward_new,name,category,phone,google_place_id FROM inserted ORDER BY name;
