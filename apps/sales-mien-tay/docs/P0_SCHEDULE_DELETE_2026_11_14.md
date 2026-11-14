# MCP-FBMN — P0: Nút Xóa lịch Công tác (14/11/2026)

**Mục tiêu Owner:** Có nút **Xóa lịch** thực sự ở phần Kế hoạch và Tuyến ngày, thay vì bắt người dùng mắc kẹt với bản ghi 409 trùng tuyến. Không phá dữ liệu đã khảo sát hoặc check-in.

## Phương án đã triển khai

- `backend/migrations/046_archive_work_schedule.sql`: Hàm `sales_archive_monthly_plan(actor, plan_id, expected_version)` chạy trên Neon production, `SECURITY DEFINER`, quyền EXECUTE chỉ `sales_api`, kiểm nhân viên còn active, đúng chủ và địa bàn/chuỗi được giao. Tăng version và ghi audit, chuyển status kế hoạch thành `cancelled`; tuyến chưa phát sinh nghiệp vụ cũng chuyển cancelled. Tuyến có GPS/lượt ghé/khảo sát hoặc lý do bỏ điểm giữ trạng thái lịch sử, **không xóa vật lý** các lượt thực địa/ảnh/khảo sát/khách.
- Backend `DELETE /api/v1/monthly-plans/:id?version=N` trả JSON item mới, 403 sai quyền, 404 không tồn tại, 409 stale. Không cho xóa bằng UI mà bỏ qua backend. Cùng API được cập nhật lên Worker production `field-sales-api` với cả 7 binding/secret cũ.
- `apps/sales_flutter/lib/monthly_plan.dart`: Nút **Xóa lịch** hiển thị rõ trên từng lịch active (chính chủ); sửa/tạo/mở/dời tuyến trong menu gọn cho 320–390px. Có nút **Xem lịch đã xóa**, mặc định chỉ xem active.
- `lib/day_route.dart`: Nút **Xóa lịch** ngay màn Tuyến ngày, lấy version mới từ server trước khi xác nhận. Đường dẫn hoạt động trên tài khoản sở hữu, không xóa tùy tiện tuyến của đồng nghiệp.
- `lib/schedule_archive.dart`: Hộp xác nhận **Giữ lịch** / **Xóa lịch** giải thích dữ liệu thực địa vẫn giữ; chỉ khi API xác nhận xóa mới cập nhật cache người dùng và loại kế hoạch khỏi danh sách.
- `lib/work_hub.dart` và `backend/src/day_routes.ts`: Liệt kê `plan_status` ở từng tuyến và không đưa tuyến của kế hoạch đã xóa vào tab Hôm nay/Kết quả hoạt động; có thể xem lịch sử từ Đã xóa.
- `lib/offline_queue.dart`: Chỉ khi server xác nhận archived và kiểm tra không có bản nháp/phiên/lượt ghé phụ thuộc mới dọn các POST lập tuyến/điểm chờ cũ, không xóa dữ liệu GPS/khảo sát. Khi PWA iPhone mở lại, 409 cũ đối chiếu read-only trước khi đánh dấu đã lưu hoặc dọn graph sau khi server đã archive. Không gửi lại tuyến bị trùng.
- Bản lịch có thể được lập lại sau khi archive vì unique index `monthly_plan_one_scope_per_day` chỉ khóa kế hoạch status `planned`.

## Nghiệm thu kỹ thuật

- API database runtime cho `sales_api` được cấp, PUBLIC không có quyền EXECUTE. Không chạy DELETE lên lịch production của Owner: dữ liệu gốc vẫn còn nguyên, Owner tự thao tác qua UI có xác nhận.
- Cloudflare Worker `field-sales-api`: API delete và `plan_status` đã đưa vào bundle hiện tại, giữ nguyên 7 binding.
- Flutter widget regression `test/schedule_delete_test.dart`: bấm nút Xóa lịch trên 320/360/390px, chỉ phát sinh DELETE sau xác nhận, 409 stale không xác nhận xóa, đổi tab Đã xóa và hủy thao tác giữ nguyên dữ liệu.
- Outbox tests `test/route_duplicate_reconcile_test.dart`: dọn graph kế hoạch sau archive khi an toàn, không dọn khi có thực địa, tự xử lý row 409 cũ nếu server xác nhận plan đã archive.
- **UAT chưa chứng minh:** chưa thao tác trực tiếp được trên PWA iPhone Owner, chưa xem được bản ghi IndexedDB thực tế hoặc xác nhận HTTP đăng nhập production với quyền nhân viên Owner. Tránh báo xong nghiệm thu thiết bị nếu không có chứng cứ.

## Không làm

Không `DELETE FROM` dữ liệu khách, tuyến, lượt ghé, phiên khảo sát hoặc audit; không reset IndexedDB, không đụng Cloudflare secrets/R2, không tạo app/repo khác. Lịch đã xóa chỉ được ẩn khỏi kế hoạch đang hoạt động, lịch sử còn tra cứu được.

## Kết quả triển khai và kiểm thử (14/11/2026)

- **Frontend Vercel production READY:** `dpl_96NRJYUJjixzUkQQjrfmkMHH8GX1`, mã nguồn `29de31387177e1e02f2a2d23892e391de771a576`, alias chính thức `https://sales-mien-tay.vercel.app` đã xác nhận qua Vercel API.
- **Build:** backend `tsc --noEmit` PASS, Flutter analyze `--no-fatal-infos` PASS (lint info không chặn build), **200/200 Flutter tests PASS**, Flutter Web release PASS và offline PWA shell 42 assets PASS, không cache API.
- **Cloudflare Worker:** deployment `fbb7933a-0bc3-4fc6-9b4b-38fbc535f5f3` đạt **100%**, bundle có hàm xóa lịch và `plan_status` để loại tuyến của lịch đã xóa khỏi Công tác; 7 bindings/secrets cũ còn nguyên.
- **Neon:** migration 046 đã chạy; `sales_archive_monthly_plan` cho `sales_api` EXECUTE và PUBLIC không được phép. **Chưa xóa thử dữ liệu production của Owner:** lúc xác nhận có 1 lịch hoạt động, 0 lịch đã xóa; bản ghi khách/lượt ghé/khảo sát không bị đụng đến.
- **Kiểm thử mới:** chạm nút rác và xác nhận API ở 320/360/390px, vào mục Đã xóa, không DELETE khi chọn Giữ lịch, 409 stale giữ dữ liệu, dọn graph tuyến chờ không kèm thực địa và giữ nguyên bản nháp/việc đã ghi GPS.

**Giới hạn:** CI GitHub Actions quota vẫn không có chứng cứ xanh; thay thế bằng build/typecheck/test trực tiếp trên Vercel. Chưa thử nghiệm có đăng nhập trên iPhone thực tế của Owner và chưa thể xem một row IndexedDB của máy. Code/deploy READY **không đồng nghĩa** hàng đợi cụ thể trên iPhone đã giảm về 0. Không xóa Safari site data/gỡ app để xử lý.
