-- 099: Audit flags on existing unvisited Ben Tre research leads.
-- Non-destructive: preserve customer links, current names, GPS and status.
-- Official manufacturer listing and tax/directory data may conflict.
WITH flag(id,warning) AS (
 VALUES ('2d6553c4-ebd4-592c-8fcd-2941ab77228d'::uuid,'CẢNH BÁO KIỂM CHỨNG: chi nhánh MST 1300377802-006 được danh bạ thuế cập nhật 30/08/2026 ghi đã chấm dứt hiệu lực; chưa chứng minh cửa hàng tại địa chỉ đã đóng. Cần gọi/xác minh trước khi ghé. Nguồn: https://chogia.vn/ma-so-thue/doanh-nghiep/1300377802-006'),
('3e0411aa-e3ff-5b80-8d77-09f04e205273'::uuid,'CẢNH BÁO KIỂM CHỨNG: chi nhánh MST 1300377802-005 được danh bạ thuế cập nhật 30/08/2026 ghi đã chấm dứt hiệu lực; chưa chứng minh mặt bằng tại địa chỉ đã đóng. Nguồn: https://chogia.vn/ma-so-thue/doanh-nghiep/1300377802-005'),
('b0496aed-b1b5-52a7-8c6c-2556f3146555'::uuid,'CẢNH BÁO KIỂM CHỨNG: VietBiz đánh dấu cơ sở này đóng từ 31/05/2023; chưa xác minh cửa hàng có mở lại. Nguồn: https://www.viet-biz.com/c%E1%BB%ADa-h%C3%A0ng-v%C4%83n-ph%C3%B2ng-ph%E1%BA%A9m-th%C3%A1i-thanh-th%E1%BA%A3o'),
('2c51020b-e1ae-5469-8cc7-f4836130ce64'::uuid,'CẢNH BÁO ĐỊA CHỈ: đối tác trên website chính thức Thiên Long ghi 116 ấp Bình Thành, xã Thành Thới B; hồ sơ hiện ghi ấp Bình Thạnh. Chưa tự thay địa chỉ, Sales cần đối chiếu. Nguồn: https://thienlonggroup.com/news/58-cua-hang-chuan-thien-long-da-co-mat-tren-toan-quoc')
), changed AS (
 UPDATE public.field_prospects p
 SET note=coalesce(p.note,'')||E'\n'||flag.warning,
     updated_at=now(),version=p.version+1
 FROM flag
 WHERE p.id=flag.id AND p.province='Bến Tre' AND p.status='new'
   AND p.converted_customer_id IS NULL
   AND p.note NOT LIKE '%CẢNH BÁO%'
 RETURNING p.id,p.name,p.version,p.status
)
SELECT * FROM changed ORDER BY name;
