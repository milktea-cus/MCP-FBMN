-- 110 | 2026-11-21 | Long An old wave-2 deep rural supplement from Hong Ha authorized point-of-sale list.
-- Area assignment additionally verified: My Lac/My Thanh -> former Thu Thua; Binh Quoi -> former Chau Thanh.
-- Research-only leads, without GPS/visits/customer conversion.
WITH src AS (
 SELECT x.*,md5('fbmn:longan-old:wave02-hongha:'||x.source_key) dg
 FROM jsonb_to_recordset('[{"district":"Huyện Thủ Thừa","name":"Nhà sách Hoàng Bảo Ngọc","address_line":"094D tỉnh lộ 817, ấp Bà Mía, xã Mỹ Lạc cũ, huyện Thủ Thừa","category":"nha_sach","phone":"0913818140","tax_code":null,"source_key":"hongha:longan:hoang-bao-ngoc:094d-tl817","source_url":"https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu","verification_note":"Danh sách điểm bán chính thức hãng Hồng Hà; xã Mỹ Lạc thuộc Thủ Thừa cũ, nay sáp nhập vào Mỹ Thạnh. Chưa Sales ghé."},{"district":"Huyện Thủ Thừa","name":"Nhà sách Khánh My","address_line":"ST0362, ấp 5, tỉnh lộ 817, xã Mỹ Thạnh cũ, huyện Thủ Thừa","category":"nha_sach","phone":"0397283120","tax_code":null,"source_key":"hongha:longan:khanh-my:st0362-my-thanh","source_url":"https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu","verification_note":"Theo điểm bán nhà cung cấp Hồng Hà; số ST0362 là ký hiệu địa chỉ nguồn, không tự suy ra số nhà. Chưa Sales ghé."},{"district":"Huyện Thủ Thừa","name":"Nhà sách Thành Trung","address_line":"132T tỉnh lộ 817, ấp Bà Mía, xã Mỹ Lạc cũ, huyện Thủ Thừa","category":"nha_sach","phone":"0917013959","tax_code":null,"source_key":"hongha:longan:thanh-trung:132t-tl817","source_url":"https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu","verification_note":"Địa chỉ khác số 094D của Hoàng Bảo Ngọc trên cùng TL817, không tự gộp. Cần Sales xác minh là cơ sở riêng."},{"district":"Huyện Châu Thành","name":"Nhà sách Thanh Thảo","address_line":"138/5 tỉnh lộ 827B, ấp Kỳ Châu, xã Bình Quới cũ, huyện Châu Thành","category":"nha_sach","phone":"0916347060","tax_code":null,"source_key":"hongha:longan:thanh-thao:138-5-tl827b","source_url":"https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu","verification_note":"Hồng Hà liệt kê điểm bán; ấp Kỳ Châu xã Bình Quới thuộc Châu Thành Long An cũ, không lẫn Châu Thành tỉnh khác."}]'::jsonb) AS x(
 district text,name text,address_line text,category text,phone text,tax_code text,
 source_key text,source_url text,verification_note text)
), ins AS (
 INSERT INTO public.field_prospects(
 id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,
 note,status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT
 (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',
 s.name,s.address_line,'Long An',s.district,s.category,s.phone,s.tax_code,
 'Nguồn Hồng Hà 21/11/2026, chưa ghé, chưa có GPS được xác minh. '||s.verification_note||' Nguồn: '||s.source_url,
 'new','manual',s.source_key,s.source_url,'2026-11-21-long-an-old-wave-02-hongha-rural-supplement'
 FROM src s
 WHERE s.district IN ('Huyện Thủ Thừa','Huyện Châu Thành') AND s.source_url LIKE 'https://%'
 AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE c.province='Long An' AND c.district=s.district AND lower(btrim(c.name))=lower(btrim(s.name)))
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p WHERE p.province='Long An' AND p.district=s.district AND
 (p.research_source_key=s.source_key OR (lower(btrim(p.name))=lower(btrim(s.name)) AND lower(btrim(p.address_line))=lower(btrim(s.address_line)))))
 ON CONFLICT(research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING district,phone,tax_code
)
SELECT district,count(*)::int inserted,count(*) FILTER(WHERE phone IS NOT NULL)::int phones FROM ins GROUP BY district ORDER BY district;