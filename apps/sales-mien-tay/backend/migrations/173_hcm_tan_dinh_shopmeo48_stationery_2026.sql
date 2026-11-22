-- 173 | 2026-11-22 | Tân Định / former Đa Kao: small specialty stationery storefront
-- Separate storefront at 52/10 Đinh Tiên Hoàng; not the existing Thu Thảo at 50.
-- Physical Google Maps stationery-store listing plus store-authored local address/phone,
-- corroborated by product sales in stationery categories. Research only: no visit/GPS.
-- Sources:
-- https://www.yellowmega.com/VN/Ho-Chi-Minh-City/244369-42/genre/200600219953504/Shopping%2B%26%2BRetail/22
-- https://shopee.vn/B%C4%83ng-keo-gi%E1%BA%A5y-washi-tape-d%E1%BB%85-th%C6%B0%C6%A1ng-trang-tr%C3%AD-s%E1%BB%95-tay--l%C3%A0m-%C4%91%E1%BB%93-th%E1%BB%A7-c%C3%B4ng-i.59367259.17035556994
WITH candidate AS (
 SELECT 'ShopMeo48 - VPP sáng tạo, đồ giấy và đồ gói'::text AS name,
        '52/10 Đinh Tiên Hoàng, phường Tân Định, TP. Hồ Chí Minh'::text AS address_new,
        '52/10 Đinh Tiên Hoàng, phường Đa Kao cũ, Quận 1, TP.HCM cũ'::text AS address_old,
        '0967014135'::text AS phone,
        'ChIJm15stE0pdTER2JUrYx3kyUQ'::text AS place,
        'gmaps:ChIJm15stE0pdTER2JUrYx3kyUQ'::text AS source_key,
        'https://www.yellowmega.com/VN/Ho-Chi-Minh-City/244369-42/genre/200600219953504/Shopping%2B%26%2BRetail/22'::text AS source_url,
        'https://www.google.com/maps/search/?api=1&query=ShopMeo48%2052%2F10%20Dinh%20Tien%20Hoang&query_place_id=ChIJm15stE0pdTER2JUrYx3kyUQ'::text AS google_maps_url
), vetted AS (
 SELECT c.* FROM candidate c
 WHERE c.source_url LIKE 'https://%'
   AND c.phone ~ '^[0-9]{10}$'
   AND c.place ~ '^ChIJ[A-Za-z0-9_-]{20,}$'
   AND EXISTS (SELECT 1 FROM public.sales_hcm_old_wards w
               WHERE w.province='TP Hồ Chí Minh' AND w.ward_new='Tân Định'
               AND w.legacy_district='Quận 1' AND w.active)
   AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE
       p.research_source_key=c.source_key OR p.google_place_id=c.place
       OR lower(btrim(p.address_line))=lower(btrim(c.address_new))
       OR (p.province='TP Hồ Chí Minh' AND p.ward_new='Tân Định'
           AND lower(btrim(p.name))=lower(btrim(c.name)))
       OR regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')=c.phone)
   AND NOT EXISTS (SELECT 1 FROM public.customers x WHERE
       lower(btrim(x.address_line))=lower(btrim(c.address_new))
       OR (x.province='TP Hồ Chí Minh' AND lower(btrim(x.name))=lower(btrim(c.name)))
       OR regexp_replace(coalesce(x.phone,''),'[^0-9]','','g')=c.phone)
), inserted AS (
 INSERT INTO public.field_prospects (
   id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,
   address_legacy,category,phone,tax_code,note,status,source_kind,
   research_source_key,research_source_url,research_batch,google_maps_url,google_place_id
 )
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
   v.name,v.address_new,'TP Hồ Chí Minh','Quận 1','Tân Định',
   v.address_old,'van_phong_pham',v.phone,NULL,
   'Tra cứu nguồn công khai ngày 22/11/2026; CHƯA GHÉ / CHƯA XÁC MINH quầy bán, không có GPS/ảnh thực địa. '
    ||'Google Maps ghi stationery store tại 52/10 Đinh Tiên Hoàng; hồ sơ ShopMeo48 công bố cửa hàng, hotline và nhóm VPP/đồ gói/đồ trang trí; '
    ||'Shopee ghi bán giấy, thiệp, phong bì, washi tape, bìa còng. Shop chuyên VPP sáng tạo, không mặc định bán đủ VPP phổ thông. '
    ||'Nguồn: https://www.yellowmega.com/VN/Ho-Chi-Minh-City/244369-42/genre/200600219953504/Shopping%2B%26%2BRetail/22',
   'new','manual',v.source_key,v.source_url,
   '2026-11-22-hcm-tan-dinh-shopmeo48-173',v.google_maps_url,v.place
 FROM vetted v
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING ward_new,name,category,phone,google_place_id
)
SELECT * FROM inserted ORDER BY name;