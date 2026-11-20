# Sóc Trăng cũ — audit đủ 11 địa bàn (20/11/2026)

## Baseline và phạm vi
- Neon production trước nhập: **10 trường ở 4/11 địa bàn cũ**. Địa giới cố định tại `backend/src/districts_old.json`.
- Đã rà tất cả **11/11 địa bàn** và thu thập **48 bản ghi mới có nguồn năm 2026**, loại 0 trùng theo tên cùng địa bàn.
- Dự kiến sau nhập: **58 bản ghi tại 11/11 địa bàn** (chỉ là hiện diện ít nhất một trường; KHÔNG phải tổng điều tra đầy đủ các trường, phân hiệu hoặc điểm trường).
- Tên trường THPT và liên cấp được đối chiếu danh mục tên+địa chỉ 2026 của Đại học FPT: https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/, danh sách 59 trường thi tuyển lớp 10 năm học 2026-2027 theo công bố ngành GD thành phố: https://thanhphosoctrang.edu.vn/upload/thanhphosoctrang/files/68/NH2526/Tuyensinh/pheduyetphuongants/Phu_luc_1_thi_tuyen__1_.pdf.
- Mục tiểu học/THCS được chọn từ tin khai giảng, hoạt động học kỳ I 2026-2027 và cơ sở dữ liệu 2026; **2 trường liên cấp từ dữ liệu đăng ký 2026 vẫn cần đối chiếu quyết định sau sáp nhập**.
- **Tỉnh mới Cần Thơ không làm thay đổi khóa địa giới `province_old='Sóc Trăng'`**. Đặc biệt, **Trường THPT Sóc Trăng** (địa chỉ nay thuộc phường Mỹ Xuyên) vốn ở **TP Sóc Trăng cũ**, không được xếp nhầm vào huyện Mỹ Xuyên cũ.
- Không có GPS thực địa được xác minh; toàn bộ maps URL là **Google Maps SEARCH**, không phải ghim/trục đường đến cổng trường.

| Địa bàn lịch sử | Neon trước | Thêm | Tổng dự kiến |
|---|---:|---:|---:|
| Thành phố Sóc Trăng | 0 | 8 | 8 |
| Huyện Châu Thành | 0 | 4 | 4 |
| Huyện Kế Sách | 0 | 5 | 5 |
| Huyện Mỹ Tú | 1 | 5 | 6 |
| Huyện Cù Lao Dung | 1 | 1 | 2 |
| Huyện Long Phú | 0 | 5 | 5 |
| Huyện Mỹ Xuyên | 0 | 5 | 5 |
| Thị xã Ngã Năm | 0 | 4 | 4 |
| Huyện Thạnh Trị | 0 | 3 | 3 |
| Thị xã Vĩnh Châu | 1 | 6 | 7 |
| Huyện Trần Đề | 7 | 2 | 9 |
| **Tổng** | **10** | **48** | **58** |

## Đối soát sáp nhập, trường trùng / tên cũ
- Phường Sóc Trăng: Trường Tiểu học Sóc Trăng sau sáp nhập có **1 điểm chính và 5 phân hiệu**; Trường THCS Sóc Trăng là đầu mối hiện hành: https://baocantho.com.vn/pho-bi-thu-thanh-uy-ho-thi-cam-dao-kiem-tra-cong-tac-chuan-bi-nam-hoc-moi-a214360.html. Không lấy các trường tiểu học trước sáp nhập làm trường độc lập.
- **THPT An Thạnh 3** ở huyện Cù Lao Dung cũ đã có trong Neon 2025; danh sách 2026 ghi **THCS và THPT An Thạnh 3**: không tự nhân đôi cùng trường thành hai bản ghi. Cần alias và điều chỉnh tên/cấp theo quyết định sau sáp nhập.
- **THPT Mỹ Hương** ở huyện Mỹ Tú đã có trong Neon 2025; danh mục 2026 nêu **THCS và THPT Mỹ Hương**, cũng chưa nhân đôi. Cần reconcile.
- Trường **Tiểu học và THCS Lai Hòa** hiện có trong Neon có bậc 1+2, khác **THCS và THPT Lai Hòa** (bậc 2+3); cần kiểm tra quan hệ pháp nhân/cơ sở với nguồn địa phương trước khi coi đây là hai điểm bán độc lập.
- Có các mục 2026 chỉ xác định địa chỉ tại xã/phường, không gán tọa độ phỏng đoán.
- Các trường mầm non, GDTX, cơ sở nghề, trường trên địa bàn Sóc Trăng cũ nhưng được sáp nhập tên hành chính với Hậu Giang cũ đều không tự nhập.
- Bản ghi seed cũ vẫn giữ nguyên cho truy vết, có thể là alias lịch sử sau sáp nhập.
- Cần kiểm kê trường tiểu học, THCS ở từng xã ngoài những mẫu được xác nhận, cùng các phân hiệu; một đầu mối không có nghĩa một điểm trường.

## Nguồn tiêu biểu
- Trường Tiểu học/THCS Sóc Trăng 2026: https://baocantho.com.vn/pho-bi-thu-thanh-uy-ho-thi-cam-dao-kiem-tra-cong-tac-chuan-bi-nam-hoc-moi-a214360.html
- Trường THCS Kế Sách 2026: https://baocantho.com.vn/trao-100-suat-hoc-bong-va-430-phan-qua-ho-tro-hoc-sinh-hoan-canh-kho-khan-a214522.html
- Trường Tiểu học Mỹ Tú (phân hiệu 2) 2026: https://baocantho.com.vn/trao-tang-9-can-nha-dai-doan-ket-nhan-ngay-hoi-dai-doan-ket-toan-dan-toc-a220601.html
- Địa bàn Long Phú cũ, Tiểu học thị trấn Long Phú B: https://beta.baocantho.com.vn/giup-hoc-sinh-hinh-thanh-thoi-quen-tuan-thu-phap-luat-giao-thong-a217826.html
- THCS Vĩnh Lợi (huyện Thạnh Trị cũ): https://beta.baocantho.com.vn/giup-hoc-sinh-hinh-thanh-thoi-quen-tuan-thu-phap-luat-giao-thong-a217826.html
- Tiểu học Vĩnh Châu (phân hiệu 3): https://baocantho.com.vn/nhieu-hoat-dong-tiep-suc-den-truong--a215325.html
- Hệ thống trường THPT năm 2026: https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/ và https://thanhphosoctrang.edu.vn/upload/thanhphosoctrang/files/68/NH2526/Tuyensinh/pheduyetphuongants/Phu_luc_1_thi_tuyen__1_.pdf
- Đối chiếu trường tiểu học/THCS lịch sử 11 địa bàn cũ (không khẳng định hoạt động độc lập sau sáp nhập): https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Quyet-dinh-1182-QD-UBND-2025-danh-gia-su-hai-long-doi-voi-chat-luong-dich-vu-giao-duc-cong-Soc-Trang-658266.aspx

## Kỹ thuật
- CSV `data/schools_soc_trang_old_full_district_audit_2026_11_20.csv`
- Migration `backend/migrations/086_soc_trang_old_full_district_schools_2026.sql`
- Batch `2026-11-20-soc-trang-old-province-audit-01`; `source_ref` ổn định; add-only, bỏ trùng tên/huyện, không cập nhật trường cũ, không gán GPS.
- Chưa kiểm thử route API bằng tài khoản Sales và thiết bị Android thật. Chỉ DB source ingest, không thay đổi ứng dụng nên không cần deploy Worker/Vercel lần này.
