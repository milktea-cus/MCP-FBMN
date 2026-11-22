# MCP-FBMN — TIỀN GIANG CŨ / CHỈ TẬP TRUNG MỸ THO VÀ GÒ CÔNG

**Ngày thực thi:** 22/11/2026. **Theo chỉ đạo Owner, dừng rà các huyện Tiền Giang khác** để chỉ tìm điểm bán nhà sách / văn phòng phẩm ở hai thị trường đô thị **TP Mỹ Tho cũ** và **TP Gò Công cũ**. Không lấy điểm từ huyện Gò Công Tây, Gò Công Đông, Chợ Gạo hay Châu Thành ghép sang hai thành phố. Các key giữ `province='Tiền Giang'` và `district='Thành phố Mỹ Tho'/'Thành phố Gò Công'` theo `backend/src/districts_old.json`, dù Maps hiện ghi Đồng Tháp.

## Neon production sau migration 162

| Tiêu chí | Trước | Bổ sung | Sau |
|---|---:|---:|---:|
| Lead nghiên cứu TP Mỹ Tho cũ | 16 | **2** | **18** |
| Lead nghiên cứu TP Gò Công cũ | 12 | **1** | **13** |
| **Tổng riêng 2 khu vực** | **28** | **3** | **31** |
| **Tổng toàn 13 tỉnh cũ** | **735** | **3** | **738** |

- Độ phủ địa bàn toàn bộ: **132/134**, không đổi; điện thoại công khai: **539** lead (so với 536 trước batch 162).
- `738/738` có URL nguồn HTTPS và `research_source_key`, `738/738` ở trạng thái `new`/chưa ghé, **0** có dấu GPS/visit. `research_source_key` trùng **0**, lô 162 trùng tên trong huyện hoặc số điện thoại với `customers` **0** theo phép so khớp SQL.
- Migration [`162_tien_giang_old_round02_my_tho_go_cong_2026.sql`](../backend/migrations/162_tien_giang_old_round02_my_tho_go_cong_2026.sql), commit [`e004689`](https://github.com/milktea-cus/MCP-FBMN/commit/e004689da5968b785145bdda2c97e4126639dda2), commit trên `main` **trước** khi chạy Neon. Chạy lại SQL **0 dòng** (idempotent). Không sửa `customers`, không tạo GPS, lượt ghé, ảnh mặt tiền, vị trí đã xác minh hay trạng thái đã bán.

## Ba lead mới được nhập (chỉ nghiên cứu trực tuyến)

| Địa bàn cũ | Điểm bán | Địa chỉ ghi nhận | Số công khai | Nguồn, mức độ chứng cứ |
|---|---|---|---|---|
| **TP Mỹ Tho** | **VPP Quang Chính** | **676 Ấp Bắc**, nay phường Trung An, Đồng Tháp; cơ sở **từng ghi 351A Ấp Bắc, phường 10 cũ** | **0971041708**, số phụ **0978411307** | [Website chính thức: liên hệ](https://vanphongphamquangchinh.com/lien-he/), [website bán sách/VPP](https://vanphongphamquangchinh.com/) xác nhận loại hàng và hai địa chỉ trước/sau. Google Maps có place ID `ChIJuQFWdQCwCjERydbe-ftCh7M`. **Cùng một cơ sở đổi địa chỉ**, chỉ tạo **1** lead, không tạo lead thứ hai 351A |
| **TP Mỹ Tho** | **Nhà sách Gioan 23** | **32 Hùng Vương, phường 7 cũ** | **02733976123** | [Viet-Biz](https://www.viet-biz.com/gioan-bookstore-0273-3976-123) và [Sổ Tay Vàng](https://sotayvang.com/nha-sach-gioan-23-phuong-7/) đồng nhất tên, số, địa chỉ và loại `Book store`; danh bạ có thể cũ, **chưa thể xác minh còn mở cửa tháng 11/2026** |
| **TP Gò Công** | **Nhà sách Minh Anh GC** | **26 Thủ Khoa Huân, khu Long Thuận** | **0369147909** | [Google Maps place ID `ChIJO_kuXwRPdTER7UiYn4fyI0g`](https://www.google.com/maps/search/?api=1&query=Nha%20sach%20Minh%20Anh%20GC%20Go%20Cong&query_place_id=ChIJO_kuXwRPdTER7UiYn4fyI0g), danh mục `Stationery store`; [HappyNew.Day](https://happynew.day/s/vn/46/) cũng ghi 26 Thủ Khoa Huân. Chưa có đánh giá/website chính hãng hay xác nhận hoạt động trong tháng 11/2026; gọi trước khi Sales ghé |

## Điểm đã có hoặc loại trừ để tránh trùng/sai địa bàn

- **Mỹ Tho:** `Nhà sách Hùng Vương` (04 Lê Văn Duyệt), `FAHASA Mỹ Tho` (Vincom), `FAHASA Tiền Giang` (GO!), `Nhà sách Giáo dục Mỹ Tho` (33/40 Thủ Khoa Huân), `VPP Thành Nghĩa` (Kiosk 06 Ngô Quyền), `VPP Vĩnh Thành` (79 Nguyễn Huệ) đều đã là lead. `Deli Zone Tiền Giang` có Maps riêng nhưng **nằm trong nhà sách Hùng Vương cùng số 04 Lê Văn Duyệt**, không tạo lead thứ hai.
- **Mỹ Tho – VPP Lê Phương:** trang [vpplephuong.com/he-thong-cua-hang](https://vpplephuong.com/he-thong-cua-hang) xác nhận cửa hàng 110 Nam Kỳ Khởi Nghĩa, nhưng `customers` đã có `NPP Lê Phương` trên **chính đường Nam Kỳ Khởi Nghĩa**. Giữ để chủ dữ liệu kiểm cùng chủ/cửa hàng trước, **không chèn thành lead cạnh khách chính** hoặc tự thay loại khách.
- **Gò Công:** `Nhà sách Gò Công/LABOCO`, `Nhà sách Bảo Long`, `Nhà sách Ngọc Trâm`, `VPP Bửu Châu`, `VPP Ngọc Phú`, `VPP Thảo Vinh`, `VPP Thu Huyên`, `VPP Thanh Tuấn`, `QUẾ HOUSE` đã là lead, không thêm lại từ Maps/danh bạ khác. `Nhà sách Nhật Minh` 68 Lê Lợi có Maps/danh bạ nhưng `customers` có `NS-Nhật Minh` 17D Rạch Gầm ở **cùng TP Gò Công**; chưa xác định có phải hai điểm cùng chủ hay đã chuyển địa chỉ, **không tạo lead mới để tránh trùng mờ**.
- `NPP Văn phòng phẩm Kim Lợi` Maps công khai ở **Bình Hàng Trung/Cao Lãnh**, không phải Gò Công; còn danh bạ MST `Kim Lợi` trên Hai Bà Trưng Gò Công chưa chứng minh quầy sách/VPP bán lẻ thực tế. **Không chèn**.
- `Nhà sách Trung tâm` 101 Lê Lợi và `Siêu thị Văn hóa Tiền Giang` 53 Đinh Bộ Lĩnh mới có hồ sơ danh bạ rất cũ (năm 2017), thiếu xác nhận tình trạng thực tế mới, chưa nhập; tránh coi listing lịch sử là quầy còn bán năm 2026.

## Trạng thái và nguyên tắc vòng tiếp theo

- **Đã thực thi migration 162 và đối soát Neon**. Không coi `new` là điểm đã ghé hoặc cửa hàng đang mở năm 2026. Các listing cần Sales gọi, ảnh mặt tiền thật và GPS check-in dưới 100m tại đúng địa điểm trước khi chuyển thành khách xác minh.
- Phạm vi các lượt rà tiếp theo mặc định **chỉ hai TP Mỹ Tho và Gò Công cũ** theo yêu cầu hiện hành; không tự mở rộng sang huyện Gò Công Tây/Đông hoặc Châu Thành. Tập trung tìm tiếp quầy lẻ và phân biệt số nhà/chi nhánh.
- Không deploy Worker, Vercel vì batch 162 chỉ là migration SQL và tài liệu; CI kiểm riêng từng commit, không thay thế kiểm thử API/Auth/PWA/Android.
