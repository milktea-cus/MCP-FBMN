# Trà Vinh cũ — audit đủ 9/9 địa bàn (20/11/2026)

## Tình trạng và dữ liệu
- Neon trước: **8 bản ghi / 3 địa bàn cũ**.
- Danh mục chính xác 9 huyện/thị xã/thành phố trong `backend/src/districts_old.json`; giữ `province_old='Trà Vinh'`, địa chỉ hành chính năm 2026 là **tỉnh Vĩnh Long**.
- Đợt này chọn **50 trường phổ thông**, gồm **13 bản ghi có bằng chứng sắp xếp/hoạt động cuối 2026**, và **37 bản ghi dựa danh mục mã trường hoặc thông tin trước khi hoàn thành sáp nhập 08/2026**. Mọi dòng chưa đủ bằng chứng sau sáp nhập được chú thích trong `verification_note`, không ghi nhầm là xác minh hoàn toàn.
- Nếu migration chạy thành công: **58 bản ghi / 9/9 địa bàn có ít nhất một trường**. **Đây KHÔNG phải danh mục đầy đủ trường tiểu học, THCS và phân hiệu; thiếu nhiều trường/điểm trường ở các xã**.
- Google Maps chỉ là **URL tìm kiếm**, hoàn toàn không tự ghi lat/lng; GPS verified = false.
- Đã bỏ 0 tên trùng với Neon theo tên+địa bàn; toàn bộ bản ghi cũ vẫn được giữ nguyên.

| Địa bàn Trà Vinh cũ | Neon trước | Thêm | Dự kiến sau |
|---|---:|---:|---:|
| Thành phố Trà Vinh | 0 | 9 | 9 |
| Huyện Càng Long | 0 | 5 | 5 |
| Huyện Cầu Kè | 0 | 5 | 5 |
| Huyện Tiểu Cần | 0 | 7 | 7 |
| Huyện Châu Thành | 2 | 4 | 6 |
| Huyện Cầu Ngang | 5 | 7 | 12 |
| Huyện Trà Cú | 1 | 7 | 8 |
| Huyện Duyên Hải | 0 | 2 | 2 |
| Thị xã Duyên Hải | 0 | 4 | 4 |
| **Tổng** | **8** | **50** | **58** |

## Điểm cần lưu ý sau sắp xếp
- UBND **phường Trà Vinh** thông báo ngày 17/09/2026 rằng sau sáp nhập từ 01/09/2026 chỉ còn **2 trường TH, 2 trường THCS** trực thuộc phường (không kể 2 trường mầm non). Tên đầu mối: Tiểu học Lương Thế Vinh, Tiểu học Lê Văn Tám, THCS Lý Tự Trọng, THCS Trần Quốc Tuấn. Tiểu học Nguyễn Hiền và THCS Minh Trí **là phân hiệu, không tạo thành trường độc lập**. Nguồn gốc ký số: https://travinh.vinhlong.gov.vn/Portals/1339/P-Tra-Vinh-TB-cac-co-so-GD-tren-dia-ban-sau-sap-sep%20%286%29_signed_signed_signed.pdf
- **Trường Thực hành Sư phạm Trà Vinh** là trường có lớp 1–12 (và mầm non), cần phân loại **Tiểu học & THCS & THPT**, không chỉ THPT: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202608/gan-137000-hoc-sinh-vinh-long-bo-ngo-ngay-dau-tuu-truong-975123e/.
- Trường Tiểu học Kim Đồng phường Duyên Hải sáp nhập Tiểu học Lương Thế Vinh và có 2 phân hiệu; không nhập lại tên trường TH Lương Thế Vinh như đầu mối: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202608/cac-dia-phuong-chuan-bi-tot-cho-nam-hoc-moi-df93380/.
- Tiểu học Trà Cú là đầu mối gộp Trà Cú A, Ngãi Xuyên A, Ngãi Xuyên B, **không nhập ba tên này độc lập**: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202609/pho-bi-thu-tinh-uy-nguyen-minh-dung-du-khai-giang-tai-truong-tieu-hoc-tra-cu-27a0e2d/.
- Xã Hưng Mỹ (Châu Thành cũ) đề xuất gộp THCS Hưng Mỹ vào THCS Trương Văn Trì; vì chưa có quyết định cuối, **không tạo thêm hai đầu mối THCS riêng**: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202608/cac-dia-phuong-chuan-bi-tot-cho-nam-hoc-moi-df93380/.
- Các trường THPT, THCS–THPT tại Trà Vinh cũ đối chiếu danh mục mã trường năm 2026: https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/; những tên chưa xác thực độc lập sau sáp nhập tháng 8 cần đối chiếu Quyết định mới.
- **Huyện Duyên Hải cũ khác Thị xã Duyên Hải cũ**: trường THPT Sơn Cang/Long Khánh thuộc huyện, còn THPT Duyên Hải, THCS–THPT Dân Thành, THPT Long Hữu thuộc thị xã.
- Các bản ghi cũ có trường THCS Hòa Minh B / Long Hòa, Cầu Ngang, Trà Cú có thể không còn là trường độc lập sau sáp nhập; giữ cho công tác rà alias, không tự xóa.

## Phạm vi kỹ thuật
- CSV `data/schools_tra_vinh_old_full_district_audit_2026_11_20.csv`
- Migration `backend/migrations/087_tra_vinh_old_full_district_schools_2026.sql`
- Batch `2026-11-20-tra-vinh-old-province-audit-01`; SQL thêm mới idempotent theo source_ref và tên/huyện, không thay đổi dòng cũ.
- Nghiệm thu tiếp: kiểm tra đầy đủ danh mục tiểu học/THCS từng xã, phân hiệu/điểm trường, GPS cổng trường, API theo tài khoản Sales.
