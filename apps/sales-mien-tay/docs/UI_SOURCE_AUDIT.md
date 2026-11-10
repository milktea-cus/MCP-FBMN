# UI FBMN — SOURCE AUDIT / PROVENANCE

Ngày kiểm tra: 2026-11-10.

1. URL được người dùng cung cấp qua cấu hình dự án: `https://github.com/milktea-cus/MCP-FBMN.git`.
2. GitHub connector (tài khoản `milktea-cus`) trả về repo `MCP-FBMN`, `size=0`, và truy vấn contents báo `This repository is empty.`.
3. Tìm kiếm `FBMN` trên GitHub không cho ra bộ UI trong tài khoản. Tìm Project files với `FBMN` / `UI_RULES` không có kết quả.
4. Repo `milktea-cus/QR-app` có các thư mục `core/theme`, `core/ui`, và `docs/PWA_STANDARD.md`, nhưng là **một repo riêng**; không có bằng chứng đó là bộ quy tắc FBMN. Không nhập nhằng nguồn.
5. Starter chỉ có `apps/sales_flutter/lib/theme.dart` tạm dùng Material 3. Không có bộ file FBMN nào được sao chép.

## Khi tìm thấy bộ UI thật

- Lập danh sách tệp, fingerprint SHA-256, commit nguồn, license, quyền sử dụng.
- Giữ bản snapshot gốc ở `design/fbmn-source/` và ghi rõ version; tuyệt đối không biến code phỏng đoán thành snapshot.
- Mở PR riêng `feat/ui-fbmn-adapter` với token mapping, widgets, screens, golden screenshots và báo cáo sai khác.
- Chỉ được đánh dấu `FBMN UI integrated = true` sau khi tất cả token/components/screen trạng thái cần thiết qua review.

Status hiện tại: `BLOCKED_SOURCE_NOT_FOUND`.