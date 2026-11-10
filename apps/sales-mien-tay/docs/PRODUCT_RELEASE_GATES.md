# Production-only execution plan — không dùng môi trường preview

## Hiện trạng (2026-11-10)

- GitHub `main`: source Sales, API và Flutter đã tích hợp; CI trước chuẩn hóa UI xanh. Commit `725752ec` đưa tài liệu FBMN gốc và theme vào main; kiểm tra CI commit mới riêng.
- Neon `raspy-bar-51596929` / `br-super-mountain-bdije4mj` (`production`), database `neondb`: migration 001/002 đã áp dụng, 6 bảng nghiệp vụ; khách hàng và staff scopes hiện 0.
- Cloudflare account `e29ec156139b3750d875a9c45ed477ec`: bucket private `sales-mien-tay-customer-media` đã tạo, binding đã thêm vào wrangler.toml; Worker chưa deploy; đích dự kiến `field-sales-api.milktea-cus.workers.dev`.
- Vercel project production `sales-mien-tay`, domain đã gắn `sales-mien-tay.vercel.app`; chưa deploy. Script CMD `scripts/deploy-vercel.cmd` đã tạo.
- UI FBMN chính thức đã xác thực và lưu ở `standards/ui-fbmn/source/` theo commit nguồn `1ad3970a3c7f133932b47fb81d27c104c12deb5d`; theme và token test đã áp dụng. Modal/drawer/toast/motion đầy đủ và UAT chưa hoàn tất.
- Xem `PRODUCTION_SETUP.md` cho phần cấu hình còn thiếu; không nhập credential vào repo.

## Kế hoạch theo đường production, không tạo preview branch

| Bước | Công việc trên main/product | Bằng chứng để nghiệm thu |
|---|---|---|
| 1. Data | Additive migrations `001_init.sql` + `002_customers_visits_photos.sql`, kiểm tra bảng + constraint trên Neon production; backup trước khi có dữ liệu thật | `information_schema`, policy; không DROP, không ghi đè bảng hiện có |
| 2. API | Scope RBAC sales/manager/admin, customer CRUD, photo upload/download via private R2, GPS check-in idempotent; negative tests | Typecheck, auth/ownership/territory test, 401/403/409/413/422 |
| 3. Flutter | Trang khách hàng, tạo điểm bán, GPS/photo, danh sách chi tiết, check-in; Android+PWA build | `flutter analyze`, `flutter test`, Android build và test thiết bị |
| 4. Identity+media | OIDC issuer/audience/JWKS, `ALLOWED_ORIGINS`, Neon pooled DATABASE_URL (secret), R2 `PHOTOS_BUCKET`; cấp staff scopes | Runtime API smoke test với token giả 401 và user thật, ảnh upload/read private |
| 5. UI | Gốc FBMN chuẩn hoá tokens/font/components, golden tests; chỉ dùng `mcp-mobi` tham khảo flow | Document nguồn chính xác commit SHA và test ảnh đối chiếu |
| 6. Business | Route/tuyến, order catalog/pricing, báo cáo ảnh/đối thủ, offline queue bền vững, survey–target–forecast | Kịch bản UAT theo hai Excel, đối chiếu số liệu/quyền |
| 7. Release | Vercel **CLI** `--prod`, Cloudflare worker live, Android signed AAB/APK, logging+backup, rollback | Production smoke test, URL, release artifact, không demo/token tay |

## DoD và chặn phát hành

- **Không tạo preview deployment.** Commit trên `main` chỉ được xem là source integration, không tự động publish dữ liệu thực.
- Không dùng các dự án `qr-app*` làm Sales. Không deploy Worker vào tên `qr-app-api-preview`.
- Chưa có OIDC thật, Neon URL/R2 secret/binding, CI integration+security test → **không publish Worker/API có quyền dữ liệu**.
- PWA browser không thể khóa OS thật; Android kiosk cần Device Owner/MDM, không ghi nhãn "khóa cứng" khi chỉ fullscreen.
- Dữ liệu khách/địa chỉ/GPS/ảnh chỉ lưu khi người dùng có quyền, cấp consent; dùng HTTPS, R2 private, TTL/retention hợp lý.
- DB production không destructive migration; thay đổi schema phải có kiểm tra compatibility và backup.