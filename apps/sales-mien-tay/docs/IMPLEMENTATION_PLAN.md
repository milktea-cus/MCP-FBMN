# KẾ HOẠCH TRIỂN KHAI CÓ CỔNG NGHIỆM THU — SALES MIỀN TÂY

**Trạng thái:** kế hoạch triển khai, chưa phê duyệt UI nguồn, chưa deploy.  
**Ngày lập:** 2026-11-10.  
**Đầu vào được kiểm tra:** 2 file Excel do anh cung cấp và `Sales_Mien_Tay_Flutter_PWA_Starter.zip`.  
**Đích sản phẩm:** Flutter/Dart dùng chung Android và PWA; Cloudflare Workers; Neon PostgreSQL; web có thể triển khai Vercel.  
**Nguyên tắc:** không đưa mã demo vào production; không đoán quy tắc FBMN khi chưa có file gốc; không chỉnh repository ngoài phạm vi; mỗi hạng mục qua kiểm thử, review và nghiệm thu mới chuyển pha.

## 0. Trạng thái nguồn và repo

- GitHub account đã kết nối: `milktea-cus`, có quyền `push` lên `milktea-cus/MCP-FBMN` và `milktea-cus/QR-app` tại lúc kiểm tra.
- `milktea-cus/MCP-FBMN` là repository **rỗng**; không chứa commit/tài liệu UI có thể lấy qua contents API.
- `milktea-cus/QR-app` là ứng dụng khác, **không** mặc định là nguồn FBMN hay repo đích.
- Chưa được chỉ rõ repository đích dành cho app Sales. Không push vào một repo hiện hữu chỉ vì có quyền.
- Tool GitHub kết nối tại thời điểm kiểm tra có ghi file, nhánh và PR, nhưng **không có action tạo repository mới**. Nếu chưa có repo đích, cần anh tạo repo trống hoặc cung cấp repo đã tạo.
- Tài liệu UI FBMN: **CHƯA TÌM THẤY** trong repo MCP-FBMN/Project files; không sao chép UI ước đoán.

### Quy tắc nhập repo

1. Xác minh owner/repo đích, loại môi trường (dev, staging, prod), quyền ghi.
2. Kiểm tra cấu trúc repo và branch protection; sao lưu commit nền nếu repo có code.
3. Đưa **file nguồn đã giải nén** thay vì một ZIP nguyên khối; loại `.env`, khóa, private key, build artifacts, dữ liệu khách hàng thực.
4. Tạo branch `feature/sales-mientay-foundation` từ nhánh chính; commit theo module; mở **draft PR** có checklist và diff để review. Không auto-merge, không tự động deploy.
5. Không ghi vào repo `QR-app` và không biến repo `MCP-FBMN` thành dự án sales khi chưa xác nhận đây là repo đích.

## 1. Mục tiêu và phạm vi nghiệp vụ

### Các module cốt lõi

1. **Quản trị người dùng:** sales, quản lý vùng, admin; gán nhân viên–tuyến–địa bàn, quyền xem/sửa/duyệt.
2. **Điểm bán/khách hàng:** hồ sơ, địa chỉ, loại hình, liên hệ, nhiều NPP, nhiều nhãn hàng, lịch sử khảo sát, chống trùng.
3. **Khảo sát thị trường:** lịch sử khảo sát, đánh dấu hiện diện riêng từng NPP/nhãn, số liệu tiềm năng, bằng chứng và dấu thời gian.
4. **Chỉ tiêu tháng:** target công ty/nhân viên, kế hoạch 5 tuần, công việc trọng tâm, trạng thái duyệt.
5. **Dự kiến doanh thu:** từng khách × tuần × tháng; tổng tháng tự tính; đối chiếu với target; không ghi đè chỉ tiêu.
6. **Đi thị trường:** lịch ghé, tuyến đi, kết quả ghé, check-in nếu đã được phê duyệt quyền riêng tư và yêu cầu GPS.
7. **Cơ hội đại lý:** pipeline, điều kiện ký, giá trị kỳ vọng và bước tiếp; không tự cộng cơ hội vào doanh thu.
8. **Đối thủ/đề xuất hỗ trợ:** chương trình đối thủ, nhận định, yêu cầu hỗ trợ, hạn xử lý và phản hồi.
9. **Báo cáo:** hiện diện theo tỉnh, tiến độ kế hoạch, so sánh 5 tuần, tỷ lệ hoàn thành, báo cáo đội nhóm; xuất file theo quyền.

### Quy tắc bất biến phải test

- Dữ liệu địa bàn cũ: 13 tỉnh/thành và 134 quận/huyện từ biểu mẫu; có `legacy_code` và tên lịch sử, không trộn tự động địa giới mới.
- Tỉnh thay đổi → huyện được xóa hoặc bắt buộc chọn lại. Không cho lưu huyện ngoài tỉnh.
- `NPP Thanh Đạt` khác `nhãn Thành Đạt (đối thủ)`; phân loại nhà phân phối và nhãn riêng biệt.
- Hiện diện chỉ đếm khi giá trị **Có**; mỗi điểm bán chỉ được đếm một lần trong tổng điểm bán; một điểm bán có thể xuất hiện ở nhiều nhãn/NPP.
- `forecast.month_total = sum(week_1 ... week_5)`; `target` không bị thay thế bằng `forecast`; `dealer.expected` không được tự cộng vào doanh thu.
- Phải xác định `outlet_id` định danh duy nhất; chống trùng khi nhiều sales nhập cùng điểm bán. Không dựa duy nhất vào tên.

## 2. Các pha triển khai — không vượt qua cổng khi chưa đạt

| Pha | Hạng mục | Đầu ra có thể review | Cổng nghiệm thu để sang pha tiếp |
| --- | --- | --- | --- |
| **P0 – Source & Repo** | Xác nhận repo đích; tìm UI FBMN ở nguồn gốc; kiểm tra ZIP, quyền và bí mật | Source manifest, sha256, source provenance, draft PR nền | Có repo đích, nguồn UI gốc hoặc đánh dấu blocker minh bạch; branch riêng, không phá code cũ |
| **P1 – Phân tích Excel** | Đọc từng sheet/cột, định dạng, công thức, dropdown, trường bắt buộc; đối chiếu flow sales thực tế | Data dictionary, field matrix Excel↔API↔DB↔UI, mẫu dữ liệu golden | Chủ nghiệp vụ duyệt quy tắc; các trường quan trọng không bị thiếu/trộn |
| **P2 – Design System FBMN** | Lấy file quy chuẩn có thật (tokens, font, colors, spacing, component guidelines, assets, states), ghi nguồn/phiên bản; chuyển sang Flutter `ThemeExtension`/widget kit và web | `design/fbmn-source/`, `design/tokens/`, `packages/ui_kit/`, component catalog, ảnh đối chiếu | Token có truy xuất nguồn, đủ trạng thái loading/error/empty/disabled; màn hình Android/web nhất quán; review UI |
| **P3 – Neon Domain Schema** | Migraton bảng chuẩn hóa, foreign keys, uniqueness, users/roles/territories/outlets/surveys/plans/visits/dealers/competitors/support/audit | ERD, SQL migrations up/down, seeds danh mục lịch sử, migration test | Chạy migration trên DB staging mới, rollback được; không có ghi chéo sai quyền; constraint chống trùng |
| **P4 – Workers API & Auth** | OIDC/PKCE, JWT validation, role/territory checks, schema validation, idempotency, pagination, concurrency, audit | OpenAPI, route handlers, security tests, standardized errors | Test 401/403, cross-user, cross-region, invalid payload, rate limit; không nhập token tay trong bản phát hành |
| **P5 – Flutter App & PWA** | Router, state management, forms offline-first, autosave, queue sync, conflict resolution, camera/location có cấp quyền; PWA install/service worker | Android build debug, web build, offline test, màn hình theo design system | `flutter analyze` sạch, `flutter test` xanh; không mất dữ liệu khi đóng app, sync không tạo bản ghi kép |
| **P6 – Quy trình kinh doanh** | Hoàn thiện 7 biểu mẫu, duyệt kế hoạch, search/filter, dashboard đúng quy tắc Excel, nhập/xuất có kiểm soát | Screenshots 2 kích thước, UAT scripts, dữ liệu mẫu đối chiếu | 100% kịch bản trọng yếu khớp Excel golden; tổng doanh thu/hiện diện không sai |
| **P7 – Hardening/Kiosk** | Session policy, secure storage, lock screen timeout, Android device policy (nếu kiosk), PWA managed kiosk nếu hạ tầng cho phép, backup/restore | Threat model, lockdown matrix theo nền tảng, audit log, runbook khôi phục | Kiểm thử Android Lock Task theo chế độ quản lý thiết bị thực; PWA không tuyên bố khóa OS nếu chỉ browser |
| **P8 – Release & Vận hành** | CI/CD, staging, beta, Android signing, web/PWA deployment, observability, backup & rollback, hướng dẫn sales | Build artifacts, release notes, dashboard giám sát, tài liệu tập huấn | Bộ regression/UAT đạt, có backup, cách rollback, nghiệm thu của người dùng; lúc đó mới phát hành |

## 3. Quy chuẩn mang UI FBMN sang dự án

**Điều kiện tiên quyết: tìm đúng file nguồn và xác định quyền sử dụng.** Với mỗi file UI phải lưu `source_repo`, `source_commit`, `source_path`, `sha256`, ngày nhập; không sửa âm thầm file gốc.

| Nhóm | File/định dạng nguồn cần thu | Kết quả chuyển sang Flutter/PWA | Kiểm tra |
| --- | --- | --- | --- |
| Theme & palette | colors, semantic tokens, dark mode, brand states | `ThemeData`, `ColorScheme`, semantic `ThemeExtension` | Không hardcode màu trực tiếp trong page |
| Typography | families, sizes, weights, line heights, usage | `TextTheme`, font fallback, styles | Đọc rõ tiếng Việt, scaling accessibility |
| Layout | spacing, radius, elevation, breakpoints | layout token, responsive grid, adaptive shell | 360px mobile, tablet và desktop; overflow test |
| Components | button, input, select, dialog, alert, card, table, tabs, nav | Widget kit dùng chung | Các state default/loading/error/disabled/focus |
| Content conventions | nhãn, validation, trợ giúp, empty, success | UI copy và error contract | Tiếng Việt thống nhất, không mất dữ liệu khi lỗi |
| Assets | icon/logo minh họa và license | asset package có provenance | Đảm bảo quyền dùng, không đưa secret/font thương mại trái phép |
| Accessibility | contrast, touch target, keyboard, assistive semantics | theme + semantic labels | Kiểm thử đọc màn hình/keyboard/contrast |

**Không được làm:** tự đặt token Material 3 và nói là FBMN; copy thiết kế từ QR-app rồi nói là FBMN; nhập bất kỳ file quy tắc nào chưa có nguồn/truy vết.

## 4. Thiết kế bảo mật và “khóa cứng”

- **PWA:** có thể yêu cầu đăng nhập, PIN/biometric theo hỗ trợ nền tảng, timeout, offline policy, kiosk qua trình duyệt/hệ thống được quản trị. PWA tự thân **không thể** cấm người dùng bấm Home, chuyển app hoặc xóa browser data trên thiết bị thông thường.
- **Android Flutter:** có thể triển khai Android Enterprise fully managed + **Device Owner / Lock Task** cho thiết bị công ty; cần cấu hình MDM/provisioning và kiểm thử thiết bị thật. Chế độ full-screen/immersive **không tương đương** kiosk cứng.
- Không cho token nằm trong code hoặc browser localStorage ở bản production; dùng OIDC Authorization Code + PKCE và session design thích hợp; HTTPS, refresh/expiry, revoke và logout.
- Dữ liệu offline cần mã hóa phù hợp và hạn chế rò rỉ; quy tắc xóa dữ liệu khi thu hồi thiết bị; server là nguồn sự thật; ghi audit theo hành động và phân quyền.
- Dữ liệu liên hệ/số điện thoại khách phải có phân quyền rõ, ghi log truy cập nhạy cảm và retention policy.

## 5. Definition of Done (DoD) áp dụng cho **mọi** PR

1. Mỗi thay đổi gắn mã requirement từ Excel hoặc ticket; có test hoặc lý do miễn test được review.
2. Không còn TODO placeholder ảnh hưởng luồng; không hardcode key/password/token; secret scan qua CI.
3. Typecheck/analyze/lint đạt; migration có chiến lược rollback; tests theo module đi kèm.
4. UI đúng tokens FBMN được đối chiếu có bằng chứng, xử lý loading/error/empty/offline; responsive.
5. RBAC qua server; kiểm thử quyền đọc/ghi sửa của sales, manager và admin.
6. Có manual QA trên Android và PWA, kèm video/screenshot được cấp phép nếu cần.
7. Changelog/README/setting cần thiết được cập nhật; reviewer xác nhận; chỉ merge khi đạt.

## 6. Test tối thiểu để không lặp lỗi Excel

- `T-BIZ-01`: chọn Long An → huyện hợp lệ; đổi qua Cà Mau → huyện cũ phải bị reset.
- `T-BIZ-02`: điểm bán có nhiều NPP/nhãn, tổng số điểm bán vẫn chỉ tính 1.
- `T-BIZ-03`: chỉ giá trị `Có` tính hiện diện, `Không`, bỏ trống, chưa khảo sát không tính.
- `T-BIZ-04`: NPP Thanh Đạt và nhãn Thành Đạt (đối thủ) tồn tại đồng thời mà không lẫn dữ liệu.
- `T-BIZ-05`: weekly `[1,2,3,4,5]` → tổng `15`; không dùng `target` hay `dealer.expected` làm forecast.
- `T-SEC-01`: Sales A không xem/sửa hồ sơ Sales B ngoài quyền cấp.
- `T-SEC-02`: token giả/mất hạn/sai audience → 401; thiếu role → 403.
- `T-OFF-01`: lưu offline, đóng app, khởi động lại → còn bản nháp; online → sync **chỉ một** record.
- `T-OFF-02`: sync 2 máy sửa cùng một hồ sơ → hiển thị conflict có cách xử lý, không âm thầm mất dữ liệu.
- `T-UI-01`: UI phone, tablet, desktop, zoom/font scale lớn, dark mode nếu FBMN yêu cầu.
- `T-RELEASE-01`: backup/restore và rollback bản phát hành thử nghiệm thành công.

## 7. Báo cáo trạng thái hiện có (không nâng khống)

| Hạng mục | Thực trạng ZIP starter | Kết luận |
| --- | --- | --- |
| Source được giải nén | Có, Flutter Dart + Worker TS + SQL | Có thể nhập làm nhánh `foundation`, **không** phải production |
| UI chuẩn FBMN | Không có file nguồn; `theme.dart` tự ghi là tạm | **BLOCKED**: cần source có chứng cứ |
| Flutter/Android/web build | ZIP thiếu platform scaffolding, môi trường chưa có Flutter/Dart SDK | **CHƯA KIỂM THỬ** |
| Đăng nhập | Nhập access token bằng tay trong RAM | **CHƯA HOÀN CHỈNH** |
| DB | 1 bảng `sales_records` kiểu JSONB | **CẦN THIẾT KẾ CHUẨN HÓA** |
| Offline | Dữ liệu demo RAM; không có persistence/sync queue | **CHƯA CÓ** |
| API | 7 loại record, auth JWT có sườn, list giới hạn 200 | **CẦN CONTRACT/SECURITY TESTS** |
| Unit/integration/widget test | Không có file test | **CHƯA CÓ** |
| Thiết bị kiosk | Chưa có mã Device Owner/Lock Task | **CHƯA CÓ** |
| Neon/Cloudflare/Vercel | Chưa deploy | **CHƯA TRIỂN KHAI** |

## 8. Những phụ thuộc không được giả định

- **Repo đích:** cần URL repository của app Sales hoặc quyền tạo repo. Hiện các action GitHub kết nối không có thao tác `create_repository`.
- **Bộ quy tắc FBMN:** cần đường dẫn repo/nhánh/thư mục hoặc file nguồn; `milktea-cus/MCP-FBMN` tại thời điểm kiểm tra không có file.
- **Khóa cứng:** phải chốt mục tiêu là `chỉ đăng nhập và giới hạn phiên`, `PWA managed-kiosk` hay `Android device-owner kiosk`; ba mức có khả năng rất khác nhau.
- **OIDC/MDM:** phải xác định nhà cung cấp nhận dạng/thiết bị trước khi phát hành; có thể bắt đầu thiết kế nhưng không hoàn tất cấu hình thực tế khi thiếu chúng.

## 9. Thứ tự triển khai đề nghị ngay khi có repo/UI

`P0: Import foundation vào nhánh riêng` → `P1: Excel contract + tests golden` → `P2: UI FBMN tokens & components` → `P3: DB schema` → `P4: API & Auth` → `P5: Flutter/PWA offline-first` → `P6: từng luồng nghiệp vụ` → `P7: kiosk/hardening` → `P8: staging, UAT, release`.

**Quy tắc ra quyết định:** Trước khi giao diện hoặc tính toán gây hiểu nhầm, chặn release và nêu issue/blocker cụ thể. Không đẩy `main` hoặc deploy production dựa trên ZIP MVP chưa được kiểm chứng.