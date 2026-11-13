# P0-L2 — Chuẩn hóa Lập lịch → Đi thực tế → Kết quả (13/11/2026)

**Trạng thái:** kế hoạch đã chốt để thực thi theo pha; chưa đánh dấu nghiệm thu. Kế thừa P0-K, P0-L, P0-M, migration 034–039. **Không có phân hệ Khảo sát độc lập cho Sales khi luồng mới hoàn chỉnh.**

## Quy tắc nghiệp vụ (một nguồn sự thật)

1. **Phân công khác quan hệ cấp trên:** nhân viên/manager chỉ lập lịch trên `territory` (một hoặc nhiều tỉnh/huyện), `chain` hoặc **khách cụ thể** mà họ có quyền công tác trực tiếp. Quyền xem của cấp trên không ngầm cấp quyền lập lịch thay. API/Neon kiểm quyền, không chỉ dropdown Flutter; thu hồi quyền làm cache offline hết hiệu lực.
2. **Ba điểm vào kế hoạch:** (a) chọn địa bàn → *hiện ngay* danh sách khách đã được giao tại địa bàn, lọc/tích nhiều; (b) chọn khách cụ thể trong toàn bộ khách được phép công tác, kể cả không có quyền toàn địa bàn; (c) chọn chuỗi → hiện khách thuộc chuỗi trong quyền, kể cả xuyên tỉnh. Danh sách không tự tạo lượt ghé; có thể thêm/bỏ chọn. Tùy chọn không chọn khách vẫn tạo tuyến tìm khách mới (địa bàn/chuỗi).
3. **Kế hoạch và thực hiện là hai sự thật riêng:** `MonthlyPlan` nêu kỳ/ngày/phạm vi/mục tiêu → `DayRoute` chứa dự định và thứ tự ghé → `RouteStop` là điểm dự kiến → `Visit/AreaVisit` ghi việc thực tế. Điểm phát sinh thuộc cùng ngày/tuyến, đánh dấu **ngoài kế hoạch**; không sửa lại kế hoạch gốc. Khách đóng cửa/không ghé cần lý do, không ghi giả check-in.
4. **Một lần ghé, một luồng GPS:** mở "Công tác → Hôm nay" → chọn điểm → check-in → tùy chọn khảo sát, chụp ảnh, tạo lead/khách hoặc ra đơn. Khảo sát là nghiệp vụ con của lần ghé, *không bắt buộc* để hoàn thành ghé; một lần check-in không đồng nghĩa khảo sát xong. Lưu GPS gốc, thời điểm, quyền và lịch sử.
5. **Ngoài kế hoạch:** địa bàn rỗng khách vẫn lập lịch + tìm khách thật; phát hiện khách mới/điểm bán đột xuất dùng "Thêm điểm phát sinh" và ghi rõ nguồn. Không tạo khách giả; lead → khách được xác minh riêng. Báo cáo cuối ngày phân biệt theo kế hoạch/phát sinh/không ghé/khảo sát/khách mới.
6. **Một luồng điều hướng:** Sales thấy "Công tác" với **Kế hoạch / Hôm nay / Kết quả**. Ẩn tab "Khảo sát" độc lập **chỉ sau khi** nút khảo sát tại từng điểm hoạt động và lịch sử còn xem được. Luồng legacy `/api/v1/routes` giữ đọc lịch sử/khả năng tương thích, không tiếp tục tạo lịch song song sau chuyển đổi.
7. **Nhãn hàng nguồn dữ liệu chung (pha riêng nối tiếp):** chuẩn hóa catalog nhãn hàng/các biến thể tên, liên kết SKU, tình trạng bán tại khách, khảo sát và báo cáo tổng. Bỏ mảng `_surveyBrands` viết cứng; không lấy số nhãn cũ làm số thực tế. Khách có thể kinh doanh nhiều nhãn, trạng thái *đã đặt/đã nhập/đang bán* không được đánh đồng. Không nhầm danh mục SKU với nhãn được xác minh ở điểm bán.


## Cập nhật P0-2 sau thi công code (13/11/2026)

**Phân loại chính xác:** Đã đưa mã lên GitHub `main`; CHƯA hoàn thành nghiệm thu, CHƯA chạy migration `042_work_stop_outcomes_unplanned.sql` trên Neon production và CHƯA deploy Cloudflare Worker/Vercel production. Không sử dụng GitHub Actions do quota dự án hết; chưa có log `flutter analyze`, `flutter test` hoặc Worker typecheck tại phiên làm việc này. Không đánh dấu các checkbox L2-A/B/C/E bên dưới là nghiệm thu.

- **P0-2A — code:** màn Kế hoạch tháng đổi chip lọc sang một dropdown duy nhất, cùng hàng nút **Thêm công tác**, bỏ text thừa; test widget dropdown/mobile 320dp được viết.
- **P0-2B — code nền kiểm tra lại:** `monthly_plan.dart`, `monthly_plans.ts` và migration 040 đã hỗ trợ ba loại `territory/customer/chain`, gợi ý khách theo quyền, tick nhiều, tuyến rỗng khách tạo area/chain stop không tạo khách giả. Cần test quyền, offline và dữ liệu thực.
- **P0-2C — code mới:** kết quả `missed_code/missed_note` cho khách đóng cửa/không gặp/không đi được; `is_unplanned` cho điểm ngoài kế hoạch; migration 042 và hai API POST kiểm tra owner/scope/idempotency. Flutter có ghi lý do, thêm điểm phát sinh, outbox offline và ngăn sửa kế hoạch sau thực tế.
- **P0-2D — code:** khảo sát mở từ điểm ghé `day_route_stop_id`, hạn chế sang đúng điểm/ngày, chặn mở khảo sát khi đã ghi không ghé; bỏ nút `Khảo sát hôm nay` độc lập trong tuyến; Sales vẫn vào `Công tác`, Admin giữ màn khảo sát lịch sử/template/media.
- **P0-2E — code:** `/day-routes` trả riêng `stop_count/visited_count/missed_count/unplanned_count/unplanned_visited_count/survey_count/lead_count`; `WorkHub` đối chiếu ngày theo kế hoạch, GPS, khảo sát, lead và điểm ngoài kế hoạch.
- **Kiểm thử mới chỉ được viết, chưa chạy:** `monthly_plan_test.dart`, `work_hub_test.dart`, `offline_queue_test.dart`. Flutter/Dart SDK không có trong môi trường thực thi; không chạy workflow tính quota.

**Điều kiện tiếp:** kiểm thử cú pháp/DB migration 042 trên nhánh an toàn và quyền DB thật; áp dụng schema theo quy trình phê duyệt Neon; kiểm tra Worker typecheck/API/Auth 401/403/409; chạy Flutter analyze/test, PWA IndexedDB/Android SQLite; triển khai đúng Cloudflare và Vercel production và smoke bằng tài khoản có quyền. Chưa qua các cổng này thì giữ nguyên production, không gọi P0-2 hoàn thành.

## Thứ tự thực hiện và tiêu chí nghiệm thu

- [ ] **L2-A — Kế hoạch/điểm chọn thống nhất:** lọc theo địa bàn/chuỗi/khách cụ thể; khi chọn phạm vi hiển thị khách trong quyền ngay, tích nhiều, tìm tên/mã, xem số khách, thêm tuyến rỗng. Plan API+DB+Flutter thống nhất; offline cache user/scope revision, chống trùng điểm, idempotent.
- [ ] **L2-B — Thực địa:** màn "Hôm nay" gắn `day_route_stop_id`, check-in GPS một lần, thao tác khảo sát, ảnh, đơn hoặc không gặp/đóng cửa, thêm điểm phát sinh (có/không có khách), không ghi đè kế hoạch. Phân quyền backend + audit.
- [ ] **L2-C — Điều hướng và kết quả:** "Công tác" là entry point duy nhất; bỏ tab Khảo sát Sales sau khi thay thế đầy đủ; Admin vẫn quản lý template, khách xem lịch sử; báo cáo plan-vs-actual.
- [ ] **L2-D — Nhãn hàng:** bảng từ danh mục chuẩn + sản phẩm/khách/khảo sát để tính KPI theo địa bàn/quyền; đối soát legacy, không hardcode.
- [ ] **L2-E — Nghiệm thu:** kiểm thử role Admin/Manager/Sales, giao trực tiếp/cùng tỉnh khác đội/chuỗi xuyên tỉnh/khách riêng/0 khách/khách phát sinh; multi-device/offline IndexedDB+SQLite, revoke, 401/403/409, GPS+media, không trùng đồng bộ; DB+API+Flutter+CI, Vercel/Worker prod smoke trước khi tick Done.

**Nguyên tắc triển khai:** làm trên repo main, additive migration, không xóa dữ liệu cũ, commit rõ theo pha, CI xanh trước pha kế tiếp; giữ nguyên R2 secrets/bindings và backend production. P0-J UAT và APK signed là cổng riêng, không tự coi đạt.
