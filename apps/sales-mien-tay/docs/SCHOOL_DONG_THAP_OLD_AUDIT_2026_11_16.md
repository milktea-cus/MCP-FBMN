# Đồng Tháp cũ — audit tất cả 12/12 địa bàn, ngày 16/11/2026

## Kết quả và giới hạn
- Đã kiểm tra Neon production (baseline **16 bản ghi, 3/12 địa bàn có trường**) và danh mục chuẩn `backend/src/districts_old.json`.
- Rà **12/12 huyện, thành phố cũ**, trong đó Tháp Mười đã có 12 trường từ lô 070 nên **không tự thêm tên trùng hoặc trường tiền-sáp-nhập**.
- Lô này thu thập và đối chiếu `44` trường/cơ sở phổ thông từ báo tỉnh, quyết định 8/2026, các cổng trường chính thức và tài liệu cơ quan nhà nước. Mỗi dòng CSV có URL nguồn, tên cấp học, huyện cũ và link Google Maps search.
- Nếu nhập thành công, số bản ghi Đồng Tháp cũ sẽ đạt `60`, hiện diện ở `12/12` huyện cũ. Đây **chỉ là độ phủ có ít nhất 1 bản ghi, không phải tỷ lệ đầy đủ trường**. Những nguồn chưa có danh mục toàn huyện hoặc cổng điểm trường phải tiếp tục điều tra.
- Không có GPS đã xác minh. Link Google Maps là link **tìm kiếm**, chưa bảo đảm dẫn đúng cổng trường.
- Mọi bản ghi trước đây còn nguyên; trong đó **Trường THPT Nguyễn Du (TP Sa Đéc) đã sáp nhập vào THPT Sa Đéc** từ năm học 2026-2027, cần lưu alias/retired trước khi ẩn khỏi tìm kiếm chính. Nguồn: https://baodongthap.vn/dong-thap-lanh-dao-tinh-du-le-khai-giang-nam-hoc-moi-tai-nhieu-truong-a245021.html.
- **Trường THCS Tân Thuận Đông (TP Cao Lãnh)** trong seed cũ đã được sáp nhập vào **Trường THCS Nguyễn Chí Thanh**; không được đếm như trường độc lập sau 8/2026. Nguồn: https://baodongthap.vn/cac-xa-phuong-cong-bo-cac-quyet-dinh-ve-sap-nhap-co-so-giao-duc-va-cong-tac-can-bo-a244380.html.
- Địa bàn Trường THPT Tháp Mười đã được nguồn khai giảng 5/9/2026 chứng thực: https://dongthap.gov.vn/web/cong-thong-tin-dtp/tin-tuc/chi-tiet?id=10751573
- Mọi địa chỉ ở mức xã/phường phải xác minh lại trước khi Sales định tuyến; riêng cơ sở đa điểm (THCS Cao Lãnh, THCS Tân Thành, THCS-THPT Tân Mỹ) cần xây dựng bảng `school_sites` riêng.

| Địa bàn cũ | Trước | Lô mới | Dự kiến sau |
|---|---:|---:|---:|
| Thành phố Cao Lãnh | 1 | 5 | 6 |
| Thành phố Sa Đéc | 3 | 4 | 7 |
| Thành phố Hồng Ngự | 0 | 8 | 8 |
| Huyện Tân Hồng | 0 | 2 | 2 |
| Huyện Hồng Ngự | 0 | 8 | 8 |
| Huyện Tam Nông | 0 | 2 | 2 |
| Huyện Tháp Mười | 12 | 0 | 12 |
| Huyện Cao Lãnh | 0 | 3 | 3 |
| Huyện Thanh Bình | 0 | 3 | 3 |
| Huyện Lấp Vò | 0 | 3 | 3 |
| Huyện Lai Vung | 0 | 3 | 3 |
| Huyện Châu Thành | 0 | 3 | 3 |
| **Tổng** | **16** | **44** | **60** |

## Nguồn tiêu biểu
- Phường Cao Lãnh và các xã vùng Hồng Ngự (quyết định sau sắp xếp tháng 8): https://baodongthap.vn/cac-xa-phuong-cong-bo-cac-quyet-dinh-ve-sap-nhap-co-so-giao-duc-va-cong-tac-can-bo-a244380.html
- Phường Sa Đéc (quyết định sắp xếp): https://www.baodongthap.vn/phuong-sa-dec-cong-bo-quyet-dinh-sap-xep-cac-co-so-giao-duc-a244300.html ; THPT Sa Đéc khai giảng: https://baodongthap.vn/dong-thap-lanh-dao-tinh-du-le-khai-giang-nam-hoc-moi-tai-nhieu-truong-a245021.html
- Phường Hồng Ngự, An Bình: https://baodongthap.vn/phuong-hong-ngu-va-an-binh-cong-bo-cac-quyet-dinh-ve-sap-nhap-co-so-giao-duc-a244335.html
- Huyện Tân Hồng cũ (hoạt động tháng 11): https://www.baodongthap.vn/xa-tan-hong-xe-thu-vien-luu-dong-anh-sang-tri-thuc-lan-toa-phong-trao-doc-sach-a246868.html ; trường THPT: https://thpttanhong.edu.vn/
- Huyện Tam Nông cũ: https://www.baodongthap.vn/xa-tam-nong-niem-vui-tu-khong-gian-hoc-tap-moi-a245632.html ; trường THPT: https://thpttamnongdongthap.edu.vn/tin-tuc/thong-bao
- Huyện Cao Lãnh cũ: https://edu.viettel.vn/page/home?site=101445 ; https://thcs-myhoi-dongthap.violet.vn/present/thong-bao-tuu-truong-nam-hoc-2026-2027-15137802.html ; https://www.caolanh1.edu.vn/
- Huyện Thanh Bình cũ: https://dulieuphapluat.vn/cong-cu/truong-tieu-hoc/dong-thap/thanh-binh-30130.html ; https://c23tanmy.dongthap.edu.vn/cong-khai/thong-tin-chung
- Huyện Lấp Vò cũ: https://dauthau.asia/procuring-entity/truong-tieu-hoc-lap-vo-223409/ ; https://thcsttlapvo.dongthap.edu.vn/ ; https://lapvo1.dongthap.edu.vn/
- Huyện Lai Vung cũ: https://www.baodongthap.vn/xa-lai-vung-chuan-bi-chu-dao-nam-hoc-moi-a245039.html ; https://www.baodongthap.vn/xa-lai-vung-kham-benh-tang-qua-cho-nguoi-dan-co-hoan-canh-kho-khan-a244849.html ; https://baodongthap.vn/hon-200-nguoi-tham-gia-phien-giao-dich-viec-lam-tai-lai-vung-a245521.html
- Huyện Châu Thành cũ: https://taisancong.vn/truong-tieu-hoc-phu-huu-tinh-dong-thap-thong-bao-tieu-chi-lua-chon-doi-tac-thuc-hien-lien-ket-to-chuc-giang-day-chuong-trinh-nha-truong-va-cung-cap-cac-dich-vu-cho-hoc-sinh-theo-chuc-nang-nhiem-vu-nam-hoc-2026-2027-54406.html ; https://dauthau.asia/project-owner/listlocation/X-Xa-Phu-Huu-moi-30244/ ; https://baodongthap.vn/tuoi-tre-dong-thap-nhieu-hoat-dong-tiep-suc-mua-thi-ho-tro-ky-thi-tuyen-sinh-lop-10-nam-hoc-2026--a241430.html
- CSV: `data/schools_dong_thap_old_full_district_audit_2026_11_16.csv`
- Migration: `backend/migrations/076_dong_thap_old_full_district_schools_2026.sql`
- Batch id: `2026-11-16-dong-thap-province-audit-01`. SQL INSERT idempotent, giữ nguyên dữ liệu cũ, không gán GPS.
- Do đã có 12 trường Tháp Mười trước lô, nhập tạm riêng tỉnh phải dùng `--province 'Đồng Tháp' --allow-partial`; không dùng kết quả đủ huyện *của riêng CSV* để suy diễn bao phủ toàn tỉnh. Bảng trên dựa trên hợp nhất Neon + CSV.
