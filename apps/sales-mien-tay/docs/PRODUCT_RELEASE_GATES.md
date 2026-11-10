# Production-only execution plan — không dùng môi trường preview

## Hiện trạng (2026-11-10)

- GitHub `milktea-cus/MCP-FBMN` `main`: P0 starter merged, CI Flutter Web + TS typecheck + source guard đã xanh.
- Neon `raspy-bar-51596929` / branch `br-super-mountain-bdije4mj` (`production`): kết nối read-only thành công, lúc kiểm tra ban đầu `public` chưa có bảng ứng dụng.
- Cloudflare account `e29ec156139b3750d875a9c45ed477ec`: chỉ thấy Worker `qr-app-api-preview`; chưa có `field-sales-api` production.
- Vercel connected team hiện mới có `qr-app`, `qr-app-step11-smoke`; chưa có project Sales.
- **UI FBMN rules chưa được xác thực**. Tham chiếu từ ảnh `mcp-mobi` chỉ thể hiện 5 màn hình, không chứa source/giá trị tokens.

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