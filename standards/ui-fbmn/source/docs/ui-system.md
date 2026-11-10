# Futurebook Miền Nam — chuẩn giao diện WEB mới 28/10/2026

> **Cập nhật visual mới 08/11/2026:** [Website Premium Purple Glass V2](web-component-design-system.md) là chuẩn hiện hành cho vật liệu card, surface, glass header/button/chip/motion và lớp ảnh nền decorative R2. Các mô tả **nền đặc, card trắng, radius/shadow cũ** trong tài liệu lịch sử này chỉ còn là tham chiếu trước V2; không dùng để phủ quyết glassmorphism chủ đạo. Bố cục/navigation/khả năng responsive đã được duyệt và quyết định **không có bottom navigation mobile** vẫn giữ nguyên. Không thay chức năng, API, SKU hoặc dữ liệu.

## Quyết định thay thế mẫu cũ

Chủ dự án xác nhận ảnh tổng hợp **desktop (laptop) + mobile (điện thoại)** gửi mới ngày 28/10/2026 là mẫu tham chiếu mới, THAY THẾ mẫu dùng cho WEB PR01–03. Bản tham chiếu người dùng: 1448×1086 JPEG, SHA-256:
afe6e39d6e7cd9b99bc7ff245c914cd96c8acf27cbf287f607ba60031bd43c68

**Quyết định cuối cùng sau khi kiểm tra staging trên iPhone (28/10/2026): website mobile KHÔNG có bottom navigation.** Ảnh composite có dock bốn mục, nhưng chủ dự án yêu cầu loại bỏ. Giữ logo, search, cart và hamburger ở header; đây vẫn là website responsive.

## Bố cục được duyệt theo ảnh mới

### Desktop (1280px, 1440px)
1. Header trắng: logo FBMN bên trái, tìm kiếm ở giữa, thông tin liên hệ, tài khoản và giỏ hàng bên phải.
2. Thanh navigation tím: menu “Danh mục sản phẩm” nổi khối phía trái, mục Trang chủ/Giới thiệu/Sản phẩm/Khuyến mãi/Dành cho đại lý/Tin tức/Liên hệ.
3. Hero lavender lớn: headline tím **VỞ VIẾT FUTUREBOOK MIỀN NAM**, vệt cọ đỏ slogan, ba lợi thế bằng icon, CTA đỏ và cụm hình tập bên phải, chấm slider.
4. Dải 6 nhóm sản phẩm trên nền nhạt: Vở A4, Vở B5, Vở kẻ ngang, Vở góc phố, Vở bìa bồi, Văn phòng phẩm.
5. Khối nổi bật: panel trái tím/hồng + 4 cards sản phẩm nền trắng, tag đỏ, ảnh, thông tin, CTA tím/đỏ.
6. Hai banner A4/B5 cạnh nhau, dải 4 lợi ích phía dưới, footer đơn giản.

### Mobile (360px, 390px)
1. Header gọn: logo FBMN bên trái, tìm kiếm/giỏ hàng/hamburger bên phải. Thanh nav desktop đổi thành menu mở bằng hamburger.
2. Hero xếp dọc: headline/vệt cọ/icon phía trên, cụm hình bên dưới; không gây overflow.
3. Category rail ngang hiển thị khoảng 4 ô mỗi khung, cuộn ngang để xem còn lại.
4. Tiêu đề Sản phẩm nổi bật và 2 product cards mỗi trang, kéo ngang; banner A4/B5 cuộn ngang.
5. Không có bottom nav/dock hoặc sticky cart. Footer cuộn bình thường; cart/account chưa mở cho đến khi backend được duyệt.

## Dữ liệu không được sao chép từ thiết kế

Các SKU M483/M494/M885/M439, giá 19.500đ/28.500đ/14.500đ/32.500đ, hotline trong ảnh, nhãn bán chạy/ưu đãi, claim chất lượng KHÔNG là catalogue/chính sách được xác minh. Không đưa giá, số điện thoại hoặc nhãn bán chạy từ thiết kế vào production. UI demo hiện sử dụng nhãn “MẪU GIAO DIỆN” và “Liên hệ báo giá”. Chỉ dùng mã/giá/ảnh chính thức theo evidence/approval của WEB PR04/05.

## Tài nguyên thực và kiểm thử

- Không tách ảnh SKU từ screenshot để dùng làm ảnh sản phẩm. Await owner-approved logo, hero banner, ảnh sản phẩm từng SKU; PR05 approved-only R2 pipeline giữ nguyên, fallback CSS cho tới khi có asset.
- Không bật search, account, cart, checkout chưa nối API/Phân quyền.
- Test tại 360px, 390px, 768px, 1280px, 1440px: không có scroll ngang bất thường, panel/CTA tương đối đúng ảnh, không có bottom nav/dock, keyboard focus và ESC mobile menu.
- File giao diện: app/page.tsx, components/site-header.tsx, app/rebaseline.css; CSS trước đây giữ lại phục vụ artwork được thay dần.
- Chưa nghiệm thu pixel-perfect trên thiết bị thật hoặc ảnh R2 chính thức. Không deploy Vercel khi chưa có lệnh.

## Thiết kế tokens (giữ nhận diện Futurebook)

| Vai trò | Giá trị |
|---|---|
| Brand purple | --color-primary: #6d249e |
| Deep purple | --color-primary-strong: #431078 |
| Red CTA | --color-accent: #ec0753 |
| Background lavender | --color-lavender: #eee6ff |
| Card radius | --radius-card: 14px |
| Container | --content-width: 1200px |


## Chuẩn tinh chỉnh component Website (03/11/2026)
Tài liệu chi tiết: [`docs/web-component-design-system.md`](web-component-design-system.md). Các thay đổi tinh chỉnh **không được đổi layout desktop/mobile đã duyệt**, không thêm bottom navigation. Giữ tím Futurebook làm nền tảng và **CTA đỏ ở đúng các vị trí website đã duyệt**, không phủ gradient vào mọi card.

## Nguồn ảnh danh mục và SKU (không cài chết)

- Hiện tại: các thumbnail chỉ là minh họa CSS lấy từ lib/ui-preview.ts; chưa có ảnh thực. Đổi kích thước bìa CSS để không còn các card trống ở mobile.
- Sau CMS: mỗi category.id tham chiếu thumbnailMediaId và sortOrder; mỗi product/variant tham chiếu coverMediaId + album, metadata/approval lưu Neon, bytes lưu Cloudflare R2.
- Web Admin tạo/chọn/duyệt ảnh; Workers API chỉ trả URL CDN đã duyệt. Website và Native App cùng đọc API, không cần deploy khi anh thay ảnh hoặc sắp xếp danh mục.
- Thiếu/ảnh lỗi: fallback an toàn với alt/placeholder; không tạo SKU hoặc claims từ mockup.
