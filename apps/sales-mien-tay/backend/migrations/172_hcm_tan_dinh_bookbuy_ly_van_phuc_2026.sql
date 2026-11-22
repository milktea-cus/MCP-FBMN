-- 172 | 2026-11-22 | Tan Dinh street-level research: BookBuy at 9 Ly Van Phuc.
-- Bookbuy.vn's own current contact page lists address and hotline; public place profile lists book/art supply store.
-- Sales must verify whether there is a walk-in retail counter (online-focused showroom); do not claim site visit.
WITH candidate AS (
 SELECT 'BookBuy.vn - sách và họa cụ'::text AS name,
 '9 Lý Văn Phức, phường Tân Định, TP. Hồ Chí Minh'::text AS address_line,
 '9 Lý Văn Phức, phường Tân Định, Quận 1, TP.HCM cũ'::text AS address_legacy,
 'ChIJHQwxwbQodTERxMeHQUY2j7E'::text AS google_place_id,
 'bookbuy:9-ly-van-phuc'::text AS research_source_key,
 'https://bookbuy.vn/lien-he.html'::text AS research_source_url,
 'https://www.google.com/maps/search/?api=1&query_place_id=ChIJHQwxwbQodTERxMeHQUY2j7E'::text AS google_maps_url
), vetted AS (
 SELECT c.* FROM candidate c
 WHERE EXISTS (SELECT 1 FROM public.sales_hcm_old_wards w WHERE w.ward_new='Tân Định' AND w.province='TP Hồ Chí Minh' AND w.active)
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE p.research_source_key=c.research_source_key OR p.google_place_id=c.google_place_id OR lower(btrim(p.address_line))=lower(btrim(c.address_line)) OR (p.ward_new='Tân Định' AND lower(btrim(p.name))=lower(btrim(c.name))) OR regexp_replace(coalesce(p.phone,''),'[^0-9]','','g')='0933109009')
 AND NOT EXISTS (SELECT 1 FROM public.customers x WHERE lower(btrim(x.address_line))=lower(btrim(c.address_line)) OR lower(btrim(x.name))=lower(btrim(c.name)) OR regexp_replace(coalesce(x.phone,''),'[^0-9]','','g')='0933109009')
), inserted AS (
 INSERT INTO public.field_prospects (id,area_visit_id,owner_sub,name,address_line,province,district,ward_new,address_legacy,category,phone,tax_code,note,status,source_kind,research_source_key,research_source_url,research_batch,google_maps_url,google_place_id)
 SELECT gen_random_uuid(),NULL,'ef943de4-18f7-49ef-8340-eefb18855534',v.name,v.address_line,'TP Hồ Chí Minh','Quận 1','Tân Định',v.address_legacy,'nha_sach','0933109009',NULL,
 'Tra cứu 22/11/2026. CHƯA GHÉ, CHƯA XÁC MINH quầy bán lẻ và GPS. BookBuy.vn công bố địa chỉ liên hệ 9 Lý Văn Phức và bán sách/họa cụ/VPP; nguồn khác mô tả showroom văn phòng. Sales cần xác minh có bán lẻ trực tiếp, không mặc định cửa hàng mặt phố. Nguồn: https://bookbuy.vn/lien-he.html ; https://phanthi.vn/tuyen-ctv-ban-thoi-gian-cho-kenh-tmdt-bookbuy-vn/',
 'new','manual',v.research_source_key,v.research_source_url,'2026-11-22-hcm-tan-dinh-bookbuy-172',v.google_maps_url,v.google_place_id
 FROM vetted v
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING name,address_line,ward_new
)
SELECT * FROM inserted;