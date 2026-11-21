# Audit bổ sung Cà Mau cũ + Hậu Giang cũ — 21/11/2026

## Phạm vi và kết quả dự kiến

- Baseline đã đọc trực tiếp Neon production: 775 trường / 130 trên 134 địa bàn cũ, 0 GPS xác thực.
- 21 trường có nguồn xác nhận, rà đúng bốn địa bàn cũ đang trắng, chi tiết:
  - Cà Mau / Huyện Năm Căn: 3 trường
  - Cà Mau / Huyện Phú Tân: 6 trường
  - Cà Mau / Huyện Ngọc Hiển: 5 trường
  - Hậu Giang / Thị xã Long Mỹ: 7 trường
- Dự kiến sau INSERT idempotent: 796 trường / 134/134 địa bàn có ít nhất một trường. **Không đồng nghĩa đủ trường phổ thông**; cần rà theo từng xã/điểm trường.
- Tham chiếu nguồn HTTPS theo từng dòng trong CSV; link Google Maps là URL **tìm kiếm**, không phải ghim cổng trường.

## Biến động sáp nhập 2026

- Năm Căn: tên Tiểu học Năm Căn, THCS Phan Ngọc Hiển là đầu mối được nguồn UBND xã công bố/hậu kiểm 2026. Không nhân đôi các Tiểu học 1/2 Năm Căn hoặc phân hiệu.
- Phú Tân: Tiểu học Phú Tân hợp nhất từ Kim Đồng / Phú Hiệp / Phú Tân; Tiểu học và THCS Mỹ Bình hợp nhất từ Tiểu học Tân Hải và trường liên cấp. Nguồn: https://phutan.camau.gov.vn/hoat-dong-lanh-dao-dieu-hanh/phu-tan-kien-toan-to-chuc-truong-hoc-san-sang-cho-nam-hoc-moi-141106
- Ngọc Hiển: nguồn tháng 8/2026 công bố Tiểu học xã Phan Ngọc Hiển và Tiểu học - THCS Viên An Đông; không nhập các trường thành phần. Nguồn: https://phanngochien.camau.gov.vn/chinh-tri-thoi-su/xa-phan-ngoc-hien-hoi-nghi-cong-bo-cac-quyet-dinh-sap-xep-co-so-giao-duc-tren-dia-ban-va-cong-ta-140479
- TX Long Mỹ: nguồn tháng 9/2026 dùng Tiểu học Long Mỹ và THCS Long Mỹ (có phân hiệu Long Trị A), và nguồn tháng 8/2026 xác nhận THCS & THPT Tân Phú, không giữ tên THPT Tân Phú cũ thành đầu mối thứ hai.
- Địa giới: mọi trường giữ `province_old` và `district_old` lịch sử; địa chỉ hiện hành ghi tỉnh Cà Mau mới hoặc TP Cần Thơ. Phường Long Phú 1, Long Bình, Long Mỹ thuộc thị xã Long Mỹ cũ theo Nghị quyết 1668/NQ-UBTVQH15: https://quochoi.vn/tintuc/Pages/tin-hoat-dong-cua-quoc-hoi.aspx?ItemID=94591

## Nghiệm thu và hạn chế

- Chạy file SQL `backend/migrations/090_ca_mau_hau_giang_old_school_gaps_2026.sql` trên Neon production, kiểm đếm theo `source_batch='2026-11-21-ca-mau-hau-giang-old-gap-audit-01'` và tổng địa bàn.
- Chống trùng bằng `source_ref` unique và chuẩn hóa tên trong **cùng tỉnh/huyện cũ**; không UPDATE/DELETE các bản ghi trước.
- Chưa xác minh GPS thực địa, phân hiệu, tư cách pháp nhân của *mọi* trường khác trên 134 địa bàn, và API theo tài khoản Sales. Dữ liệu đã thêm là trường đầu mối có nguồn; đây chưa phải tổng điều tra đầy đủ.
