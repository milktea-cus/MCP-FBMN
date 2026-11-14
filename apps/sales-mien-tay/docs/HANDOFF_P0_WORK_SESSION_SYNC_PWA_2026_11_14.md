# BÀN GIAO CHAT MỚI — MCP-FBMN: P0 WORK SESSION + 409 + PWA UPDATE

**Ngày audit:** 14/11/2026  
**Ưu tiên:** P0-blocker; Owner báo mất gần một ngày vì luồng Công tác khó hiểu, 409 và banner tím chờ đồng bộ.  
**Trạng thái:** AUDIT HOÀN THÀNH, **CHƯA THI CÔNG / CHƯA NGHIỆM THU** các hạng mục trong tài liệu này.

## 0. Nguồn đã đọc trực tiếp và điều kiện làm việc

- **Repo CHỈ được sửa:** https://github.com/milktea-cus/MCP-FBMN (branch `main`); chuẩn UI `standards/ui-fbmn/`.
- **Repo tham khảo trực tiếp theo Owner:** https://github.com/gustavjung01/mcp-mobi (branch `main`). ĐÃ ĐỌC source Flutter của repo này, không đánh đồng với tài liệu cũ `MCP_MOBI_REFERENCE.md` vốn mô tả **repo khác** `binhnxwjfjxm/mcp-mobi` chỉ có ảnh tham khảo.
- Source tham chiếu: `mcp-mobi/lib/features/routes/routes_page.dart`, `lib/features/routes/fixed_routes_page.dart`, `lib/core/data/field_data_client.dart`, `lib/core/data/route_management_client.dart`, `lib/core/sync/route_management_sync.dart`, `docs/mcp-parity-matrix-l0.md`.
- **Hạ tầng giữ nguyên:** Neon production `raspy-bar-51596929` branch `br-super-mountain-bdije4mj`; Worker `field-sales-api` và 7 binding/secret đang có; Vercel project `sales-mien-tay`, production https://sales-mien-tay.vercel.app.
- **Vercel BẮT BUỘC deploy thủ công bằng Vercel plugin/API đã kết nối**, theo SHA `main`, **không cần/xin token, không bắt Owner chạy CMD, không deploy qua comment Issue, không tạo project/preview**, không tiêu hao quota GitHub Actions. `build-vercel.sh` chạy typecheck + DB contract + Flutter analyze/test/web build/offline-shell.
- PWA phone dùng **IndexedDB**; Android native dùng **SQLite**, không xóa dữ liệu chưa đồng bộ và không đặt token trong DB business.

## 1. Bằng chứng lỗi và nguyên nhân gốc

### A — **409 vì tự tạo hai địa bàn trùng trong cùng tuyến (đã chứng minh bằng code + index)**

**Chuỗi tái hiện logic:**
1. `apps/sales-mien-tay/apps/sales_flutter/lib/monthly_plan.dart`, `_edit()` khoảng dòng 106–127: khi tạo kế hoạch theo `territory`/`chain` mà không chọn khách, app **tự enqueue** một route stop `area`/`chain` vào `POST /api/v1/day-routes/:id/stops`. Kế hoạch mới đã có sẵn điểm tìm khách.
2. `lib/day_route.dart`, `addAreaOrChain()` khoảng dòng 128–149: màn Tuyến ngày **vẫn hiển thị nút “Điểm tìm khách”/“Điểm công tác chuỗi”**, mỗi lần bấm tạo UUID mới và enqueue thêm cùng `province,district` hoặc `chain_id`. **Không kiểm tra stop cùng scope đã tồn tại** trước khi enqueue.
3. Neon production có unique `field_route_stops_area_once ON(day_route_id,province,district) WHERE stop_kind='area'`, và `field_route_stops_chain_once ON(day_route_id,chain_id)`. Do đó thêm địa bàn/chuỗi lần hai bị chặn, Worker trả **HTTP 409**. **Không được bỏ unique constraint để che lỗi**.
4. Một đường 409 khác: `day_route.dart::addUnplanned()` cho “Điểm phát sinh → Tìm điểm bán / lead mới” tạo `POST /api/v1/day-routes/:id/unplanned-stops` với `stop_kind=area/chain`. DB vẫn chịu cùng unique constraint planned + unplanned. Dù popup có `scopeAlready`, state stale hoặc thao tác trước chưa đồng bộ vẫn tạo xung đột.
5. Hệ quả nghiệp vụ: **địa bàn/chuỗi là phạm vi của PHIÊN, không phải một điểm khách cần tạo thêm**. Tránh tạo stop đại diện địa bàn lặp lại; lịch tìm khách mới không cần khách giả.

Chưa truy xuất được payload đúng row iPhone Owner, do đó chỉ có thể khẳng định **đường lỗi 409 tất yếu trên các kịch bản nêu trên**, không gán chắc lỗi trên iPhone cho một UUID cụ thể.

### B — **Banner đồng bộ tím bị kẹt và nút thử lại không giải quyết**

- `lib/offline_queue.dart::isRouteDuplicateConflict()` (~ dòng 220): chỉ nhận dạng `POST /api/v1/day-routes` và `POST /api/v1/day-routes/:id/stops`; **không nhận `unplanned-stops`**. Khi endpoint này 409, row thành `status='blocked'` nhưng không có đối chiếu/ACK phù hợp.
- `sync()` (~ dòng 514): `pending.isNotEmpty && readyCount==0` thì RETURN; `start()` retry mỗi 30 giây nhưng blocked row **không tự được giải quyết**; banner ở `main.dart::SyncQueueBanner` còn tồn tại khi `pending`/error khác rỗng.
- `main.dart::showSyncQueueDetails` có nút “Thử ngay” và “Đối chiếu...” nhưng `onPressed:queue.syncing?null:...`; `retryBlocked` còn RETURN khi `syncing` hoặc `_reconciling`. Người dùng có thể thấy **bấm không phản hồi** khi state đó còn true; cần điều tra thực tế trên Safari PWA (không kết luận mọi lần click đều bị chặn).
- `isStalled` chỉ ghi thông báo khi >2 phút, không phải cơ chế recovery chắc chắn. Lỗi `409` nghiệp vụ không được giải quyết bằng POST lặp lại.
- Cần phân biệt `pending/processing/blocked(conflict)/waiting_dependency/acknowledged`; nút phải luôn báo hành động/phản hồi trong thời gian hữu hạn và không làm mất survey/ảnh chưa gửi.

### C — **Thiếu mô hình PHIÊN công tác như MCP**

- FBMN hiện có `MonthlyPlan → DayRoute → RouteStop → Visit/AreaVisit/SurveySession`. `field_day_routes.status` hiện phục vụ `ready/cancelled`; database hiện chỉ có bảng tên `field_survey_sessions` (phiên **khảo sát**), **không có vòng đời phiên đi thực tế riêng** `open / ongoing / done / cancelled` theo địa bàn/chuỗi/khách.
- `WorkHubPage` hiện chỉ có `Kế hoạch/Hôm nay/Kết quả`, mở thẳng `DayRoutePage`; màn này trộn quản lý danh sách điểm kế hoạch, điểm địa bàn giả, điểm phát sinh, mẫu tuyến, xóa lịch, khảo sát và GPS. Nút bấm không thể hiện ý nghĩa phiên.
- Repo `gustavjung01/mcp-mobi` phân biệt **Tuyến cố định → Bắt đầu phiên (`POST /api/mcp-day/open-session`) → Phiên đang đi chứa khách → Check-in/Bỏ qua/ghi báo cáo, đơn, thử sản phẩm, follow-up → Kết thúc/Hủy/Xóa phiên rỗng**. Source: `lib/features/routes/routes_page.dart`, `lib/core/data/field_data_client.dart`, `lib/core/data/route_management_client.dart`. **Tham khảo UX + state machine, không chép nguyên API**: FBMN di chuyển đổi ngày và scope mỗi tháng, không theo tuần cố định. Chính tài liệu parity `mcp-mobi/docs/mcp-parity-matrix-l0.md` còn ghi một số luồng PARTIAL/chờ runtime test, không coi app tham khảo đã hoàn hảo.

### D — **PWA phải vuốt tắt hai lần mới cập nhật, không có nút Cập nhật**

- `apps/sales_flutter/scripts/build_offline_shell.py`: sinh `filed-sw.js` hash theo asset, cache app shell, `skipWaiting/clients.claim` và `register('/filed-sw.js').then(reg=>reg.update())` **chỉ khi index.html chạy/khởi động**, không có UI “Bản mới → Cập nhật ngay” hoặc xử lý rõ `controllerchange`/xác nhận `build version` mới đã thực sự hoạt động.
- `main.dart::SalesHomeDrawer.onUpdate` **chỉ gán callback Android native** (`!kIsWeb && TargetPlatform.android`); PWA không có đường cập nhật thủ công. `app_update_page.dart` chỉ là luồng APK Android/R2.
- Chuẩn lưu tại `standards/references/qr-app/docs/PWA_STANDARD.md` yêu cầu **deploy sinh version mới; update không yêu cầu người dùng reload thủ công**. Không được hướng dẫn Owner xóa app/site data/IndexedDB để nhận bản mới, không được đổi app ID/origin.

### E — DB production ở thời điểm audit (read-only)

- Có **2 kế hoạch** tại Bình Đại, Bến Tre ngày **12 và 14/11/2026**, cả hai đã `cancelled`; **0 planned**.
- Mỗi kế hoạch có một route `cancelled` và một area stop `is_unplanned=false`; chưa có `area_visit` hay `survey` gắn hai route đó.
- Audit này KHÔNG sửa/xóa thêm row production. Thay đổi DB trước đó (fix lỗi audit SQLSTATE 23514 cho Xóa lịch) đã được ghi `P0_SCHEDULE_DELETE_409_PRODUCTION_RCA_2026_11_14.md`.
- Production gần nhất khi audit: Vercel `dpl_FSWXkr2urc3L6rpLhDQ3UW1pEgKN` READY; Worker đã có xử lý trùng `day-routes/:id/stops` và `X-Sync-Protocol:2` nhưng **chưa có recovery unplanned + session UX + PWA update UI**.

## 2. Hợp đồng nghiệp vụ phải chốt để làm (Owner đã nói rõ)

**“Lịch” = kế hoạch dự kiến trong tháng** (ngày/thời gian, địa bàn/chuỗi/khách, mục tiêu), có thể thay đổi qua từng tháng.

**“Phiên” = lần đi thực tế theo một scope `territory | chain | customer` và ngày công tác.** Một scope là bối cảnh của phiên, KHÔNG phải một route stop địa bàn trùng lặp.

Luồng một đường, mobile gọn:

`Công tác → Kế hoạch (chọn ngày/scope/khách) → Bắt đầu hoặc Tiếp tục phiên → Khách trên phiên → Ghé khách / Tìm khách mới → Hoạt động tại khách → Kết thúc phiên → Lịch sử/Kết quả`.

- Phiên địa bàn: khách đã gắn địa bàn hiển thị sẵn, chọn nhiều; **0 khách vẫn mở phiên** để tìm khách/lead ngoài thị trường. Tìm khách mới mở luồng **đi tìm/ghi nhận thực tế trong phiên**, không tự INSERT thêm area stop mỗi lần bấm.
- Phiên chuỗi: danh sách khách thuộc chuỗi trong quyền, kể cả xuyên tỉnh; không tạo chain stop trùng.
- Phiên khách: mở thẳng khách đó.
- **Tại mỗi khách:** GPS/check-in (nếu hợp lệ), ghi nhận ghé hoặc không ghé + lý do; khảo sát nhãn hàng/đối thủ, ảnh, ghi chú, đơn, việc theo dõi. Những phần chưa có không tạo nút giả. Check-in không tự coi là đã khảo sát.
- Khách mới chưa được định danh thì tạo **lead** thực tế, có thông tin/GPS/ảnh/ghi chú; sau xác minh mới tạo/liên kết hồ sơ khách. Không tạo customer giả.
- Kết thúc/hủy phiên theo trạng thái; xóa **phiên rỗng** có xác nhận, phiên đã có hoạt động phải giữ lịch sử. Xóa kế hoạch và xóa phiên là hai nghiệp vụ khác nhau.
- Một Sales có thể phụ trách nhiều tỉnh/huyện, chuỗi hoặc khách riêng; quyền kiểm ở DB/API, không chỉ ẩn UI. Manager xem cây nhân viên theo scope, không tự có quyền sửa của cấp dưới.
- Nhãn thị trường đếm **khách × nhãn × khu vực** DISTINCT, không theo SKU Futurebook hay số lần khảo sát; ghi lại tháng sau ở cùng khách không làm tăng số khách kinh doanh nhãn.

## 3. Pha sửa bắt buộc (THỰC THI, KHÔNG DỪNG Ở PLAN)

### P0-A — Loại tận gốc duplicate area stop + xử lý 409

1. Loại cơ chế tạo area/chain stop như một “điểm ghé” khi mở phiên scope; lịch rỗng khách vẫn hợp lệ. Ẩn/bỏ nút `addAreaOrChain` gây trùng khỏi view thực địa. Thay `addUnplanned` cho tìm lead bằng luồng ghi nhận thực địa của **phiên**, không INSERT area trùng.
2. Giữ nguyên/đọc được dữ liệu route/area stop cũ và các khóa unique DB; migration tương thích, **không xóa khách/visit/survey production**.
3. Cố định `client_ref` cho mỗi thao tác và nội dung nghiệp vụ, không đổi UUID chỉ vì retry, mở lại hoặc chuyển trang. API trả canonical ID nếu duplicate chính xác, khác nội dung là conflict có giải pháp cụ thể.
4. Xử lý `unplanned-stops` trong resolver/outbox; chỉ acknowledge khi GET đúng scope/status/canonical hoặc đã confirmed archive và không có draft/ảnh/visit phụ thuộc. Với xung đột khác, hiển thị lựa chọn an toàn, không tự POST lại vô hạn.
5. Backend trả business error code rõ `ROUTE_ALREADY_HAS_AREA`, `SESSION_CLOSED`, `SCOPE_REVOKED`, v.v.; 409 không nuốt thành thông báo chung.

### P0-B — Phiên công tác thực sự, một UX

1. Thiết kế schema/state machine **phiên thực tế** (`open/ongoing/done/cancelled`, user/date/scope, version, audit, FK về kế hoạch/tuyến) tách với `field_survey_sessions`, additive migration và kiểm thử cạnh tranh/đa thiết bị. Lựa chọn cụ thể bảng hoặc tái sử dụng entity phải bảo đảm **vòng đời rõ ràng**, không gắn “phiên” giả cho mỗi area stop.
2. API: bắt đầu/tiếp tục/đóng/hủy/xóa phiên rỗng, lấy khách trong quyền theo scope, ghi check-in, khảo sát, phát sinh/lead. Phiên đã đóng có chế độ đọc lịch sử. Chống hai phiên active xung đột một cách có giải thích, tránh báo generic 409.
3. UI theo MCP tham khảo nhưng FBMN kế hoạch tháng biến động: màn Hôm nay có **Bắt đầu phiên/Tiếp tục phiên**, status phiên và số khách đã ghé, danh sách khách theo scope. Trong phiên có **Tìm khách mới** (nếu địa bàn/chuỗi) và thêm khách thật; chọn khách mở việc của khách. Hạn chế một hành động chính mỗi màn; tuân chuẩn `standards/ui-fbmn`.
4. Không chừa hai đường song song `field_work.dart` legacy và `WorkHub/day_route` cùng tạo tuyến cho Sales; thống nhất entrypoint, legacy chỉ đọc lịch sử sau migration.

### P0-C — Hàng đợi offline & banner không thể treo vô hạn

1. Tách trạng thái UI khỏi mạng: `pending/sending/waiting_dependency/blocked/reconciled`; giới hạn thời gian các lần gửi; cuối request hoặc timeout luôn báo trạng thái + cách xử lý, không “Đang gửi…” mãi.
2. Banner là nút mở **trang Chẩn đoán đồng bộ** luôn tương tác; hành động “Đối chiếu / Gửi tiếp / Giữ bản nháp / Xem lỗi” có phản hồi ngay; không cấm mọi nút khi một Future bị mắc kẹt. Chỉ vô hiệu hóa thao tác ghi có thể trùng.
3. Kiểm thử IndexedDB mở lại PWA, force-close, airplane mode, 409 ở planned/unplanned, 401, 403 revoke, 404, 500, network timeout; không mất hồ sơ/ảnh/khảo sát/đơn, không rò giữa tài khoản/scope revision.
4. Sau sync xong và hết lỗi, banner phải biến mất ngay cả khi người dùng đã qua màn khác, không giữ lỗi cũ nếu không còn row liên quan.

### P0-D — Cập nhật PWA một chạm, an toàn dữ liệu

1. Bổ sung **nút “Cập nhật ứng dụng” cho PWA ở menu** (khác APK Android); luôn cho “Kiểm tra bản mới”, hiển thị mã bản cài/đang chạy với commit/build SHA; khi có bản mới, “Cập nhật ngay”.
2. Phát hành `version.json` hoặc build manifest theo commit (no-store) và bridge service worker cho `registration.update()`, `updatefound`, `waiting/skipWaiting`, `controllerchange`; chỉ reload khi bản mới được kích hoạt thành công. Không reload khi đang nhập form chưa ghi bền vào IndexedDB; có lưu draft/đối chiếu trước.
3. PWA iPhone cần mở lần đầu kiểm bản mới, hiện thông báo dễ hiểu; **không phụ thuộc vuốt đóng hai lần**, không yêu cầu xóa cache Safari/IndexedDB, không làm mất session hoặc hàng đợi.
4. E2E **nâng cấp version A → B** khi có outbox + draft đang chờ trên iPhone Home Screen PWA; xác nhận dữ liệu và thao tác mới giữ nguyên.

### P0-E — Gate nghiệm thu & deploy production trực tiếp

1. Test **DB thật/API Worker thật có auth**: tạo lịch scope/khách, không tạo 2 area stop, mở phiên, thao tác tại khách, nhiều vùng/chuỗi, đóng/hủy/xóa rỗng, idempotency, 401/403/409, audit. Mock Flutter không thay E2E.
2. Test UI thật 320/360/390px, **iPhone PWA Home Screen** (tap mọi nút và cập nhật A→B), Android PWA/SQLite native theo khả năng, chuyển foreground/background, offline/reconnect. Không tick done nếu thiếu chứng cứ máy thật.
3. Commit từng pha lên `main`; typecheck + DB contract + Flutter analyze/test/build + smoke, sửa lỗi xong mới sang pha. Trước Neon migration kiểm FK/constraint/audit, sau migrate query đọc xác thực. Worker deploy giữ nguyên 7 secret/binding.
4. **Deploy Vercel manually via connected Vercel plugin/API to existing production project** (GitHub `main` SHA, root `apps/sales-mien-tay/apps/sales_flutter`, `build-vercel.sh`, output `build/web`, `vercel.json` rewrite giữ nguyên); không token, không CMD, không comment deploy, không tạo preview. Kiểm tra production domain `sales-mien-tay.vercel.app`, origin/API/Auth/offline/version và ghi deployment ID.
5. Cập nhật Issue #3 và checklist với `DONE / BLOCKED / PENDING UAT` riêng; báo ngắn **đã sửa, commit, test, deployment, lỗi còn lại**. Không nói “dứt điểm” chỉ vì 203 tests mock hoặc READY.

## 4. Bản tiếp theo bắt đầu bằng gì

**Bắt đầu P0-A trước:** từ `monthly_plan.dart::_edit` + `day_route.dart::addAreaOrChain/addUnplanned` + `day_routes.ts` + unique index; viết regression “kế hoạch địa bàn 0 khách → mở phiên tìm khách mới lặp lại 3 lần → 0 POST stop area trùng và 0 blocked 409”. Sau đó xử lý stuck outbox của version cũ, không xóa row thiếu bằng chứng. P0-B/C/D/E phải đi cùng để nghiệm thu tổng, không chỉ vá một nút.

**Điều cấm:** không viết prompt/planning rồi dừng, không tắt unique constraint, không xóa production để trông hết lỗi, không tự tạo dữ liệu demo, không làm mất IndexedDB, không chuyển Vercel project, không yêu cầu Owner cung cấp token.

---

Nguồn chính: [MCP-FBMN main](https://github.com/milktea-cus/MCP-FBMN), [MCP Mobile main](https://github.com/gustavjung01/mcp-mobi), [L2 workflow đã chốt](WORKFLOW_CONG_TAC_P0_L2_2026_11_13.md), [production RCA 23514/409](P0_SCHEDULE_DELETE_409_PRODUCTION_RCA_2026_11_14.md).
