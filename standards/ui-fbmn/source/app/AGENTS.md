# Futurebook Website — quy tắc UI bắt buộc

**Áp dụng:** Website Futurebook trong `app/**` và các component Website; không áp theme tím sang Admin hoặc storefront khác.

## READ FIRST — trước mọi PR UI
1. [Root AGENTS.md](../AGENTS.md).
2. [UI Contract chung](../docs/futurebook-ui-contract.md) — geometry, controls, modal, toast, motion, accessibility.
3. [Website Premium Purple Glass V2.0](../docs/web-component-design-system.md) — **nguồn chuẩn visual Website hiện hành theo quyết định Owner 08/11/2026**.
4. [Tài liệu bố cục đã duyệt](../docs/ui-system.md) và [roadmap duy nhất](../docs/roadmap.md).

## Website UI-only
- **Visual V2 chủ đạo là glassmorphism trong suốt** trên lớp ảnh nền decorative được cấu hình từ Cloudflare R2 (khi có URL hợp lệ), fallback lavender gradient khi không có ảnh.
- Chỉ sửa skin/card/button/chip/typography/spacing/shadow/border/blur/motion, không đổi business logic, SKU, variant, giá, routing, SEO, API, DB, auth, nội dung hoặc cấu trúc navigation đã duyệt.
- Không dùng ảnh AI/mockup làm ảnh sản phẩm. SKU/ảnh/quy cách phải lấy từ public data hợp lệ.
- Một bộ token và primitive dùng chung. **Không vá CSS rải rác, không đè !important tràn lan, không thêm framework UI tùy hứng**.
- **Chống chồng CSS (Owner 08/11/2026):** mỗi UI element/component chỉ có **một style owner**; một component kính không được đồng thời mang class skin `.catalog-*`/`.catalogue-*` và class kính `.fb-glass-*`/`.fb-song-*`. Chỉnh style của GlassChip/Button/Card/Panel trực tiếp tại `app/glass-foundation.css` với token từ `app/globals.css`; CSS trang chi tiết `app/glass-product-detail.css` **chỉ được quản lý grid, spacing và nội dung riêng** với class `.fb-song-*`, tuyệt đối không override màu, chiều cao, padding, border, radius hay shadow của primitives. Không chồng selector specificity hoặc thêm `!important` để vá UX. Khi cần biến thể phải mở rộng component chính thức và regression test chống giao thoa selector.
- Card glass dùng radius 20–28px; CTA/chip riêng của Website có thể dạng pill. Button thường 36px desktop / 44px mobile; input 40px; chữ control >=13px; radius field/control thường 8–10px. Giữ màu tím Futurebook và ngoại lệ CTA đỏ trang chủ đã duyệt.
- Motion: button 180–200ms; menu 180–220ms; hover card translateY 2–4px; focus/active/disabled rõ; `prefers-reduced-motion`. Không làm blur animate liên tục.
- Blur chỉ khi hữu ích, có fallback nếu `backdrop-filter` không hỗ trợ; chữ WCAG AA, không nền rối phía sau thông tin quan trọng. Ảnh sản phẩm phải sắc nét, đúng màu.
- Website mobile **không có bottom dock/navigation**; giữ responsive và các chức năng hiện hành, không dùng hiệu ứng đè CTA/selector/footer.
- Background URL phải đến từ cấu hình public đã có; nếu thiếu contract API thì báo thiếu và dùng fallback, **không tự sửa schema DB/API**.
- **Ngoại lệ G04R được Owner duyệt ngày 08/11/2026:** Owner yêu cầu nối chính xác ảnh `fbmn/banners/G04/backdrop-v1.webp` đã upload vào pilot Song Natural qua đường đọc kiểm soát. Được phép mở rộng **đúng một endpoint đọc ảnh** trong Public Worker đang có binding `PUBLIC_MEDIA_R2` và proxy same-origin Website; nguồn kích hoạt bắt buộc là manifest công khai `lib/media/decorative-background.ts` (mặc định `null` khi thu hồi), không gán URL R2 tuỳ ý trong trang. Nếu endpoint thiếu hoặc ảnh lỗi vẫn dùng gradient G04; không tự bật Public Access bucket, không thay DB/schema/giá/SKU/Admin, không coi đây là CMS hoặc quyền tạo endpoint khác. Worker/Website production chỉ deploy khi Owner ra lệnh.
- **G05 được Owner duyệt cùng ngày:** mở rộng **skin** theo 2 ảnh tham chiếu ra mọi trang Website; dùng **một** `GlassPageBackdrop` trong `app/layout.tsx` và manifest `publicDecorativeBackground.website` trỏ tới **endpoint G04R đã có**, không bật R2 public hay thêm backend. Không lồng backdrop lần nữa ở Song Natural, không đưa ảnh thiết kế vào catalogue. Áp V2 toàn bộ chi tiết SKU qua cùng GlassPanel/Gallery/Chip; không đổi logic lựa chọn, giá, nội dung, SEO. Visual CSS theo style owner hiện hữu, dùng tokens globals; G06 kiểm desktop/mobile bằng ảnh thực. Chưa có lệnh deploy thì không deploy.
- **G07 được Owner phê duyệt (08/11/2026):** một PR Website-only đổi UX thẻ sản phẩm: cả card là một link thực, không nút “Xem chi tiết”; desktop card dọc gọn, mobile catalogue card ngang. Trên mobile chi tiết đưa preview ảnh thật + tên và SKU lên trước gallery; gallery dùng native `dialog` xem ảnh lớn, phím Escape; CTA báo giá chỉ nổi khi CTA chính ngoài viewport, hiển thị đúng SKU. Dùng cùng dữ liệu và state SKU, không thêm SKU/ảnh/giá giả, không đổi Admin/API/DB/SEO, không thêm bottom navigation. Đây là ngoại lệ bố cục cụ thể theo yêu cầu Owner, không mở rộng cho trang khác. Phải qua CI, Codex, squash merge và Owner đồng bộ repo chính trước khi deploy.
- **G07.2 Owner xác nhận từ ảnh nghiệm thu:** chỉ Website; 1 ảnh thật thì không thêm thumbnail/card con (mobile preview đơn nhưng vẫn zoom), sản phẩm gợi ý dùng grid desktop 4/tablet 3/mobile 1 cột card ngang thay carousel, footer tinh gọn và giữ nguồn liên hệ chính xác, popup/nút Tải app theo kính V2 và CH Play đa sắc, tab bỏ banner tiêu đề/mô tả lặp nhưng giữ H1 ẩn trợ năng/SEO. Không đổi SKU, app store URL chưa xác minh, navigation, Worker, API hay DB. 1 PR → CI → Codex → squash merge repo phụ; deploy khi Owner ra lệnh.

## Chất lượng và phát hành
- Thực hiện trang Song Natural trước, chốt UI bằng screenshot desktop/mobile thực (1440, 1280, 768, 390, 360px) và test gallery/SKU/CTA; sau đó rollout các trang khác.
- Kiểm npm lint/typecheck/test/build; không lỗi hydration, keyboard focus, overflows hoặc suy giảm LCP/CLS đáng kể.
- Branch → PR repo phát triển → CI xanh → Codex review sạch → squash merge → đồng bộ local và repo chính theo quy trình; **không deploy production nếu Owner chưa cho phép**.
- PR tài liệu chỉ thay quy chuẩn; không tuyên bố UI runtime đã được sửa nếu chưa có PR code và screenshot nghiệm thu.
