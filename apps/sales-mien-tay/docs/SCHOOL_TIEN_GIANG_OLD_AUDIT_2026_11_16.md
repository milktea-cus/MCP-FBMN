# Tiền Giang cũ — audit 11/11 địa bàn, ngày 16/11/2026

## Baseline và kết quả rà

- Neon production trước lô: **14 trường / 4 địa bàn cũ**.
- 11 địa bàn cũ lấy từ `backend/src/districts_old.json`; phân biệt huyện Cai Lậy với thị xã Cai Lậy, huyện Gò Công Tây với Gò Công Đông, Gò Công thành phố.
- Đã rà và chuẩn hóa **52 tên trường mới**, 0 bản ghi trùng hiện có được bỏ qua. Sau nhập dự kiến **66 trường / 11 huyện có ít nhất một bản ghi**.
- **23** tên được đối chiếu qua quyết định/tin hoạt động gần năm học 2026–2027, **29** tên chỉ có danh mục tuyển sinh 2026 hoặc đăng ký thuế 2026 và **cần xác minh lại trạng thái đầu mối sau sáp nhập 8/2026**. Phân biệt bằng `verification_note`, tuyệt đối không tự nhận tất cả tên đã được xác thực hoạt động độc lập.
- Mốc sắp xếp toàn Đồng Tháp mới: 375 đầu mối (bao gồm mầm non) sau 8/2026: https://cms.baochinhphu.vn/dong-thap-giam-700-co-so-giao-duc-sau-sap-xep-tang-toc-chuan-bi-nam-hoc-moi-10226082515584973.htm.
- Lô chỉ xác định trường đầu mối chọn lọc, còn thiếu số lượng lớn trường/điểm trường. **11/11 có dữ liệu không đồng nghĩa kiểm kê đầy đủ.**
- `gps_verified=FALSE`, latitude/longitude để NULL; Google Maps là tìm kiếm, chưa xác minh ghim/cổng trường.

| Địa bàn Tiền Giang cũ | Neon trước | Thêm | Sau nhập |
|---|---:|---:|---:|
| Thành phố Mỹ Tho | 0 | 8 | 8 |
| Thành phố Gò Công | 0 | 5 | 5 |
| Thị xã Cai Lậy | 0 | 6 | 6 |
| Huyện Tân Phước | 0 | 4 | 4 |
| Huyện Cái Bè | 6 | 7 | 13 |
| Huyện Cai Lậy | 0 | 2 | 2 |
| Huyện Châu Thành | 0 | 5 | 5 |
| Huyện Chợ Gạo | 2 | 4 | 6 |
| Huyện Gò Công Tây | 0 | 5 | 5 |
| Huyện Gò Công Đông | 5 | 3 | 8 |
| Huyện Tân Phú Đông | 1 | 3 | 4 |
| **Tổng** | **14** | **52** | **66** |

## Sáp nhập đã được xác thực

- Phường Mỹ Tho: Tiểu học Thủ Khoa Huân gộp 5 tiểu học, THCS Lê Ngọc Hân gộp 2 trường: https://baodongthap.vn/phuong-my-tho-cong-bo-cac-quyet-dinh-sap-xep-truong-hoc-va-cong-tac-can-bo-a244196.html. Không nhập tên trường cũ Nguyễn Trãi, Tân Long, Hồ Văn Nhánh, Đinh Bộ Lĩnh, Trịnh Hoài Đức thành đầu mối riêng.
- Phường Đạo Thạnh: Tiểu học Thiên Hộ Dương gộp trường Lê Quý Đôn: https://www.baodongthap.vn/truong-tieu-hoc-thien-ho-duong-khai-giang-nam-hoc-moi-a245023.html.
- Thị xã Cai Lậy cũ/phường Mỹ Phước Tây: Tiểu học Phan Văn Kiêu và Tiểu học & THCS Mỹ Phước Tây gộp các trường cũ: https://baodongthap.vn/phuong-my-phuoc-tay-cong-bo-cac-quyet-dinh-thanh-lap-co-so-giao-duc-cong-lap-a244275.html.
- Phường Cai Lậy: THCS Cai Lậy gộp Võ Việt Tân, Thái Thị Kim Hồng: https://baodongthap.vn/dong-thap-lanh-dao-tinh-du-le-khai-giang-nam-hoc-moi-a245021.html. Không tạo đầu mối trường Võ Việt Tân riêng, dù cơ sở/điểm trường mang tên cũ.
- TP Gò Công: Tiểu học Long Hòa gộp Nguyễn Trọng Hợp: https://www.baodongthap.vn/cac-dia-phuong-cong-bo-quyet-dinh-sap-nhap-co-so-giao-duc-a244306.html; TH & THCS Bình Xuân gộp 4 trường: https://www.baodongthap.vn/cac-dia-phuong-cong-bo-quyet-dinh-sap-nhap-co-so-giao-duc-a244306.html. Trường THCS & THPT Gò Công gộp THPT Gò Công, THCS Gò Công và THCS Phường 5 theo Quyết định 2625/13-8: https://dauthau.asia/thongbao/moithau/goi-so-01-mua-sam-trang-thiet-bi-nam-2026-1789462.html. Không nhập THPT Gò Công tên cũ độc lập.
- Chợ Gạo: Trường TH Chợ Gạo và THCS Chợ Gạo là đầu mối mới sau 14/8: https://www.baodongthap.vn/cac-dia-phuong-cong-bo-quyet-dinh-sap-nhap-co-so-giao-duc-a244306.html. Không nhập lại Long Bình Điền/Thị trấn Chợ Gạo/Song Bình thành đầu mối độc lập.
- Tân Phước cũ: Trường TH Mỹ Phước sau 8/2026: https://baodongthap.vn/dong-chi-nguyen-thanh-nhan-tan-phuoc-1-can-tap-trung-khai-thac-loi-the-cay-khom-va-cong-nghiep-a246282.html; trường TH&THCS Tân Lập khai giảng 5/9: https://baodongthap.vn/dong-thap-lanh-dao-tinh-du-le-khai-giang-nam-hoc-moi-a245021.html.
- Cái Bè: Tiểu học An Hữu và Tiểu học & THCS Phan Văn Ba, điểm trường Hậu Mỹ Phú có hoạt động 5/9/2026: https://baodongthap.vn/dong-thap-lanh-dao-tinh-du-le-khai-giang-nam-hoc-moi-a245021.html. Không tách phân hiệu Hòa Hưng hoặc Hậu Mỹ Phú thành trường riêng.
- Gò Công Tây: THCS Gò Công Tây, điểm trường Nguyễn Văn Thiều: https://baodongthap.vn/truyen-thong-va-kham-mat-cho-hoc-sinh-truong-thcs-go-cong-tay-a246284.html. THCS&THPT Long Bình và Tiểu học Long Bình: https://baodongthap.vn/xa-long-binh-tu-hao-truyen-thong-vung-tin-vuon-minh-phat-trien-a244712.html.
- Tân Phú Đông: Tiểu học Tân Thới sau sáp nhập: https://baodongthap.vn/xa-tan-thoi-trien-khai-cac-quyet-dinh-thanh-lap-dang-bo-truong-hoc-a244738.html. THCS&THPT Tân Thới hoạt động 9/2026: https://baodongthap.vn/tuyen-truyen-an-toan-giao-thong-cho-hon-400-hoc-sinh-tai-xa-tan-thoi-a245627.html. THCS&THPT Phú Thạnh có hoạt động 1/2026: https://baodongthap.vn/chung-ket-cap-tinh-cuoc-thi-em-yeu-bien-dao-que-huong-tai-dong-thap-a235445.html.
- Gò Công Đông: chỉ bản ghi tiểu học Võ Thị Lớ từ dữ liệu thuế 2026 https://masothue.com/1201177312-truong-tieu-hoc-vo-thi-lo, và 2 trường THPT từ danh mục mã tuyển sinh 2026, cần kiểm lại sau sắp xếp.
- Châu Thành, huyện Cai Lậy: một phần trường cấp 3 từ danh mục mã trường 2026 https://vietjack.com/thong-tin-tuyen-sinh/ma-tinh-dong-thap.jsp, chưa đối chiếu được quyết định giữ độc lập sau 8/2026. Không tự xóa/bỏ qua các trường sau này cho tới khi có quyết định chính thức.

## Kỹ thuật

- `data/schools_tien_giang_old_full_district_audit_2026_11_16.csv`
- `backend/migrations/079_tien_giang_old_full_district_schools_2026.sql`
- `source_batch=2026-11-16-tien-giang-old-province-audit-01`
- INSERT add-only, idempotent theo source_ref và tên huyện; không thay đổi bản ghi cũ. Không cần deploy UI/backend vì không thay code chức năng.
- Việc cần làm: rà từng xã/điểm trường và GPS thực địa, xử lý alias/retired của trường đã gộp và kiểm API theo quyền Sales.
