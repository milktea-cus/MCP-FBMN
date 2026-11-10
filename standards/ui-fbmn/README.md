# UI FBMN — nguồn chuẩn và kiểm soát tích hợp

## Trạng thái kiểm chứng (2026-11-10)

`milktea-cus/MCP-FBMN` là repo rỗng tại thời điểm bắt đầu. Chưa tìm thấy bộ quy tắc UI FBMN gốc trong repo này hoặc file đính kèm của dự án. Không có căn cứ để tuyên bố UI Flutter hiện tại là UI chuẩn FBMN.

Đã kiểm tra và chuyển **bản tham chiếu** từ repo `milktea-cus/QR-app` vào `standards/references/qr-app/`, giữ đường dẫn tương đối:

- `docs/PWA_STANDARD.md`
- `core/theme/README.md`, `core/theme/apply-theme.js`
- `core/ui/README.md` (nếu có trong nguồn), `core/ui/catalogue.js`, `core/ui/cta.js`, `core/ui/interactions.js`

**Lưu ý:** QR-app có thể là dự án liên quan nhưng KHÔNG được tự động coi là bộ chuẩn FBMN chính thức. Mã JS không thể chép nguyên sang Flutter/Dart: cần xác thực design tokens, typography, spacing, states, accessibility, responsive và tạo component Dart tương ứng.

## Điều kiện hoàn thành P2 — UI chuẩn

1. Xác minh bộ quy tắc gốc, owner, commit hash và phạm vi tái sử dụng.
2. Danh mục `tokens`, component states và screenshot baseline có nguồn đối chứng.
3. Áp dụng tokens cho Flutter theme, forms, navigation, tables và PWA responsive.
4. Widget/golden tests và review khác biệt Android/web.
5. Chỉ sau review mới được đổi trạng thái “UI FBMN verified”.

Không đưa brand màu, font hoặc hành vi từ repo QR-app thành tiêu chuẩn FBMN khi chưa có bằng chứng.
