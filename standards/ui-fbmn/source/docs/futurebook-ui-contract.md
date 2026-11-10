# Futurebook Miền Nam — UI Contract (quy chuẩn bắt buộc, toàn repo)

**Owner chốt:** 03/11/2026 · **Trạng thái:** mandatory / normative.  
**Áp dụng:** Admin `apps/admin/**`, Website `app/**`, frontend App đại lý/NPP và App người tiêu dùng khi được tạo.  
**Ưu tiên:** tài liệu này là **nguồn chuẩn chung** cho component geometry / màu / pattern; [Admin design system](admin-ui-design-system.md) và [Website design system](web-component-design-system.md) chỉ bổ sung các yêu cầu riêng; nếu các tài liệu cũ ghi số khác, **quy chuẩn này thắng**.

## 1. Design tokens cố định

| Thành phần | Quy chuẩn Owner | Token / lưu ý |
|---|---|---|
| Nút trên desktop | **36px** | `--fb-control-height-compact: 36px` |
| Input / select / dropdown | **40px** | `--fb-field-height: 40px` |
| Nút trên mobile (≤780px) | **44px** | `--fb-control-height-touch: 44px` |
| Chữ điều khiển | **13px** | `--fb-control-font-size: 13px`; label không được nhỏ hơn 13px |
| Bo góc nút/ô nhập | **8–10px** | `--fb-control-radius: 9px` |
| Điểm nhấn | **Tím Futurebook** | `--fb-ui-primary: #6D249E`; hover `#572080`; không phủ tím toàn nền |
| Nền header bảng dữ liệu | **Tím lavender nhạt** | `--fb-ui-table-header-bg: #F4EDFA`, chữ `#43215F`, đường viền `#E5D7F1` |
| Thông báo thao tác | **Toast nhỏ cố định góc trên bên phải** | dùng component toast chung; không chèn thông báo lưu/lỗi vào giữa form |
| Form tạo/sửa | **Drawer hoặc popup/modal** | danh sách và form tách, không chèn form dài vào danh sách |
| Motion Admin | **Nút 180–200ms; menu 180–220ms; popup mở 280ms / đóng 220ms; drawer 300ms** | Motion mượt dùng easing chung; không thay motion toast đã duyệt |
| Header popup Admin | **52px desktop / 56px mobile; tiêu đề 16px** | Nền trắng pha lavender rất nhạt, điểm nhấn tím Futurebook; không header quá dày |

Header bảng dữ liệu: có độ tương phản đủ đọc, **tím nhạt vừa phải**, không trắng tinh, không tím đậm tràn nền. Không đổi màu vùng bảng trống, data cell hay card nếu không có lý do. Chỉ tô `thead th` hoặc header của data grid, không nhầm với tiêu đề trang.

## 2. Component và vị trí quản lý

- **Một chỗ khai báo token và primitive** trong hệ thống dùng chung; các trang **dùng lại**, không tự đặt height/padding/radius/color cho nút, dropdown, tab. Với Admin: `apps/admin/app/admin-controls.css` import tại `layout.tsx`, class base `.btn`, `.import-btn`, `.catalogue-actions-trigger`, tab `.fb-pricing-tabs`; class tùy chọn `.fb-ui-button`, `.fb-ui-field`, `.fb-ui-select`, `.fb-ui-data-header`.
- Button variants: `primary` tím, `secondary` trắng viền, `ghost` trong, `danger` riêng; không dùng 4 nút primary trong cùng một cụm. Icon 16px, gap 8px, padding ngang 12px; height theo bảng.
- Inputs / selects: label ở trên, helper phía dưới, khoảng cách 6–8px; error đặt sát control **khi là lỗi xác thực trường** (không phải toast thao tác). Checkbox/radio, native file input, textarea, icon-only có ngoại lệ kích thước được mô tả rõ — **không ép input file thành ô text cố định**.
- Tabs: một style dùng chung, active có nền lavender nhạt + điểm nhấn tím, rounded 9–10px, cùng font 13px và chiều cao nút; **không lấy CSS từ một trang nghiệp vụ Excel để render tab của trang khác**. Tab và nội dung phải còn đủ sau refactor. Giữ thiết kế nhất quán trên desktop/mobile.
- Table: header lavender nhạt; dữ liệu để nền trắng, hàng phân tách mảnh, hover nhẹ; SKU luôn chuỗi, giữ số 0 đầu. Bảng rộng cuộn ngang trong vùng bảng, không làm toàn viewport tràn ngang.
- Toast: dùng `admin-toast.tsx` cho Admin; success/error/info trên góc phải trên, không chèn alert lớn đẩy layout. Cảnh báo bảo mật dài hạn và nội dung xác thực trường **không thay bằng toast tự biến mất**.
- **Toast motion chuẩn mẫu Owner (03/11/2026):** thẻ trắng cao tối thiểu **66px**, rộng tối đa **404px**, viền xám mảnh, bóng mềm, icon trạng thái dạng vòng tròn nét mảnh, dấu X, thanh thời gian **3px** sát đáy; chuyển vào từ **phải** và fade-in **220ms**, chuyển ra phải và fade-out **190ms**, các toast xếp dọc chuyển chỗ mượt; tự ẩn mặc định khoảng **4,8 giây**. Chỉ thay vị trí so với video mẫu thành **góc phải trên**. Có hỗ trợ `prefers-reduced-motion`, và toast bên trong popup vẫn nằm trong focus trap.
- Form: **popup/drawer** cho tạo/sửa, giữ context của danh sách, header/footer rõ, Esc/hủy/đóng không làm mất dữ liệu chưa lưu; responsive tối đa viewport.

### 2.1 Motion tương tác bắt buộc (Owner 03/11/2026)
- Áp dụng cho mọi popup, menu, nút và drawer trong Futurebook Admin; các UI Futurebook mới cũng phải tuân thủ trừ ngoại lệ được Owner duyệt. Dùng token và component dùng chung; không đặt timing tùy ý theo màn hình.
- **Nút hover/press/focus:** **180–200ms**; chỉ chuyển nền, viền, shadow, chữ và transform nhẹ; không giật, nảy hoặc gây layout shift.
- **Dropdown / menu ba chấm / popover:** **180–220ms**, fade và dịch khoảng **6px**; phải giữ focus và thao tác bàn phím.
- **Popup/modal mở:** **280ms**, fade và scale(0.97) → scale(1). **Popup/modal đóng:** **220ms**, fade và thu nhỏ nhẹ; overlay fade **220ms**. Phải chạy exit animation trước khi unmount; không gỡ popup khỏi DOM ngay khi nhấn đóng.
- **Drawer mở/đóng:** **300ms**, trượt từ cạnh phải và fade nhẹ; không kéo layout chính dịch chuyển.
- **Easing chung:** mở cubic-bezier(.22, 1, .36, 1), đóng cubic-bezier(.4, 0, 1, 1). Ưu tiên opacity/transform, không delay phản hồi API để tạo cảm giác mượt.
- **Ngoại lệ:** toast đã chốt dùng motion vào **220ms / ra 190ms**, thanh thời gian **4,8 giây**, không thay theo timing popup/menu.
- **Accessibility:** prefers-reduced-motion: reduce phải tắt/giảm animation. Không làm hỏng Esc, backdrop click, focus trap, restore focus hoặc cảnh báo thay đổi chưa lưu.

### 2.2 Header popup/modal bắt buộc (Owner 03/11/2026)
- **Chiều cao mục tiêu:** **52px desktop / 56px mobile** (mobile giữ nút đóng có vùng chạm tối thiểu 44px). Canh giữa tiêu đề và nút X theo chiều dọc, không để header cao vô lý so với chữ.
- **Tiêu đề:** **16px**, font-weight **700**, line-height khoảng **1.35**. Tiêu đề dài được phép xuống dòng và header tăng chiều cao vừa đủ, không cắt nội dung.
- **Màu:** nền trắng pha **lavender rất nhạt** (lấy từ token --fb-ui-primary-subtle: #F4EDFA), đường phân cách mảnh và **một đường/điểm nhấn tím Futurebook** (token --fb-ui-primary: #6D249E). Không phủ tím đậm cả header, không gradient sặc sỡ.
- **Spacing:** padding ngang **16px desktop / 12px mobile**, padding dọc tính theo chiều cao mục tiêu. Không dùng lại header cũ padding 19px 22px + title 19px.
- **Nguồn triển khai duy nhất:** primitive apps/admin/app/product-modal.tsx và shared CSS apps/admin/app/admin-controls.css; giảm khai báo modal cũ ở import-preview.css khi thực hiện PR UI. Toàn bộ popup SKU, danh mục, Excel, hình ảnh dùng cùng thiết kế.
- **Trạng thái:** đây là quy chuẩn mới được ghi vào tài liệu; runtime popup cũ **chưa được sửa trong PR tài liệu này**. Không báo đã thay đổi giao diện trước khi có PR UI, CI và kiểm tra ảnh thật.

- Website public có ngoại lệ CTA đỏ quảng bá theo layout được Owner duyệt; **không tự đổi CTA đỏ thành tím**. Các token kích thước/chữ/toast/form vẫn giữ cùng tinh thần chuẩn. Frontend App dùng contract này từ khi bắt đầu.

## 3. UX nghiệp vụ và ngôn ngữ

- Chức năng **một quy trình xuyên suốt**: tạo bảng giá → chọn bảng giá đó khi sửa SKU / nhập Excel → xem trước → **Lưu** → **Áp dụng** một lần cho toàn bảng theo quyền Owner; **không hardcode loại giá ở một màn hình còn màn kia cho tạo mã tùy chọn**.
- Chọn **một hoặc nhiều kênh** nếu nghiệp vụ cho phép (ví dụ **Website và App người tiêu dùng**); không biến checkbox đa lựa chọn thành dropdown đơn lựa chọn vì muốn UI gọn. Kênh áp dụng và đối tượng khách là hai khái niệm; quyền đọc/NET phải kiểm ở backend.
- Label và tab là ngôn ngữ nghiệp vụ tự nhiên: `Bảng giá`, `Giá sản phẩm`, `Nhập / xuất Excel`, `Mã bảng giá`, `Tên bảng giá`, `Kênh áp dụng`. Tránh copy rập khuôn `tên do anh lựa chọn`, `bảng giá tự tạo` ở nơi chỉ cần `Bảng giá`, `Excel giá hiện có` và thuật ngữ code. Không xóa tab đã duyệt chỉ vì muốn gọn.
- Khi Owner yêu cầu thay đổi UX, xác định *toàn bộ trang tác động*, API liên quan, import/export, role và test trước khi code. **Không chữa ngọn bằng ghi đè CSS; tìm nguồn quy chuẩn.**

## 4. Quality gate bắt buộc cho UI PR

1. Đọc `AGENTS.md` root + `apps/admin/AGENTS.md` hoặc `app/AGENTS.md` và contract này; ghi rõ component dùng chung nào sẽ tái sử dụng.
2. Soát ở **1440px, 1280px, 390px và 360px**: nút, bảng, tab, drawer, toast, overflow, loading/empty/success/error/disabled/focus.
3. Kiểm con số (36/40/44/13/9), **motion 180–200/180–220/280/220/300ms**, **header popup 52/56px, title 16px và điểm nhấn tím lavender**, header bảng tím nhạt; không style inline mới cho cùng loại control. Toast giữ motion 220/190ms. Nếu cần ngoại lệ phải ghi nguyên nhân trong PR.
4. Có kiểm thử tự động ở `tests/futurebook-ui-contract.test.mjs`, CI chạy bằng `npm test`. CI **không thay** UAT bằng trình duyệt thực.
5. PR → CI 4/4 xanh → Codex review sạch → squash merge → deploy khi Owner yêu cầu. **Chưa chứng minh screenshot/behavior thì báo chưa UAT, không gọi hoàn tất.**

## 5. Phạm vi áp dụng cho code cũ

Đây là **quy tắc triển khai mới và mọi phần UI được chạm tới**; code cũ chưa khớp được ghi nhận là nợ kỹ thuật, không mặc nhiên gọi là đã khắc phục chỉ vì thêm tài liệu. Khi sửa một component cũ, chuyển nó sang primitive chung cùng test tương ứng, không tạo thêm bản sao định nghĩa ở CSS cấp trang. Không đổi dữ liệu giá, phân quyền, API hay kiến trúc sản phẩm vì mục đích làm đẹp.

### Quy tắc Owner giá (03/11/2026)

- **Không duyệt từng SKU hay duyệt hai cấp.** Owner tạo/sửa/lưu bảng giá và mức giá; một nút **Áp dụng** kích hoạt nội bộ cùng lúc mọi giá hợp lệ đang lưu trong bảng.
- Bảng đang áp dụng: Owner được sửa mức giá và nhập Excel trực tiếp; thay đổi giá được ghi nhận/audit và có hiệu lực nội bộ ngay khi lưu. **Không đồng nghĩa xuất bản ra Website/App**.
- Muốn đổi phạm vi kênh hoặc khách của bảng đang áp dụng: **Ngừng áp dụng** trước rồi sửa và Áp dụng lại, để không vô tình chuyển giá riêng sang kênh công khai.
- Mọi thao tác vẫn kiểm quyền Owner, nguồn giá/VAT, mã SKU giữ 0 đầu, kỳ giá không chồng lấn, revision, Excel preview và audit. Trạng thái “approved” cũ trong database mang nghĩa **Đang áp dụng nội bộ**; không tự bật API giá công khai.

## 6. Website visual V2 — Owner 08/11/2026 (bắt buộc)
**Chỉ cho Website Futurebook, không áp dụng cho Admin hoặc storefront khác.** [Website Premium Glass V2](web-component-design-system.md) thay thế các quy tắc **visual surface/card** cũ của Website; chuẩn chung về nghiệp vụ, layout đã duyệt, geometry control, toast và motion trong tài liệu này vẫn giữ.

- **Glassmorphism là phong cách chủ đạo**, không chỉ là điểm nhấn: lớp ảnh nền decorative (Cloudflare R2 khi có public config hợp lệ) -> overlay dễ đọc -> glass header/panel/cards/chips/buttons -> nội dung/ảnh SKU thật. Nếu thiếu URL nền, dùng gradient fallback; không hardcode địa chỉ R2.
- Website glass card radius **20–28px**, translucent surface, border kính sáng, bóng mềm và blur kiểm soát. Đây là **ngoại lệ visual Website** so với card trắng 12–14px cũ; không thay đổi radius controls thông thường **8–10px**, field **40px**, button thường **36px desktop/44px mobile**, font control tối thiểu **13px**.
- **Website CTA và SKU chip** có thể bo pill 999px theo ảnh tham chiếu; CTA đỏ đã được Owner duyệt ở vị trí hiện hành giữ nguyên, CTA sản phẩm có thể dùng tím. Không mang ngoại lệ radius này vào UI Admin.
- Button **180–200ms**; menu **180–220ms**; card hover nâng nhẹ **2–4px**, không scale giật hoặc animation blur liên tục. Popup/drawer/toast vẫn giữ timing bắt buộc đang có.
- Glass header, gallery frame, product info, SKU selector, related-product cards, dealer banner, footer phải dùng chung tokens và primitives. Overlay kính không làm sai màu ảnh sản phẩm; text trên background ảnh phải đạt WCAG AA. Có fallback không hỗ trợ backdrop-filter và giảm motion cho thiết bị cần thiết.
- UI-only: **không đổi** dữ liệu, SKU, API, database, quy trình mua/báo giá, routing, SEO, auth, quyền, logic variant/ảnh. Background R2 qua config/endpoint public hiện hữu nếu có; **không tự tạo migration/API** chỉ để đạt UI tham chiếu.
- Trình tự visual rollout tại [roadmap duy nhất](roadmap.md); kiểm trang Song Natural trước. Ảnh mockup do Owner gửi chỉ là style reference, không dùng làm nguồn ảnh sản phẩm hoặc bằng chứng UAT.
