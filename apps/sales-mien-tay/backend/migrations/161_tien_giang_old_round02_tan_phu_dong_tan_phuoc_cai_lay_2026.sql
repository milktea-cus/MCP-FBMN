-- Migration 161 | 2026-11-22 | Tiền Giang OLD - focused batch 01: Huyện Tân Phú Đông, Huyện Tân Phước, Huyện Cai Lậy.
-- Only ONE qualified online VPP prospect from the three districts; do not fabricate entries to fill a fixed quota.
-- Chip Chip at ấp 6 xã Mỹ Thành Nam (Huyện Cai Lậy cũ) published a July 18 2026 list of Thiên Long notebooks, pens, rulers, glue and A4.
-- Tân Phú Đông 0: existing leads + ambiguous search results; Tân Phước 0: Hoàng An Khang tax ID 1201659796 has TERMINATED status.
-- Exclusions: FAHASA/Hiệu Sách Trung at urban Thị xã Cai Lậy; Shop Hướng Dương is TP Mỹ Tho; no duplicate Lam Phương at Phú An.
-- Online source is NOT physical verification: do not assign location/check-in, selling status or customer records.
WITH src AS (
 SELECT x.*,md5('fbmn:old13:round02:161:'||x.source_key) dg
 FROM jsonb_to_recordset('[{"province":"Tiền Giang","district":"Huyện Cai Lậy","name":"Trà Sữa Chip Chip - Mỹ Phẩm - Văn Phòng Phẩm","address_line":"Ấp 6, xã Mỹ Thành Nam cũ, huyện Cai Lậy, Tiền Giang (nay Đồng Tháp)","category":"van_phong_pham","phone":"0989522814","tax_code":null,"source_key":"socialmirror:beautynailhairsalons:107850801671011:chipchip-my-thanh-nam","source_url":"https://www.beautynailhairsalons.com/VN/Cai-Lay/107850801671011/Tr%C3%A0-S%E1%BB%AFa-Chip-Chip---M%E1%BB%B9-Ph%E1%BA%A9m---V%C4%83n-Ph%C3%B2ng-Ph%E1%BA%A9m","note":"Bài đăng sản phẩm ngày 18/07/2026 trên trang sao lưu mạng xã hội liệt kê hàng Thiên Long bán tại tiệm: tập 96/200 trang, bút bi/gel/xóa, thước, gôm/bào chì, bút lông dầu, màu sáp/màu nước, hồ dán, nhãn tập, giấy A4; trang ghi số 0989522814 và địa chỉ ấp 6 Mỹ Thành Nam. Cửa hàng đa ngành trà sữa/mỹ phẩm/VPP, chưa xác minh tồn tại hoặc bán hàng ở cửa hàng thực tế 22/11/2026. Địa giới ấp 6 xã Mỹ Thành Nam thuộc Huyện Cai Lậy cũ theo Thông tư 18/2017/TT-BTNMT: https://thuvienphapluat.vn/van-ban/Tai-nguyen-Moi-truong/Thong-tu-18-2017-TT-BTNMT-Danh-muc-dia-danh-dan-cu-son-van-thuy-van-kinh-te-xa-hoi-Tien-Giang-359826.aspx"}]'::jsonb)
 x(province text,district text,name text,address_line text,category text,phone text,tax_code text,
 source_key text,source_url text,note text)
), ins AS (
 INSERT INTO public.field_prospects (
  id,area_visit_id,owner_sub,name,address_line,province,district,category,phone,tax_code,note,
  status,source_kind,research_source_key,research_source_url,research_batch)
 SELECT (substr(s.dg,1,8)||'-'||substr(s.dg,9,4)||'-5'||substr(s.dg,14,3)||'-8'||substr(s.dg,18,3)||'-'||substr(s.dg,21,12))::uuid,
  NULL,'ef943de4-18f7-49ef-8340-eefb18855534',s.name,s.address_line,s.province,s.district,s.category,s.phone,s.tax_code,
  'Tiền Giang cũ / vòng 2 / lô 3 huyện / 22/11/2026; CHƯA GHÉ; chưa xác minh GPS hoặc cửa hàng còn hoạt động năm 2026. '||s.note||' Nguồn: '||s.source_url,
  'new','manual',s.source_key,s.source_url,'2026-11-22-old13-round02-tiengiang-3districts-161'
 FROM src s
 WHERE s.province='Tiền Giang' AND s.district IN ('Huyện Tân Phú Đông','Huyện Tân Phước','Huyện Cai Lậy')
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
 RETURNING province,district,name,category
)
SELECT province,district,name,category FROM ins ORDER BY province,district,name;
