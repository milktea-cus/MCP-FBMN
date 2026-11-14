# P0 — Khắc phục hàng đợi iPhone bị 409 tuyến trùng

**Ngày:** 14/11/2026  
**Triệu chứng thực tế:** Owner thấy `Chờ đồng bộ: 1`; mở `Chi tiết` cho biết máy chủ từ chối 409 vì tuyến trùng.

## Đối chiếu nguyên nhân

- Database Neon production có **1 tuyến ngày và 1 điểm ghé** tại thời điểm kiểm tra; bảng `sales_records` legacy không có bản ghi visit. Điều này hỗ trợ kiểm tra tuyến Công tác mới, **không chứng minh row đang chờ trên iPhone có đúng cùng nội dung**, vì IndexedDB thiết bị không truy xuất được từ máy chủ.
- `field_day_routes` có unique `monthly_plan_id`; `field_route_stops` có unique theo tuyến + khách/chuỗi/địa bàn. Tạo lại một tuyến/điểm ghé với UUID thao tác mới khiến DB trả 409 dù bản kinh doanh có thể đã lưu.
- Backend cố ý chống trùng và phân quyền; không được bỏ ràng buộc, không sửa/cancel dữ liệu sản xuất để che lỗi.
- Outbox trước đó chỉ giữ trạng thái `blocked` cho lỗi 409, không tìm tuyến thực tế để xác minh. Các bản PWA cũ có thể lưu lỗi chỉ bằng tiếng Việt, không kèm mã HTTP trong row.

## Sửa thực tế

- `apps/sales-mien-tay/apps/sales_flutter/lib/offline_queue.dart`: `reconcileBlockedRoutes()` đối chiếu read-only tuyến/điểm ghé qua API hiện có, scoped theo tài khoản/owner và quyền máy chủ. Khi trùng **hoàn toàn** cùng kế hoạch tháng, ngày, mục đích, ghi chú, trạng thái; hoặc cùng tuyến, loại điểm ghé, khách/chuỗi/địa bàn, thứ tự và mục đích, mới xác nhận đã lưu.
- Nếu khác bất kỳ thuộc tính nghiệp vụ quan trọng nào, không tự đóng/xóa operation, không gửi lại POST, giữ nguyên row và hiển thị thông báo xung đột.
- Khi server có cùng tuyến nhưng UUID khác với UUID local, dùng **một giao dịch IndexedDB/SQLite** để xóa operation đã đối chiếu và đổi path, `depends_on` cùng payload tham chiếu của các thao tác còn chờ sang UUID canonical. Khi điểm ghé trùng, còn chuyển `route_stop_id`/`day_route_stop_id` trong thao tác pending và bản nháp survey, giữ lại answers và ảnh.
- Khi PWA mở lại, tự đối chiếu các route create bị blocked bằng GET trước khi thử sync. Nút `Đối chiếu tuyến đã lưu` trong hộp `Chi tiết` không tạo POST trùng.
- Nếu server trả 401/403, lỗi mạng hoặc dữ liệu không khớp, row vẫn được giữ nguyên, không xóa cache/database, không ghi đè.
- Không tạo migration Neon, không thay Worker production/bindings, không reset mật khẩu/session.

## Kiểm thử

- `test/route_duplicate_reconcile_test.dart`: 6 kiểm thử mới cho tuyến trùng đúng nội dung, chuyển các điểm ghé phụ thuộc, tuyến khác mục đích, khác chủ quyền, điểm ghé trùng, bảo toàn bản nháp survey và tình huống server từ chối 403. Bao gồm kiểm tra **không POST lại** khi đang đối chiếu, cả lỗi 409 lưu bằng text cũ.
- `flutter analyze --no-fatal-infos` và TypeScript backend `tsc --noEmit` đạt; **192/192 bài Flutter test đạt** ở lần build sửa mã hợp lệ.
- Frontend Flutter Web production: deployment `dpl_4kMt4XP8Sq2LigNt1ut5fqSJq5XE`, SHA `1e07364bb9873177743efba0f3097c6336f30727`. Trạng thái READY và alias production cần xác nhận riêng trước khi bàn giao.

## UAT còn mở

- Hàng đợi cũ **chỉ nằm trong IndexedDB của iPhone**. Không thể xác nhận remote rằng duy nhất 1 thao tác của Owner đã xong nếu chưa để PWA tải bản mới và chạy phép đối chiếu.
- Nếu dữ liệu khác, app phải tiếp tục giữ 409 và cho Owner xem/đưa ra quyết định nghiệp vụ, không tự xóa.
- Không gỡ PWA hoặc xóa lịch sử/dữ liệu Safari vì có thể làm mất thao tác chưa đồng bộ.
