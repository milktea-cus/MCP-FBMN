# P0 — Xử lý hàng đợi đồng bộ PWA/iPhone bị đứng

**Ngày:** 14/11/2026  
**Lý do:** Owner phản ánh trên iPhone Field Work có `Chờ đồng bộ: 1 · Cách ly: 0`, dòng `Đang đồng bộ` kéo dài qua ngày.

## Kiểm tra mã nguồn

- `OfflineQueue.sync()` cũ chạy bằng timer 30 giây, mỗi lần lại kiểm tra `GET /api/v1/me` rồi xử lý toàn bộ queue. Nếu 503/timeout, có thể thử lặp liên tục mà không chỉ ra khi nào thử lại.
- API lỗi 4xx được giữ `status=blocked` nhưng banner vẫn có thời điểm báo `Đang đồng bộ`/không nêu nguyên nhân. Dialog hàng đợi chỉ hiện tên mơ hồ và không có số lần thử/đường nghiệp vụ.
- Các thao tác không gắn session/photo trước đây ép phản hồi thành công luôn có `result['item'] as Map`. Với API chỉ trả `{ok:true}`, lỗi client sau 2xx khiến thao tác đã được server nhận vẫn ở hàng đợi, thử lặp.
- iOS PWA có thể đình chỉ request/IndexedDB Future khi đưa app vào nền; trước đây không có cảnh báo cho lượt đồng bộ kéo dài bất thường.

## Bản sửa trên main

- `apps/sales-mien-tay/apps/sales_flutter/lib/offline_queue.dart`: lỗi tạm thời dùng exponential backoff có giới hạn 30–300 giây, tự động không retry khi tất cả mục đang blocked, không xóa hàng đợi trên lỗi; thành công `2xx` không `item` vẫn xác nhận cho các nghiệp vụ không cần entity; giữ kiểm tra `item` bắt buộc riêng cho ảnh/phiên.
- Ghi `HTTP status`, thông điệp lỗi và thời gian vào row; xuất `lastAttemptAt`, `lastSuccessAt`, `nextRetryAt`, `activePath`, `blockedCount`, `transientFailures`.
- `sync(manual:true)` bỏ qua backoff nếu người dùng chủ động chọn thử lại; `retryBlocked(key)` chỉ mở đúng row của cùng namespace tài khoản/phạm vi rồi thử. Tác vụ 403/409 không tự biến mất.
- Nếu lượt đồng bộ treo quá 2 phút: cảnh báo đóng rồi mở lại PWA để tiếp tục, **không khởi động thêm một request song song** vì có nguy cơ ghi trùng/đụng hàng.
- `lib/main.dart`: chạm banner tím mở dialog có tên nghiệp vụ (`Bắt đầu phiên khảo sát`, `Hoàn tất phiên khảo sát`, `Ảnh khảo sát`, `Khách hàng`, v.v.), trạng thái, giờ tạo, số lần thử, mã lỗi cuối cùng, các phụ thuộc, nút `Thử gửi lại` hoặc `Thử ngay`. Không hiển thị cookie, token hoặc body nhạy cảm.

## Kiểm thử và bảo toàn dữ liệu

- `test/offline_queue_test.dart`: thêm 3 test: API 200 chỉ trả `ok` gỡ đúng row; lỗi 503 không mất row khi mở lại database và không spam check khi chưa tới thời gian retry; 409 được giữ blocked và thao tác retry rõ ràng.
- Build Vercel: backend TS typecheck, Flutter analyze --no-fatal-infos, `flutter test` và `flutter build web`. **183/183 Flutter tests đã đạt** ở lượt build bản cuối.
- Không có migration Neon, không đổi Cloudflare bindings, không đụng production data.
- **Không xóa IndexedDB, không logout/xóa app/xóa dữ liệu Safari để xử lý**, vì row đang chờ chỉ nằm trong điện thoại.
- Không thể biết chính xác row đang chờ của Owner từ server; phải dùng dialog mới trên PWA để xem loại thao tác + mã lỗi sau khi máy tải mã web mới. 401/403/409 do quyền hoặc dữ liệu thực tế có thể vẫn cần xử lý từng bản ghi, không được báo đã giải quyết nếu hàng đợi chưa nhận được ACK.
