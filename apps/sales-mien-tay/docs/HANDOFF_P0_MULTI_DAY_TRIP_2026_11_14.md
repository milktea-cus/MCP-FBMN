# BÀN GIAO CHAT MỚI — P0 CHUYẾN CÔNG TÁC DÀI NGÀY (14/11/2026)

> **ƯU TIÊN P0 — CHƯA THỰC HIỆN / CHƯA NGHIỆM THU.**
> Owner yêu cầu triển khai **thật** trên `milktea-cus/MCP-FBMN` branch `main`; kiểm thử, commit, tự deploy production, báo chứng cứ. **Không chỉ lập kế hoạch, không vá UI/logic rời rạc.**
>
> **Tài liệu này là bàn giao mới nhất cho riêng phần chuyến dài ngày.** Các mô tả “Bắt đầu phiên thủ công” và trạng thái DB cũ trong `HANDOFF_P0_WORK_SESSION_SYNC_PWA_2026_11_14.md` là ảnh chụp audit *trước khi có work sessions*; **không dùng nguyên trạng để thiết kế lại**. Nghiệp vụ mới của Owner được ưu tiên tại đây.

## 0. Trạng thái kiểm tra trước khi bàn giao

- GitHub `main` **`4b73abb0033f244362e8fac2951bc33ab0029016`**; [CI run 43582585633](https://github.com/milktea-cus/MCP-FBMN/actions/runs/43582585633): **4/4 job PASS**, gồm Flutter Web, Android **debug** APK, TypeScript, source guards. Không suy diễn APK signed release hoặc UAT Android thật.
- Vercel production **`dpl_CJx17HaZ2L5D8YaNW3Uvodw5sMrf` READY**, domain [sales-mien-tay.vercel.app](https://sales-mien-tay.vercel.app), đúng SHA trên. Worker `field-sales-api` production đang sử dụng version **`31ba2e6f-907b-4b6a-9bf1-1179157c9720`**, đã kiểm tra 7 bindings giữ nguyên; Neon production dự án `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`, đã áp migrations **052–053** cho *hoạt động tại khách*, **không phải schema chuyến dài ngày**.
- **P0 chuyến dài ngày còn 0% nghiệm thu**. Hiện `field_monthly_plans.work_date` một ngày, `field_day_routes.route_date` một ngày, `field_work_sessions.day_route_id` một tuyến ngày; `WorkHubPage.dayRoutes` lọc **ngày đúng bằng hôm nay**, `openRoute()` tự mở work session khi vào tuyến ngày. `MonthlyPlanEditor` dùng ngày đơn. Có nút **Kết thúc sớm** ở tuyến ngày nhưng **không có Gia hạn chuyến**. Cần thiết kế lại mô hình để hỗ trợ một chuyến qua nhiều ngày và nhiều scope.
- Phần đã có code **không được đập đi làm lại**: danh sách khách trong phạm vi, `CustomerWorkPage` (nhãn/NPP theo mẫu, ghi chú, GPS thực tế, ảnh, đơn), liên hệ nhanh Maps/Zalo/điện thoại, `OfflineQueue` IndexedDB/SQLite, hành vi thị trường chống trùng khách–nhãn, `CustomerEditor` tạo khách mới tự liên kết, phân quyền DB/API, soft delete/audit. **Chưa có chứng cứ UAT iPhone/Android thật và outbox 409 cũ**; cần kiểm lại cùng chuyến dài ngày.
- [Issue #3](https://github.com/milktea-cus/MCP-FBMN/issues/3) là **tracker tổng**. [Issue #4](https://github.com/milktea-cus/MCP-FBMN/issues/4) là audit/UAT tồn; không tạo roadmap thứ hai. Các checklist lịch sử trong Issue #3 không phản ánh trạng thái source mới — đối chiếu current main trước khi sửa.

## 1. Hợp đồng nghiệp vụ Owner đã chốt — không hỏi lại

### 1.1 Một CHUYẾN thay vì nhiều “phiên ngày”
- **Một chuyến công tác** có `start_date` → `end_date` (đầu/cuối **bao gồm**), người phụ trách, mục đích, nhiều **phạm vi**: một hoặc nhiều **tỉnh/huyện, chuỗi xuyên tỉnh, khách cụ thể**; nhiều khách có thể cùng xuất hiện ở nhiều scope nhưng **không nhân đôi trong danh sách**.
- Ví dụ chuyến **14–17/11/2026**: ngày 14, 15, 16 và 17, màn **Hôm nay** tự hiểu **cùng chuyến** (ngày 1/4 → 4/4), không phải mở phiên mới hằng ngày. Có thể có các hoạt động, GPS, ảnh, đơn trong những ngày khác nhau thuộc cùng `trip_id`.
- **Không cần nút “Bắt đầu phiên”**. Tới ngày hệ thống tự xác định chuyến đang trong thời hạn; mở Hôm nay đi thẳng vào danh sách khách. Trước ngày là `Sắp diễn ra`. Hết `end_date` mà chưa đóng là **`Quá hạn`**, **KHÔNG tự đánh dấu hoàn thành**, vẫn thấy lịch sử và có tùy chọn gia hạn/kết thúc.
- **Giữ “Kết thúc sớm”** (xác nhận, có lý do/ghi chú, giữ lịch sử chưa ghé và đã ghé). **Bổ sung “Gia hạn”** chọn ngày kết thúc mới khi đang đi hoặc quá hạn; cập nhật **chính chuyến hiện tại**, không tạo chuyến/khách/khảo sát mới, không reset GPS/ảnh/đơn. Sau khi đã kết thúc, chỉ đọc lịch sử; không cho chỉnh ngầm thành đang đi. Quyền gia hạn/kết thúc do backend kiểm, audit actor/time/version.
- Trạng thái đề xuất UI: `Sắp diễn ra`, `Đang công tác`, `Quá hạn`, `Đã kết thúc` (và `Đã hủy` nếu nghiệp vụ yêu cầu). Phân biệt **trạng thái chuyến theo lịch** với **trạng thái đồng bộ** và **thực tế đã đi**. “Đến ngày” không tự khẳng định đã ghé.
- Có thể chọn ngày khi **xem lịch sử/đổi lịch** nhưng không biến ngày xem thành phiên phải bắt đầu thủ công. Luật xử lý chuyến trùng thời gian của cùng một Sales cần nhất quán tại backend, không dựa nút ẩn UI.

### 1.2 Danh sách khách & thao tác trong chuyến
- Chọn phạm vi địa bàn/chuỗi là **ngầm bao gồm tất cả khách được phân quyền trong phạm vi**. Tick khách **ưu tiên** không giới hạn khách hiển thị/được ghé; có thể 0 khách để phát triển thị trường. Khách mới được tạo trong chuyến là **khách thực** trong danh mục Khách hàng và tự nối đúng chuyến/phạm vi. Không tạo khách/area stop giả.
- Một danh sách khách duy nhất; lọc/tìm kiếm; icon/màu **đúng với tab Khách hàng**: NPP cam, Đại lý tím, Nhà sách xanh dương, VPP xanh lá (và các loại khác theo component chung). Bên ngoài thẻ: **Chỉ đường / Gọi điện / Zalo** nếu dữ liệu cho phép.
- Chạm khách → **một màn “Làm việc với khách”**, có Back trở lại danh sách, **không tự mở phiên khảo sát mới**, không màn trắng. Tại đó: lựa chọn nhiều **nhãn hàng thị trường** nếu admin đã cấu hình, chọn nhiều **NPP đang lấy** hoặc “Mua trực tiếp công ty” từ mẫu, ghi chú ngắn, ảnh cửa hàng, GPS thực tế, **Ra đơn**, lịch sử lần ghé và hạng mục tùy biến từ mẫu thiết lập. Cấu hình mẫu ở **Menu ☰**, không chen nút vào Hôm nay.
- **Có hoạt động thực tế đã lưu** (check-in / ghi chú / khảo sát / ảnh / đơn) → thẻ ghi **Đã ghé**; nếu không check-in, quản lý nhìn được **thiếu bằng chứng GPS** để kiểm tra, không chặn mọi nghiệp vụ. Nhãn đã tick tự cập nhật quan hệ khách–nhãn, **một khách–nhãn chỉ đếm một** qua nhiều chuyến; không trộn với SKU Futurebook. Chưa có tọa độ cửa hàng không được chặn lấy GPS của Sales, **không ghi đè GPS cửa hàng đã xác minh**.
- **Giữ mọi tính năng đang chạy tốt**; trọng tâm pha này là chuyến dài ngày và nối data/permission/offline xuyên ngày, không tạo một hệ thống làm việc khách thứ hai.

## 2. Nguyên nhân gốc / các file phải đọc trước khi sửa

| Thành phần | Trạng thái source hiện tại / cần làm |
| --- | --- |
| `apps/sales-mien-tay/backend/migrations/034_monthly_field_plans.sql` | `field_monthly_plans.work_date date NOT NULL`, unique theo **owner, ngày, scope**; một ngày, một scope trên một plan. Không có `start_date/end_date` chuyến |
| `.../migrations/035_day_routes_and_stops.sql` | `field_day_routes.monthly_plan_id UNIQUE`, `route_date date NOT NULL`; child route stop gắn **tuyến ngày**. Cần tránh phá FK/history |
| `.../migrations/049_field_work_sessions.sql` và `050/051` | `field_work_sessions.day_route_id UNIQUE`, `state ongoing/done/cancelled`, unique owner ongoing; các hàm/guards gắn **ngày**. Phải rà mọi guard khi thêm chuyến, không lách permission |
| `.../backend/src/monthly_plans.ts` | Validate `work_date` nằm trong tháng `period_ym`, chỉ có scope đơn, version/owner auth |
| `.../backend/src/day_routes.ts`, `work_sessions.ts`, `customer_work.ts` | Route/customer candidate/work-session/activity read/write phụ thuộc `route_id`, `route_date`/work session. Phải đổi/điều chỉnh API đồng bộ, idempotency và khoá quyền |
| `.../apps/sales_flutter/lib/monthly_plan.dart` | `MonthlyPlanEditor` chọn **một ngày**, chọn nhiều scope nhưng tạo **nhiều plan+day_route** theo ngày; không có trip range |
| `.../apps/sales_flutter/lib/work_hub.dart` | `dayRoutes` lọc `route_date == selected day`; `openRoute()` tự enqueue bắt đầu phiên đúng ngày; phải mở cùng trip liên tục trong khoảng ngày |
| `.../apps/sales_flutter/lib/day_route.dart`, `customer_work_page.dart` | Danh sách khách/stop, phiên, thao tác tại khách; giữ reuse, không xây popup khảo sát mới |
| `.../apps/sales_flutter/lib/offline_queue.dart`, `work_session_identity.dart` | Bền vững IndexedDB/SQLite, `client_ref`/dependsOn, reconcile 409, identity theo route; cần trip UUID ổn định qua ngày |
| `standards/ui-fbmn/` | Token/theme/component gốc, không vá CSS/màu tùy tiện |

**Tài liệu tham khảo:** [MCP-Mobi](https://github.com/gustavjung01/mcp-mobi) cho thao tác xuống khách; không sao chép “tuyến cố định/phiên ngày” sang FBMN. FBMN di chuyển theo lịch tháng đổi ngày và chuyến nhiều ngày.

## 3. Hướng triển khai bắt buộc theo pha (định nghĩa done rõ)

### P0-T1 — Phân tích quan hệ và hợp đồng kỹ thuật
- [ ] Đọc **current main + Issue #3 + handoff này + UI standards**, xác minh **Neon production schema/index/guard hiện tại chỉ đọc** trước khi tạo migration.
- [ ] Thiết kế **một thực thể chuyến duy nhất** (đề xuất trip header + trip scopes + dữ liệu hoạt động theo ngày). Có thể giữ day route làm lịch con/tương thích legacy, **không gộp nhiều lịch ngày giả thành “một phiên” ở UI**, không dùng cookie/local state làm nguồn sự thật.
- [ ] Quy định ID ổn định, owner, scope, khoảng ngày, version, audit, quyền Manager/Sales, time-zone `Asia/Ho_Chi_Minh`; đường nâng cấp lịch một ngày cũ **không đổi/gãy ID lịch sử**.

### P0-T2 — Neon + Worker backend thật
- [ ] Migration **additive, rollback-safe**, tránh xóa/bẻ cột `work_date`, `route_date` hoặc các FK cũ; không sửa dữ liệu chuyến/khách production để “cho test pass”. Nếu cần backfill, tách kiểm kê/đối chiếu, không tự sửa record lịch sử.
- [ ] API tạo/sửa chuyến range + nhiều scope; GET chuyến hiệu lực hôm nay, GET khách thuộc union scopes đúng grants, GET lịch sử theo `trip_id`; **Gia hạn** / **Kết thúc sớm** optimistic `version + mutation_ref` và audit. Timezone VN, phân quyền server-side; không cho role xem tự động sửa.
- [ ] Với chuyến qua nhiều ngày: một hoạt động thực tế có `trip_id` xuyên ngày + timestamp/Ngày ghé; giữ tương thích `day_route_id` hiện hữu, bảo đảm không orphan ảnh/khảo sát/đơn. Không yêu cầu **bắt đầu work session mới hằng ngày**; backend có cơ chế tự hợp lệ theo ngày được phép hoạt động, khác check-in GPS.
- [ ] Giữ 409 có mã lỗi nghiệp vụ rõ, không tắt unique/index để che lỗi. Retry UUID chính xác phải idempotent, khác payload phải conflict và không mất evidence.

### P0-T3 — Flutter UI chuẩn FBMN
- [ ] Kế hoạch: chọn từ ngày → đến ngày, gán **nhiều địa bàn/chuỗi/khách**, khách ưu tiên tùy chọn; có xem trước số ngày và scope; ngày xuyên tháng được xác định rõ, không bị cắt ở ngày 28/31.
- [ ] Hôm nay: tự có chuyến nếu hôm nay trong range; hiển thị `Ngày X/Y`, số khách/đã ghé/chưa ghé, tìm/lọc/thêm khách; icon/phím tắt gốc. **Không Bắt đầu phiên**, chỉ **Gia hạn** và **Kết thúc sớm** trong vị trí dễ hiểu, có xác nhận và audit.
- [ ] Khi quá hạn: không tự `done`, không làm mất pending hoặc lịch sử; cho lựa chọn hợp lệ để gia hạn/kết thúc. Người dùng mở chuyến qua các ngày vẫn vào cùng danh sách/hoạt động, không bị trắng hoặc mở phiên khảo sát mới.
- [ ] Reuse `CustomerWorkPage` và mẫu menu hiện có; đảm bảo việc đã lưu được gắn `trip_id` đúng day/time và quyền.

### P0-T4 — Offline/sync + hồi quy
- [ ] PWA điện thoại **IndexedDB**, Android native **SQLite**, isolation theo tài khoản/revision; lưu local trip ID và mọi child ID; không migrate bằng cách xóa object store/outbox.
- [ ] Offline lập chuyến 14–17, lưu nhiều khách/ghi chú/GPS/ảnh/đơn, qua ngày 15 vẫn cùng trip, mất mạng/restart, gia hạn, sync parent-before-child không trùng; concurrent extension vs close từ hai máy → 409 có cách giải quyết, **không xóa draft**.
- [ ] Kiểm thử thêm khách thuộc danh mục cố định, nhiều scope cùng khách không duplicate, 0 khách, chuỗi xuyên tỉnh, Manager chỉ xem khi không có quyền sửa, revoke/403, photo/R2 và 401/404/5xx; lịch cũ 1 ngày vẫn hoạt động. Regression outbox 409 đang tồn trên iPhone **PENDING UAT**, không giả định đã khỏi.

### P0-T5 — Nghiệm thu + deploy
- [ ] DB tests có transaction rollback/Neon branch và policy; API Worker authenticated E2E, audit/version/idempotency; Flutter test 320/360/390px và build Web+Android. **CI xanh ≠ UAT thực tế**.
- [ ] Các case bắt buộc: `14–17/11` xuyên 4 ngày; `29/11–02/12` xuyên tháng; nhiều địa bàn/chuỗi; 0 khách; kết thúc sớm 15/11; gia hạn 17→20/11; hết hạn chưa hoàn tất; ngày khác trong cùng trip; cùng khách nhiều scope chỉ một card; thiếu GPS shop vẫn check-in; offline qua midnight; đổi quyền/hai máy.
- [ ] Commit `main` từng pha, CI pass trước pha tiếp. Neon migration kiểm constraint/role/audit; Worker deploy production **giữ toàn bộ bindings/secrets/R2**; Vercel **manual deploy bằng connected API** đúng SHA trên project production hiện có, không tạo preview; smoke domain/API/auth/version. Ghi commit/CI/deployment chính xác vào Issue #3, không báo `DONE` nếu không có bằng chứng.
- [ ] UAT thực tế Android/iPhone Home Screen PWA với GPS, camera, Zalo, outbox cũ, kiểm logout/đổi account. Tách **DONE code/test**, **PENDING real-device UAT**, **BLOCKED**.

## 4. Định nghĩa không được gọi là “xong”

Không coi các trường hợp sau là đã hoàn tất P0 dài ngày:
1. Cho chọn 2 ngày rồi **tự sinh các phiên ngày độc lập** với nút bắt đầu/đóng riêng; hoặc chỉ vẽ UI “Ngày 1/4” bằng local state.
2. Đổi `route_date` hằng ngày để “giả” chuyến mà làm mất visit đã ghi hoặc thay UUID.
3. Hết `end_date` tự ghi `done` dù chưa đi; gia hạn lại tạo chuyến trùng; danh sách địa bàn bắt Sales tick lại từng khách.
4. Báo 409 đã khỏi khi chưa xử lý **row blocked thực tế** và chưa có test chịu lỗi PWA offline/hai máy.
5. Báo deploy/đã nghiệm thu sau khi chỉ build Flutter test mock hoặc Vercel `READY`, chưa có authenticated API + Android/iPhone UAT.

## 5. Yêu cầu của Owner cho chat mới

**Làm trực tiếp, không hỏi lại repo/hạ tầng:** `https://github.com/milktea-cus/MCP-FBMN.git` trên `main`. Đầu tiên đọc tài liệu này, Issue #3 và code mới nhất; thực thi P0-T1→T5 thật, commit + sửa lỗi + test + deploy production; báo ngắn **đã làm / commit / CI / DB / Worker / Vercel / tồn đọng UAT**. Không tự thêm repo/ZIP, không yêu cầu chạy CMD/đưa secret, không xóa production hay IndexedDB. **Chỉ hỏi Owner khi cần quyết định nghiệp vụ không thể suy ra hoặc cấp quyền.**

**Lưu ý kiểm tra source sau khi đọc:** nhiều tài liệu lịch sử ghi P0-A/B/C đã “chưa làm” theo audit 14/11 đầu ngày. Một phần sau đó đã được triển khai, vì vậy **không tick hoặc làm lại** chỉ dựa vào ghi chú cũ; xác định baseline từ `main` + Neon/API thật.
