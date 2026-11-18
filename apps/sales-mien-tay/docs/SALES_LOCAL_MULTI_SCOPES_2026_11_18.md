# P0: Đa chọn trong hai loại tuyến cố định — 18/11/2026

- Tuyến lặp theo **thứ trong tuần** và tuyến lặp theo **Tuần 1–5 của tháng** đều dùng một bộ chọn chung, có lọc theo tỉnh/huyện, khách và chuỗi; chuyển tab/tìm kiếm không làm mất các lựa chọn đã tích.
- Một tuyến có một tên, một kỳ, tối đa 50 phạm vi hỗn hợp. Có thể xóa từng chip hoặc chọn lại trước khi lưu. Không cần chia thành nhiều tuyến chỉ vì các phạm vi khác loại.
- Lưu nguyên danh sách `scopes` vào từng quy tắc; cấp quyền cho *mọi phạm vi* bằng `sales_local_scopes_allowed` ở Neon. API không bỏ bớt lựa chọn không hợp lệ để lưu nửa chừng. Bảng audit, version, client_ref và khóa ghi trực tiếp được giữ.
- Trường legacy của hai bảng chỉ là phạm vi đầu tiên để tương thích với ứng dụng cũ. Bản Android cũ không được sửa một quy tắc nhiều phạm vi để tránh làm rơi dữ liệu.
- **Lập tuyến:** dùng phạm vi đầu tiên làm neo Kế hoạch tháng cũ, đưa **toàn bộ các phạm vi** vào chuyến (`field_trip_scopes`). Endpoint candidates hiện có đọc hợp của tuyến và chuyến, nên không mất khách của địa bàn/chuỗi thứ hai.
- Thống kê khách tháng dùng EXISTS trên toàn bộ scopes; mỗi khách chỉ đếm một lần ngay cả khi thuộc nhiều phạm vi. GPS và khảo sát chỉ tính khi đã thực hiện.
- Chọn nhiều chỉ tạo một tuyến/chuyến khi Sales bấm Lập tuyến; không tự ghi lịch sử.
- OfflineQueue dùng IndexedDB trên Web/PWA và SQLite trên Android, quyền được server kiểm tra lại khi đồng bộ. Xung đột version/dupe được giữ trong hàng đợi.
- Không chỉnh sửa schema field_monthly_plans, field_day_routes, field_trips hay lịch sử đã chạy.

Nghiệm thu: tích 2 huyện + 1 chuỗi + 1 khách trong cùng một tuyến hằng tuần và một tuyến tháng; lưu, tải lại, sửa, tạm dừng, tạo một ngày thực hiện; kiểm tra endpoint candidates có đủ khách và không đếm trùng; offline + đồng bộ; thu hồi quyền tại backend; bản Web + APK rc.9.
