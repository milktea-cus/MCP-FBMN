# Vĩnh Long cũ — audit 8/8 địa bàn (20/11/2026)

## Phạm vi và baseline
- Neon production trước lô: **8 trường / 4 địa bàn cũ**.
- Danh mục 8 huyện, thị xã, thành phố cũ từ `backend/src/districts_old.json`. Giữ `province_old='Vĩnh Long'`, tránh lẫn trường thuộc **Bến Tre cũ** và **Trà Vinh cũ** mặc dù nay cùng tỉnh Vĩnh Long.
- Đã rà cả **8/8 địa bàn** và xác định **42 bản ghi mới**, 0 bản ghi tên trùng Neon bỏ qua; dự kiến sau nhập **50 trường / 8/8 địa bàn có dữ liệu**.
- Các tên trường/địa chỉ THPT–liên cấp năm 2026 đối chiếu nguồn mã trường Đại học FPT: https://daihoc.fpt.edu.vn/tin-campus/tin-campus-can-tho/ma-truong-thpt/; đối chiếu nhóm địa bàn lịch sử và kết quả tuyển sinh 2025–2026: https://baovinhlong.com.vn/tin-moi/202504/tuyen-hon-9200-chi-tieuvao-lop-10-nam-hoc-2025-2026-c0001a1/.
- **12** trường có nguồn xác nhận hoạt động sau sáp nhập hoặc trong năm học 2026–2027; **30** trường chỉ có mã trường/nguồn trước hoàn tất sáp nhập 08/2026, phải đối chiếu quyết định sau sáp nhập trước khi coi là trường độc lập. Tình trạng từng dòng ghi trong `verification_note`.
- Không có GPS thực địa, không gán tọa độ hay nhãn đã xác minh. Link Google Maps là **tìm kiếm**, không phải đường dẫn đến đúng cổng.
- **8/8 có trường không phải kiểm kê đủ toàn bộ trường học**; thiếu rất nhiều trường tiểu học, THCS, phân hiệu/điểm trường tại các xã khác.

| Địa bàn cũ | Neon trước | Bổ sung | Sau nhập |
|---|---:|---:|---:|
| Thành phố Vĩnh Long | 2 | 5 | 7 |
| Huyện Long Hồ | 4 | 3 | 7 |
| Huyện Mang Thít | 0 | 4 | 4 |
| Huyện Vũng Liêm | 0 | 8 | 8 |
| Huyện Tam Bình | 1 | 7 | 8 |
| Thị xã Bình Minh | 1 | 6 | 7 |
| Huyện Trà Ôn | 0 | 5 | 5 |
| Huyện Bình Tân | 0 | 4 | 4 |
| **Tổng** | **8** | **42** | **50** |

## Đối soát thay đổi sau sáp nhập
- **THPT Trà Ôn** tiếp nhận **THPT Lê Thanh Mừng** từ 09/2026, theo bài ngày 15/11/2026: https://baovinhlong.com.vn/xa-hoi/202611/truong-thpt-tra-on-ky-niem-60-nam-thanh-lap-f2b22e2/. **Không nhập THPT Lê Thanh Mừng** dưới tư cách đầu mối độc lập.
- **THPT Vĩnh Xuân** tiếp nhận **THPT Hựu Thành** theo Quyết định ngày 28/8/2026, báo ngày 20/11/2026: https://baovinhlong.com.vn/thoi-su/202611/pho-bi-thu-tinh-uy-lam-minh-dang-du-hop-mat-ngay-nha-giao-viet-nam-tai-truong-thpt-vinh-xuan-9f05560/. **Không nhập THPT Hựu Thành** như trường mới.
- **Trường Tiểu học An Trường A** tiếp nhận Tiểu học B An Trường; THCS A An Trường còn được nêu sau quyết định sắp xếp 30/8: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202609/an-truong-sap-xep-on-dinh-truong-lop-huong-den-giao-duc-toan-dien-7a0353f/. Không nhập Tiểu học B An Trường như trường riêng.
- **THCS Chánh An (Mang Thít cũ)** hoạt động 9/2026: https://baovinhlong.com.vn/xa-hoi/202609/truong-ban-tuyen-giao-tinh-uy-nguyen-thi-minh-trang-vui-tet-trung-thu-voi-hoc-sinh-truong-thcs-chanh-an-c212405/; **THPT Phạm Hùng (Long Hồ cũ)** tiếp nhận lớp 10/2026: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202608/vinh-long-san-sang-cho-nam-hoc-moi-0bb1a1a/.
- **THPT Nguyễn Hiếu Tự và THPT Võ Văn Kiệt** cùng được công an xã Trung Thành tổ chức phổ biến tuyển sinh 04/2026: https://congan.vinhlong.gov.vn/tin-hoat-dong-cua-nganh/cong-an-xa-trung-thanh-phoi-hop-voi-cac-truong-thpt-tren-dia-ban-tuyen-truyen-tu-van-tuyen-sinh-nam-2026-2415.html; cần quyết định cuối tháng 8 nếu sau đó còn điều chỉnh đầu mối.
- **THCS Tam Bình, Tiểu học Lưu Văn Liệt, Tiểu học Mỹ Thạnh Trung** có công tác phối hợp trường tháng 10/2026: https://congan.vinhlong.gov.vn/phong-trao-bao-ve-an-ninh-trat-tu/cong-an-xa-tam-binh-ky-ket-phoi-hop-tuyen-truyen-pho-bien-giao-duc-phap-luat-7411.html.
- **THCS Thành Đông** hoạt động tại xã Tân Quới trong năm 2026: https://baovinhlong.com.vn/the-gioi-tre/202605/ky-niem-85-nam-ngay-thanh-lap-doi-tntp-ho-chi-minh-1551941-1552026-hoc-tap-ren-luyen-xung-dang-chau-ngoan-bac-ho-5f809ea/; xếp **huyện Bình Tân cũ**, tránh nhầm địa chỉ mới thuộc phường Đông Thành của TX Bình Minh cũ.
- **Tiểu học Thoại Ngọc Hầu** tại phường Bình Minh: https://baovinhlong.com.vn/xa-hoi/giao-duc-dao-tao/202512/lo-trinh-dua-tieng-anh-tro-thanh-ngon-ngu-thu-hai-6450ab3/. Tiểu học Phù Ly và Nguyễn Văn Trỗi nêu trong quyết định chính quyền 01/2026, cần xét đầu mối sau 08/2026: https://tuyencongchuc.com/van-ban/quyet-dinh-so-022026qd-ubnd-quy-dinh-ve-dia-ban-va-khoang-cach-lam-can-cu-xac-dinh-hoc-sinh-hoc-vien-khong-the-di-den-truong-va-tro-ve-nha-trong-ngay---186487/.
- Các trường THPT Trưng Vương, Nguyễn Thông, Vĩnh Long ở **TP Vĩnh Long cũ**, không nhầm THPT Phạm Hùng (huyện Long Hồ).
- Đối chiếu trường THPT, cấp 1/2 tại từng xã khác và quản lý `school_sites` để mỗi phân hiệu có tọa độ cổng, tránh sai nhu cầu tuyến Sales.

## Kỹ thuật
- CSV `data/schools_vinh_long_old_full_district_audit_2026_11_20.csv`
- SQL `backend/migrations/088_vinh_long_old_full_district_schools_2026.sql`
- Batch `2026-11-20-vinh-long-old-province-audit-01`. SQL add-only, kiểm tra trùng tên trong huyện và source_ref, an toàn chạy lại.
- Chưa nghiệm thu API theo phân quyền Sales và GPS cổng trường/thiết bị thực địa. DB-only migration nên không redeploy Worker/Vercel.
