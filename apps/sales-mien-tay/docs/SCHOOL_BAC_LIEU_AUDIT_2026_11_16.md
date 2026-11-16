# Bạc Liêu cũ — audit toàn bộ 7 địa bàn, ngày 16/11/2026

Phạm vi: một tỉnh lịch sử, 7/7 huyện/thị xã/TP cũ; **15 trường có nguồn công khai**, không phải toàn bộ số trường hiện hành. Bước nhập này không thay đổi tên bản ghi cũ hay xóa trường. Chưa xác minh GPS nào.

| Huyện cũ | Neon trước | Trường trong lô | Dự kiến sau |
|---|---:|---:|---:|
| Thành phố Bạc Liêu | 2 | 3 | 5 |
| Huyện Vĩnh Lợi | 9 | 1 | 10 |
| Thị xã Giá Rai | 1 | 1 | 2 |
| Huyện Hồng Dân | 0 | 3 | 3 |
| Huyện Phước Long | 0 | 3 | 3 |
| Huyện Đông Hải | 0 | 2 | 2 |
| Huyện Hòa Bình | 0 | 2 | 2 |
| **Tổng** | **12** | **15** | **27** |

- 4 huyện cũ hoàn toàn trống trước lô: Hồng Dân, Phước Long, Đông Hải, Hòa Bình.
- **7/7 địa bàn có ít nhất một trường không đồng nghĩa đủ trường**. Còn phải đối chiếu toàn bộ trường công lập, tư thục, phân hiệu, quyết định sáp nhập của từng xã/phường.
- Nguồn trường hiện hành TP Bạc Liêu: https://baclieu.camau.gov.vn/thong-bao/phuong-bac-lieu-to-chuc-hoi-nghi-cong-bo-cac-quyet-dinh-ve-sap-xep-cac-co-so-giao-duc-cong-lap-v-140782. Phường đã sáp nhập 19 trường đầu mối mầm non/tiểu học/THCS xuống 6, vì vậy không nhập các tên trường cũ như trường độc lập.
- Trường Tiểu học Vĩnh Phú Đông đã chuyển điểm chính về trụ sở xã Vĩnh Phú Đông cũ trong 2026: https://tuoitre.vn/ca-mau-bien-tru-so-doi-du-sau-sap-nhap-thanh-truong-hoc-khang-trang-100260929165439245.htm.
- Có hơn một Trường Tiểu học Phước Long trên các xã hiện nay; **chỉ nhập trường tại Ấp Long Hậu**. Trường trùng tên cần mã định danh trường/điểm học trước khi thêm.
- Trường Phổ thông Dân tộc nội trú Cà Mau có hai cơ sở, chưa có danh mục điểm trường độc lập. Địa chỉ/cổng trường mọi dòng cần GPS thực địa; không dùng Maps search làm tọa độ.
- Chưa tự sửa dữ liệu sơ bộ trong DB: cần nguồn và khóa đối chiếu trước khi sửa/đánh dấu alias.
- Dữ liệu đi kèm: `data/schools_bac_lieu_verified_2026_11_16.csv`; migration: `backend/migrations/072_bac_lieu_full_district_school_audit.sql`.
- Script hỗ trợ cổng phủ theo tỉnh: `python3 scripts/schools_bulk_ingest.py --input data/schools_bac_lieu_verified_2026_11_16.csv --province 'Bạc Liêu' --check-only`; chế độ mặc định vẫn yêu cầu đủ 134 địa bàn.

Nguồn đối chiếu 2026: https://baocamau.vn/thu-truong-bo-tai-chinh-le-tan-can-tang-qua-nam-hoc-moi-tai-tinh-ca-mau-a132168.html; https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/; https://baocamau.vn/on-dinh-doi-ngu-sau-sap-xep-chuan-bi-chu-dao-cho-nam-hoc-2026-2027-a131747.html; https://congan.camau.gov.vn/ch12/2259-Canh-sat-giao-thong-Cong-an-tinh-Ca-Mau-trao-100-phan-qua-tiep-suc-hoc-sinh-kho-khan-den-truong.html; https://baocamau.vn/index.php/cac-dong-chi-lanh-dao-tinh-du-khai-giang-nam-hoc-moi-chung-vui-cung-voi-hon-397-000-hoc-sinh-sinh--a132162.html. Mỗi dòng CSV chứa URL xác minh và URL phụ cho địa chỉ.
