# MCP-FBMN — P0-3 sửa nghiệp vụ nhãn hàng THỊ TRƯỜNG

**Ngày:** 14/11/2026  
**Quy tắc Owner:** SKU là mã hàng của **Futurebook**. Bảng nhãn hàng ở Tổng quan **không dựa vào SKU, đơn hàng, tồn kho hay danh mục sản phẩm**. Nó là dữ liệu nhãn/đối thủ Sales quan sát tại từng khách trong Công tác → Khảo sát.

## Mô hình đúng

- **SKU (product catalog):** 609 SKU hiện hữu được gắn nhãn sản phẩm Futurebook (Neon migration 045). Điều này không tạo **bất kỳ** lần hiện diện thị trường nào.
- **Nhãn thị trường (`market_brands`):** Danh sách tên nhãn quan sát ở khách, ví dụ MGP và Thành Đạt; không phải `catalog_brands` của SKU.
- **Hiện diện hiện tại (`market_customer_brands`):** Khóa chính `(customer_id,brand_id)`, trạng thái `present`, lần đầu thấy, lần gần nhất thấy và phiên khảo sát gần nhất. Chỉ lấy khách thật; khu vực tỉnh/huyện từ hồ sơ khách hiện tại.
- **Lịch sử (`market_survey_brand_observations`):** Mỗi phiên khảo sát lưu các nhãn đã gặp, khóa `(session_id,brand_id)`. Dùng làm lịch sử, **không cộng số lần** trong Tổng quan.
- **Khảo sát:** Mục `Nhãn hàng đang thấy tại điểm bán` chọn nhiều từ nhãn đã gặp hoặc tự gõ tên mới; nhập `MGP, Thành Đạt` tại câu checklist `brands` cũ cũng tự đưa vào danh sách. Có checkbox xác nhận kiểm tra: không chọn thì không thay đổi dữ liệu hiện diện; xác nhận và không chọn nhãn nghĩa là hiện không thấy nhãn nào. Mỗi lần hoàn thành khảo sát, DB cập nhật ảnh chụp nhãn mới nhất **trong cùng giao dịch hoàn thành phiên**, kiểm quyền và ảnh bắt buộc.
- **Tổng quan:** API `/api/v1/market/brands`, `/api/v1/market/coverage`, `/api/v1/market/customers` phục vụ lọc nhãn, tỉnh/huyện, tìm khách và hiển thị đếm khách duy nhất trên từng nhãn. Tất cả truy vấn khách áp dụng `sales_customer_allowed(actor,customer_id,'view')` tại backend. Không nối dữ liệu `catalog_products`, `customer_product_assortment` hay `catalog_brands` vào các thống kê.
- **Hồ sơ khách:** Nhãn thị trường đọc từ `/api/v1/market/customers?customer_id=...` và hiển thị lần gần nhất gặp; phần SKU của khách vẫn riêng biệt.
- **Offline:** Draft và payload `market_brands` đi cùng PATCH hoàn thành khảo sát qua IndexedDB (theo account/scope revision); SQL dùng `ended_at` để ngăn gói đồng bộ cũ làm đảo ngược kết quả quan sát mới.

### Ví dụ tính đúng

| Khách | Tỉnh/huyện | Phiên khảo sát | Nhãn nhìn thấy | Tổng quan MGP | Tổng quan Thành Đạt |
|---|---|---|---|---:|---:|
| A | Sóc Trăng / Mỹ Xuyên | Tháng 11 | MGP, Thành Đạt | 1 | 1 |
| A | Sóc Trăng / Mỹ Xuyên | Tháng 12 | MGP, Thành Đạt | **1** | **1** |
| B | Sóc Trăng / Mỹ Xuyên | Tháng 12 | MGP | **2** | **1** |

Các con số ở ví dụ chỉ minh họa logic, **không ghi khách giả vào production**. Nếu khảo sát mới của A xác nhận chỉ còn MGP thì Thành Đạt tại A chuyển `present=false`, lịch sử cũ vẫn còn.

## Thay đổi repo / hạ tầng

- Migration: `backend/migrations/045_market_brand_sightings.sql`, additive, tạo 3 bảng mới và chức năng `sales_complete_survey_market`. 609 SKU vốn chưa có brand đã được gắn chính xác Futurebook theo xác nhận Owner.
- Backend: `backend/src/market.ts`, `src/index.ts`, `src/surveys.ts`, truy vấn độc lập từ SKU và scope permission.
- Flutter: `lib/surveys.dart`, `lib/main.dart`, `lib/customer_assortment.dart`; sửa các kiểm thử survey, Tổng quan và customer profile.
- Cloudflare Worker production: cập nhật script hiện hữu, giữ nguyên 7 secret/binding/R2; không tạo Worker thứ hai.
- Vercel production Flutter: `build-vercel.sh` thực hiện backend TS typecheck → Flutter analyze → flutter test → web release → offline shell.
- Dữ liệu sản xuất sau migration: 609/609 SKU có brand Futurebook, **25 khách thật**, **0 phiên khảo sát completed**, **0 nhãn thị trường**. Không bịa dữ liệu MGP/Thành Đạt; chúng sẽ xuất hiện khi Sales hoàn thành khảo sát thực tế.

## Nghiệm thu / chưa kết luận

Cần kiểm tra các mục DB schema+permission, Flutter tests và build production; nhưng **không gọi UAT thực tế là đạt** khi chưa có kiểm tra đăng nhập HTTP, khảo sát GPS/ảnh, đồng bộ offline trên điện thoại và tài khoản Sales–Manager.

**Bản ghi này thay thế định nghĩa KPI nhãn hàng dựa vào SKU ở biên bản P0-3 trước đó.**

## Bằng chứng triển khai 14/11/2026

- **Neon production:** migration 045 transaction 15 statements PASS; kiểm tra 609 SKU được map Futurebook, 25 khách thật giữ nguyên, ràng buộc unique `market_customer_brands(customer_id,brand_id)`, hàm `sales_complete_survey_market` chỉ `sales_api` có EXECUTE và PUBLIC không có. SQL `EXPLAIN` thống kê theo tỉnh/huyện, quyền đọc theo khách chạy thành công.
- **Cloudflare Worker:** deployment `89e16492-385d-4b84-807f-db9d23b0a072` **100%**, đã xác nhận route market, survey atomic + bridge đọc checklist offline cũ trong bundle production. Giữ nguyên 7 binding/secret hiện hữu.
- **Vercel production:** `dpl_C9d9c5H9VW3dhx1cDxijTVFxmA4c` **READY**, code SHA `b87e9adec8012192cae0759af515e24dd3030146`, source backend TypeScript typecheck PASS, Flutter analyze --no-fatal-infos PASS, **180/180 Flutter tests PASS**, web release PASS, offline shell 42 assets. Production alias `https://sales-mien-tay.vercel.app`.
- **UAT chưa xác minh:** hiện không có phiên `field_survey_sessions` hoàn thành trong production, nên 0 quan sát nhãn thị trường là đúng; không tạo MGP/Thành Đạt hoặc khách giả. Chưa có end-to-end HTTP thật với GPS+ảnh, người dùng Sales/Manager và offline phone; không tuyên bố nghiệm thu thiết bị đã đạt. Worker production được cập nhật bằng patch trên compiled script hiện hữu vì môi trường không có backend build local; TypeScript source đã được typecheck trong Vercel.

