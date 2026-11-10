# FUTUREBOOK MIỀN NAM — WEBSITE UI DESIGN SYSTEM V2.0
**Owner direction:** 08/11/2026 — Premium Purple Glassmorphism, dựa trên hai ảnh tham chiếu do Owner cung cấp.
**Áp dụng:** Website Futurebook tại repo root; không áp theme tím sang Admin hay storefront khác.
**Nguồn chuẩn:** [UI Contract toàn repo](futurebook-ui-contract.md) là chuẩn geometry, accessibility, motion dùng chung. Tài liệu này quy định vật liệu và phong cách riêng của Website V2. Nếu chuẩn cũ mô tả card trắng đặc, shadow/radius cũ thì Website V2 thay thế **chỉ về visual surface**, không thay logic hay bố cục đã duyệt.

## 1. Phạm vi tuyệt đối — UI-only
- Chỉ thay skin, CSS tokens, surface, card, button, chip, navigation presentation, typography, layout polish không làm đổi khung thông tin, trạng thái, interaction feedback và motion.
- Bảo toàn URL/routing/SEO, số liệu, SKU (kể cả số 0), cách chọn mẫu/khổ, gallery logic, CTA liên hệ, public API, quyền, form và nội dung hiện có. Không thay schema DB, migration, backend, Cloudflare Worker, auth hay business logic.
- Không tự hiển thị giá NET hoặc thông tin chưa được duyệt. Ảnh sản phẩm phải từ media thật; ảnh minh hoạ AI trong tham chiếu **chỉ là cảm hứng UI**.
- Header/menu, thứ tự nội dung, responsive layout cũ là contract đã duyệt; không tái kiến trúc navigation, không thêm bottom dock/mobile bottom navigation, không bật tính năng chưa kết nối.
- Quy tắc trạng thái: loading/empty/error/disabled/focus đều có giao diện; không được thay đổi ý nghĩa hoặc che lỗi.
- Đây là kế hoạch + quy chuẩn; ghi tài liệu không được báo là UI runtime đã triển khai.

## 2. Chủ đạo thiết kế
Website phải thể hiện **lớp kính mờ trong suốt trên ảnh nền riêng**, đúng tinh thần hai ảnh Owner gửi. Không biến toàn trang thành trắng đặc hoặc chỉ thêm một card kính làm điểm nhấn.
- Backdrop làm lớp sâu nhất, có thể là ảnh trang trí từ R2; bên trên có overlay/gradient giúp chữ đọc tốt.
- Glass surfaces là chủ đạo ở header, product info panel, category/product cards, selector, benefits, banner; dùng nền trong suốt màu trắng/lavender, mảnh border sáng và bóng mềm.
- Hình SKU thực tế nằm trên vùng hiển thị trung tính đủ sáng, không phủ tinted glass lên pixels ảnh; giữ độ chính xác màu bìa và tỉ lệ ảnh.
- Phân tầng rõ: background ảnh -> overlay dịu -> glass section/card -> văn bản/nút/ảnh chính.
- Tránh neon, glow dày, blur mọi phần tử, gradient phủ toàn bộ nội dung, nhiều lớp bóng hoặc gradient gây nhiễu.

## 3. Tokens tham chiếu (Website)
Chốt một nguồn khai báo dưới website, ưu tiên mở rộng token hiện có thay vì override trùng lặp. Các con số dưới đây là baseline để kiểm tra bằng screenshot, không tự động ép mọi vùng dùng cùng một mức blur.

| Token đề xuất | Giá trị tham chiếu | Vai trò |
|---|---|---|
| `--color-primary` | `#6D249E` | Tím brand đã duyệt |
| `--color-primary-strong` | `#431078` | Chữ/gradient tím đậm |
| `--fb-glass-page` | `#F7F3FC` | Fallback nền khi thiếu ảnh |
| `--fb-glass-surface` | `rgba(255,255,255,.68)` | Kính sáng cơ bản |
| `--fb-glass-surface-strong` | `rgba(255,255,255,.82)` | Vùng nội dung cần đọc rõ |
| `--fb-glass-border` | `rgba(255,255,255,.65)` | Viền highlight |
| `--fb-glass-blur` | `20px` | Kính chính, điều chỉnh trong 16–24px |
| `--fb-glass-card-radius` | `24px` | Card kính lớn, trong phạm vi 20–28px |
| `--fb-glass-panel-radius` | `20px` | Panel/section |
| `--fb-glass-shadow` | `0 14px 32px rgba(63,25,98,.12)` | Bóng mềm, tránh đen đậm |
| `--fb-glass-ink` | `#241331` | Nội dung chính |
| `--fb-glass-muted` | `#62576C` | Nội dung phụ |

- 1–2 họ font hỗ trợ đầy đủ tiếng Việt, không tự cài font chỉ để trang trí; ưu tiên dễ đọc hơn kiểu chữ.
- Chuẩn control toàn repo vẫn là nút thường 36px desktop / 44px mobile; field 40px, chữ control tối thiểu 13px. Radius control thường 8–10px. **Ngoại lệ Website V2 đã được Owner yêu cầu**: CTA thương mại và chip/variant có thể dạng pill 999px; card kính dùng 20–28px. Không áp ngoại lệ này sang Admin.
- Giữ nút CTA đỏ ở vị trí đã duyệt trên homepage/hero cũ; product-detail CTA có thể dùng tím gradient. Không đổi ý nghĩa hoặc hành động của CTA.

## 4. Glass surface và component contract
- `GlassPageBackdrop`: lớp ảnh nền/gradient/overlay cho trang; không lồng blur nặng theo từng card; lớp nền decorative không chặn click/scroll và không sinh CLS.
- `GlassHeader`: kính bán trong suốt, border sáng nhỏ, có blur/fallback; giữ navigation, search, hamburger hiện tại.
- `GlassCard` / `GlassPanel`: surface/border/shadow dùng token; dùng chung thay vì CSS copy ở từng trang.
- `GlassButton`: primary tím nổi, secondary kính viền, ghost trong; hover/focus/active/disabled rõ ràng; giữ behavior cũ.
- `GlassChip`: normal kính sáng, hover viền tím, active tím rõ; active có aria-pressed/selected phù hợp; tuyệt đối không làm sai selection state.
- `ProductGallery`: khung sáng, thumbnail active có viền; chuyển ảnh không giật; media thật, fallback an toàn khi thiếu ảnh.
- `RelatedProductCard`, `DealerCTABanner`, `GlassFooter`: cùng rhythm, responsive và độ tương phản.
Tên component có thể đổi theo code hiện hành, **không tạo bản sao** chỉ vì đặt tên mới.

## 5. Motion, tương tác và accessibility
- Nút: 180–200ms; menu/dropdown: 180–220ms. Chuyển visual state của chip/selector trong khoảng này, không dùng animation nhiều tầng.
- Card hover desktop chỉ nâng 2–4px bằng transform, shadow/border đổi nhẹ; không phóng to gây nhảy bố cục. Mobile dùng touch/active feedback, không lệ thuộc hover.
- Gallery: chuyển ảnh/tựa thumbnail nhẹ, giữ alt, ratio, kích thước ổn định; không delay API hay navigation để tạo chuyển động giả.
- Ưu tiên transform/opacity; backdrop-filter của card **không animate** liên tục. Tôn trọng `prefers-reduced-motion`, focus-visible và keyboard navigation.
- Nội dung chữ bình thường đạt tối thiểu WCAG AA 4.5:1 trên nền kính + backdrop ảnh thực; nền quá sáng/rối phải tăng opacity hoặc thêm overlay thay vì ép chữ nhạt.
- Blur chỉ dùng vùng cần thiết; có fallback màu bán trong suốt cho browser không hỗ trợ. Không thêm animation chạy vô hạn, giảm blur trên mobile/thiết bị yếu.

## 6. Ảnh nền R2 — kiến trúc visual-only
- Ảnh trang trí nền và **ảnh sản phẩm là hai nguồn/vai trò khác nhau**. Không dùng ảnh nền AI làm ảnh SKU, không cắt ảnh trong mockup làm dữ liệu thật.
- Website hiển thị decorative background theo URL cấu hình đã tồn tại và được phép công khai từ kênh nội dung/R2 CDN; không hardcode hostname/key/URL R2 theo từng trang.
- Vùng cấu hình kỳ vọng: `backgroundImageUrl`, `backgroundPosition`, `backgroundSize`, `backgroundOverlay`; `glassIntensity` (nếu được chuẩn hóa) chỉ tác động visual. Đây là **yêu cầu thiết kế**, không xác nhận API hiện có đã trả các trường đó.
- Nếu hệ thống hiện tại chưa có cấu hình hợp lệ, triển khai visual fallback gradient trước, báo thiếu và tách hạng mục tích hợp data theo đúng thẩm quyền; **không tự mở rộng database/API để làm UI**.
- Dùng ảnh tối ưu (WebP/AVIF khi phù hợp), kích thước phù hợp desktop/mobile, preload có chọn lọc, không dùng tấm ảnh rất lớn làm nền vô điều kiện; nền không làm chậm LCP/CLS.
- Nếu URL ảnh nền trống/hỏng: gradient lavender mềm, glass vẫn đọc được, không làm lỗi sản phẩm.
- Khi thay asset cấu hình hợp lệ trên R2/CMS, giao diện lấy URL mới mà không cần sửa component hay redeploy code (phụ thuộc dữ liệu được API hiện hành cung cấp).

## 7. Trang kiểm chứng đầu tiên
Trang: `/san-pham/sku-3ac08ff247847c1e77bfccb0e806ed29` (Song Natural).
Giữ nguyên data và cấu trúc: header → breadcrumb → gallery/thông tin → chọn nhóm/khổ/SKU → quy cách → CTA → lợi ích có chứng cứ → sản phẩm liên quan → banner → footer.
- Desktop: gallery trái, info glass card phải; mobile: gallery trên, info/selector dưới; không làm thay đổi slug, query hay SKU.
- Mọi lựa chọn SKU cập nhật ảnh/quy cách **theo data thật**. Không suy ra mã/giá/thông số từ ảnh mockup.
- CTA báo giá giữ luồng hiện hành và truyền SKU thật; nếu nút chưa có action, không giả lập đã hoạt động.
- Thiếu thông tin/ảnh: hiển thị empty/fallback rõ, không thay bằng text hoặc hình AI bịa ra.

## 8. Triển khai và nghiệm thu
- Quy trình: audit code + read AGENTS/UI/roadmap → branch repo phát triển → PR nhỏ → CI xanh → Codex review sạch → squash merge repo phát triển → sync local → fast-forward upstream theo quy trình → chỉ deploy khi Owner cho phép.
- Một source token, không !important đại trà, không framework mới nếu không có lý do kỹ thuật. Kiểm tra CSS đang có ở `app/globals.css`, `app/rebaseline.css` và các component catalogue trước khi refactor.
- Mỗi PR UI phải có diff file, screenshots **thực tế** 1440/1280/768/390/360, trạng thái hover/focus/active/loading/empty/error, kiểm không overflow, browser console/hydration, build, lint, typecheck, tests.
- Đánh giá Web Vitals LCP/CLS, tương tác SKU, gallery, CTA và nav; không gọi nghiệm thu nếu thiếu ảnh thực, UAT hay kết quả CI.
- Rollout sau khi trang mẫu đạt yêu cầu, theo roadmap duy nhất: foundation → primitives → Song Natural → R2 background visual support → trang còn lại → QA.
