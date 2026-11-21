-- 100: targeted map-based research in Ba Tri, Cho Lach, Giong Trom, Thanh Phu.
-- Idempotent research-only rows: no GPS, photo, visit, selling or client conversion.
-- Source details in ../data/market_prospects_ben_tre_local_maps_sweep_2026_11_21.json
WITH source_data AS (
 SELECT x.*,md5('fbmn:ben-tre:map-extra:2026:'||x.source_key) AS digest
 FROM jsonb_to_recordset('[{"district":"Huyện Ba Tri","name":"Photocopy – Văn phòng phẩm Khải Linh","address_line":"6A Trần Hưng Đạo, thị trấn Ba Tri, huyện Ba Tri cũ","category":"van_phong_pham","phone":"0985181494","tax_code":null,"source_key":"gmap:ChIJA3t22Vz5nzERSq5bjTSjGGM","source_url":"https://www.google.com/maps/search/?api=1&query=Photocopy%20%E2%80%93%20V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20Kh%E1%BA%A3i%20Linh%20Huy%E1%BB%87n%20Ba%20Tri%20B%E1%BA%BFn%20Tre%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJA3t22Vz5nzERSq5bjTSjGGM","confidence":"public_map_listing","evidence":"Hồ sơ địa điểm công khai có tên, phân loại cửa hàng và địa chỉ khu vực cũ","verification_note":"Danh mục bản đồ ghi đồng thời Office supply store và Print shop; cần xác nhận thực tế bán giấy/bút."},{"district":"Huyện Chợ Lách","name":"Mẹ Bông Store","address_line":"Khu phố 1, thị trấn Chợ Lách, huyện Chợ Lách cũ","category":"van_phong_pham","phone":"0975731680","tax_code":null,"source_key":"gmap:ChIJl0_umUmfCjERdGc-8aDRMTE","source_url":"https://www.google.com/maps/search/?api=1&query=M%E1%BA%B9%20B%C3%B4ng%20Store%20Huy%E1%BB%87n%20Ch%E1%BB%A3%20L%C3%A1ch%20B%E1%BA%BFn%20Tre%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJl0_umUmfCjERdGc-8aDRMTE","confidence":"public_map_listing","evidence":"Hồ sơ địa điểm công khai có tên, phân loại cửa hàng và địa chỉ khu vực cũ","verification_note":"Google Maps phân loại Stationery store; chưa có số nhà chi tiết, chưa có GPS thực địa."},{"district":"Huyện Chợ Lách","name":"Hiệu sách Anh Luân","address_line":"Khu vực ấp Chợ Lách, huyện Chợ Lách cũ (plus code 743J+R9R)","category":"nha_sach","phone":null,"tax_code":null,"source_key":"gmap:ChIJn-UGbgqfCjER_JTW_S0JwDI","source_url":"https://www.google.com/maps/search/?api=1&query=Hi%E1%BB%87u%20s%C3%A1ch%20Anh%20Lu%C3%A2n%20Huy%E1%BB%87n%20Ch%E1%BB%A3%20L%C3%A1ch%20B%E1%BA%BFn%20Tre%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJn-UGbgqfCjER_JTW_S0JwDI","confidence":"public_map_listing","evidence":"Hồ sơ địa điểm công khai có tên, phân loại cửa hàng và địa chỉ khu vực cũ","verification_note":"Google Maps phân loại Scrapbooking store, chưa có số nhà và số điện thoại; cần xác nhận còn bán sách hoặc dụng cụ học tập."},{"district":"Huyện Giồng Trôm","name":"Nhà sách Thanh Trúc","address_line":"ĐT885, khu vực Giồng Trôm, huyện Giồng Trôm cũ (plus code 5G62+PCH)","category":"nha_sach","phone":"0979056789","tax_code":null,"source_key":"gmap:ChIJjyDWH0UAoDER0nNP15dotjc","source_url":"https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20s%C3%A1ch%20Thanh%20Tr%C3%BAc%20Huy%E1%BB%87n%20Gi%E1%BB%93ng%20Tr%C3%B4m%20B%E1%BA%BFn%20Tre%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJjyDWH0UAoDER0nNP15dotjc","confidence":"public_map_listing","evidence":"Hồ sơ địa điểm công khai có tên, phân loại cửa hàng và địa chỉ khu vực cũ","verification_note":"Google Maps phân loại Book store, có điện thoại; chưa có số nhà."},{"district":"Huyện Thạnh Phú","name":"Cửa hàng Thiết bị Văn phòng Phi Long","address_line":"QL57, khu vực Thạnh Phú, huyện Thạnh Phú cũ (plus code WGW7+QW8)","category":"van_phong_pham","phone":"02753726222","tax_code":null,"source_key":"gmap:ChIJs8cRLuodoDERp3Ike1rSTiw","source_url":"https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20Thi%E1%BA%BFt%20b%E1%BB%8B%20V%C4%83n%20ph%C3%B2ng%20Phi%20Long%20Huy%E1%BB%87n%20Th%E1%BA%A1nh%20Ph%C3%BA%20B%E1%BA%BFn%20Tre%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJs8cRLuodoDERp3Ike1rSTiw","confidence":"public_map_listing","evidence":"Hồ sơ địa điểm công khai có tên, phân loại cửa hàng và địa chỉ khu vực cũ","verification_note":"Google Maps phân loại Office supply store; chưa xác nhận định vị thực địa."},{"district":"Huyện Thạnh Phú","name":"Văn phòng phẩm – Photocopy – Lưu niệm Cô Huy","address_line":"QL57, khu vực Thạnh Phú, huyện Thạnh Phú cũ (plus code WGMF+5J6)","category":"van_phong_pham","phone":null,"tax_code":null,"source_key":"gmap:ChIJxyLjuR8doDER0tyrQK3qAJw","source_url":"https://www.google.com/maps/search/?api=1&query=V%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20%E2%80%93%20Photocopy%20%E2%80%93%20L%C6%B0u%20ni%E1%BB%87m%20C%C3%B4%20Huy%20Huy%E1%BB%87n%20Th%E1%BA%A1nh%20Ph%C3%BA%20B%E1%BA%BFn%20Tre%20Vi%E1%BB%87t%20Nam&query_place_id=ChIJxyLjuR8doDER0tyrQK3qAJw","confidence":"public_map_listing","evidence":"Hồ sơ địa điểm công khai có tên, phân loại cửa hàng và địa chỉ khu vực cũ","verification_note":"Hồ sơ địa điểm có VPP/photocopy/lưu niệm và bách hóa; chưa có số nhà, gọi/ghé kiểm tra."}]'::jsonb)
 AS x(district text,name text,address_line text,category text,phone text,
  tax_code text,source_key text,source_url text,confidence text,evidence text,verification_note text)
), inserted AS (
 INSERT INTO public.field_prospects(
 id,area_visit_id,owner_sub,name,address_line,province,district,
 category,phone,tax_code,note,status,source_kind,
 research_source_key,research_source_url,research_batch)
 SELECT
 (substr(x.digest,1,8)||'-'||substr(x.digest,9,4)||'-5'||substr(x.digest,14,3)
 ||'-8'||substr(x.digest,18,3)||'-'||substr(x.digest,21,12))::uuid,
 NULL,'ef943de4-18f7-49ef-8340-eefb18855534',x.name,x.address_line,
 'Bến Tre',x.district,x.category,x.phone,NULL,
 'Địa điểm trên bản đồ công khai ('||x.confidence||'); CHƯA GHÉ và GPS chưa xác minh. '
 ||x.verification_note||' Nguồn: '||x.source_url,
 'new','manual',x.source_key,x.source_url,'2026-11-21-ben-tre-local-maps-sweep-02'
 FROM source_data x
 WHERE x.category IN ('nha_sach','van_phong_pham') AND x.source_url LIKE 'https://%'
 AND x.district IN ('Huyện Ba Tri','Huyện Chợ Lách','Huyện Giồng Trôm','Huyện Thạnh Phú')
 AND NOT EXISTS (SELECT 1 FROM public.customers c
  WHERE c.province='Bến Tre' AND c.district=x.district
  AND lower(btrim(c.name))=lower(btrim(x.name)))
 AND NOT EXISTS (SELECT 1 FROM public.field_prospects p
  WHERE p.province='Bến Tre' AND p.district=x.district
  AND (p.research_source_key=x.source_key OR (lower(btrim(p.name))=lower(btrim(x.name)) AND lower(btrim(p.address_line))=lower(btrim(x.address_line)))))
 ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING
 RETURNING id,name,district,category)
SELECT id,name,district,category FROM inserted ORDER BY district,name;
