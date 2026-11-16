# Kiên Giang cũ — audit tỉnh 15/15 địa bàn — 16/11/2026

## Baseline và phương pháp

- Neon production trước đợt: **10** bản ghi ở **5/15 huyện cũ**, chưa kiểm chứng hoạt động từng bản ghi cũ; các record cũ đang giữ nguyên.
- Đã đối chiếu 15/15 huyện cũ với `backend/src/districts_old.json`, nguồn năm học 2026–2027 của UBND xã/phường, Báo An Giang và website trường.
- **60 tên trường mới** có nguồn tại 15/15 địa bàn, 15/15 địa bàn có ứng viên trong danh sách rà. 0 tên có sẵn Neon được loại khỏi INSERT.
- Nhiều địa chỉ chỉ đến xã/phường; **không có GPS đã xác minh**. Nút Maps mở kết quả tìm kiếm, chưa phải định vị chính xác cổng trường.
- Đây là **lô bổ sung trường đầu mối**, chưa phải danh sách đầy đủ trường và phân hiệu của cả tỉnh. Có ước tính 1.184 phân hiệu/điểm phụ toàn An Giang mới sau sáp nhập: cần xây dựng `school_sites` riêng.

| Địa bàn lịch sử Kiên Giang | Neon trước | Bổ sung | Sau nhập |
|---|---:|---:|---:|
| Thành phố Rạch Giá | 0 | 12 | 12 |
| Thành phố Hà Tiên | 0 | 5 | 5 |
| Huyện Kiên Lương | 0 | 5 | 5 |
| Huyện Hòn Đất | 0 | 4 | 4 |
| Huyện Tân Hiệp | 2 | 2 | 4 |
| Huyện Châu Thành | 1 | 4 | 5 |
| Huyện Giồng Riềng | 4 | 5 | 9 |
| Huyện Gò Quao | 1 | 3 | 4 |
| Huyện An Biên | 2 | 4 | 6 |
| Huyện An Minh | 0 | 4 | 4 |
| Huyện Vĩnh Thuận | 0 | 2 | 2 |
| Thành phố Phú Quốc | 0 | 3 | 3 |
| Huyện Kiên Hải | 0 | 1 | 1 |
| Huyện U Minh Thượng | 0 | 3 | 3 |
| Huyện Giang Thành | 0 | 3 | 3 |
| **Tổng** | **10** | **60** | **70** |

## Lưu ý sáp nhập và địa chỉ

- Rạch Giá: 9 tiểu học + 3 THCS trong 16 trường trực thuộc phường sau sáp nhập, không đưa lại Mạc Đĩnh Chi, Trần Văn Ơn đã nhập vào hoặc các tên cũ không có trong quyết định mới: https://rachgia.angiang.gov.vn/rach-gia-chuc-hoi-nghi-cong-bo-quyet-dinh-thanh-lap-chuc-dang-sap-xep-cac-co-so-giao-duc-cong-lap-va-cong-tac-can-bo
- Hà Tiên/Tô Châu: chỉ lấy 3 + 2 đầu mối sau tháng 8, không đưa trường Pháo Đài 1, Cừ Đứt, Dương Hòa, Thuận Yên như trường độc lập. https://baoangiang.com.vn/ha-tien-sap-nhap-hang-loat-truong-cong-lap-a494779.html ; https://baoangiang.com.vn/phuong-to-chau-sap-nhap-con-3-truong-a494820.html
- Hòn Đất: 4 trường liên cấp trong 6 đầu mối của xã (2 trường còn lại mầm non không thuộc phạm vi). https://hondat.angiang.gov.vn/hon-dat-cong-bo-cac-quyet-dinh-ve-thanh-lap-sap-xep-cac-truong-hoc-va-cong-tac-can-bo
- Kiên Hải: **Trường TH, THCS và THPT Kiên Hải** hình thành từ Tiểu học Hòn Tre + THCS & THPT Kiên Hải. Không nhập hai trường cũ thành các đầu mối riêng. https://kienhai.angiang.gov.vn/truong-th-thcs-va-thpt-kien-hai-khai-giang-nam-hoc-2026-2027
- Phú Quốc: 15 đầu mối ở khối thuộc đặc khu sau 20/8/2026, gồm 8 trường liên cấp. Lô này chỉ xác nhận 3 trường từ thông báo chính thức 10/2026, chưa đủ toàn đặc khu. https://baophapluat.vn/phu-quoc-cong-bo-quyet-dinh-sap-nhap-cac-co-so-giao-duc-cong-lap.html
- U Minh Thượng: Minh Thuận 5, An Minh Bắc 4, Minh Thuận 6 đã sáp nhập, **không tạo bản ghi độc lập**. https://uminhthuong.angiang.gov.vn/u-minh-thuong-sap-xep-kien-toan-cac-co-so-giao-duc-cong-lap
- Giang Thành: đưa trường nội trú đã tuyển sinh 2026-2027, và hai trường được dự kiến giữ nguyên ở báo cáo tháng 4. **Cần đối chiếu quyết định chính thức sau tháng 8 đối với hai trường giữ nguyên**; giữ trạng thái GPS chưa xác minh.
- Tân Hiệp: kiểm chứng THPT Thạnh Đông và TH&THCS Thạnh Đông 1 trong khai giảng 5/9; 2 bản ghi cũ chưa xác thực lại.
- Còn rất nhiều trường tại các xã mới ngoài khu vực trung tâm, trường THPT trực thuộc Sở, phân hiệu/điểm trường, tên trường cũ chưa đối chiếu. Không đánh dấu hoàn thành tỉnh.
- CSV: `data/schools_kien_giang_full_district_audit_2026_11_16.csv`, migration: `backend/migrations/074_kien_giang_full_district_schools_2026.sql`, batch `2026-11-16-kien-giang-province-audit-01`.
