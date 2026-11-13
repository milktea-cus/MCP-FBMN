> **ĐÃ ĐIỀU CHỈNH NGHIỆP VỤ 14/11/2026:** Phần nhãn hàng **Tổng quan** dưới đây từng dùng nhãn SKU, nay không còn đúng. SKU toàn bộ thuộc Futurebook; thống kê thị trường chỉ dùng nhãn mà Sales ghi nhận tại **từng khách/phiên Công tác**, đếm một lần cho mỗi khách–nhãn và cho phép tìm theo tỉnh/huyện. Xem tài liệu chính thức thay thế: [P0-3 — Nhãn hàng thị trường](P0_3_MARKET_BRANDS_CORRECTION_2026_11_14.md). Tài liệu cũ được giữ lại làm lịch sử, **không dùng làm đặc tả hiện hành**.

# P0-3 — Danh mục nhãn hàng dùng chung (13/11/2026)

## Phạm vi đã đưa vào mã nguồn

- **Neon (additive):** migrations `043_brand_customer_links_and_aliases.sql` và `044_customer_brand_audit_reader.sql`. `catalog_products.brand_id` tham chiếu `catalog_brands.id`, giữ nguyên `brand` chữ cũ. Alias chỉ do Admin thêm, có nhật ký và ánh xạ SKU cũ sang ID chuẩn mà không xóa/chỉnh văn bản nguồn.
- **Điểm bán:** `customer_brand_verifications` chứa từng cặp khách–nhãn, trạng thái đang bán được nhân viên xác minh riêng với lý do, phiên bản, UUID chống trùng; audit bất biến; DB và API kiểm `sales_customer_allowed(...,'edit')`, phân quyền view riêng.
- **Khảo sát:** Admin có nút `Dùng nhãn hàng chuẩn` để tạo **phiên bản mẫu mới**, lựa chọn từ nhãn active; API xác minh danh mục tại lúc phát hành. Mẫu cũ và câu trả lời lịch sử không đổi. Nhãn được quan sát trong khảo sát **không tự động** là nhãn đang kinh doanh.
- **Báo cáo:** `/api/v1/catalog/brand-coverage` đếm khách duy nhất theo tỉnh và từng nhãn ID; tách 3 trạng thái `Đang bán` (xác minh SKU hoặc nhãn), `Đã nhập`, `Đã đặt`. Lọc quyền xem từng khách tại API. Không suy luận giao dịch hoặc trả lời khảo sát thành xác minh bán hàng.
- **Flutter:** Admin mở `Danh mục SKU → Nhãn hàng` để tạo nhãn, alias và ngừng kích hoạt; SKU tìm/hiển thị tên chuẩn. Hồ sơ khách, phần sản phẩm có panel `Nhãn hàng tại điểm bán` để đọc/xác minh nhãn; hàng đợi offline tách account/scope_revision. Mẫu khảo sát chọn danh mục chuẩn; Tổng quan có dropdown so sánh 3 trạng thái.
- **Kiểm thử:** bổ sung `customer_brand_test.dart` kiểm request, header sync identity/revision, phân tách ba trạng thái, persistence offline, cách ly revoke account, widget mobile 360px. `build-vercel.sh` nay chạy backend TypeScript typecheck trước Flutter analyze/test/build.

## Nguồn dữ liệu có thật và quy tắc không tự suy diễn

Neon production tại lúc audit: **609 SKU**, **25 khách**, **13 mẫu khảo sát tỉnh**, **0 nhãn chuẩn**, **0 dòng xác minh khách–SKU**. Cả 609 SKU đều có `catalog_products.brand IS NULL`; cơ sở Store nguồn đã kiểm tra không có trường nhãn/brand trong bảng `products`. Không tự tạo nhãn `Futurebook` hoặc gán nhãn theo tên sản phẩm vì chưa có dữ liệu xác nhận, tránh sai báo cáo.

Để phát sinh số liệu thực tế: Admin tạo nhãn chính thức, cập nhật nhãn trên SKU hoặc alias nếu có tên cũ; Sales xác minh SKU hoặc nhãn đang bán tại khách; Admin phát hành **mẫu khảo sát phiên bản mới** có câu hỏi nhãn hàng chuẩn. Các trạng thái `đã đặt` và `đã nhập` lấy từ chứng từ hiện hữu, không làm tăng `đang bán` khi thiếu xác minh.

## Bằng chứng hạ tầng

- Migrations 043 (20 statements) và 044 (3 statements) áp dụng Neon transaction thành công, dữ liệu SKU/khách gốc không xóa. `sales_api` được quyền EXECUTE hàm nghiệp vụ; PUBLIC không được quyền; audit raw không cấp SELECT cho `sales_api`.
- Cloudflare Worker `field-sales-api` được cập nhật **trên script hiện hữu**, deployment `07218691-e76d-4f5e-be1c-eb457b5fbb91` 100%. Đã kiểm tra code có p03BrandRoutes, alias/verify, survey-version guard, canonical SKU; **giữ nguyên bảy binding/secret** gồm Neon/R2/push. Script bundle đã upload được Cloudflare xác nhận; chưa có kiểm thử HTTP đăng nhập production vì môi trường không truy cập được URL public trực tiếp.
- Code tới SHA `f38a80ddeff27e1d69d07e924b4cd2172ee55320`. Vercel production deployment `dpl_A41CxAnz1RexaShhattCJ3sEGjK7` từ chính SHA này **READY**; `npm --prefix ../../backend run typecheck` PASS, Flutter analyze `--no-fatal-infos` PASS (còn thông tin lint), **179 Flutter tests PASS**, Flutter web release PASS, offline shell 42 assets, production aliases của project hiện hữu được duy trì. Link: `https://sales-mien-tay.vercel.app` (HTTP browser UAT chưa có bằng chứng do môi trường không mở được website).
- Chưa đóng P0-J: UAT tạo nhãn/SKU/khách/khảo sát thực bằng tài khoản Admin–Manager–Sales trên mobile, offline/revoke/thiết bị Android, snapshot sau import Excel, production HTTP 401/403/409 là cổng riêng.

## Các API chính

`GET /api/v1/catalog/brands`, `POST /api/v1/catalog/brands`, `PATCH /api/v1/catalog/brands/:id`, `POST /api/v1/catalog/brand-aliases`, `GET /api/v1/catalog/brand-coverage`.

`GET /api/v1/customers/:id/brands`, `POST /api/v1/customers/:id/brands`, `GET /api/v1/customers/:id/brands/audit`. Khảo sát vẫn qua `/api/v1/survey-templates` và `/api/v1/sessions`.

**Không dùng GitHub Actions quota**, không tạo repo/app khác, không mở R2 công khai, không sửa secrets, không tạo khách/SKU giả.
