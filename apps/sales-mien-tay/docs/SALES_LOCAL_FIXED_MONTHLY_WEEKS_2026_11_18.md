# Sales Local — Hai tuyến cố định (18/11/2026)

## Luồng 1: T2–CN lặp hằng tuần
- Thiết lập chọn các thứ (T2–CN), không chọn ngày tháng.
- Mỗi địa bàn một tuyến; nhiều thứ cùng địa bàn tạo một rule.
- Phân hệ Công tác → Hôm nay gợi ý tuyến khi đến đúng thứ. Chỉ khi Sales nhấn Lập tuyến mới phát sinh lịch/công tác thực tế; GPS, khảo sát và kết quả không tự phát sinh.
- Bản ghi cũ có start_on được giữ nguyên; bản tạo mới mặc định hiệu lực từ 2000-01-01 để lặp liên tục, không ghi lại lịch sử.

## Luồng 2: Tuần 1–5 của tháng (mới, độc lập)
- Tuần 1=1..7, tuần 2=8..14, tuần 3=15..21, tuần 4=22..28, tuần 5=29..cuối tháng (nếu có), đúng planning_periods.dart.
- Mỗi phân công = tên nhiệm vụ + một tuần + một scope: toàn tỉnh/huyện, khách hoặc chuỗi. Cho phép nhiều phân công trong một tuần, lặp lại các tháng.
- Người phụ trách có thể chọn bất kỳ ngày chưa qua trong tuần và lập tuyến ngày; nhiều ngày trong cùng tuần đều hợp lệ.
- Dùng API options hiện tại để chọn scope đã cấp; server kiểm tra phân quyền lại tại hàm security definer. GET chỉ trả scope owner còn quyền.
- Số khách đã ghé thực tế / tổng số khách trong phạm vi được phép lập kế hoạch (đếm theo field_visits, riêng từng tháng và từng tuần). "Đủ lượt ghé" không có nghĩa tất cả khảo sát, đơn hay yêu cầu đã hoàn thành.
- Mỗi ngày thực thi giữ nguyên graph Kế hoạch tháng → Tuyến ngày → Chuyến trong OfflineQueue, không chỉnh sửa schema hoặc nghiệp vụ cũ. UUIDv5 chống trùng giữa thiết bị. Phân công pause/update chỉ ảnh hưởng ngày tương lai.
- PWA IndexedDB và native Android SQLite qua outbox chung; idempotent + optimistic version + audit table.
- Không tự xóa khách, khảo sát, lịch trình hay chuyến cũ.

## UAT
- Lưu T2 và T4 hàng tuần; quan sát card T2–CN không còn ngày.
- Tuần 1 cho một huyện; Tuần 2 cho huyện, chuỗi và một khách; Tuần 5 ở tháng 2 (28 ngày) không phát sinh, tháng 11 có ngày 29–30.
- Trong một tuần lập tuyến trên 2 ngày khác nhau; các lần được lưu độc lập. Bấm lại cùng ngày/phạm vi không sinh trùng.
- Thử tắt mạng khi lưu, đồng bộ lại; tạm dừng/bật lại; thu hồi quyền được trả 403; hai thiết bị xung đột 409.
- Thống kê lượt ghé lấy từ field_visits, không tự chốt hoàn thành các công việc khác.
- Nghiệm thu trên production Web và Android, không chỉ CI.
