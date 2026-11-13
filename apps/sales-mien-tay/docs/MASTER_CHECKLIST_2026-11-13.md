# FIELD WORK — CHECKLIST TỔNG & NGHIỆP VỤ ĐÃ CHỐT (13/11/2026)

**Nguồn sự thật cho việc tiếp theo:** tài liệu này + checklist đầu [Issue #3](https://github.com/milktea-cus/MCP-FBMN/issues/3). [Issue #4](https://github.com/milktea-cus/MCP-FBMN/issues/4) là lịch sử audit UI/ra đơn và bằng chứng P1-H/P0-I. **Không lấy checkbox chưa được cập nhật của Issue cũ làm bằng chứng đã/ chưa có code.** GitHub `main` lúc audit `557b49f2529132805e540fcd691efb3ba040bfe3`, CI [43154778431](https://github.com/milktea-cus/MCP-FBMN/actions/runs/43154778431) **4/4 PASS** (Flutter 158 unit/widget, 3 Chrome IndexedDB, Android debug build; không phải Android release). Production Cloudflare Worker APK API đã smoke health/DB OK, unauthorized 401, unknown origin 403. Web production gần nhất P1-H; chưa xác minh web đã nhận mọi cập nhật Dart P0-I. Không gọi v1.0 nghiệm thu khi chưa có UAT thật.

## Quy định triển khai Vercel — cập nhật 13/11/2026 (Owner xác nhận)

**Vercel production PHẢI deploy thủ công, trực tiếp vào project hiện hữu `sales-mien-tay` qua Vercel plugin/API hoặc công cụ triển khai do trợ lý điều khiển.** Repo đã hết quota GitHub Actions theo thông báo của Owner: **không dùng GitHub Actions để build/deploy, không kích hoạt lệnh `/deploy production` trong Issue #2, và không yêu cầu Owner chạy CMD.** Workflow `.github/workflows/sales-production-comment.yml` chỉ là cơ chế cũ, không phải đường deploy đang áp dụng.

- Build Flutter Web từ đúng SHA trên `main` trong môi trường không tiêu hao GitHub Actions, kiểm tra `flutter analyze`, `flutter test`, build release/offline IndexedDB/service worker và file đầu ra trước khi phát hành; không dùng lại artifact cũ giả làm build commit mới.
- **Bắt buộc đóng gói `apps/sales-mien-tay/apps/sales_flutter/vercel.json` ở đúng thư mục root Flutter khi deploy source trực tiếp qua Vercel API**, giữ rewrite `/api/:path*` -> Worker. Thiếu file sẽ khiến `/api/v1/admin/staff`, `/api/v1/admin/org`, `/api/v1/me` trả 404, trang nhân viên trắng và app hiện cảnh báo cache offline (đã xảy ra 13/11/2026). Không coi `READY` là API hoạt động. Kiểm thử thật `/api/v1/me` chưa có cookie phải 401 (không phải 404); có phiên Admin phải trả 200; thử GET staff/org cùng phiên.
- Sau khi kiểm tra tương thích Neon/Worker, triển khai **trực tiếp Vercel production** vào đúng project/domain `https://sales-mien-tay.vercel.app`. Giữ nguyên cấu hình, environment và domain hiện hành; không tạo app/project/preview thay thế.
- Kiểm tra production URL thực tế, app-shell, API/Auth, phân quyền, cache/offline, phiên bản/chính xác SHA. Ghi bằng chứng deployment ID, thời gian, HTTP smoke và các lỗi tồn đọng vào Issue #3.
- **Deploy thủ công không được hiểu là bỏ cổng nghiệm thu.** Nếu chưa đủ test, thiếu công cụ build hoặc không có quyền triển khai, báo rõ blocker và giữ nguyên phiên bản production; không tự ý bật `SALES_PRODUCTION_READY` để vượt workflow cũ.
- CI GitHub Actions chỉ dùng lại sau khi Owner xác nhận quota được khôi phục. Với commit tài liệu đơn thuần, đặt `[skip ci]` để không lãng phí quota. Công việc code chưa có CI phải được kiểm thử theo quy trình thay thế và báo trung thực, không tuyên bố CI xanh khi chưa chạy.

## 0. Phân loại tiến độ (không gộp code với nghiệm thu)

| Hạng mục | Code/DB hiện có | Cổng còn mở |
|---|---|---|
| P1 Login/nhân viên/tỉnh-huyện; Lô 1 hierarchy | Có 3 role `admin/manager/sales`, `manager_sub`, cây nhiều tầng và vùng giao nhau (Neon migration 009). | Chưa có grant độc lập theo đội/chuỗi và theo phạm vi chức năng; chưa UAT thu hồi quyền mọi API/offline |
| Lô 2A kế hoạch tháng | Đã có 5 kỳ 1–7,8–14,15–21,22–28,29–cuối; tuyến ngày/tuần, copy mẫu tuyến tại máy | Chưa hiện ngày cụ thể cạnh từng kỳ; chưa lập kế hoạch **khu vực trống khách**; mẫu tuyến chưa đồng bộ đa thiết bị |
| Lô 2B/2C khảo sát & media | Có phiên `field_survey_sessions` liên kết `route_stop_id`, template, GPS, ảnh thumbnail R2 private, offline outbox | Phiên khảo sát còn bắt buộc `customer_id`; chưa có khảo sát khu vực/khách tiềm năng độc lập; UAT camera/offline/R2 còn mở |
| Lô 3 sản phẩm/tồn/Excel | Có danh mục/tra tồn/nhập Excel/ánh xạ cột & preview | Cần đối chiếu workbook công ty, nhập dữ liệu thực và hồi quy |
| Lô 4 Target & doanh số | Có nhân viên/khách/**SKU** theo kỳ, doanh số thực tế Excel/report | **Phải thay SKU bằng địa bàn** trong phân bổ; bổ sung nhóm SP chỉ sau khi có danh mục nhóm; UAT đối soát |
| Lô 5/P0-A/B/C/D ra đơn | Có tìm hàng debounce/pagination/offline, giỏ draft, vòng đời đơn/hủy/điều chỉnh, quan hệ SKU–khách, export | P0-A/B còn kiểm tra thao tác, form thật và trạng thái ngoại tuyến; đơn không phải ERP, không trừ tồn/doanh số tự động |
| P0-E/F/G/H KH, GPS, icon loại KH, mobile | Đã có code & migrations 026–028, P1-H web production (CI xác minh) | UAT ảnh/Maps/Zalo/GPS/touch thật, admin legacy screens |
| P0-I Android APK R2 | Đã commit native Android, update UI/API, bucket R2 private và gated signer workflow; Worker prod 100% | **CHƯA có signed APK phát hành:** xác minh signer bản Owner đang cài, provisioning secrets, R2 latest, UAT 2 phiên bản / SQLite |
| P0-J nghiệm thu v1.0 | Có unit/widget/browser CI và một số smoke production | Chưa UAT nhiều user, smartphone thật, xuất/nhập file công ty, backup/rollback & hiệu năng |

**Neon production SELECT tại audit 13/11:** 20 khách, 19 khách do Admin tạo/sở hữu; 1 Manager active; **0 nhân viên có `manager_sub`**, 0 dòng Target bất kỳ dimension, 3 ảnh khách, 1 phiên khảo sát, 0 tuyến dự kiến (`visit`). Các con số chỉ đúng tại thời điểm audit, không phải dữ liệu giả lập. **Không thực hiện ghi DB trong pha lập checklist.**

## K0 — QUY TẮC NHÂN SỰ & PHẠM VI MỚI (OWNER CHỐT 13/11/2026)

**Hai cấu trúc độc lập, không dùng đội nhóm để quyết định cấp trên.** Phân quyền cấp trên = cây `staff_members.manager_sub`; phân công kinh doanh = địa bàn trong `staff_scopes` và giao chuỗi/khách trong `staff_business_assignments`, cộng `customer_scope_bindings` gắn khách vào chuỗi. Không tự biến địa bàn của cấp dưới thành phân công trực tiếp của cấp trên.

- [x] Chỉ có 3 **role hệ thống**: `admin/manager/sales`. **Chức danh** (`job_title`) là tên tự đặt tối đa 120 ký tự, không giới hạn số tầng quản lý. Frontend hồ sơ + backend + SQL migration 030 triển khai.
- [x] **Cấp trên thấy toàn bộ cây cấp dưới** cho quyền `view` (kể cả nhân viên phụ trách chuỗi/địa bàn/khách riêng), không cần tạo đội nhóm, không cần cấp quyền Xem lặp lại. Cây nhiều tầng, chu kỳ quản lý bị chặn bằng hàm save staff cũ.
- [x] **Hai Manager cùng cấp** (cùng `manager_sub`) có thể xem nhau trong **địa bàn giao nhau** (phải khớp tỉnh/huyện của khách). Khác địa bàn không mở rộng quyền xem chéo; xem cây cấp dưới của riêng mình.
- [x] **Kinh doanh độc lập**: giao nhiều tỉnh/huyện tại hồ sơ nhân viên; giao nhiều chuỗi/khách riêng tại tab Phân công kinh doanh. Thêm/thu hồi giao riêng có audit và tăng `scope_revision` cho nhân viên + cấp trên. Không tạo đội nhóm cho tổ chức mới; bảng cũ giữ để tương thích, không xóa production.
- [x] **Quyền thao tác độc lập**: chỉ `view` tự động; `edit`, `approve`, `target`, `transfer`, `export`, `media`... vẫn phải cấp rõ và kiểm tra backend. Việc được nhìn thấy không tự tạo quyền sửa hoặc duyệt.
- [x] **UX chia 3 tab**: Cây nhân sự / Phân công kinh doanh / Quyền thao tác. Chức danh, cấp trên, địa bàn nằm trong hồ sơ nhân viên.
- [ ] **Còn kiểm tra P0-K toàn hệ thống**: đối soát từng API báo cáo/khảo sát/đơn/ảnh theo quyền, lọc dữ liệu cùng cấp, thử 401/403/409 bằng phiên thật; offline PWA IndexedDB, Android SQLite, thu hồi quyền, test nhiều tầng và nhiều nhân viên cùng cấp trên điện thoại thật. **Chưa nghiệm thu P0-K/P0-J chỉ vì CI/deploy xanh.**
- [ ] **Quản trị Role nâng cao** (nếu cần sau này): permission presets/ủy quyền có thời hạn, không làm thay đổi 3 role cố định và không cho cấp quyền vượt Admin.

**Triển khai 13/11:** Neon production đã áp dụng migration `030_staff_job_title.sql` + `031_staff_business_assignments_auto_read.sql`; API Worker production deployment `c8d00f67-3b72-4f50-b6c7-9828dbf86a5b`, 100%, bảo toàn đủ 7 bindings; Flutter Web production `dpl_AaEPQqWig7NLWCNqtb3fJxjd9dz1` READY, domain `sales-mien-tay.vercel.app`, HTTP root 200. Test Worker TypeScript, Flutter Analyze, Web release, offline shell và Push PASS. API HTTP được xác thực chưa kiểm qua công cụ vì Vercel share-link chặn các đường /api; cần UAT.

**Dữ liệu cập nhật:** 3 nhân viên, 22 khách hàng; chưa có `manager_sub` nào được chọn, chưa có phân công chuỗi/khách qua bảng mới, các giá trị/identity cũ được giữ. `mekong03` hiện `sales_identity_exists=false`, cần đối soát Neon Auth trước khi test đăng nhập tài khoản này; không tự thay identity.

## P0-K — THI CÔNG PHÂN QUYỀN & ĐỊA LÝ TOÀN QUỐC (ƯU TIÊN ĐẦU TIÊN)

- [ ] K-1: chứng minh policy hiện tại & ánh xạ tất cả API truy vấn `sales_can_access`; viết matrix grant ở DB/test (trong đó Manager theo chain/team không địa bàn, vùng có KH do Admin giao); thiết kế tương thích với báo cáo/target/order.
- [ ] K-2: migration **additive**, chỉ khi có kiểm kê/backup, policy mới, tables grant và national geo; sửa backend đọc/ghi có scope rõ; chặn truy cập qua ID guessed, query aggregate, file và ảnh.
- [ ] K-3: màn Admin giao quyền: sơ đồ cây/quản lý cấp dưới, địa bàn, đội/nhân viên, chuỗi khách, quyền xem/sửa/duyệt; preview **khách/nv nằm trong phạm vi** trước lưu; thu hồi quyền và audit.
- [ ] K-4: có chức năng chuyển khách do Admin tạo sang trách nhiệm Manager/vùng/chuỗi nhưng không thay lịch sử người tạo; đối chiếu không trùng khách khi nhiều grant giao nhau.
- [ ] K-5: CI, tests 401/403/409, query Neon chính sách thật, UAT hai tài khoản và offline namespace/revoke, Worker smoke production; chỉ tick khi có bằng chứng.

## P0-L — KẾ HOẠCH THÁNG → TUYẾN DI CHUYỂN → PHIÊN KHẢO SÁT

**Phân biệt ba cấp:** `MonthlyPlan` (tháng/kỳ/mục tiêu vùng/chuỗi, chưa cần KH) → `DayRoute/RouteStop` (ngày, thứ tự, loại điểm ghé `customer | area | prospect | chain`) → `Visit/SurveySession` (việc *đã thực hiện*, GPS/checklist/ảnh). Tuyến thay đổi theo ngày/tháng; **không mặc định tuyến cố định hàng tuần** như một số app DMS. Mẫu tuyến là lựa chọn sao chép, không phải quy tắc bắt buộc.

- [ ] L-1: Chọn tháng tự hiển thị `Kỳ 1 · 01–07/MM`, `Kỳ 2 · 08–14/MM`, `Kỳ 3 · 15–21/MM`, `Kỳ 4 · 22–28/MM`, `Kỳ 5 · 29–ngày cuối/MM` khi có ngày; tháng 28 ngày **ẩn kỳ 5 không có ngày**. Giữ 5 *kỳ kế hoạch theo ngày tháng* tách với tuần lịch thứ Hai–Chủ nhật; không lẫn hai khái niệm. Điểm ghé luôn có ngày thực tế rõ.
- [ ] L-2: lập kế hoạch **địa bàn trước**, chọn nhiều tỉnh/địa bàn/chuỗi được giao, mục đích, ngày, dự kiến số KH cần phát triển, ghi chú/ưu tiên/di chuyển; lưu plan **không buộc tồn tại khách hàng** trong tỉnh.
- [ ] L-3: sau khi chọn địa bàn, gợi ý khách trong quyền theo khu vực/chuỗi; nếu không có KH thì màn vẫn cho lập `area stop` (đi tìm khách mới) và không phát sinh bản ghi khách giả. Cho thêm lead/khách khi phát hiện điểm bán sau này, gắn vào hoạt động tương ứng.
- [ ] L-4: phân hệ Khảo sát mặc định **việc hôm nay** theo kế hoạch ngày, mỗi route stop khách có `route_stop_id` + `survey_session_id`. Nếu ghé đột xuất, session có `route_stop_id=NULL`. **Area stop** có `area_visit` riêng với GPS/ảnh/ghi chú/kết quả tìm kiếm; survey form khách chỉ tạo sau khi có KH thật (hoặc lead được xác nhận). Không tạo KH rỗng chỉ để lưu plan.
- [ ] L-5: phân biệt `planned` / `visited GPS` / `survey started` / `survey completed` / `unscheduled`. Một KH có nhiều phiên lịch sử, một lần check-in không tự là hoàn thành khảo sát, chưa đi thì không hoàn thành kế hoạch.
- [ ] L-6: mẫu tuyến có version lưu DB đồng bộ đa thiết bị, sao chép không sửa ngày đã khảo sát; drag/sort, điều chỉnh ngày, xử lý nghỉ/đổi lịch, duplicate UUID/idempotent; mục tiêu tuyến không bắt user mở từng khách trước.
- [ ] L-7: UAT 0 khách trong tỉnh, 1 khách, nhiều khách, Manager chuỗi xuyên tỉnh, 5 kỳ/tháng nhuận/28–31 ngày, plan offline → khảo sát online/offline → đồng bộ không trùng → Manager xem đúng quyền.

**Đối chiếu MCP Mobi:** nguồn tham chiếu nội bộ `docs/MCP_MOBI_REFERENCE.md` ghi repo `binhnxwjfjxm/mcp-mobi` tại `e8e9bbd` chỉ có ảnh demo `ui-tham-khao.jpg` và README, **không có source mô hình/route/session để xác minh**; tại audit 13/11 đã xác minh trực tiếp **repo private** qua kết nối GitHub owner: nhánh `main` SHA `e8e9bbd99c6d02c93d46ff5458e5e4c5995ab352` chỉ có đúng `README.md` và `ui-tham-khao.jpg`, không chứa code mô hình phiên/tuyến. Do vậy không xác nhận “giống hệt MCP Mobi”. Điểm khác nghiệp vụ Field Work là *kế hoạch tháng di chuyển linh hoạt, không ép tuần cố định*.

## P0-M — TARGET: BỎ SKU KHỎI PHÂN BỔ, CHUYỂN THÀNH ĐỊA BÀN

- [ ] M-1: phân bổ Target theo **nhân viên** (cha) → **địa lý/vùng bán hàng** (con) đối với người có địa bàn; hiển thị vùng/tỉnh/khu vực được giao theo chính sách P0-K; **Manager phụ trách chuỗi không có địa bàn vẫn nhận Target theo nhân viên/nhóm hoặc chuỗi được giao, không bắt chọn tỉnh**. Không cho chọn SKU trong phần phân bổ.
- [ ] M-2: migrate `sales_targets.dimension='product'` sang hỗ trợ `territory` bằng additive versioning/check constraint; dữ liệu SKU cũ nếu có thì lưu lịch sử/ẩn khỏi form, **không xóa hay tự đổi amount**. Audit hiện 0 dòng Target nên chuyển dạng UI khả thi, vẫn giữ migration an toàn.
- [ ] M-3: nếu có phân bổ KH riêng, đây là một cách phân tích *song song*, **không cộng Target KH + địa bàn + nhân viên** (tránh double count). Tổng con theo địa bàn không vượt chỉ tiêu cha; qua cấp Manager, không đếm chỉ tiêu team hai lần.
- [ ] M-4: kiểm doanh số thực tế theo mã địa bàn của giao dịch/khách tại thời điểm phát sinh (snapshot, lưu lịch sử khi chuyển địa giới); dashboard người/địa bàn đúng quyền.
- [ ] M-5: `product_group` có thể bổ sung sau **khi có catalog nhóm sản phẩm thực và quy tắc ánh xạ SKU→nhóm**; không đưa SKU lẻ trở lại dropdown Target; test rounding, conflict, version, offline và Excel.

## P1-N — ẢNH KHÁCH HÀNG: CACHE-FIRST NHƯNG VẪN R2 PRIVATE

- [ ] N-1: hiển thị ảnh thumb đã lưu local (IndexedDB PWA / cache file Android) **ngay frame đầu** cùng metadata cache; gọi API làm mới ở nền; **không chờ tuần tự ảnh gallery + lịch sử ghé** trước khi hiện ảnh cũ; không clear Future cache vô cớ khi mỗi lần mở hồ sơ.
- [ ] N-2: preload thumb của khách vừa nhìn/đang chọn ở danh sách (giới hạn số lượng, network-aware), chỉ lấy ảnh 1600px khi bấm xem lớn; skeleton đúng kích cỡ, image decode phù hợp, image resizing/compression.
- [ ] N-3: cache có dung lượng/TTL/LRU/version/ETag/checksum và khóa riêng từng account+scope_revision; quyền mất/đổi user phải purge hoặc quarantine; không public R2, không shared SW cache API auth, không lộ URL truy cập vĩnh viễn.
- [ ] N-4: đo cold/warm P50/P95 trên mạng di động (thời gian đầu hiện thumbnail, không chỉ tải hết dữ liệu); kỳ vọng **warm gần như tức thời**, cold có placeholder rõ. UAT 2–5 giây thực tế, offline và permission revoked.

## P1-O — UI ICON PHÂN HỆ KHÔNG ĐÓNG KHUNG

- [ ] O-1: `SalesModuleGrid` hiện mỗi module trong `Card` (110dp); đổi thành **icon + nhãn bên dưới, không border/card cá nhân**, khoảng trống hợp lý; giữ màu nhận diện/tokens FBMN, không xóa các card số liệu/KPI cần giữ.
- [ ] O-2: vùng bấm vô hình min 44×44dp, icon nhất quán 24–28dp, nhãn 1–2 dòng, 3–4 cột mobile theo chiều rộng; không đụng logo FBMN, chuông badge, mục tài khoản bottom navigation, dark mode và navigation hiện đúng.
- [ ] O-3: kiểm màn 320/360/390/430px, textScale 1.4, light/dark, keyboard/focus/semantics và screenshot so trước/sau; sửa test `module_grid_test.dart` theo kiểu mới.

## P0-I — KHÓA PHÁT HÀNH APK VÀ P0-J — NGHIỆM THU V1.0

- [x] I-code: native update, bộ kiểm signer SHA256/checksum/version, Worker API và private bucket R2, gated release CI đã được commit; Cloudflare production đã deploy API.
- [x] I-CI: `main 557b49f2` CI [43154778431](https://github.com/milktea-cus/MCP-FBMN/actions/runs/43154778431) 4/4 green: 158 Flutter + 3 Chrome IndexedDB + APK debug + backend, chưa phải release.
- [ ] I-release: xác minh package ID và **chữ ký APK trên điện thoại Owner**, install signing credentials ở kênh bảo mật (công cụ Cloudflare secret hiện còn chặn cấu hình `APP_DOWNLOAD_HMAC_KEY`), publish hai bản signed `versionCode` tăng bằng R2 immutable, test quyền tải và cài đè SQLite/outbox trên máy thật. Không uninstall tự động.
- [ ] J-auth: UAT đủ ma trận P0-K: manager nhiều cấp, territory-only/team-only/chain-only, cross-region, giao KH Admin, tenant isolation và thu hồi quyền offline.
- [ ] J-route: lập tháng ở tỉnh 0 khách, ghé khu vực tìm KH, sinh lead/KH, phiên đúng tuyến, ngoài tuyến, 5 kỳ động, GPS/ảnh/khảo sát offline đồng bộ.
- [ ] J-target: Target theo địa bàn + doanh số thực tế Excel mẫu công ty, đối chiếu tổng kỳ/tháng và không nhân đôi chỉ tiêu.
- [ ] J-order: P0-A/B còn UAT picker/giỏ/draft/đơn/CSV-XLSX thực; P0-C/D trạng thái, mã KH, snapshot tồn chỉ tham khảo, không tự cập nhật tồn hay doanh số (Field Work **không phải ERP**).
- [ ] J-media: cold/warm ảnh R2, quyền thumbnails và revoke; UAT Android/PWA, 360/390/430, Zalo/Maps, notifications/lock screen, dark mode, keyboard.
- [ ] J-release: bản build ký, Vercel production/Worker/Neon audit, backup/rollback, hai thiết bị và hai tài khoản thật, các lỗi 401/403/409, xóa cache khi đổi tài khoản. CI xanh **không** thay thế nghiệm thu.

## Thứ tự thực thi chốt

1. **P0-K** phân quyền đa cấp + geographic/team/chain + national catalog và giao trách nhiệm KH (hạ tầng nghiệp vụ đầu tiên).
2. **P0-L** lịch tháng theo vùng/chuỗi và tuyến rỗng khách → khảo sát/lead, hiển thị từng kỳ ngày chính xác.
3. **P0-M** phân bổ Target chuyển SKU → địa bàn, phân cấp và đối chiếu actuals.
4. **P1-N + P1-O** ảnh cache-first và grid icon không khung (có thể độc lập triển khai khi P0-L/M đang làm).
5. **P0-I** đóng phát hành APK ký/R2 sau signer + secrets + UAT; code/API hiện có không xóa hoặc làm lại.
6. **P0-J** hồi quy đơn hàng / nghiệp vụ / bảo mật / offline + UAT & nghiệm thu v1.0.

**Quy tắc Done cho mỗi pha:** đọc code/head, migration additive + backup/compatibility, test auth/DB/API/frontend/offline, CI xanh, deploy đúng Cloudflare/Vercel khi liên quan, smoke production và ghi SHA/bằng chứng; không làm giả real-device UAT. Không chỉnh production để “làm đẹp checklist”. Không tạo repo hay ZIP thay thế.


## Cập nhật 13/11/2026 — Staff Editor Mobile (chọn cấp dưới hàng loạt)

- [x] **UX:** màn Thêm/Sửa nhân viên tối ưu cho mobile dạng toàn màn hình, nút Lưu/Hủy cố định; chỉ cần mở từng khu vực khi sử dụng, không hiển thị danh sách tỉnh/huyện dài từ đầu.
- [x] Đổi nhãn **Cấp trên trực tiếp** (1 người), kèm diễn giải người quản lý nhân viên này; Manager có **Chọn nhân viên cấp dưới (N)**, tìm theo tên/mã, tích nhiều người và xem cấp trên hiện tại trước khi chuyển. Không dùng đội nhóm. Vai trò + chức danh vẫn độc lập.
- [x] **Địa bàn phụ trách riêng** thu gọn, chọn nhiều tỉnh/huyện trực tiếp. Chuỗi/khách riêng tiếp tục quản lý ở tab **Phân công kinh doanh**, độc lập với cây nhân sự.
- [x] **Ghi DB an toàn:** migration `032_staff_reporting_batch.sql`, RPC `sales_save_staff_with_reports` lưu hồ sơ và thay đổi cấp dưới trong cùng giao dịch, kiểm tra Admin, phiên bản từng nhân viên, không trùng, không có chu kỳ, cập nhật scope revision cho nhánh cũ/mới và ghi audit. Backend hỗ trợ payload cũ không gửi `report_changes`.
- [x] **Test Neon tạm:** chuyển cấp dưới đạt; sai scope_revision và tạo vòng lặp đều bị từ chối (rollback); bỏ cấp dưới bị khóa đạt; quyền xem theo nhánh không tự thành quyền sửa. Production không tạo chuyển cấp dưới khi thử.
- [x] **Deploy:** code commit `bf326eeba435e280d57ee7e34933b0d4eb7de6c7`; Neon production migration 032; Vercel `dpl_HsvrruCb6AGqUrzdAvTpj9BzaHQf` READY + alias `sales-mien-tay.vercel.app`; Worker `738d271e-42da-41dd-a8bd-a987dd25cba7` version `aa203aad-af61-4943-b199-17c55066bae8` 100%, SHA256 bundle `ff6270e282ffbf8c8ac423ed259568c0053705f8ef3d184391884b4eb5c84a0c`. 7 Cloudflare bindings preserved.
- [x] TypeScript typecheck, Wrangler dry-run/minify, Flutter Analyze (117 infos, không lỗi/warning gây chặn), Flutter Web release, offline shell 42 tài nguyên không cache API, push check PASS; trang chủ production HTTP 200.
- [ ] **UAT còn mở:** đăng nhập bằng phiên Admin và dùng chọn nhiều cấp dưới trên điện thoại thật; kiểm 401/403/409 API, mất mạng/IndexedDB và Android SQLite; URL /api qua Vercel tool bị share-link authentication chặn, không có bằng chứng HTTP API với cookie thật. Android APK chưa phát hành lại.



## Cập nhật 13/11/2026 — Giao địa bàn trực tiếp & quyền lập lịch

- [x] **UX Phân công kinh doanh:** chọn nhân viên → **Giao / sửa tỉnh, huyện** ngay trong tab; tìm tỉnh, chọn toàn tỉnh hoặc nhiều huyện, lưu một lượt. Tóm tắt địa bàn gọn để không tràn màn hình điện thoại. Không trộn cây cấp trên với phạm vi kinh doanh.
- [x] **Migrations additive 033** (`033_territory_assignments_route_planning.sql`): `sales_set_staff_territories` Admin-only, validate revision, chống dữ liệu sai/trùng, cập nhật `staff_scopes`, tăng revision nhân viên/cấp trên, audit; `sales_customer_plannable` chỉ xét Admin hoặc phạm vi khách được giao **trực tiếp** (owner, địa bàn, chuỗi, khách riêng), không tự cho cấp trên lập lịch toàn bộ khách cấp dưới.
- [x] **Backend:** endpoint Admin `POST /api/v1/admin/org/territory-assignments` kiểm tra tỉnh/huyện trong danh mục; `GET /api/v1/customers` trả `can_plan` theo backend; lịch `visit` của nhân viên có thể tham chiếu khách **do Admin/nhân viên khác tạo** nếu khách thuộc phạm vi của chính người lập. Bản ghi lịch thuộc người lập, không chuyển `owner_sub` khách. Sửa lịch của chính mình kiểm tra lại phạm vi, không cấp quyền sửa hồ sơ khách.
- [x] **Flutter Web/PWA:** lịch chọn khách theo `can_plan` thay vì chỉ `owner_sub`; lưu cờ `can_plan` vào cache account/revision, fallback cũ an toàn; tuyến GET nối lịch theo `owner_sub` người lập.
- [x] **Neon test branch:** giao Kiên Giang cho KB: 5 khách Kiên Giang lập lịch được, An Giang 0; Admin-owned customers `can_plan=true` nhưng `create/edit customer=false`; thử ghi 1 visit trong branch trả đúng `owner_sub` người lập; kiểm lỗi non-admin và stale revision đều bị chặn. **Không sửa phân công trên production để test.**
- [x] **Triển khai:** source commit `3fa2bf310442276c82a5ec3f4939e96cb1d97e46`, Vercel production `dpl_5ZWkgchmkSbicdpoYRXetq6VN1By` READY, domain `sales-mien-tay.vercel.app` HTTP 200; Worker deployment `99854665-61b7-4d57-9723-d81ade4cdaa2`, version `318bed93-1bd2-4cd5-9b92-601a50449f5e` 100%; SHA256 `83a45fcdafc29234e81ecc14e3fc6d585a8518c0f66d0b2042e609bc7071855b`; 7 binding/secret giữ nguyên. Neon production migration 033 (6 SQL statements).
- [x] TypeScript typecheck, Wrangler dry-run/minify, Flutter Analyze (124 issues `info`, không có error), Flutter Web release, offline shell 42 assets/no API caching, Push shell PASS; Vercel root HTTP 200.
- [ ] **Chưa UAT API có session thật và thiết bị thật:** Vercel `/api/*` bị lớp share-link auth chặn; container/web tools không thể lấy HTTP chính xác. Không coi Worker 100%/Vercel READY là nghiệm thu. Nhân viên cần đăng nhập/khởi động lại sau đổi `scope_revision`.
- [ ] **Kế tiếp P0-L:** lịch **địa bàn không có khách** và lead/khảo sát khu vực chưa triển khai trong sửa lần này; check-in/khảo sát khách do Admin tạo vẫn còn chính sách `owner_sub` cần chỉnh quyền nghiệp vụ riêng và UAT. Android APK chưa phát hành lại. Tài khoản mekong03 email chưa verified nên chưa nghiệm thu login.

