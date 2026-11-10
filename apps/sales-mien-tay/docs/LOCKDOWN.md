# "PWA khóa cứng" - yêu cầu và giới hạn kỹ thuật

## Khóa truy cập và dữ liệu (khả thi trên PWA)

- Chỉ cho sử dụng sau đăng nhập OIDC/PKCE (chưa nối IdP trong khung demo).
- Backend xác minh JWT (issuer, audience, chữ ký) ở mọi route dữ liệu.
- Phân quyền sales chỉ xem bản ghi của mình; manager/admin có quyền tổng hợp; chỉ admin được xóa.
- Cấu hình `ALLOWED_ORIGINS` chính xác, HTTPS, session expiry, refresh/revoke token, rate limit ở Cloudflare.
- Định kỳ audit truy cập/chỉnh sửa; tách dữ liệu người dùng theo ID.
- Không lưu token trong localStorage, không đóng gói secret trong Flutter/Vercel.

## Khóa toàn màn hình / khóa thoát app (PWA không đảm bảo)

- Manifest `display: standalone` chỉ làm giao diện như ứng dụng, **không khóa nút Home/Back hay thanh thông báo**.
- Kiosk thực thụ trên Android cần thiết bị quản lý (Device Owner/MDM) và Android Lock Task Mode. Không tự bật Lock Task trên máy cá nhân tùy ý.
- Muốn chống can thiệp, xem xét Android Enterprise, quản lý máy, Play Integrity/API attestation, chính sách xóa từ xa (theo quyền công ty và sự đồng ý người dùng).
- iOS hay trình duyệt thường không thể giả lập khóa OS bằng PWA thuần.

## Trạng thái code hiện tại

- Có giao diện Flutter Material 3 cho PWA/Android và manifest PWA.
- Có Cloudflare API buộc JWT và phân quyền cơ bản.
- Chưa có OIDC/PKCE, đăng ký thiết bị, khóa thiết bị, mã hóa lưu bản nháp, đồng bộ offline hoặc thông báo push.
- Chế độ không API trong ứng dụng là **demo chỉ lưu RAM**, không nhập số điện thoại/thông tin khách hàng thật.