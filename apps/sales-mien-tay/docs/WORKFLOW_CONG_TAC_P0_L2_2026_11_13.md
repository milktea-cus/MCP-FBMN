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


## P0-2 — Thực thi code và production (13/11/2026)

**Triển khai mã nguồn:** P0-2A/B/C/D/E đã cập nhật vào `main` tới commit `c94fc43c3890b49c0fd60445ba9b9e501eb4df0a`. P0-2B sử dụng nền tảng `monthly_plans`/migration 040 đã có; P0-2C/E bổ sung migration 042, API và UI. Luồng Sales: Công tác → Kế hoạch/Hôm nay/Kết quả, khảo sát mở theo điểm ghé, không dùng GPS làm dấu hoàn thành khảo sát.

**Neon production:** migration `042_work_stop_outcomes_unplanned.sql` thực thi giao dịch thành công. Đã kiểm tra đủ **5 cột** `is_unplanned,missed_code,missed_note,missed_at,missed_ref` và **2 hàm** `sales_add_unplanned_route_stop`, `sales_mark_route_stop_missed`. Hai hàm chỉ cấp EXECUTE cho `sales_api`, PUBLIC bị chặn. Trước/sau migration vẫn có 1 tuyến/1 điểm đã tồn tại; không tạo, xóa hay cập nhật fixture production.

**Cloudflare Worker production:** Worker `field-sales-api` được cập nhật nội dung module trên script hiện hành (không tạo Worker khác), deployment ID `19939e3d-1ac4-4839-8e74-22f6e1f2f87f`, version `bfe7a2fc-62b9-414a-b501-bca98aed03f3` **100%**. Kiểm lại 7 bindings/secret đã được giữ nguyên: `ALLOWED_ORIGINS`, `APP_RELEASES_BUCKET`, `DATABASE_URL`, `PHOTOS_BUCKET`, `VAPID_PRIVATE_JWK`, `VAPID_PUBLIC_KEY`, `VAPID_SUBJECT`. Nội dung bundle có handler missed/unplanned, counter, guard khảo sát/plan. Production bundle được patch có kiểm tra từ bản triển khai hiện tại; chưa có build Worker typecheck độc lập từ SHA `main`, cần kiểm chứng lại khi chuẩn hóa pipeline Worker tiếp theo.

**Flutter Web/Vercel production:** build trực tiếp từ SHA `c94fc43c...` qua dự án hiện hữu `sales-mien-tay`; deployment `dpl_8sMFCXZaHrxQbSRmciU2RJDWGY9E` **READY**, alias `https://sales-mien-tay.vercel.app`. Build đã chạy `flutter analyze --no-fatal-infos` (pass, 137 thông tin lint không chặn), **175 Flutter tests PASS**, `flutter build web --release` PASS, offline shell **42 assets**, `vercel.json` có rewrite /api đến Worker. Không dùng GitHub Actions quota.

**Giới hạn nghiệm thu còn mở:** kiểm tra HTTP 200/401/403/409 trực tiếp từ URL production bị hạn chế bởi môi trường kiểm tra web (không thể đọc phản hồi URL), chưa có UAT hai tài khoản, GPS, offline trên PWA/Android thật, camera, kiểm tra chéo quyền và hồi quy runtime. Vercel READY + 175 test **không** thay thế UAT. Không đóng checklist L2-E/P0-J và không báo hoàn thành sản phẩm v1.0 chỉ từ những bằng chứng trên.

## Thứ tự thực hiện và tiêu chí nghiệm thu

- [ ] **L2-A — Kế hoạch/điểm chọn thống nhất:** lọc theo địa bàn/chuỗi/khách cụ thể; khi chọn phạm vi hiển thị khách trong quyền ngay, tích nhiều, tìm tên/mã, xem số khách, thêm tuyến rỗng. Plan API+DB+Flutter thống nhất; offline cache user/scope revision, chống trùng điểm, idempotent.
- [ ] **L2-B — Thực địa:** màn "Hôm nay" gắn `day_route_stop_id`, check-in GPS một lần, thao tác khảo sát, ảnh, đơn hoặc không gặp/đóng cửa, thêm điểm phát sinh (có/không có khách), không ghi đè kế hoạch. Phân quyền backend + audit.
- [ ] **L2-C — Điều hướng và kết quả:** "Công tác" là entry point duy nhất; bỏ tab Khảo sát Sales sau khi thay thế đầy đủ; Admin vẫn quản lý template, khách xem lịch sử; báo cáo plan-vs-actual.
- [ ] **L2-D — Nhãn hàng:** bảng từ danh mục chuẩn + sản phẩm/khách/khảo sát để tính KPI theo địa bàn/quyền; đối soát legacy, không hardcode.
- [ ] **L2-E — Nghiệm thu:** kiểm thử role Admin/Manager/Sales, giao trực tiếp/cùng tỉnh khác đội/chuỗi xuyên tỉnh/khách riêng/0 khách/khách phát sinh; multi-device/offline IndexedDB+SQLite, revoke, 401/403/409, GPS+media, không trùng đồng bộ; DB+API+Flutter+CI, Vercel/Worker prod smoke trước khi tick Done.

**Nguyên tắc triển khai:** làm trên repo main, additive migration, không xóa dữ liệu cũ, commit rõ theo pha, CI xanh trước pha kế tiếp; giữ nguyên R2 secrets/bindings và backend production. P0-J UAT và APK signed là cổng riêng, không tự coi đạt.
