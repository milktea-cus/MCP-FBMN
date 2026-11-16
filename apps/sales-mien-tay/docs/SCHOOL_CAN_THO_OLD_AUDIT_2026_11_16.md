# Cần Thơ cũ — audit tất cả 9/9 quận/huyện (16/11/2026)

## Phạm vi và cách kiểm chứng

- Neon trước đợt: **13 bản ghi tại 3/9 địa bàn cũ**; dữ liệu seed cũ chưa xác minh độc lập.
- Đã rà toàn bộ **9/9 quận/huyện cũ** theo `backend/src/districts_old.json`.
- Trường mầm non và GDTX không trong phạm vi cấp 1–2–3, không nhập.
- **40 bản ghi mới** từ quyết định sáp nhập tháng 8/2026, danh sách trực thuộc Sở GDĐT QĐ 5022 ngày 29/9/2026, tin khai giảng 2026 và trang trường đang hoạt động. **0 trường trùng Neon** được bỏ qua.
- Dự kiến sau nhập: **53 bản ghi tại 9/9 địa bàn cũ**; đây chỉ là hiện diện tối thiểu, **KHÔNG đồng nghĩa đã kiểm kê đủ trường**, đặc biệt mạng lưới phân hiệu/điểm trường.
- Tên hiện hành sau 1/9/2026 và địa chỉ hành chính mới nằm ở `name,address_text`; quận/huyện theo địa giới Cần Thơ cũ nằm ở `district_old`, tránh nhầm với Cần Thơ mới bao gồm Sóc Trăng và Hậu Giang.
- **GPS verified = false** cho toàn bộ đợt này. Không tạo lat/lng. Link Maps luôn là tìm kiếm, không bảo đảm dẫn đến cổng chính.

| Địa bàn lịch sử | Neon trước | Thêm | Dự kiến |
|---|---:|---:|---:|
| Quận Ninh Kiều | 0 | 12 | 12 |
| Quận Ô Môn | 0 | 5 | 5 |
| Quận Bình Thủy | 0 | 4 | 4 |
| Quận Cái Răng | 0 | 4 | 4 |
| Quận Thốt Nốt | 0 | 3 | 3 |
| Huyện Vĩnh Thạnh | 10 | 2 | 12 |
| Huyện Cờ Đỏ | 2 | 2 | 4 |
| Huyện Phong Điền | 1 | 4 | 5 |
| Huyện Thới Lai | 0 | 4 | 4 |
| **Tổng** | **13** | **40** | **53** |

## Nguồn và lưu ý sáp nhập

- Thành phố vận hành trường mới từ 1/9/2026, mỗi xã/phường ưu tiên 1 trường mỗi cấp: https://pbgdpl.cantho.gov.vn/can-tho-sap-xep-1156-co-so-giao-duc-con-406-co-so-giam-6488; https://xaydungchinhsach.chinhphu.vn/sap-xep-giam-6488-co-so-giao-duc-1080-hieu-truong-hieu-pho-duoc-bo-tri-cong-viec-khac-119260808211238586.htm
- Ninh Kiều: Tiểu học Ninh Kiều (gộp 9), THCS Ninh Kiều (gộp 6); Cái Khế và Tân An cũng tổ chức lại: https://www.vietnam.vn/cong-bo-sap-nhap-cac-co-so-giao-duc-cong-lap-va-quyet-dinh-ve-cong-tac-can-bo, https://tuoitre.vn/mot-phuong-o-can-tho-tu-12-truong-hoc-sap-nhap-con-3-truong-100260819193859582.htm. **Không nhập các trường tiểu học/THCS tiền sáp nhập thành đầu mối riêng.**
- Bình Thủy: Tiểu học Bình Thủy gộp 4 trường: https://dangcongsan.org.vn/cantho/tin-tuc-hoat-dong/pho-chu-tich-hdnd-thanh-pho-tran-quoc-vu-du-le-khai-giang-nam-hoc-2026-2027-tai-truong-tieu-hoc-binh-thuy-.html. THCS Bình Thủy có MST từ 27/8/2026: https://masothue.com/1801838557-truong-thcs-binh-thuy; không nhầm với THCS Bình Thủy tại An Giang mới.
- Cái Răng: Trường Tiểu học Cái Răng và THCS Cái Răng hiện hành: https://congan.cantho.gov.vn/hoat-dong-cong-an-co-so/cong-an-phuong-cai-rang-trao-tang-2-000-quyen-tap-tiep-suc-cac-em-hoc-sinh-den-truong-10560.html; THPT Trần Đại Nghĩa: https://baocantho.com.vn/truong-ban-tuyen-giao-thanh-uy-nguyen-ngoc-tam-du-le-khai-giang-nam-hoc-moi-tai-truong-thpt-tran-dai-a214457.html; THPT chuyên Lý Tự Trọng tại phường Cái Răng, **không thuộc Ninh Kiều cũ**: https://ltt.nhpoj.net/ts2026/index.html.
- Ô Môn và Thốt Nốt: trường thuộc Sở có quyết định hiện hành https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Quyet-dinh-5022-QD-UBND-2026-chuc-nang-nhiem-vu-quyen-han-co-cau-to-chuc-So-Giao-duc-va-Dao-tao-Can-Tho-727189.aspx?tab=3; đối chiếu địa chỉ qua https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/. THCS và THPT Tân Lộc có nhiều điểm trường, không coi điểm lẻ là trường riêng: https://baocantho.com.vn/-e-nghi-chia-tach-truong-cap-2-va-3-theo-cap-hoc-a186056.html.
- Cờ Đỏ cũ: THPT Hà Huy Giáp được xác nhận trên tin hoạt động 9/2026: https://congan.cantho.gov.vn/hoat-dong-cua-cong-an-thanh-pho/cong-an-xa-co-do-phoi-hop-tuyen-truyen-phap-luat-ve-trat-tu-an-toan-giao-thong-va-huong-dan-ky-nang-lai-xe-gan-may-an-toan-cho-hoc-sinh-10440.html; THPT Trung An có trong QĐ 5022, địa giới lịch sử **Huyện Cờ Đỏ** (không chuyển sang Thốt Nốt chỉ vì tên xã Trung An): https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Quyet-dinh-5022-QD-UBND-2026-chuc-nang-nhiem-vu-quyen-han-co-cau-to-chuc-So-Giao-duc-va-Dao-tao-Can-Tho-727189.aspx?tab=3, https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/. **Dữ liệu seed có 'Trường THCS và THPT Trần Ngọc Hoàng'**, QĐ 5022 ghi '**Trần Ngọc Hoằng**' (khác tên); cần đối soát alias, chưa thêm trùng.
- Vĩnh Thạnh cũ: THPT Vĩnh Thạnh https://congan.cantho.gov.vn/hoat-dong-cong-an-co-so/cong-an-xa-vinh-thanh-ra-mat-mo-hinh-cong-truong-an-toan-giao-thong-tai-truong-trung-hoc-pho-thong-vinh-thanh-10406.html, THPT Thạnh An https://baocantho.com.vn/pho-bi-thu-thanh-uy-tran-van-huyen-du-le-khai-giang-nam-hoc-moi-tai-truong-thpt-thanh-an-a214436.html; danh sách tiểu học cũ Vĩnh Thạnh chưa xác minh sau sáp nhập nên không thêm bản ghi suy đoán.
- Phong Điền: Trường TH Phong Điền hoạt động 11/2026 https://edu.viettel.vn/page/home?site=57684; THCS Phong Điền, THPT Phan Văn Trị và Giai Xuân xác minh qua https://congan.cantho.gov.vn/hoat-dong-cong-an-co-so/cong-an-xa-phong-dien-lan-toa-dieu-tot-dep-chung-tay-xay-dung-moi-truong-an-toan-xa-hoi-van-minh-12028.html, https://congan.cantho.gov.vn/hoat-dong-cua-luc-luong-cong-an/cong-an-xa-phong-dien-bao-dam-an-ninh-an-toan-ky-thi-tuyen-sinh-trung-hoc-pho-thong-nam-hoc-2026-2027-8656.html.
- Thới Lai: trường TH và THCS đang được chính quyền hỗ trợ tháng 10/2026: https://beta.baocantho.com.vn/cung-co-niem-tin-cua-nhan-dan-a213884.html; THPT Thới Lai https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Quyet-dinh-5022-QD-UBND-2026-chuc-nang-nhiem-vu-quyen-han-co-cau-to-chuc-So-Giao-duc-va-Dao-tao-Can-Tho-727189.aspx?tab=3; THCS và THPT Trường Xuân https://congan.cantho.gov.vn/hoat-dong-cua-luc-luong-cong-an/cong-an-xa-truong-xuan-dam-bao-an-ninh-an-toan-ky-thi-tot-nghiep-thpt-nam-2026-8218.html.
- Cần rà tiếp tất cả xã/phường khác trong từng huyện cũ, các điểm trường, phân hiệu, trường tư và GPS thực địa. Hệ thống thiếu mô hình `school_sites` cho mỗi điểm sau sáp nhập.

## Kỹ thuật

- CSV: `data/schools_can_tho_old_full_district_audit_2026_11_16.csv`.
- Migration: `backend/migrations/077_can_tho_old_full_district_schools_2026.sql`.
- Source batch: `2026-11-16-can-tho-old-province-audit-01`. `source_ref` ổn định; nhập add-only; chạy lặp không tạo thêm bản ghi.
