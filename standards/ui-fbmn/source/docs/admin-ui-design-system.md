# Futurebook Miền Nam — Admin UI Component Design System v1

> **Quy chuẩn bắt buộc từ Owner (03/11/2026):** [Futurebook UI Contract](futurebook-ui-contract.md) là nguồn chuẩn cao nhất cho kích thước nút **36px desktop/44px mobile**, ô nhập **40px**, font **13px**, bo **8–10px**, header bảng dữ liệu **tím nhạt**, toast trên phải, form tạo/sửa modal/drawer. **Motion Owner:** nút 180–200ms, menu 180–220ms, popup mở 280ms/đóng 220ms, drawer 300ms; **header popup:** 52px desktop/56px mobile, chữ 16px, nền lavender rất nhạt + điểm nhấn tím. Các dải giá trị ước lượng ở v1 bên dưới chỉ là tham khảo lịch sử khi không mâu thuẫn. CSS runtime tập trung tại `apps/admin/app/admin-controls.css` và dùng chung cho mọi màn hình.
Ngày chốt quy tắc: 03/11/2026 · Phạm vi: `apps/admin/**` · Trạng thái: **quy tắc thiết kế mục tiêu; chưa phải xác nhận đã triển khai vào CSS**.

## 0. Quyết định của Owner
- **Giữ nguyên IA, bố cục, điều hướng, tính năng và luồng nghiệp vụ hiện có.** Chủ dự án yêu cầu nâng chất lượng thiết kế của **card, button, input, select, table, modal, icon và các trạng thái**, KHÔNG yêu cầu làm lại dashboard hoặc tự thêm widget, biểu đồ, banner.
- **Tím Futurebook là điểm nhấn nhận diện**, không nhuộm tím tất cả card/nền. Nền trung tính, nội dung có ưu tiên rõ; mật độ thông tin phù hợp Admin thực tế.
- Ưu tiên **premium minimal SaaS / enterprise UI**: sắc nét, tiết chế, nhất quán, không tạo hiệu ứng chỉ để nhìn đẹp trên ảnh mẫu.
- Các hình AI/moodboard chỉ tham khảo cảm giác vật liệu; **không được lấy dữ liệu, SKU, logo, giá, ảnh, chỉ tiêu, nội dung nghiệp vụ hoặc bố cục từ ảnh mẫu**.
- Tài liệu `docs/ui-system.md` đang mô tả **website công khai**, không dùng nó làm đặc tả bố cục Admin. Bộ quy tắc này KHÔNG thay thế hệ thống website.

## 1. Design tokens — đích chuẩn hóa, không tuyên bố CSS hiện tại đã khớp
Sử dụng **semantic CSS custom properties** thay cho thêm các mã hex tùy hứng theo màn hình. Khi triển khai, thống nhất token trong một nơi được import từ `apps/admin/app/layout.tsx` và giảm dần override rải rác; không tự refactor hàng loạt để áp dụng tài liệu này.

| Vai trò | Token đề xuất | Giá trị ban đầu | Cách dùng |
|---|---|---|---|
| Brand primary | `--fb-ui-primary` | `#6D249E` | CTA chính, selected, liên kết cần nhấn |
| Brand hover | `--fb-ui-primary-hover` | `#572080` | Hover CTA |
| Brand strong | `--fb-ui-primary-strong` | `#431078` | Text/icon nhấn trên nền sáng |
| Brand subtle | `--fb-ui-primary-subtle` | `#F4EDFA` | Focus nền, chip selected nhẹ |
| Canvas | `--fb-ui-canvas` | `#F7F8FC` | Vùng làm việc |
| Surface | `--fb-ui-surface` | `#FFFFFF` | Card, input, modal |
| Border | `--fb-ui-border` | `#E4E7EF` | Viền trung tính |
| Ink | `--fb-ui-ink` | `#20223B` | Text chính |
| Muted | `--fb-ui-muted` | `#667085` | Label phụ, mô tả |
| Danger | `--fb-ui-danger` | `#B42318` | Xóa, lỗi, cảnh báo rõ |
| Radius control | `--fb-ui-radius-control` | `10px` | Input, button, dropdown |
| Radius card | `--fb-ui-radius-card` | `14px` | Panel lớn |
| Shadow card | `--fb-ui-shadow-card` | `0 4px 18px rgba(32,24,70,.045)` | Nổi rất nhẹ, không viền phát sáng |
| Focus ring | `--fb-ui-focus-ring` | `0 0 0 3px rgba(109,36,158,.20)` | Visible focus |

**Chú ý hiện trạng:** `apps/admin/app/admin.css`, `admin-refinement.css`, `catalogue-workspace.css`, `catalogue-structure.css` đang có nhiều màu xanh/tím, kích thước và shadow riêng. Đây là **mục tiêu cần thống nhất dần trong PR UI**, không phải lý do tự động đổi toàn bộ CSS. Tận dụng font `Be Vietnam Pro` đã có; không tự thêm font hoặc thư viện UI mới.

- Spacing scale: `4 / 8 / 12 / 16 / 24 / 32px`. Trong một vùng, spacing cùng bội số; không thêm margin tùy hứng theo từng nút.
- Typography: body tối thiểu `13–14px` desktop và `14px` mobile; heading panel `16px`, title trang `22–26px`, helper `12–13px`. Tránh văn bản chức năng `10px` hoặc màu quá nhạt.
- Hierarchy: dùng cỡ/weight/màu/spacing trước; chỉ một primary CTA nổi bật trong mỗi cụm hành động. Không trang trí mọi card bằng gradient.

## 2. Component contracts

### 2.1 Card / Panel
- Mặt trắng hoặc xám cực nhạt; border 1px trung tính; bo 12–14px; shadow mềm *rất nhẹ*. Padding mặc định 16–20px; card dữ liệu dày có thể 12–16px.
- Chỉ card thực sự clickable mới có hover/pressed/keyboard focus. Card thường **không nhảy**, không nâng mạnh và không gắn shadow hover đồng loạt.
- Card có hình/số liệu: khoảng cách icon–text ổn định, alignment theo baseline; badge không chen dữ liệu.
- Không dùng lồng 3–4 card cùng viền và bóng; dùng divider hoặc section heading để phân cấp.

### 2.2 Button
- Variants: `primary` (nền tím, chữ trắng), `secondary` (nền trắng, viền trung tính), `ghost` (trong suốt), `danger` (dùng khi xóa/thao tác phá hủy).
- **Bắt buộc:** button desktop 36px, button mobile 44px, font 13px; không tùy màn hình nâng lên 40/48px. Border radius 9–10px, icon 16–18px, gap 8px.
- Rõ hover, focus-visible, active, disabled, loading; loading giữ nguyên độ rộng để tránh layout shift. Icon-only bắt buộc có accessible name/tooltip.
- **Không biến mọi action thành nút tím đậm**, không gradient nhiều sắc và không tạo thêm CTA trùng mục đích.

### 2.3 Input / Select / Dropdown
- Label nằm trên control, cùng kiểu, khoảng cách ~6px. **Bắt buộc:** input/select/dropdown 40px; viền nhẹ; focus ring tím rõ và không làm layout dịch.
- Placeholder khác dữ liệu thật; read-only khác disabled; lỗi có thông báo sát trường, không chỉ đổi màu viền.
- Một trường chỉ có **một nơi chọn**. Không lặp tên cột ở trên rồi thêm dropdown/selector bên dưới gây thừa UI.
- Với Excel mapping: **Bỏ qua cột = không đụng dữ liệu cột đó**; cột được ánh xạ thì mới đưa vào quy trình cập nhật. Theo quyết định UX gần nhất của Owner, **ô nguồn trống ở cột đã ánh xạ có ý nghĩa chủ động để trống/xóa dữ liệu**, KHÁC với Bỏ qua. *Chú ý:* tài liệu P3 cũ từng quy định blank giữ nguyên. Không tự sửa thuật toán khi chỉ làm skin; nếu logic hiện tại chưa khớp, tách thành thay đổi nghiệp vụ riêng, xác nhận bằng test trước deploy.
- Đặt tên và mã danh mục / nhóm mẫu **do người quản trị tự nhập**, không tự cấp mã; UI không được hiển thị giả như mã đã tự cấp.

### 2.4 Table / Data grid
- Bảng làm việc là thành phần ưu tiên của Admin: header rõ nhưng nhẹ; chiều cao hàng khoảng 44–52px; đường phân tách mảnh; hover xám/tím rất nhạt; lựa chọn có phân biệt ngoài màu.
- Cột SKU dùng text, giữ `0114` khác `114`; số và mã không bị rút gọn vô cớ. Cột thao tác gọn, nhất quán, không dồn icon không nhãn.
- Dữ liệu nhiều cột có overflow ngang chủ động hoặc responsive strategy rõ; KHÔNG hy sinh khả năng đọc để cố nhét hết vào mobile.
- Pagination, filter, sort, empty/loading/error state dùng cùng pattern. Không tạo dữ liệu SKU giả để lấp bảng.

### 2.5 Modal / Drawer / Confirmation
- Overlay trung tính; modal trắng, border/shadow rõ vừa đủ, góc 14–16px. Header và footer có thứ bậc rõ; body cuộn độc lập nếu nội dung dài.
- **Header popup chung:** **52px desktop / 56px mobile**, tiêu đề **16px**, weight **700**; canh tâm với nút X. Padding ngang 16px / 12px. Nền trắng pha lavender rất nhạt + **một điểm/đường nhấn tím Futurebook** và đường phân cách nhẹ. Tiêu đề dài được xuống dòng; không dùng lại padding 19px 22px / title 19px.
- **Motion popup:** mở **280ms** fade + scale(.97→1), đóng **220ms** fade + scale nhẹ; exit trước khi unmount. **Drawer:** trượt từ phải **300ms**. Quy chuẩn tại shared CSS admin-controls.css + primitive product-modal.tsx, không tạo màn hình có header/timing riêng.
- Esc, close, click outside phải tuân theo hành vi nghiệp vụ và bảo vệ thay đổi chưa lưu; không để modal tràn khỏi viewport. Tối đa khoảng 90–95dvh tùy màn.
- Hành động hủy/phụ phía trái, hành động lưu/xác nhận phía phải nếu không xung đột luồng hiện hành; xóa có xác nhận riêng.
- Không chuyển toàn bộ modal quản lý SKU thành drawer nếu chưa có yêu cầu Owner; đó là thay đổi UX, không phải polish.

### 2.6 Notification / Toast (Owner, 03/11/2026)
- Phản hồi thao tác ngắn (lưu thành công/thất bại, lưu giá, lỗi import, sửa danh mục, trạng thái hiển thị) bắt buộc là **toast nhỏ cố định góc trên bên phải**, không chèn banner vào luồng nội dung khiến nút và form dịch vị trí.
- Dùng chung `apps/admin/app/admin-toast.tsx`, `variant="success"|"error"|"info"`; lỗi phải có `role="alert"`, thông báo khác `role="status"`. Có nút đóng và tự ẩn sau khoảng 4–5 giây.
- **Riêng màn hình Giá** bỏ thông báo `catalogue-pricebook-inline-success/error` dưới nút Lưu giá. Giữ nguyên xác thực, giá, VAT, nguồn và quy trình lưu.
- Helper text, empty state, cảnh báo bảo mật cần đọc lâu và hộp thoại xác nhận xóa **không thay bằng toast tự biến mất**.
- Khi có modal đang mở, toast phải vẫn hiển thị góc trên phải và không bị modal che. Test desktop/mobile.
- Nếu có nhiều thao tác đồng thời (giá, ảnh, sản phẩm), các toast trong cùng modal phải xếp dọc trong `.fb-product-modal-toast-stack`, không phủ lên nhau, và nút đóng vẫn nằm trong focus trap của modal.
 
### 2.7 Icon / Status / Motion
- Icon nét đồng bộ (16/18/20px, stroke khoảng 1.75–2), không phối tùy tiện nét đậm/mỏng/3D; dùng lại bộ SVG đang có nếu phù hợp thay vì tự bổ sung thư viện.
- Success / warning / error có icon và text, không phụ thuộc màu sắc; không dùng tím thay mọi trạng thái.
- **Motion chuẩn Owner thay thế chuẩn cũ 120–180ms:** nút hover/press/focus **180–200ms**; dropdown/menu ba chấm **180–220ms** fade + dịch 6px; modal mở **280ms** / đóng **220ms**; drawer **300ms**. Easing mở cubic-bezier(.22, 1, .36, 1), đóng cubic-bezier(.4, 0, 1, 1). Tránh bounce/glow/layout shift, tôn trọng prefers-reduced-motion. **Toast riêng 220/190ms, không bị ghi đè.**

## 3. Ứng dụng trong mã nguồn
- Tập trung Admin: `apps/admin/app/admin.css`, `admin-refinement.css`, `catalogue-workspace.css`, `catalogue-structure.css`, `import-preview.css`, cùng TSX tương ứng.
- Khi bắt đầu một PR UI: liệt kê component và trạng thái liên quan; chỉ điều chỉnh CSS/markup cần thiết; **không đổi database/API/auth/đường dẫn sản phẩm/chính sách giá** dưới danh nghĩa làm đẹp.
- Migrate token theo thành phần, ưu tiên button → input/select → card → table → modal; hạn chế selector chồng đè ở cuối file. Không tạo thêm một file `*-final.css` chỉ để vá lỗi cascade.
- Giữ nhận diện logo thật, không thay bằng icon sách giả hoặc logo từ mockup.
- Không được hiển thị giá NET hoặc dữ liệu khách hàng trong UI demo / ảnh chụp công khai.

## 4. Definition of Done cho mỗi PR có thay đổi Admin UI
1. **Trước/sau**: ảnh chụp cùng một trạng thái thật ở **desktop 1280/1440** và **mobile 390px**; kiểm tra 360px nếu modal/bảng phức tạp. Không dùng ảnh AI làm bằng chứng đã triển khai.
2. Các thành phần mới/đổi tuân theo tokens, variants, spacing, typography; không thêm control trùng.
3. Kiểm đủ: default / hover / focus / active / disabled / loading / empty / error / long text, với keyboard Tab/Enter/Esc và không có scroll ngang ngoài vùng bảng.
4. Tương phản text thường nên đạt WCAG AA (4.5:1); target touch hợp lý; focus visible rõ. Kiểm `prefers-reduced-motion`.
5. Không thay hành vi Excel, mã công ty, danh mục, nhóm mẫu, SKU, media, auth hoặc giá khi PR chỉ duyệt skin.
6. CI lint + typecheck + tests + build xanh; có review code sạch; không tự deploy. Quy trình chung: branch → PR → CI → review → squash merge theo xác nhận và chính sách release dự án.
7. Nếu screen cũ lệch bộ chuẩn, ghi rõ món nào chờ migration; **không bắt buộc sửa cả ứng dụng cùng một PR**.

## 5. Phân biệt chuẩn thiết kế và nghiệm thu
- Đây là **design contract** có thể kiểm bằng code review và screenshot, không phải asset, giao diện hoàn thiện hoặc thay đổi đã chạy trên Vercel.
- Quyết định nghiệp vụ của Owner và các tài liệu ADM hiện hành vẫn có hiệu lực; khi phát hiện mâu thuẫn phải nêu rõ trước khi sửa logic.
- Nếu Owner muốn đổi **bố cục/luồng**, lập scope UX riêng; không đánh đồng với chuẩn hóa component.
