# Production setup — Sales Miền Tây

## Đích đã xác minh

- GitHub: milktea-cus/MCP-FBMN, main; app ở apps/sales-mien-tay.
- Neon production: project raspy-bar-51596929, branch br-super-mountain-bdije4mj, database neondb; migration 001/002 đã áp dụng, không chạy lại theo cách destructive.
- Cloudflare account: e29ec156139b3750d875a9c45ed477ec; Workers subdomain milktea-cus. Worker name field-sales-api; URL dự kiến https://field-sales-api.milktea-cus.workers.dev (chỉ xác nhận live sau deploy).
- R2 private: sales-mien-tay-customer-media, binding PHOTOS_BUCKET.
- Vercel: sales-mien-tay, team_8KoQUR2ALt0Mc4eywJoz8wjH, prj_5fNaLxgkk5kYTKXKdY3NOKkFLnXQ, domain verified sales-mien-tay.vercel.app (chưa có deployment).
- Không tạo preview. Không đưa secrets vào git, Flutter --dart-define hay chat.

## 1. Điều Owner cần cung cấp/cấu hình

1. Định danh người dùng: chọn IdP đang dùng; issuer, audience của API, JWKS HTTPS và public client ID/redirect URLs. JWT ký RS256/ES256, có sub; role/roles từ issuer tin cậy mới được cấp manager/admin. Không tự cấp quyền admin dựa trên email hoặc dữ liệu client. Với OIDC, Flutter phải hoàn tất flow đăng nhập Authorization Code + PKCE trước khi mở cho sales; hiện access token tay chỉ để kiểm tra.
2. Neon: lấy pooled URL từ Connect của đúng DB production và đặt vào Worker secret DATABASE_URL, ưu tiên role dành riêng app với quyền tối thiểu; không gửi mật khẩu cho ai. Không tạo DB mới.
3. Cloudflare: nếu tự chạy CLI, đăng nhập wrangler hoặc đặt CLOUDFLARE_API_TOKEN trong môi trường riêng có quyền Workers Scripts Edit và quyền phù hợp để dùng R2; CLOUDFLARE_ACCOUNT_ID đã biết. Nếu dùng connector, xác thực đúng account trước. ALLOWED_ORIGINS chính xác https://sales-mien-tay.vercel.app.
4. Vercel: VERCEL_TOKEN có quyền project/team đã tạo. Chỉ cấu hình token ở môi trường riêng hoặc GitHub Actions secret; không ghi vào source. VERCEL_CLI_VERSION là phiên bản CLI đã chọn và kiểm tra. Không cần tạo project khác.

## 2. CLI Worker (CMD, Windows)

Chỉ thực hiện sau khi xác minh issuer/audience/JWKS và source CI. Từ repo root:

```bat
cd apps\sales-mien-tay\backend
npm install
npm run typecheck
set "CLOUDFLARE_ACCOUNT_ID=e29ec156139b3750d875a9c45ed477ec"
rem Dùng phiên đăng nhập wrangler hoặc đặt CLOUDFLARE_API_TOKEN an toàn.
rem AUTH_ISSUER, AUTH_AUDIENCE, AUTH_JWKS_URL đặt giá trị thật của IdP.
npx wrangler deploy --var "AUTH_ISSUER:%AUTH_ISSUER%" --var "AUTH_AUDIENCE:%AUTH_AUDIENCE%" --var "AUTH_JWKS_URL:%AUTH_JWKS_URL%" --var "ALLOWED_ORIGINS:https://sales-mien-tay.vercel.app"
npx wrangler secret put DATABASE_URL
```

Nhập pooled URL tại prompt của Wrangler, không đặt ở command line. Deploy lần đầu chưa có DB secret phải fail closed cho nghiệp vụ. Kiểm tra deployment thực tế và /health; /health chỉ chứng minh Worker sống, KHÔNG chứng minh database. Kiểm tra với admin/test JWT thật: API customers đọc được; token giả nhận 401; staff ngoài địa bàn 403; ảnh upload/read đúng quyền; R2 không public. Cấp staff scopes bằng admin API theo sub IdP xác minh và danh mục tỉnh/huyện. Chưa có nhân viên được phân quyền (0 rows khi kiểm tra).

## 3. Vercel production bằng CMD

Chỉ sau khi Worker live, login thật và các release gates đạt, từ repo root (Windows CMD):

```bat
git pull --ff-only origin main
set "API_BASE_URL=https://field-sales-api.milktea-cus.workers.dev"
rem VERCEL_TOKEN đã đặt an toàn trong môi trường.
rem VERCEL_CLI_VERSION đặt phiên bản exact đã kiểm tra (npm view vercel version để tham khảo).
call apps\sales-mien-tay\scripts\deploy-vercel.cmd
```

Script tự gắn project/team, generate platform scaffolding, analyze, test, build Flutter web và deploy CLI --prod; không deploy preview. Kiểm tra URL https://sales-mien-tay.vercel.app sau khi CLI báo thành công. Phiên bản hiện còn thiếu đăng nhập thật/offline/kiosk, không mở cho kinh doanh chỉ vì build xanh.
