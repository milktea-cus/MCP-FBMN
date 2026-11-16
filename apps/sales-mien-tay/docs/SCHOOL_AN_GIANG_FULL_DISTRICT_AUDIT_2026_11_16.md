# An Giang cũ — audit 11/11 địa bàn, 16/11/2026

## Phương pháp

- Kiểm tra trực tiếp `public.schools` trên Neon (105 bản ghi, 6/11 địa bàn), so sánh danh sách huyện với `backend/src/districts_old.json`.
- Đối chiếu quyết định sắp xếp tháng 8/2026 và tin hoạt động trường 2026-2027 trên UBND xã, phường và Công an tỉnh An Giang.
- Chỉ nhập tên hiện hành theo nguồn công khai. Không cộng tên trường đã sáp nhập, không ghi tọa độ giả.
- `47` trường mới trong lô. `0` ứng viên trùng DB được bỏ qua. 11/11 địa bàn đã được rà, trong đó 3 địa bàn đã có dữ liệu 2026 nên không cần nhập thêm từ các nguồn kiểm trong đợt này.
- **Có trường tại 11/11 địa bàn không đồng nghĩa hoàn tất tổng điều tra mọi trường**. Nhiều địa chỉ chỉ xác nhận đến xã/phường, cần xác minh GPS và phân hiệu.

| Địa bàn cũ | Neon trước | Bổ sung từ nguồn công khai | Sau nếu áp dụng |
|---|---:|---:|---:|
| Thành phố Long Xuyên | 3 | 10 | 13 |
| Thành phố Châu Đốc | 5 | 6 | 11 |
| Huyện An Phú | 20 | 0 | 20 |
| Thị xã Tân Châu | 0 | 6 | 6 |
| Huyện Phú Tân | 0 | 5 | 5 |
| Huyện Châu Phú | 31 | 0 | 31 |
| Thị xã Tịnh Biên | 0 | 6 | 6 |
| Huyện Tri Tôn | 0 | 5 | 5 |
| Huyện Châu Thành | 0 | 5 | 5 |
| Huyện Chợ Mới | 38 | 0 | 38 |
| Huyện Thoại Sơn | 8 | 4 | 12 |
| **Tổng** | **105** | **47** | **152** |

## Nguồn và vấn đề dữ liệu cũ

- Long Xuyên: https://longxuyen.angiang.gov.vn/hoi-nghi-cong-bo-trao-quyet-dinh-ve-cong-tac-chuc-bo-may-va-can-bo-quan-ly-cac-truong-hoc-tren-dia-ban-phuong; Trường Tiểu học Bùi Thị Xuân cũ sáp nhập thành Trường Tiểu học Nguyễn Khuyến; Trường Tiểu học Châu Văn Liêm hiện hành đã có DB.
- Châu Đốc: https://chaudoc.angiang.gov.vn/index.php/phuong-chau-doc-trao-quyet-dinh-sap-nhap-chuc-lai-truong-hoc-va-cong-tac-can-bo; Trường Tiểu học Hoàng Hoa Thám nhập vào Tiểu học Lê Văn Tám, Lý Tự Trọng nhập vào Tiểu học Lê Lợi, Trưng Vương tổ chức lại thành **Tiểu học Bán trú Trưng Vương**. Bản ghi cũ hiện còn và phải bổ sung trạng thái alias/retired trong đợt làm sạch tiếp theo; không tự xóa.
- Tân Châu: https://tanchau.angiang.gov.vn/phuong-tan-chau-trao-quyet-dinh-thanh-lap-cac-truong-va-bo-nhiem-can-bo-quan-ly-cac-truong-cong-lap. Trường Tiểu học Tân Châu có 3 cơ sở; THCS Tân Châu có trường chính, phân hiệu và điểm trường — chưa tách `school_sites`.
- Phú Tân: https://phutan.angiang.gov.vn/xa-phu-tan-cong-bo-quyet-dinh-sap-xep-cac-co-so-giao-duc; https://binhthanhdong.angiang.gov.vn/binh-thanh-dong-cong-bo-quyet-dinh-thanh-lap-truong-va-trien-khai-nhiem-vu-nam-hoc-moi-2026-2027. Trường Phú Hưng, Tân Hòa, Phú Mỹ cũ đã gộp thành 3 trường mới tại xã Phú Tân; tuyệt đối không tạo các tên cũ.
- Tịnh Biên: https://tinhbien.angiang.gov.vn/index.php/cac-truong-tren-dia-ban-phuong-tinh-bien-khai-giang-nam-hoc-moi-2026-2027; https://nuicam.angiang.gov.vn/nui-cam-cong-bo-cac-quyet-dinh-ve-sap-nhap-truong-va-cong-tac-can-bo. Trường THCS Lương Thế Vinh, Nguyễn Văn Trỗi và khối THCS Trần Quang Khải gộp thành THCS Tịnh Biên.
- Tri Tôn: https://triton.angiang.gov.vn/index.php/node/905; https://bachuc.angiang.gov.vn/hdnd-xa-ba-chuc-khao-sat-cong-tac-chuan-bi-va-thuc-hien-nhiem-vu-nam-hoc-2026-2027. Quyết định tháng 8/2026 thay thế cấu trúc trường tháng 1/2026 nên ưu tiên nguồn mới.
- Châu Thành: https://candang.angiang.gov.vn/index.php/can-dang-cong-bo-quyet-dinh-sap-nhap-cac-co-so-giao-duc-va-cong-tac-nhan-su-sau-sap-nhap; https://candang.angiang.gov.vn/can-dang-cong-bo-quyet-dinh-thanh-lap-chuc-co-so-dang-truong-mam-non-truong-tieu-hoc-va-truong-thcs-sau-sap-nhap; https://binhhoa.angiang.gov.vn/lanh-dao-ubnd-xa-binh-hoa-kiem-tra-cong-tac-chuan-bi-khai-giang-nam-hoc-moi; https://vinhhanh.angiang.gov.vn/truong-thcs-thpt-vinh-hanh-don-nam-hoc-moi-trong-khong-khi-phan-khoi-0.
- Thoại Sơn: https://vinhtrach.angiang.gov.vn/vinh-trach-ra-quan-thang-hanh-dong-vi-su-nghiep-giao-duc-nam-2026; https://vinhtrach.angiang.gov.vn/so-giao-duc-va-dao-tao-giang-kiem-tra-viec-thuc-hien-nhiem-vu-dau-nam-hoc-tai-xa-vinh-trach.
- Ba huyện đã có lô nguồn 2026: An Phú (20 trường), Châu Phú (31), Chợ Mới (38). Không suy diễn đầy đủ trường của cả ba huyện. Chợ Mới có nguồn hiện hành: https://chomoi.angiang.gov.vn/le-cong-bo-quyet-dinh-thanh-lap-moi-chuc-dang-don-vi-su-nghiep-truc-thuoc-dang-bo-xa-cho-moi; Châu Phú: https://chauphu.angiang.gov.vn/chau-phu-chuc-le-cong-bo-va-trao-quyet-dinh-ve-cong-tac-chuc-bo-may-va-can-bo-quan-ly-cac-co-so.
- Lô `source_batch`: `2026-11-16-an-giang-province-audit-01`; CSV: `data/schools_an_giang_full_district_audit_2026_11_16.csv`; migration 073. Source URL từng dòng cụ thể trong CSV. GPS luôn `false`.
- Không thay Cloudflare/Vercel vì chỉ nhập dữ liệu và tài liệu, không đổi API/UI.
