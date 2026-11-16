# Audit Kiên Giang cũ — 15/15 địa bàn, ngày 16/11/2026

- Neon trước: **10 trường / 5 địa bàn cũ**.
- Đã rà 15/15 địa bàn cũ, đối chiếu nguồn UBND, báo chính thống, cơ sở giáo dục năm học 2026–2027.
- Lô nhập **57 trường mới**; dự kiến Kiên Giang đạt **67 trường / 15 địa bàn có dữ liệu**.
- Đây chỉ là **độ hiện diện**, KHÔNG phải danh sách đầy đủ trường đầu mối và phân hiệu toàn tỉnh.
- Nhiều địa chỉ mới đủ đến xã/phường; **0 GPS đã xác minh**, Google Maps chỉ là link tìm kiếm. Giữ nguyên toàn bộ bản ghi cũ.
- Có 3 tên trường được **loại khỏi batch** vì chưa rõ tình trạng độc lập sau sáp nhập tháng 8/2026; cần xác minh lại trước khi nhập.

| Huyện/thành phố cũ | Neon trước | Bổ sung | Dự kiến |
|---|---:|---:|---:|
| Thành phố Rạch Giá | 0 | 12 | 12 |
| Thành phố Hà Tiên | 0 | 5 | 5 |
| Huyện Kiên Lương | 0 | 4 | 4 |
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
| Huyện Giang Thành | 0 | 1 | 1 |
| **Tổng** | **10** | **57** | **67** |

## Đối chiếu sáp nhập và nguồn

- Rạch Giá: 9 tiểu học, 3 THCS đầu mối sau sắp xếp 8/2026; không nhập các tên cũ đã gộp: https://rachgia.angiang.gov.vn/rach-gia-chuc-hoi-nghi-cong-bo-quyet-dinh-thanh-lap-chuc-dang-sap-xep-cac-co-so-giao-duc-cong-lap-va-cong-tac-can-bo
- Hà Tiên và Tô Châu: 5 trường sau gộp: https://baoangiang.com.vn/ha-tien-sap-nhap-hang-loat-truong-cong-lap-a494779.html và https://baoangiang.com.vn/phuong-to-chau-sap-nhap-con-3-truong-a494820.html
- Hòn Đất: chỉ 4 trường liên cấp sau sáp nhập, không lấy 2 trường mầm non: https://hondat.angiang.gov.vn/hon-dat-cong-bo-cac-quyet-dinh-ve-thanh-lap-sap-xep-cac-truong-hoc-va-cong-tac-can-bo
- Giồng Riềng: 5 trường có trụ sở ấp từ quyết định 8/2026, vẫn cần tọa độ từng phân hiệu: https://giongrieng.angiang.gov.vn/giong-rieng-cong-bo-cac-quyet-dinh-sap-xep-chuc-lai-co-so-giao-duc-cong-lap
- Kiên Hải: Tiểu học Hòn Tre nhập với THCS và THPT Kiên Hải thành trường liên cấp 3 cấp: https://kienhai.angiang.gov.vn/truong-th-thcs-va-thpt-kien-hai-khai-giang-nam-hoc-2026-2027
- Phú Quốc: chỉ 3 trường từ thông báo 27/10/2026 của đặc khu, cần bổ sung danh sách 15 đầu mối (có cả mầm non) và phân hiệu: https://phuquoc.angiang.gov.vn/thong-bao-ve-viec-cho-thue-nha-do-ban-boi-thuong-ho-tro-va-tai-dinh-cu-dac-khu-phu-quoc-quan-ly-khai-thac-0
- Vĩnh Thuận/U Minh Thượng/An Minh/An Biên: chỉ lấy tên sau quyết định sáp nhập, URLs chi tiết trong CSV.
- **Loại khỏi lô**: Trường Tiểu học Kiên Lương 2 vì Kiên Lương 1 tiếp nhận một phần trường cũ và phân hiệu Lò Bom (tư cách đầu mối trường 2 cần đối chiếu); Trường Tiểu học Tân Khánh Hòa và Trường THCS Tân Khánh Hòa vì chỉ có tài liệu giữ ổn định/dự kiến cũ, trong khi công trình 11/2026 đã ghi “Trường Tiểu học Tân Khánh Hòa cũ”. Nguồn: https://kienluong.angiang.gov.vn/chu-tich-ubnd-xa-kien-luong-tran-binh-trong-cung-doan-cong-tac-xa-lam-viec-voi-truong-tieu-hoc-kien-luong-1 ; https://giangthanh.angiang.gov.vn/pho-chu-tich-ubnd-xa-tran-ngoc-bich-di-kiem-tra-cac-cong-trinh-thuoc-tieu-du-an-1-cua-du-an-4.
- Mục tiêu tiếp: đối chiếu tên trường đầu mối còn thiếu theo quyết định từng xã/phường; GPS cổng trường/phân hiệu và danh mục `school_sites`; xử lý tên trường cũ đã sáp nhập như alias.
- CSV `data/schools_kien_giang_full_district_audit_2026_11_16.csv`, migration `backend/migrations/074_kien_giang_full_district_schools_2026.sql`; batch `2026-11-16-kien-giang-province-audit-01`.
