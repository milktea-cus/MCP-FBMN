# P0 — RCA production: Xóa lịch rollback và 409 tuyến trùng

**Ngày:** 14/11/2026  
**Phạm vi:** MCP-FBMN trên Neon production, Cloudflare Worker `field-sales-api`, Flutter PWA tại Vercel.

## Root cause có bằng chứng (không phải giả thuyết)

- Bản cập nhật 046 tạo `sales_archive_monthly_plan` với `INSERT INTO field_route_audit(action='cancel')`.
- Cấu trúc DB cũ lại có `field_route_audit_action_check = CHECK(action IN ('create','update'))`.
- Thực thi thao tác Xóa lịch ngay trên Neon production trả **SQLSTATE 23514**: `new row for relation "field_route_audit" violates check constraint "field_route_audit_action_check"`. Cả UPDATE tuyến và kế hoạch bị **rollback**; frontend trước đó chỉ nhận 503 chung nên người dùng xóa mãi không được.
- Lúc kiểm tra, tài khoản tạo lịch vẫn **active**, có 13 phạm vi phụ trách và `sales_monthly_plan_scope_allowed(...) = true`: không phải lỗi quyền.
- Lỗi **409 trùng tuyến** là vấn đề khác nhưng cùng luồng: `field_day_routes.monthly_plan_id` unique; PWA có thể gửi cùng kế hoạch với `client_ref` mới trong khi server đã lưu một tuyến. `field_route_stops` cũng unique theo khách/chuỗi/địa bàn. Outbox cũ giữ POST bị blocked.

## Sửa trực tiếp production và bằng chứng

1. Migration `047_route_audit_cancel_action.sql`: mở rộng CHECK thành `('create','update','cancel')`. Đã áp dụng trên Neon production và xác nhận lại catalog `pg_constraint` (DO assertion PASS).
2. Gọi **hàm quyền và audit thật** `sales_archive_monthly_plan` với kế hoạch công tác ngày 12/11/2026 tại Bình Đại, Bến Tre (version 1): **thành công**. Không dùng `DELETE FROM` và không phá lịch sử.
3. Đối chiếu sau xử lý: **0 kế hoạch active, 1 archived**; cả kế hoạch và tuyến ngày có `status='cancelled'`, version 2, audit action `cancel` ghi đủ trên hai bảng. Điểm tuyến vẫn lưu; 25 khách, 1 lượt ghé, 1 phiên khảo sát còn nguyên.
4. Gọi thử lại hàm archive trên chính bản ghi vừa xử lý trả `already_archived=true`, không tạo lịch hay audit trùng.
5. Backend `day_routes.ts` và Worker: POST tuyến/điểm ghé trùng **giống hoàn toàn** trả bản ghi đã lưu, khác nội dung vẫn trả 409. Chỉ trả canonical-ID acknowledgement cho PWA đã khai báo `X-Sync-Protocol: 2` hoặc khi cùng UUID; PWA cũ không bị mất liên kết con do hiểu nhầm 200. Worker CORS cho header mới, giữ nguyên 7 binding/secrets.
6. Flutter offline queue remap atomic `depends_on`, đường dẫn stop, payload (route_stop_id/day_route_id) khi server trả `already_saved`, đọc lại queue trước khi gửi con. Với tuyến đã archive và không có bản nháp/khảo sát/lượt ghé, dọn riêng POST chờ trùng; **không tự xóa** operation có dữ liệu công tác phụ thuộc.
7. `backend/scripts/check_work_audit_contract.mjs` chạy trong `build-vercel.sh`: chặn build nếu thiếu constraint `cancel`, hàm archive, chống trùng hoặc giao thức an toàn.

## Kiểm thử

- **Neon transaction integration**: trước migration tái hiện SQLSTATE 23514; sau migration thực thi archive thành công và có audit thực tế; gọi lại idempotent PASS.
- Backend TypeScript typecheck và schema contract 6 checks PASS tại Vercel.
- Flutter test: 203/203 đạt ở lượt build mới nhất, gồm Xóa lịch 320/360/390 px, 409 trùng route/stop, remap canonical ID, bảo vệ khảo sát offline, đối chiếu lịch đã archived.
- Worker API phiên bản production có archive + duplicate reconciliation + header compatibility, deployment 100% (binding/secrets được giữ).

**Lưu ý nghiệm thu:** Không thể truy cập bản ghi IndexedDB riêng của iPhone Owner hoặc thực hiện thao tác người dùng có đăng nhập trên thiết bị thật từ API quản trị. Sau khi bản web mới READY, cần xác nhận PWA tải mã mới và outbox trên máy giảm, nếu trước đó có operation đã được server ghi. Không khuyến nghị xóa cache/site data hoặc gỡ PWA. Không hứa hết mọi lỗi tương lai: guard bảo vệ đúng các nguyên nhân đã tái hiện ở đây.
