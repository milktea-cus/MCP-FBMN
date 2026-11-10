# Futurebook Miền Nam — bắt buộc đọc trước khi sửa repo

**Repo này còn chứa kế hoạch Nhà sách Đại Việt, một storefront riêng dùng chung Admin. Trước BẤT KỲ việc Đại Việt nào, bắt buộc đọc apps/dai-viet/AGENTS.md và docs/dai-viet/00-master-plan.md + docs/dai-viet/README.md rồi toàn bộ tài liệu 01–07. Đây là bước READ-FIRST của mọi chat/AI/PR, không được bỏ qua. Đại Việt có theme ĐỎ riêng; contract kích thước/motion dùng chung nhưng KHÔNG áp màu tím Futurebook cho Đại Việt. Không tạo Admin thứ hai. Giữ nguyên UI Futurebook và Admin khi làm Đại Việt.**

Đây là chỉ dẫn **áp dụng toàn repo**, cho mọi phiên AI/chat, Codex, developer và PR. Nội dung của một chat riêng lẻ **không** thay thế quy tắc này.

## Quy tắc UI bắt buộc

Trước khi tạo/sửa bất kỳ giao diện Futurebook nào, đọc:
1. [Quy chuẩn UI chung](docs/futurebook-ui-contract.md) — **nguồn sự thật duy nhất** cho nút, input, tab, bảng, toast, form và màu sắc.
2. Với Admin `apps/admin/**`: đọc thêm [hướng dẫn Admin](apps/admin/AGENTS.md) và [thiết kế Admin](docs/admin-ui-design-system.md).
3. Với Website `app/**`: đọc thêm [hướng dẫn Website](app/AGENTS.md) và [thiết kế Website](docs/web-component-design-system.md).

**Chốt visual Website Futurebook ngày 08/11/2026:** [Website Premium Purple Glass UI V2](docs/web-component-design-system.md) là chuẩn thiết kế visual hiện hành: card/panel/header kính mờ trong suốt trên ảnh nền decorative R2 khi có public config, fallback gradient. Bộ quy tắc này **chỉ áp dụng Website Futurebook**, không lan sang Admin hoặc storefront khác; không đổi bố cục/navigation, dữ liệu, API, SKU, logic hay SEO. Chuẩn control và motion toàn repo vẫn giữ, ngoại lệ visual radius của card/chip Website được ghi rõ trong UI Contract mục 6.

**Ngoại lệ G04R theo lệnh Owner 08/11/2026:** chỉ tích hợp ảnh nền `banners/G04/backdrop-v1.webp` đã được Owner chọn, thông qua endpoint đọc cố định trên **Public Worker hiện hữu** và Website proxy cùng origin, dùng manifest `lib/media/decorative-background.ts` để bật/tắt. Không thay API catalogue/CMS, DB, Admin hay mở bucket; giữ gradient khi Worker/ảnh lỗi. Không mở rộng ngoại lệ sang ảnh khác hay sản phẩm khác nếu Owner chưa duyệt. Deploy Worker/Website production phải được Owner cho phép riêng.

**G05 theo lệnh Owner 08/11/2026:** hai ảnh mẫu Premium Purple Glass là hướng visual cho **toàn Website Futurebook**; sử dụng lại chính đường đọc ảnh G04R đã được phê duyệt làm **một nền chung** từ `app/layout.tsx`, không tạo R2/API mới. G03 Song Natural chỉ còn là mẫu giao diện, các trang SKU khác dùng lại component kính; giữ SKU, ảnh thật, SEO, navigation, API, form, giá và footer không bịa chính sách. Chỉ Website, không thay Admin/Worker/DB. G06 UAT 1440/1280/768/390/360 còn phải kiểm tra trước khi gọi đạt pixel mẫu; deploy production cần lệnh Owner riêng.


**Không được tự suy diễn kích thước nút, màu, padding, vị trí toast, motion, header popup hay thiết kế lại điều hướng.** Các con số bắt buộc: nút desktop **36px**, input/select **40px**, nút mobile **44px**, chữ điều khiển **13px**, bo góc điều khiển **8–10px**, nhấn **tím Futurebook**, toast **nhỏ góc trên phải**, form tạo/sửa **drawer hoặc popup**, header các bảng dữ liệu **tím nhạt**. **Motion bắt buộc:** nút **180–200ms**, menu **180–220ms**, popup mở **280ms** / đóng **220ms**, drawer **300ms**. **Header popup bắt buộc:** **52px desktop / 56px mobile**, tiêu đề **16px**, nền lavender rất nhạt có điểm nhấn tím Futurebook; tránh padding header dày. Một nguồn token duy nhất và component dùng chung; không sao chép CSS hoặc tạo override riêng lẻ.

Nếu yêu cầu nghiệp vụ thay đổi UX, làm trọn luồng liên quan, không sửa một trang khiến các trang khác mất kết nối hoặc mất tab. Không xóa/thêm tính năng hoặc đổi bố cục đã duyệt ngoài phạm vi được yêu cầu.

## Bảo toàn dữ liệu và phát hành

- Chỉ xử lý Futurebook Miền Nam. Không phát minh giá NET, bảng giá, SKU, mã, logo, quyền, chính sách, số liệu hoặc dữ liệu khách.
- Giá NET/giá riêng/đại lý không được công khai trên Website, App người tiêu dùng hoặc cho khách khác.
- Phải kiểm tra UI desktop/mobile và các trạng thái hover/focus/disabled/loading/empty/error; nghiệm thu bằng ảnh thật, không dùng mockup AI.
- Thực hiện **branch → PR → CI xanh → Codex review sạch → squash merge**; deploy **thủ công khi Owner yêu cầu**. Mọi thay đổi giao diện phải có kiểm tra quy chuẩn bằng CI.
- Không tạo issue/roadmap trùng; theo [Issue #104](https://github.com/alibaba240185/fbmn/issues/104) cho các lô Admin.

Nếu gặp CSS hoặc tính năng cũ lệch chuẩn, xác định phạm vi, sửa ở **hệ thống dùng chung** thay vì vá từng trang; mô tả ngoại lệ và kế hoạch chuyển đổi trong PR.
