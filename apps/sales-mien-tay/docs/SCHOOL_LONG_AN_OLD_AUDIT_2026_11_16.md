# Long An cũ — 15/15 quận/huyện — rà ngày 16/11/2026

## Phạm vi và baseline
- Neon production trước lô: **18 trường / 7/15 huyện cũ** trong `public.schools`.
- Địa giới `province_old='Long An'` và `district_old` phải giữ theo **tỉnh Long An cũ**, mặc dù địa chỉ hiện tại thuộc Tây Ninh mới.
- Đối chiếu đủ 15/15 địa bàn. Có **54 bản ghi mới**, 0 tên trùng Neon được bỏ qua. Sau nhập dự kiến **72 trường / 15 địa bàn có ít nhất một trường**.
- **Không phải tổng điều tra đầy đủ trường**. Hiện mới xác nhận đầu mối chọn lọc, thiếu nhiều trường tiểu học/THCS/điểm trường tại các xã khác; không có GPS thực địa.
- Phân loại nguồn: **13** dòng chỉ đối chiếu qua danh mục mã trường tháng 05/2026, sau sáp nhập 08/2026 chưa đủ chứng cứ riêng về trạng thái hoạt động; **3** dòng từ đề án được thông qua nhưng cần kiểm quyết định thực thi. Các dòng này ghi **rõ cảnh báo trong verification_note**, không được khẳng định đã xác minh hoàn toàn.
- Trường THCS&THPT Khánh Hưng cũ **không nhập** vì bài 23/10/2026 cho thấy cơ sở chuyển công năng: https://baotayninh.vn/xa-khanh-hung-siet-chat-quan-ly-tai-chinh-tai-san-cong-351668.html
- Không nhập THPT Kiến Tường (vì phương án 08/2026 nhập vào Thiên Hộ Dương), không nhập THPT Chu Văn An (nhập vào Cần Đước). Quyết định sáp nhập: https://tuoitre.vn/phuong-an-sap-xep-giam-hon-45-don-vi-giao-duc-trong-thang-8-2026-cua-tay-ninh-100260801141323219.htm.
- **Châu Thành Long An cũ khác huyện Châu Thành Tây Ninh cũ**. Chỉ nhận các trường ở xã Tầm Vu và Thuận Mỹ (Long An cũ). Hoàng Văn Thụ là Châu Thành Tây Ninh cũ nên cố ý loại bỏ.
- Bản ghi seed 2025 chưa đối chiếu vẫn để nguyên, không tự xóa, có khả năng chứa địa chỉ trường cũ.

| Huyện/thành phố Long An cũ | Trước | Bổ sung | Sau nếu áp dụng |
|---|---:|---:|---:|
| Thành phố Tân An | 10 | 6 | 16 |
| Thị xã Kiến Tường | 2 | 2 | 4 |
| Huyện Tân Hưng | 0 | 2 | 2 |
| Huyện Vĩnh Hưng | 0 | 2 | 2 |
| Huyện Mộc Hóa | 2 | 1 | 3 |
| Huyện Tân Thạnh | 0 | 3 | 3 |
| Huyện Thạnh Hóa | 0 | 2 | 2 |
| Huyện Đức Huệ | 0 | 5 | 5 |
| Huyện Đức Hòa | 0 | 5 | 5 |
| Huyện Bến Lức | 1 | 10 | 11 |
| Huyện Thủ Thừa | 1 | 3 | 4 |
| Huyện Tân Trụ | 1 | 3 | 4 |
| Huyện Cần Đước | 1 | 5 | 6 |
| Huyện Cần Giuộc | 0 | 3 | 3 |
| Huyện Châu Thành | 0 | 2 | 2 |
| **Tổng** | **18** | **54** | **72** |

## Nguồn và quyết định chính

- Danh mục mã trường do Bộ GDĐT cập nhật 09/05/2026 (trước sáp nhập trường 08/2026): https://mtud.edu.vn/wp-content/uploads/2026/05/Danh-sach-truong-THPT-9.5.2026-Bo-sung-them-ma-xa.pdf. Các dòng dùng nguồn này có cờ cảnh báo, không gán chắc chắn trạng thái sau sáp nhập.
- Tân Hưng: https://baotayninh.vn/dang-uy-xa-tan-hung-sap-xep-thanh-lap-cac-chi-bo-truong-hoc-truc-thuoc-155370.html, https://baotayninh.vn/nghi-luc-vuot-kho-cua-co-hoc-tro-mo-coi-350857.html. Vĩnh Hưng: https://baotayninh.vn/cong-ty-co-phan-nicotex-dong-hanh-chap-canh-uoc-mo-155794.html, https://baotayninh.vn/tay-ninh-co-59-thi-sinh-doat-giai-hoc-sinh-gioi-quoc-gia-136296.html. Mộc Hóa: https://baotayninh.vn/truong-thcs-va-thpt-binh-phong-thanh-chu-trong-nang-cao-chat-luong-day-va-hoc-155809.html.
- Tân Thạnh: https://baotayninh.vn/pho-chu-tich-thuong-truc-ubmttq-viet-nam-tinh-du-khai-giang-tai-truong-thpt-tan-thanh-155832.html, https://baotayninh.vn/xa-tan-thanh-100-phan-qua-trung-thu-cho-hoc-sinh-co-hoan-canh-kho-khan-156094.html, https://baotayninh.vn/tay-ninh-vinh-danh-51-tap-the-ca-nhan-tai-cuoc-thi-dai-su-van-hoa-doc-nam-2026-155003.html. Thạnh Hóa: https://baotayninh.vn/xuat-hien-ca-sau-gan-truong-hoc-chinh-quyen-phat-canh-bao-146911.html.
- Đức Huệ: https://baotayninh.vn/so-giao-duc-va-dao-tao-kiem-tra-cong-tac-sap-xep-van-hanh-cac-co-so-giao-duc-tai-xa-duc-hue-352151.html, https://baotayninh.vn/tiep-suc-mua-thi-dong-hanh-cung-si-tu-buoc-vao-lop-10-148324.html. Đức Hòa: https://baotayninh.vn/xa-duc-hoa-tang-cuong-phong-ngua-bao-luc-hoc-duong-351859.html, https://baotayninh.vn/tap-huan-ky-nang-lai-xe-an-toan-cho-hoc-sinh-trung-hoc-pho-thong-146922.html.
- Bến Lức: https://baotayninh.vn/hdnd-xa-ben-luc-thong-qua-de-an-sap-xep-sap-nhap-cac-co-so-giao-duc-cong-lap-154595.html, https://baotayninh.vn/thu-truong-bo-giao-duc-va-dao-tao-doan-trung-kien-tham-va-lam-viec-voi-mot-so-truong-hoc-tai-xa-ben-luc-157606.html, https://baotayninh.vn/swire-coca-cola-viet-nam-dong-hanh-xay-dung-nang-luc-an-toan-cho-hoc-sinh-157380.html. Ở Bến Lức, trường THCS Nguyễn Trung Trực có 1 chính + 1 phân hiệu; không tách thành hai trường.
- Thủ Thừa: https://baotayninh.vn/bien-ly-thuyet-an-toan-giao-thong-thanh-ky-nang-song-cho-hoc-sinh-158049.html, https://baotayninh.vn/lanh-dao-tinh-kiem-tra-cong-tac-chuan-bi-ky-thi-tot-nghiep-thpt-nam-2026-148929.html. Tân Trụ: https://baotayninh.vn/tan-tru-cong-bo-quyet-dinh-sap-nhap-cac-co-so-giao-duc-kien-toan-to-chuc-dang-va-can-bo-quan-ly-154949.html, https://baotayninh.vn/tinh-doan-tay-ninh-tham-dong-vien-cac-doi-hinh-tiep-suc-mua-thi-149205.html.
- Kiến Tường: https://baotayninh.vn/chu-dong-tu-som-de-phong-ngua-bao-luc-hoc-duong-353198.html. Cần Đước: https://tuoitre.vn/phuong-an-sap-xep-giam-hon-45-don-vi-giao-duc-trong-thang-8-2026-cua-tay-ninh-100260801141323219.htm, https://baotayninh.vn/long-cang-tu-van-huong-nghiep-cho-hoc-sinh-khoi-12-145938.html, https://baotayninh.vn/tay-ninh-co-4-nha-giao-tre-tieu-bieu-duoc-trung-uong-doan-tuyen-duong-nam-2026-353171.html. Cần Giuộc: https://baotayninh.vn/pho-bi-thu-tinh-uy-chu-tich-uy-ban-mttq-viet-nam-tinh-nguyen-thanh-hai-du-le-khai-giang-tai-truong-thpt-can-giuoc-155798.html, https://baotayninh.vn/chu-dong-tu-som-de-phong-ngua-bao-luc-hoc-duong-353198.html.
- Châu Thành Long An cũ: https://baotayninh.vn/tang-toc-on-tap-truoc-ky-thi-tot-nghiep-thpt-nam-2026-145833.html; dữ liệu mã THPT Phan Văn Đạt trong danh mục 05/2026 (nguồn ở CSV).
- Không tạo trường mầm non, không tự đặt lat/long hoặc gps_verified. Google Maps chỉ link tìm kiếm.
- Cần lập bảng `school_sites` để Sales có thể đi từng điểm trường sau sáp nhập (không đồng nghĩa một đầu mối bằng một địa điểm).
- CSV: `data/schools_long_an_old_full_district_audit_2026_11_16.csv`, migration `backend/migrations/078_long_an_old_full_district_schools_2026.sql`, batch `2026-11-16-long-an-old-province-audit-01`.
