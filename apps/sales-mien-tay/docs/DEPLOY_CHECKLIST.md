# Checklist nghiệm thu ứng dụng Sales

- [x] Đọc các sheet và xác định 7 nhóm nghiệp vụ + dashboard.
- [x] Trích xuất 13 tỉnh/134 quận huyện cũ và dropdown phụ thuộc.
- [x] Form khảo sát riêng NPP và nhãn đối thủ Thành Đạt.
- [x] Dự kiến doanh thu 5 tuần; doanh số kỳ vọng đại lý không cộng vào tổng kế hoạch.
- [x] Dựng Flutter Material 3 UI tạm thời và manifest PWA.
- [x] Khung Cloudflare API bắt buộc xác minh JWT, phân quyền owner/manager/admin.
- [x] SQL khởi tạo Neon (chưa chạy trên database thật).
- [ ] Xác minh nguồn chính thức của bộ UI FBMN và thay token/widget tương ứng.
- [ ] Xác định chính xác repository nhận code; tạo nhánh/PR, không tự sửa repo khác.
- [ ] Chạy `flutter analyze`, `flutter test`, build Flutter web/Android trên máy có SDK.
- [ ] Cấu hình đăng nhập OIDC/PKCE và thiết bị được phép hoạt động.
- [ ] Thay bản demo RAM bằng hệ thống lưu bền/đồng bộ offline mã hóa.
- [ ] Chuẩn hóa bảng dữ liệu và thống kê SQL toàn bộ bản ghi, phân trang, xử lý trùng.
- [ ] Kiểm thử quyền với tài khoản sales/manager/admin, kiểm thử bảo mật input, CORS và session.
- [ ] Tích hợp Neon/Cloudflare/Vercel thật, thiết lập giám sát lỗi và backup.
- [ ] Nếu cần khóa OS: chuẩn bị thiết bị Android managed/kiosk với chính sách rõ ràng.
- [ ] Nghiệm thu số liệu thống kê đối chiếu Excel từ dữ liệu mẫu.