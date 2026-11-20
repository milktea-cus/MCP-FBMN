# Bến Tre cũ — audit đủ 9 địa bàn — 20/11/2026

## Kết quả và hạn chế
- Neon production trước lô: **15 trường tại 6/9 địa bàn cũ**. Danh mục địa bàn `backend/src/districts_old.json` gồm 9 huyện/thành phố.
- Rà toàn bộ 9 địa bàn, bổ sung **49 trường có nguồn đối chiếu**, không nhập 0 tên trùng hiện tại. Dự kiến **64 trường tại 9/9 địa bàn** sau migration.
- Nguồn nêu hoạt động/quyết định sau tháng 8/2026 của **14** trường; **35** trường có trong danh mục mã tuyển sinh 2026 hoặc nguồn trước khi hoàn tất sắp xếp, **chưa chứng minh được tư cách đầu mối độc lập sau sáp nhập**. Mỗi dòng đã được gắn `verification_note` cụ thể.
- `province_old='Bến Tre'` và `district_old` theo địa giới cũ. Địa chỉ hiện tại sử dụng **tỉnh Vĩnh Long mới**. Trường không được tự chuyển sang Trà Vinh cũ / Vĩnh Long cũ vì tỉnh hiện hành giống nhau.
- Đây **chỉ là hiện diện trường ở 9/9 địa bàn**, chưa phải điều tra toàn bộ trường tiểu học, THCS, phân hiệu và điểm trường. Nhiều xã vẫn chưa có trường trong danh sách.
- Không tự tạo tọa độ GPS. `gps_verified=FALSE`, Google Maps là **link tìm kiếm**, không phải ghim cổng trường.

| Địa bàn lịch sử | Trước | Thêm | Dự kiến |
|---|---:|---:|---:|
| Thành phố Bến Tre | 1 | 9 | 10 |
| Huyện Châu Thành | 7 | 2 | 9 |
| Huyện Chợ Lách | 0 | 3 | 3 |
| Huyện Mỏ Cày Nam | 3 | 7 | 10 |
| Huyện Giồng Trôm | 2 | 5 | 7 |
| Huyện Bình Đại | 0 | 7 | 7 |
| Huyện Ba Tri | 0 | 8 | 8 |
| Huyện Thạnh Phú | 1 | 6 | 7 |
| Huyện Mỏ Cày Bắc | 1 | 2 | 3 |
| **Tổng** | **15** | **49** | **64** |

## Đối chiếu sáp nhập năm 2026
- **Huyện Chợ Lách:** theo quyết định 5351/QĐ-UBND ngày 28/08/2026, Trường THCS Chợ Lách nhập với THPT Trần Văn Kiết thành **THCS và THPT Trần Văn Kiết**. Không nhập tên THCS Chợ Lách/THPT Trần Văn Kiết riêng: https://tuyencongchuc.vn/thong-bao/truong-thcs-thpt-tran-van-kiet-tinh-vinh-long-tuyen-dung-hop-dong-lao-dong-nam-2026/; hoạt động 27/10/2026 còn được báo dưới tên cũ https://congan.vinhlong.gov.vn/tuyen-truyen-pho-bien-giao-duc-phap-luat/tuyen-truyen-phap-luat-ve-ttatgt-tai-truong-thpt-tran-van-kiet-7637.html. THPT Chợ Lách thành lập 7/2025 có công khai năm học 2026–2027 tại trang trường https://thptcholach.edu.vn/.
- **Phường An Hội, TP Bến Tre cũ:** Tiểu học Bến Tre + Tiểu học Phú Thọ gộp thành Tiểu học Bến Tre; Tiểu học Mỹ Thạnh An + Tiểu học Phú Nhuận + Tiểu học Sơn Phú gộp thành **Tiểu học An Hội**. Không nhân đôi trường cũ: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202608/phuong-an-hoi-trien-khai-de-an-sap-nhap-cac-truong-mam-non-tieu-hoc-tren-dia-ban-phuong-3222824/; Tiểu học Bến Tre hoạt động 20/11/2026: https://baovinhlong.com.vn/tin-moi/202611/truong-tieu-hoc-ben-tre-hop-mat-ky-niem-44-nam-ngay-nha-giao-viet-nam-07b559b/.
- **Xã Thạnh Phước, huyện Bình Đại cũ:** Tiểu học Nguyễn Thị Lang + Võ Văn Lân + Trà Thị Cụt thành Tiểu học Trà Thị Cụt; THCS Đỗ Hữu Phương + Võ Văn Lân thành THCS Võ Văn Lân. Không nhập trường tiền sáp nhập như đầu mối độc lập: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202609/thanh-phuoc-sap-xep-co-so-giao-duc-tren-dia-ban-xa-000323d/.
- Các trường THPT và liên cấp theo danh sách mã trường/địa chỉ năm 2026 của Trường Đại học FPT: https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/. Một số trường có địa chỉ xã mới hoặc tên pháp nhân chưa cập nhật sau sắp xếp, đã đánh dấu cần kiểm tra trong CSV.
- **Ba Tri cũ:** THPT Phan Thanh Giản hoạt động 28/8/2026 https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202608/phien-giao-dich-viec-lam-ket-noi-hon-300-hoc-sinh-sinh-vien-va-nguoi-lao-dong-voi-doanh-nghiep-b4e241e/; THCS Ba Tri khám sức khỏe 10/2026 https://baovinhlong.com.vn/xa-hoi/202610/tam-soat-tim-bam-sinh-mien-phi-cho-tre-em-84b2d20/; THCS Bảo Thạnh và Tiểu học Nguyễn Đình Chiểu có hoạt động 9/2026 https://baovinhlong.com.vn/xa-hoi/202609/kiem-tra-don-doc-tien-do-kham-sang-loc-suc-khoe-toan-dan-tai-xa-ba-tri-va-bao-thanh-1821b40/.
- **Bình Đại cũ:** THPT Lê Hoàng Chiếu có hoạt động 9/2026 https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202609/de-moi-hoat-dong-trai-nghiem-huong-nghiep-la-mot-bai-hoc-dc60576/, THPT Huỳnh Tấn Phát, Lê Quí Đôn, Thạnh Phước trong danh mục mã trường. Thạnh Phước là **xã thuộc Bình Đại cũ**, không được nhầm với **huyện Thạnh Phú cũ**.
- **Thạnh Phú cũ:** THCS Thạnh Phú hoạt động 9/2026 https://baovinhlong.com.vn/xa-hoi/202609/hoi-nghi-truyen-thong-phong-chong-toi-pham-nam-2026-d8d2cd6/, THCS Mỹ An hoạt động 10/2026 https://baovinhlong.com.vn/van-hoa-giai-tri/202610/tong-ket-trao-giai-cuoc-thi-dai-su-van-hoa-doc-va-sang-tac-video-ed47f56/; THPT Lê Hoài Đôn, Lương Thế Vinh, Đoàn Thị Điểm, Trần Trường Sinh có trong danh mục mã trường 2026.
- **Giồng Trôm cũ:** bốn THPT nguồn 2026, Tiểu học Thị trấn Giồng Trôm nguồn trước sáp nhập: https://baovinhlong.com.vn/thoi-su/202603/kiem-tra-cac-cong-viec-chuan-bi-to-chuc-bau-cu-tai-xa-giong-trom-20b301b/, chưa nhận là đầu mối hiện hành.
- **Mỏ Cày Nam cũ:** THPT Chê-Ghêvara, Quản Trọng Hoàng, Ca Văn Thỉnh, An Thới, Nguyễn Thị Minh Khai; THCS Tạ Minh Khâm là tên đổi từ THCS Mỏ Cày theo tin 2025 https://baovinhlong.com.vn/phong-su-ky-su/202512/vun-dap-truyen-thong-tu-nhung-pho-tuong-nghia-tinh-49b3ecf/. Không tạo tên THCS Mỏ Cày như trường thứ hai.
- **Mỏ Cày Bắc cũ:** Ngô Văn Cấn đã có trong Neon, bổ sung Lê Anh Xuân và Nhuận Phú Tân, tránh lẫn với Mỏ Cày Nam. **Châu Thành** chỉ lấy huyện Châu Thành Bến Tre cũ, không lẫn tỉnh Trà Vinh/Vĩnh Long cũ.
- **Trường Phổ thông Hermann Gmeiner Bến Tre** và **IGC Bến Tre** đều có **3 cấp học** theo chính website trường https://bentre.hgs.edu.vn/, https://igc.edu.vn/tuyen-sinh/thong-bao-tuyen-sinh/igc-school-chinh-thuc-nhan-ho-so-tuyen-sinh-hoc-ky-mua-xuan-2026-2027, không ghi sai chỉ THPT.

## Kỹ thuật và bước nghiệm thu tiếp
- CSV `data/schools_ben_tre_old_full_district_audit_2026_11_20.csv`.
- SQL `backend/migrations/089_ben_tre_old_full_district_schools_2026.sql`.
- Batch `2026-11-20-ben-tre-old-province-audit-01`. Idempotent `source_ref`, tránh trùng tên+địa bàn, không cập nhật trường cũ.
- Cần tiếp tục kiểm kê đầy đủ cấp 1/2 từng xã, phân hiệu/điểm trường, đánh dấu trường đã sáp nhập (alias/retired) sau xác minh, GPS cổng trường, kiểm tra API thật theo quyền tài khoản Sales. DB-only, không cần deploy lại frontend/Worker.
