# FIELD WORK — CHECKLIST TỔNG & NGHIỆP VỤ ĐÃ CHỐT (13/11/2026)

**Nguồn sự thật cho việc tiếp theo:** tài liệu này + checklist đầu [Issue #3](https://github.com/milktea-cus/MCP-FBMN/issues/3). [Issue #4](https://github.com/milktea-cus/MCP-FBMN/issues/4) là lịch sử audit UI/ra đơn và bằng chứng P1-H/P0-I. **Không lấy checkbox chưa được cập nhật của Issue cũ làm bằng chứng đã/ chưa có code.** GitHub `main` lúc audit `557b49f2529132805e540fcd691efb3ba040bfe3`, CI [43154778431](https://github.com/milktea-cus/MCP-FBMN/actions/runs/43154778431) **4/4 PASS** (Flutter 158 unit/widget, 3 Chrome IndexedDB, Android debug build; không phải Android release). Production Cloudflare Worker APK API đã smoke health/DB OK, unauthorized 401, unknown origin 403. Web production gần nhất P1-H; chưa xác minh web đã nhận mọi cập nhật Dart P0-I. Không gọi v1.0 nghiệm thu khi chưa có UAT thật.

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

## K0 — QUY TẮC PHÂN QUYỀN ĐÃ CHỐT

**Quyền = trạng thái tài khoản + khả năng nghiệp vụ (action) + grant đối tượng (địa bàn / nhân sự / nhóm / chuỗi / giao trực tiếp) + giới hạn theo record + audit.** Chỉ cùng tỉnh **không đủ** để tự thấy khách hàng của nhóm khác, và chỉ là cấp Manager cũng **không đủ** để sửa/duyệt.

- [ ] **Sơ đồ tổ chức vô hạn tầng:** giữ `admin/manager/sales` là role hệ thống; cấp chức danh có thể là Giám đốc/Khu vực/Giám sát nhưng không hardcode số cấp vào quyền. Giữ `manager_sub` là tuyến chính, hỗ trợ Manager quản lý Manager/Sales và quản lý nhóm/ủy quyền chéo có thời hạn khi được cấp; chặn chu kỳ và tự nâng quyền.
- [ ] **Phạm vi Manager cấu hình độc lập**: (A) `territory` — vùng/tỉnh/địa bàn được giao, gồm khách doanh nghiệp giao theo vùng; (B) `team` — nhân viên/đội trực tiếp + cấp dưới theo cây quản lý, bất kể khách nằm tỉnh nào; (C) `chain` — chuỗi/hệ thống khách được giao dù xuyên tỉnh; (D) `explicit` — KH/tài khoản được Admin giao riêng. Một người có thể có nhiều grant (hợp theo grants đã cấp); các giới hạn/deny và quyền action vẫn áp dụng.
- [ ] **Phân quyền thao tác riêng**: xem khách, tạo, sửa của mình, sửa khách thuộc nhóm, giao/chuyển khách, xem lịch/khảo sát, giao target, xem doanh số, export, xem ảnh, quản lý nhân viên, duyệt. Không suy quyền sửa từ quyền xem. Role mẫu có thể gán permission profile có lịch sử, không hardcode mọi Manager đều full.
- [ ] **Quản lý khách khác người tạo**: thêm `created_by`/người khởi tạo, `responsible_staff`, quan hệ `customer_assignments` tới nhân viên/nhóm/vùng/chuỗi, hiệu lực & lịch sử chuyển giao. **Không đổi nghĩa/xóa `owner_sub` cũ thô bạo**. Khách do Admin tạo chỉ hiện cho Manager khi đã *được giao* vào grant vùng/đội/chuỗi tương ứng; không mặc định hiện theo tọa độ cùng tỉnh.
- [ ] **Chuỗi hệ thống xuyên tỉnh**: catalog `chains`/account groups và membership khách/nhân viên; giao quản lý theo chuỗi hoàn toàn không bắt buộc Manager phải có địa bàn. Một khách có thể nằm trong vùng và chuỗi nhưng không nhân đôi customer/visit/actual. Không lạm dụng trường `category` (NPP/Đại lý...) làm chuỗi.
- [ ] **Mở rộng toàn quốc**: thay hardcode `districts_old.json`/13 tỉnh và `staff_scopes` miền Tây bằng danh mục vùng địa lý có ID/code bền vững, cấu trúc nhiều cấp & alias/hiệu lực, giữ mapping tên lịch sử. Không tự thay tên/tỉnh của khách cũ khi có thay đổi địa giới. Cho phép vùng bán hàng tùy biến, không ép chỉ tỉnh/huyện.
- [ ] **Giao trách nhiệm có quyền chuyển**: Admin giao/quản lý grant; Manager chỉ được giao tiếp trong các đối tượng đang quản lý và phạm vi ủy quyền, chặn nâng quyền rộng hơn grant gốc; log trước/sau, người giao, mốc hiệu lực, `scope_revision` của tất cả người bị ảnh hưởng.
- [ ] **Bảo mật backend/offline đồng nhất**: function/grants ở Neon + mọi API khách, media, khảo sát, lịch, Target, actual, order, push; 401/403 cho truy cập sai quyền; không trả dữ liệu chỉ để Flutter tự ẩn. Offline PWA IndexedDB, Android SQLite cách ly tài khoản+revision, revoke/quarantine dữ liệu khi quyền bị rút; kiểm lại phân quyền khi đồng bộ.
- [ ] **UAT ma trận**: Admin, Manager trên nhiều tầng, 2 Manager đồng cấp, Sales, người quản lý chuỗi xuyên 3 tỉnh, Manager theo nhân viên 0 địa bàn, Manager vùng có KH Admin *được giao*, KH cùng tỉnh *không được giao*, manager khóa, chuyển đội, chu kỳ tổ chức, đổi tài khoản offline, overlap grant và audit.

**Mặc định an toàn:** KH/Admin chưa được giao vẫn không hiển thị cho Manager. Nếu business muốn Manager lãnh đạo vùng xem kho KH thuộc công ty, phải có grant doanh nghiệp `territory_pool` rõ ràng; grant này chỉ là quyền `read` nếu không có quyền sửa bổ sung.

### Cấu trúc additive đề xuất (không phải migration đã áp dụng)

`geo_nodes` (ID, hierarchy, loại, tên/code/alias, hiệu lực), `staff_team_memberships`, `team_delegations`, `customer_chains`, `chain_memberships`, `access_grants` (subject, type, scope, permission, hiệu lực, issued_by), `customer_assignments` (đối tượng được giao, quyền, từ/đến, lịch sử), `permission_profiles` + audits. Giữ tương thích ngược dữ liệu `staff_members`/`staff_scopes`, tránh làm hỏng `sales_can_access` trước khi viết policy mới và regression. Không cho bất kỳ người dùng có cùng địa chỉ tỉnh tự xem KH khi thiếu grant.

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

**Đối chiếu MCP Mobi:** nguồn tham chiếu nội bộ `docs/MCP_MOBI_REFERENCE.md` ghi repo `binhnxwjfjxm/mcp-mobi` tại `e8e9bbd` chỉ có ảnh demo `ui-tham-khao.jpg` và README, **không có source mô hình/route/session để xác minh**; tại audit 13/11 repo qua connector trả 404. Do vậy không xác nhận “giống hệt MCP Mobi”. Điểm khác nghiệp vụ Field Work là *kế hoạch tháng di chuyển linh hoạt, không ép tuần cố định*.

## P0-M — TARGET: BỎ SKU KHỎI PHÂN BỔ, CHUYỂN THÀNH ĐỊA BÀN

- [ ] M-1: phân bổ Target theo **nhân viên** (cha) → **địa lý/vùng bán hàng** (con); hiển thị vùng/tỉnh/khu vực được giao theo chính sách P0-K; không cho chọn SKU trong phần phân bổ.
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
