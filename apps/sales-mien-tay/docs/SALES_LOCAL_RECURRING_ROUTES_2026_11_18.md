# Tuyến cố định Sales Local — 18/11/2026

Nguồn `binhnxwjfjxm/mcp-mobi` main hiện chỉ chứa README và một ảnh UI, không có mã nguồn tuyến để sao chép.

## Nghiệp vụ
- Tạo tuyến cố định theo một thứ ("Theo ngày") hoặc nhiều thứ ("Theo tuần"), lặp hằng tuần kể từ ngày áp dụng.
- Mỗi tuyến có một địa bàn và người phụ trách tự quản; nhiều địa bàn tạo nhiều tuyến riêng.
- Xem lịch tuần, tạm dừng/bật lại và sửa quy tắc. Quy tắc không cập nhật lại lịch sử.
- Khi chọn **Lập lịch ngày**, dùng chính `enqueueTripGraph` để lưu kế hoạch → tuyến → chuyến công tác 1 ngày bằng UUIDv5 ổn định cho rule + date. Mọi khách trong scope được nạp qua API ứng viên có phân quyền; không tạo khách/checkin/khảo sát giả.
- Chặn lập trùng địa bàn/ngày dựa trên kế hoạch hiện có hoặc outbox; server có ràng buộc UNIQUE và trả 409 nếu hai máy đua nhau.
- Không thay đổi `field_monthly_plans`, `field_day_routes`, `field_trips`, `field_work_sessions`, công tác dài ngày hoặc evidence.
- OfflineQueue theo tài khoản/revision lưu trên IndexedDB (PWA) và SQLite (native). Trường hợp offline cache cũ gây xung đột, bảo lưu outbox blocked cho xử lý thủ công.
- DB function kiểm tra quyền địa bàn ở mỗi lần lưu và version/audit; API GET chỉ cho owner còn quyền.

## UAT còn phải xác minh
DB migration 081; Cloudflare Worker/Vercel deployment; 1 thứ và nhiều thứ, liên tháng; lịch tháng đã có; 409 hai thiết bị; tạm dừng, đổi quyền/403; offline/reconnect; Android/GPS thực tế.
