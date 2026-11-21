# Pilot dữ liệu Điểm bán tiềm năng — TP Bến Tre cũ (21/11/2026)

## Phạm vi và nghiệp vụ
- Bản ghi mới: **17**, tất cả `province='Bến Tre'`, `district='Thành phố Bến Tre'`.
- `public.field_prospects` (lead riêng), **KHÔNG** nhập vào `public.customers`.
- `status='new'` = **Chưa ghé**; `area_visit_id=NULL`, `last_visit_at=NULL`, GPS không xác minh; không tạo ảnh/lượt ghé và không đánh dấu `is_selling`.
- 14/17 có điện thoại; 4/17 có MST từ nguồn công khai; 17/17 có URL nguồn và mã nguồn duy nhất.
- Bản ghi chủ sở hữu ban đầu **Admin**, vì đây là dữ liệu nghiên cứu trung tâm chưa phân công Sales. **Quyền đọc hiện tại của API:** Admin thấy cả 17; các Manager/Sales chỉ nhìn được theo sở hữu/cây quản lý và quyền địa bàn. Cần thiết kế bước phân công/nhận lead trước rollout Sales; **không được nhầm lô dữ liệu có sẵn với lãnh thổ Sales được cấp**.
- Chú ý `source_kind='manual'` do schema/API Flutter v12 đang giới hạn 3 giá trị. Lô thực chất được phân biệt qua `research_source_key`, `research_source_url`, `research_batch` và ghi chú "Dữ liệu công khai, chưa ghé"; không được coi là Sales đã ghi nhận thực địa.
- Mã trùng: `research_source_key` có unique index; import idempotent. MST chỉ dùng để cảnh báo trùng nghiệp vụ theo chốt Owner, không khóa nhiều chi nhánh.

## Dữ liệu nguồn
[Danh sách 17 điểm và URL riêng](../data/market_prospects_ben_tre_city_pilot_2026_11_21.json).
Nguồn tham khảo gồm website VPP Bến Tre, CB STORE, nhà sách Hùng Vương/STG, danh mục cửa hàng NXB Giáo dục 2025–2026, Google Maps Place ID, Danh bạ VietBiz và Trang Vàng.
Một vài cơ sở chỉ có hồ sơ địa điểm từ danh bạ; phải gọi/ghé thực tế để xác nhận còn hoạt động. Bỏ ngoài dữ liệu có dấu hiệu trùng hoặc địa chỉ mâu thuẫn.

## Không nhập trùng Khách hàng hiện hữu
- NS Nhân Văn: 38A Nguyễn Trung Trực
- NS Kim Anh: 512F Nguyễn Văn Cánh
- NS Hoà Bình / địa chỉ 228 Nguyễn Huệ.
- Các gợi ý không rõ 8 Nguyễn Văn Tư ↔ 52 Nguyễn Trãi (Nhà sách Bến Tre 1), VPP Sen Việt khác số nhà, hoặc doanh nghiệp phân phối chung địa chỉ 228 Nguyễn Huệ **không seed**.

## DDL và thao tác DB
1. [Migration 094](../backend/migrations/094_market_prospect_research_provenance.sql) thêm 3 cột metadata và unique index, không thay đổi ràng buộc cũ.
2. Nhập `jsonb_to_recordset` từ JSON đã commit, ID ổn định có version UUID5-like bắt nguồn từ hash `source_key`, `ON CONFLICT (research_source_key) WHERE research_source_key IS NOT NULL DO NOTHING`; đối chiếu khách hàng cùng MST/tên-địa chỉ trước khi nhập. Lô: `2026-11-21-ben-tre-city-pilot-01`.
3. Readback sau commit: **17/17 new, 4 MST, 14 điện thoại, 17 URL nguồn; 0 converted, 0 visits, 0 GPS**, distinct source key 17; 55 khách hàng và 796 trường học không đổi.

## Hướng dẫn test live
- https://sales-mien-tay.vercel.app, tài khoản **Admin** đã đăng nhập.
- Menu trái → Điểm bán tiềm năng → Tỉnh cũ **Bến Tre** → Huyện cũ **Thành phố Bến Tre** → 17 điểm.
- Tìm "FAHASA", "VPP", "Nhà sách"; lọc `Đang tìm`, mở Google Maps/gọi điện.
- Lựa chọn một cửa hàng *thực tế* để ghé kiểm tra GPS/camera, sau đó chuyển vào KH nếu phù hợp. Không đánh dấu lượt ghé giả.
- Các quyền Manager/Sales chưa được test như là chủ hồ sơ nghiên cứu trung tâm; vấn đề phân công cần xử lý ở luồng sau.

## Không diễn giải quá mức
Dữ liệu thu thập từ nguồn công khai, không có bằng chứng tất cả cơ sở đang mở hoặc bán đúng ngành tại thời điểm nhập; không có tọa độ GPS thực địa, số bản ghi 17 là pilot UX chứ **không phải kiểm kê đầy đủ cửa hàng toàn TP Bến Tre cũ**.
