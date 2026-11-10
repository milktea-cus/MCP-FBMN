# BÁO CÁO KIỂM TOÁN MÃ NGUỒN STARTER (chưa chạy build)

**Phạm vi:** kiểm tra tĩnh ZIP đầu vào và source giải nén; chưa có Flutter SDK/test integration, chưa kết nối Neon/Cloudflare thật.

| Mã | Mức | Quan sát có thể đối chiếu trong source | Ảnh hưởng | Hướng khắc phục / test |
| --- | --- | --- | --- | --- |
| F-01 | BLOCKER | `apps/sales_flutter/lib/theme.dart`: ghi rõ theme Material 3 tạm, không phải FBMN; repo UI được chỉ định rỗng | Chưa thể cam kết UI chuẩn FBMN | Tìm file gốc, provenance, UI review; không đưa nhãn FBMN vào app |
| F-02 | BLOCKER | `apps/sales_flutter/lib/main.dart`: `_settings()` yêu cầu nhập token tay, `_accessToken` RAM | Thiếu đăng nhập và phiên hoạt động thực tế | OIDC Authorization Code + PKCE, refresh/logout/revoke, test expiry |
| F-03 | BLOCKER | `_items` trong `main.dart` là RAM; `_addRecord` tạo `demo-...` khi không kết nối | Người dùng mất dữ liệu khi thoát | Offline database + encrypted storage + queue/idempotent sync; test kill/restart |
| F-04 | HIGH | `backend/migrations/001_init.sql` chỉ có bảng chung `sales_records` JSONB | Khó đảm bảo constraint nghiệp vụ, chống trùng điểm bán, phê duyệt, quyền theo tuyến | Tách normalized tables; migrations + ERD + rollback |
| F-05 | HIGH | `backend/src/index.ts`: manager kiểm tra `manager OR owner_sub=user.sub`, **không** giới hạn theo team/province | Manager có thể đọc/sửa ngoài tổ đội | Phân quyền territory/team dựa trên DB server; test cross-team 403 |
| F-06 | HIGH | `backend/src/index.ts`: PATCH cập nhật province/district độc lập và giữ giá trị cũ nếu không gửi; chỉ validate cặp có trong request | Có thể lưu province mới + district cũ sai địa bàn | Load record hiện tại, merge-validate toàn bộ trước UPDATE; test đổi tỉnh |
| F-07 | HIGH | `POST /api/v1/records`: chưa có idempotency key hoặc unique cho nhiều nghiệp vụ | Offline retry tạo hồ sơ trùng | Client UUID + unique request key + retry test |
| F-08 | HIGH | `target`/`forecast` chỉ validate 5 tuần **nếu** `data` được gửi; không bắt buộc khi `data` thiếu | Lưu kế hoạch thiếu weekly numbers | Schema validation theo từng kind + db constraints |
| F-09 | HIGH | PWA web shell/Android scaffold chưa có trong ZIP; `README` yêu cầu tự chạy `flutter create` | ZIP không build trực tiếp ngay | Scaffold platforms có chọn version, test Android/web, commit lockfiles |
| F-10 | HIGH | Không thấy thư mục `test/`, `integration_test/` hoặc test API | Không có bộ kiểm tra regression | Tạo unit/widget/API/migration/UAT cases; CI bắt buộc |
| F-11 | MEDIUM | `/api/v1/records` list tối đa 200 rows/kind, chưa phân trang | Dashboard có nguy cơ thiếu dữ liệu khi mở rộng | Server-side pagination, aggregate SQL, test >200 |
| F-12 | MEDIUM | `main.dart` dashboard tổng hiện diện duyệt `surveys` records thay vì keyed `outlet_id` | Nếu khảo sát lặp một điểm bán, số điểm bán có thể bị đếm nhiều lần | Outlet master + distinct IDs, snapshot historical survey rules |
| F-13 | HIGH | Không có mã Android `DevicePolicyManager`/Lock Task và không có cấu hình managed PWA kiosk | Yêu cầu “khóa cứng” chưa được đáp ứng | Chốt mô hình thiết bị, POC trên máy thật/managed browser; test escape routes |
| F-14 | HIGH | Không có CI/CD, monitoring, backups, staging hoặc release artifact xác minh được | Không sẵn sàng phát hành | CI + staging + UAT + backup/rollback + release checklist |

**Lưu ý:** Đây là báo cáo review tĩnh; severity là ưu tiên xử lý nội bộ, không tuyên bố đã tái hiện qua môi trường production. Gói Git-ready không tự sửa các blocker này; chúng là công việc bắt buộc của từng pha.