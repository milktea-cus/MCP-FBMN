# Sales Miền Tây – Flutter Android + PWA + Cloudflare Workers + Neon

Đây là **bộ khởi tạo MVP từ 2 biểu mẫu Excel**, chưa phải sản phẩm production đã triển khai. Bản Flutter cho phép nhập và xem 7 loại nghiệp vụ; khi chưa cấu hình API, dữ liệu demo nằm trong bộ nhớ và mất khi thoát.

## Nguồn UI

Ngày kiểm tra: 2026-11-10. GitHub connector trả về `milktea-cus/MCP-FBMN` hiện **rỗng** (GitHub API trả 404 `This repository is empty.`). Vì vậy **không có bộ UI FBMN nào đã được sao chép**. `apps/sales_flutter/lib/theme.dart` chỉ là token Material 3 tạm thời và là điểm thay thế khi tìm được nguồn chuẩn. `milktea-cus/QR-app` là repo khác, không giả định có thiết kế FBMN.

## Thư mục

- `apps/sales_flutter/`: Flutter/Dart cùng source cho Android và web/PWA, 7 biểu mẫu + dashboard hiện diện 13 tỉnh.
- `apps/sales_flutter/assets/districts_old.json`: danh sách chuẩn 134 huyện theo 2 file Excel, lọc bỏ ghi chú ở cuối cột Long An.
- `backend/src/index.ts`: API Cloudflare Workers, JWT JWKS, CORS, giới hạn quyền.
- `backend/migrations/001_init.sql`: dữ liệu Neon PostgreSQL.
- `docs/DOMAIN_MAPPING.md`: ánh xạ các sheet và quy tắc tính.
- `docs/LOCKDOWN.md`: mức độ khóa có thể làm được bằng PWA và Android.

## Chạy giao diện

Yêu cầu Flutter SDK hỗ trợ Android/web. Máy sinh bộ khởi tạo chưa có Flutter SDK nên code Dart **chưa được biên dịch/kiểm thử build**.

```bash
cd apps/sales_flutter
flutter create --platforms=android,web .
flutter pub get
flutter run -d chrome
# hoặc kết nối máy Android rồi flutter run -d <device-id>
```

`flutter create` sẽ bổ sung các tệp nền tảng cần thiết (`android/`, `web/index.html`, icon...). Không dùng `--overwrite` để tránh đè `lib/` và `web/manifest.json` của starter.

### Chế độ demo

Mở app và nhập một khảo sát. Khi chưa kết nối API, chỉ lưu trong RAM. Không dùng chế độ này để lưu thông tin khách thật.

### Kết nối dữ liệu

Cần cấu hình nhà cung cấp OIDC cấp **access token** hợp lệ theo `AUTH_ISSUER`, `AUTH_AUDIENCE`, `AUTH_JWKS_URL`. Nút cài đặt trên app hiện chỉ hỗ trợ nhập token tạm thời trong RAM để **kiểm thử nội bộ**. Trước production, thay bằng đăng nhập OIDC/PKCE và kiểm thử trên web + Android.

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://<worker-domain>
flutter build web --release --dart-define=API_BASE_URL=https://<worker-domain>
```

### Triển khai web lên Vercel (sau khi `flutter build web` thành công)

```bash
cp vercel.json build/web/vercel.json
cd build/web
vercel --prod
```

Đăng nhập Vercel CLI đúng tài khoản/dự án của anh. Hiện chưa có deployment thực tế.

## Backend / Neon

1. Tạo database trong Neon; chạy `backend/migrations/001_init.sql` trên database **mới hoặc schema dành riêng cho app**, không chạy tùy tiện vào schema hiện có.
2. Cấu hình Cloudflare Worker trong `backend/`. `DATABASE_URL` phải là secret, tuyệt đối không commit vào Git.
3. Cấp các biến `AUTH_ISSUER`, `AUTH_AUDIENCE`, `AUTH_JWKS_URL`, `ALLOWED_ORIGINS` (origin PWA chính xác).
4. Cài dependency, typecheck và deploy sau khi xác thực môi trường.

```bash
cd backend
npm install
npm run typecheck
npx wrangler secret put DATABASE_URL
npx wrangler secret put AUTH_ISSUER
npx wrangler secret put AUTH_AUDIENCE
npx wrangler secret put AUTH_JWKS_URL
npx wrangler secret put ALLOWED_ORIGINS
npm run deploy
```

Lệnh dùng Wrangler theo cấu hình mẫu kèm trong starter; nếu công ty chuẩn hóa sang `cf` CLI thì chuyển cấu hình tương ứng. Chưa có secret hay môi trường nào được sửa/triển khai trong quá trình tạo starter.

Các route có sẵn:

- `GET /health` – kiểm tra worker sống (không cần xác thực).
- `GET /api/v1/meta` – danh mục tỉnh/huyện và loại nghiệp vụ (cần JWT).
- `GET /api/v1/records?kind=survey|target|forecast|visit|dealer|competitor|support` – tối đa 200 bản ghi/loại, lọc owner.
- `POST /api/v1/records` – tạo bản ghi.
- `PATCH /api/v1/records/{id}` – cập nhật nội dung/địa bàn; cần chuẩn hóa validation trước production.
- `DELETE /api/v1/records/{id}` – chỉ admin.

**Chưa có kết nối Neon, Cloudflare hoặc Vercel thật, không có thay đổi remote repo.** Để di chuyển nguyên bộ chuẩn UI FBMN sang repo đích, cần quyền truy cập nơi chứa thiết kế (không phải kho MCP-FBMN đang rỗng) và tên repo đích.

## Roadmap / kiểm soát chất lượng

- [Kế hoạch triển khai từng pha, điều kiện nghiệm thu và test](docs/IMPLEMENTATION_PLAN.md)
- [Kiểm tra nguồn bộ UI FBMN và điều kiện nhập](docs/UI_SOURCE_AUDIT.md)
- [Quy trình chuyển mã nguồn vào GitHub không ghi nhầm repo](docs/GITHUB_DELIVERY.md)

**Gói này chưa được push lên một repo Sales đích**, chưa có UI FBMN nguồn được chứng thực, chưa có build production. Không dùng bộ starter làm app cho dữ liệu khách thật.