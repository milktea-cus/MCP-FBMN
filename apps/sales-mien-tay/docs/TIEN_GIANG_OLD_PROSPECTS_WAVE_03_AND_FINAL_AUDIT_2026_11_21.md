# TIỀN GIANG CŨ — ĐỢT 3/3 VÀ ĐỐI CHIẾU TOÀN TỈNH (11/11 ĐỊA BÀN)

Ngày thực hiện & đọc lại DB: **21/11/2026**. Repo: `milktea-cus/MCP-FBMN`, branch `main`; Neon production: `raspy-bar-51596929`.

## 1. Phạm vi chia ba đợt theo huyện/TP/TX cũ

- **Đợt 1 (4 địa bàn):** TP Mỹ Tho, huyện Châu Thành, huyện Chợ Gạo, huyện Tân Phước — 39 điểm nghiên cứu.
- **Đợt 2 (4 địa bàn):** TP Gò Công, huyện Gò Công Đông, huyện Gò Công Tây, huyện Tân Phú Đông — 31 điểm nghiên cứu.
- **Đợt 3 (3 địa bàn):** **TX Cai Lậy, huyện Cai Lậy, huyện Cái Bè — 25 điểm nghiên cứu**.

Tỉnh Tiền Giang cũ hiện thuộc tỉnh Đồng Tháp mới, tuy nhiên bản ghi vẫn lưu `province='Tiền Giang'` và `district` tên đơn vị hành chính **cũ**. Nhầm lẫn phổ biến cần tránh: **TX Cai Lậy ≠ huyện Cai Lậy**. ĐT875 ấp 4 Phú An, Phú Nhuận, Mỹ Long, Ngũ Hiệp, khu phố Bình Ninh (TT Bình Phú cũ) thuộc **huyện Cai Lậy cũ**; Nhà sách FAHASA Co.opmart đường 30/4 và Nhà sách Khai Trí Nguyễn Văn Lo thuộc **TX Cai Lậy**.

## 2. Đợt 3 — Neon production readback

| Địa bàn cũ | Migration 117 | Bổ sung 118 | Tổng | Nhà sách | VPP/đầu mối | Có ĐT | Có MST |
|---|---:|---:|---:|---:|---:|---:|---:|
| TX Cai Lậy | 6 | 1 | **7** | 4 | 3 | 4 | 1 |
| Huyện Cai Lậy | 5 | 0 | **5** | 1 | 4 | 5 | 0 |
| Huyện Cái Bè | 13 | 0 | **13** | 5 | 8 | 9 | 2 |
| **Tổng đợt 3** | **24** | **1** | **25** | **10** | **15** | **18** | **3** |

Các file ghi trực tiếp Neon production, migration idempotent:
- `apps/sales-mien-tay/backend/migrations/117_tien_giang_old_wave03_cai_lay_cai_be_prospects_2026.sql`; commit `94640594f6101507c4d8dd47900f4617a98733f7`.
- `apps/sales-mien-tay/backend/migrations/118_tien_giang_old_wave03_cai_lay_supplement_2026.sql`; commit `4f9ac135d3cc631c092a8c72fccc26295f1c18b9`.

**25/25** bản ghi đợt 3 có HTTPS source URL; đều `status='new'`, chưa có `last_visit_at`, chưa có tọa độ GPS xác minh. Không đánh dấu bất kỳ cửa hàng nào đã được Sales ghé/bán hàng; không chuyển thành `customers`, không sửa ảnh/tuyến cũ.

## 3. Lũy kế Tiền Giang cũ sau ba đợt — 11/11 địa bàn có dữ liệu

| Địa bàn cũ | Điểm |
|---|---:|
| TP Mỹ Tho | 16 |
| Châu Thành | 5 |
| Chợ Gạo | 13 |
| Tân Phước | 5 |
| TP Gò Công | 12 |
| Gò Công Đông | 8 |
| Gò Công Tây | 8 |
| Tân Phú Đông | 3 |
| TX Cai Lậy | 7 |
| Huyện Cai Lậy | 5 |
| Huyện Cái Bè | 13 |
| **TỔNG** | **95** |

- **39** đợt 1 + **31** đợt 2 + **25** đợt 3 = **95 nguồn điểm bán tiềm năng** trên **11/11 huyện/TP/TX cũ**.
- Theo nhóm hiện lưu: **37 nhà sách** / **58 VPP & đầu mối có ngành hàng liên quan**.
- **70/95** có số điện thoại; **11/95** có MST; **95/95** có URL nguồn.
- **95/95** vẫn `status='new'`, `last_visit_at IS NULL`, chưa xác minh thực địa, không chuyển sang khách chính.

## 4. Các địa chỉ/nguồn chính đã nhập đợt 3

### TX Cai Lậy

- FAHASA Cai Lậy — lầu 1 Co.opmart Cai Lậy, 79 đường 30/4, khu phố 2 (website chính thức `https://fahasasg.com.vn/bookstore/nha-sach-fahasa-cai-lay/`); không tính quầy tầng 2 theo danh bạ cũ thành một điểm khác.
- Nhà sách Khai Trí — 02 Nguyễn Văn Lo, Place ID `ChIJOVm0tLyXCjERgujmGiMOeds`.
- Nhà sách TBTH Hùng Vương — 2–4–6–8 Đặng Văn Thạnh theo chương trình Thiên Long **2019**; cần gọi xác minh biển hiệu và hoạt động hiện tại.
- Bí Bo — photocopy/VPP đường Mỹ Trang, khu phố 1, Place ID `ChIJPXsQwL2XCjERh_XNLgZJnmY`.
- VPP Hải Nghi — số 6 Ông Hiệu, Place ID `ChIJaQmJeqKXCjERCA6ZjmH3ids`.
- Đầu mối sách TiTan Tiền Giang — ĐT868, khu phố 5 theo danh sách Minh Long `https://www.minhlongbook.com.vn/pages/he-thong-phan-phoi`; **không đủ bằng chứng đang bán tại quầy**.
- Cơ sở in & VPP Tấn Đạt — tổ 28 đường Mai Thị Út, khu phố 1 theo danh bạ có địa chỉ `https://www.tratencongty.com/tinh-tien-giang/?page=238`; chưa xác minh quầy bán lẻ.

### Huyện Cai Lậy cũ

- Nhà sách Lam Phương (cũng được nhà cung cấp Hồng Hà ghi là **VPP Lam Phương**) — ấp 4, xã Phú An cũ. Bản đồ có phone **0984211211**, Hồng Hà ghi **0901539539**. **Chỉ tạo một điểm** để tránh trùng hai tên bán sách/VPP ở cùng ấp; cần gọi để xác nhận là một cơ sở.
- VPP Ngọc Lan — ấp Chà Là, xã Phú Nhuận cũ, **0988638663**.
- VPP Phát Giàu — ấp Hòa Hảo, xã Ngũ Hiệp cũ, **0394489637**.
- VPP/quà lưu niệm Cô Hạnh — khu vực xã Mỹ Long cũ (hiện xã Long Tiên), **02733711709**.
- VPP Lê — khu phố Bình Ninh, thị trấn Bình Phú cũ, **0889843938**.
- Ba địa chỉ Lam Phương, Ngọc Lan, Phát Giàu xuất phát từ danh sách điểm bán Hồng Hà `https://vpphongha.com.vn/vi/gaga`.

### Huyện Cái Bè cũ

- FAHASA Cái Bè — TTTM Sense Market, gian A2.04 khu 2, thị trấn Cái Bè cũ; nguồn chính thức `https://fahasasg.com.vn/bookstore/nha-sach-fahasa-cai-be/`.
- Nhà sách Cái Bè tại 477 ĐT875 khu 4, điện thoại **0932222642**, MST **1201622154**; Hồng Hà liệt kê cùng điểm. Không nhập hai bản ghi vì tên Công ty TMDV Nhà sách Cái Bè và Nhà sách Cái Bè là một địa chỉ.
- Nhà sách Anh Trung — 193 Thiên Hộ Dương, **0797993898**; Nhà sách Lê Anh — 164 Trưng Nữ Vương **0941808235**.
- VPP Ngọc Lợi — 184 Trưng Nữ Vương, **0938384189**; VPP Liên Kiệt — 336 Thiên Hộ Dương, **02733823711**; VPP Hải Đăng — 14 Trưng Nữ Vương, **0813450687**.
- Nhà sách Nga — ĐH71, có Plus Code nhưng chưa số nhà, cần xác minh xã cũ.
- VPP/photocopy tại ấp Mỹ Quới thuộc Mỹ Đức Đông cũ; VPP Kim Dung và Thúy Hiền dọc QL1A khu vực Mỹ Đức Tây; cần xác minh cửa hàng độc lập vì các Plus Code gần nhau.
- Hộ kinh doanh Nhà sách/VPP P.Cái Bè — ấp 3, nguồn nhà thầu 2026 (không đủ bằng chứng bán lẻ tại quầy).
- Công ty Tâm Bảo Tín — ấp 1, xã An Hữu cũ, đăng ký dịch vụ photocopy và ngành bán lẻ sách/VPP, chưa chứng minh đang có quầy bán học phẩm.

### Không nhập trùng khách chính

Trong `public.customers` đã có **NS Lam Phượng** (TT Cái Bè) và **Thành Trang** (Đông Hiệp, Cái Bè). Không thêm hai khách này dưới dạng prospect mới. **Nhà sách Lam Phương** ở xã Phú An **huyện Cai Lậy cũ** không phải mặc định cùng cửa hàng với khách **Lam Phượng** ở Cái Bè; địa bàn khác, nguồn khác.

## 5. Nghiệm thu và cảnh báo

Đã chạy đọc lại bảng production sau migration 117/118:
- Đúng **95 điểm / 11/11 địa bàn**.
- **0** trùng `research_source_key`.
- **0** trùng chính xác `district + lower(trim(name)) + lower(trim(address_line))`.
- **0** trùng chính xác tên khách hàng chính trong cùng huyện.
- **0** số điện thoại trùng trong cùng địa bàn (theo phone đang có).
- Chạy lại SQL migration 117 và 118: **0 bản ghi mới**.
- GitHub combined statuses cho commit cuối trả `statuses=[]`, **chưa có bằng chứng CI xanh**.
- Chưa nghiệm thu API/Auth theo Sales/Manager, offline PWA/Android hoặc kiểm thử thực địa / GPS, nên **không báo app đã hoàn thành chức năng chỉ dựa vào DB**.

**9/9, 11/11 địa bàn có dữ liệu không đồng nghĩa 100% cửa hàng ngoài đời.** Đặc biệt còn khoảng trống ở **huyện Cai Lậy (5 điểm)**, **Tân Phú Đông (3)**, **Tân Phước (5)**, và nhiều xã xa trung tâm huyện Cái Bè (13 phần lớn nằm thị trấn). Cần Sales xác minh những điểm chưa đủ số nhà, có bán sỉ, hồ sơ thuế/nhà thầu hoặc đã lâu chưa cập nhật; rà các chợ, trường TH/THCS/THPT, tuyến dân cư, cửa hàng tạp hóa có bán VPP.

## SQL đọc lại

```sql
SELECT district,COUNT(*) AS total,
 COUNT(*) FILTER(WHERE category='nha_sach') AS bookstores,
 COUNT(*) FILTER(WHERE category='van_phong_pham') AS stationery,
 COUNT(*) FILTER(WHERE phone IS NOT NULL) AS phones,
 COUNT(*) FILTER(WHERE tax_code IS NOT NULL) AS taxes,
 COUNT(*) FILTER(WHERE research_source_url LIKE 'https://%') AS sourced,
 COUNT(*) FILTER(WHERE last_visit_at IS NOT NULL) AS visited
FROM public.field_prospects
WHERE province='Tiền Giang'
GROUP BY district ORDER BY district;
```
