# MCP-FBMN — KIỂM KÊ 13 TỈNH CŨ: KẾT THÚC VÒNG 1, BẮT ĐẦU VÒNG 2
Ngày: **21/11/2026**. Repository `milktea-cus/MCP-FBMN` branch `main`; Neon production project `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`.

## Cập nhật Neon production sau migration 150 — 21/11/2026

> **Snapshot hiện hành**, đã đối soát trực tiếp trên project Neon production `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`. Các bảng phía dưới được giữ lại dưới dạng **snapshot lịch sử trước migration 150** để tránh mất dấu vết kiểm kê.

| Chỉ tiêu | Hiện tại |
|---|---:|
| Lead nghiên cứu `field_prospects` | **675** |
| Địa bàn cũ có lead | **130/134** |
| URL nguồn HTTPS / research source key | **675/675 · 675/675** |
| Lead trạng thái new, chưa ghé | **675/675** |
| Lead liên kết lượt ghé | **0** |
| Nhà sách / VPP-đầu mối | **380 / 295** |
| Lead có số điện thoại | **487** |
| Địa bàn đã có lead nhưng chỉ 1–2 | **46** |

- Migration: `backend/migrations/150_old_provinces_round02_p0_gaps_2026.sql`, commit [`14eeecc`](https://github.com/milktea-cus/MCP-FBMN/commit/14eeecc0f8d17cfc4c27f2e6bb8b49dbae162420), đã có **7 lead** trên Neon: Giang Thành 2, Cù Lao Dung 2, Vị Thủy 2, Đông Hải 1. Tất cả là **nghiên cứu trực tuyến, chưa xác minh tại cửa hàng**.
- **4/134 địa bàn cũ chưa có lead:** Kiên Giang / Huyện Kiên Hải; Hậu Giang / Huyện Long Mỹ (khác **Thị xã Long Mỹ**); Sóc Trăng / Huyện Trần Đề; Bạc Liêu / Huyện Vĩnh Lợi.
- CI: không tìm thấy workflow run hoặc commit status ghi nhận cho commit `14eeecc`; **không được diễn giải là CI xanh**. Chưa nghiệm thu API, phân quyền và app thiết bị thực tế chỉ từ việc import SQL.
- Đối soát vòng này không thấy trùng `research_source_key`, hoặc trùng tên/số điện thoại với khách chính **trong 7 lead của migration 150** theo bộ kiểm SQL; kiểm trùng mờ và việc cửa hàng thực sự hoạt động vẫn cần Sales xác minh.
- Nguồn tìm kiếm thêm ngày 21/11: tên “tạp hóa – văn phòng phẩm Phú Lên” xuất hiện khi tìm Trần Đề nhưng địa chỉ nguồn ghi **ấp Phú Giao, Mỹ Xuyên**, không gán sai Trần Đề (https://giatot24gio.com/tiem-tap-hoa-soc-trang/). “Nhà Sách Long Mỹ” có địa chỉ theo hồ sơ thị trấn Long Mỹ cũ, chưa đủ chắc để gán **Huyện Long Mỹ** thay vì **Thị xã Long Mỹ**, không nhập.
- Chưa có lead mới được nhập từ lượt rà bù bổ sung này. **Không tạo dữ liệu giả để đạt 134/134.**

### 46 địa bàn có 1–2 lead (snapshot hiện hành)

| Tỉnh cũ | Địa bàn (số lead) |
|---|---|
| An Giang | Huyện An Phú (2); Huyện Châu Phú (2); Huyện Châu Thành (1); Huyện Chợ Mới (2); Huyện Thoại Sơn (2); Huyện Tri Tôn (2); Thị xã Tịnh Biên (1) |
| Bạc Liêu | Huyện Hòa Bình (2); Huyện Phước Long (2); Huyện Đông Hải (1) |
| Cà Mau | Huyện Ngọc Hiển (2); Huyện Năm Căn (2); Huyện Thới Bình (2); Huyện Trần Văn Thời (2) |
| Cần Thơ | Huyện Cờ Đỏ (1); Huyện Phong Điền (1); Huyện Thới Lai (1); Huyện Vĩnh Thạnh (2); Quận Bình Thủy (2); Quận Thốt Nốt (2); Quận Ô Môn (2) |
| Hậu Giang | Huyện Châu Thành (1); Huyện Châu Thành A (1); Huyện Phụng Hiệp (1); Huyện Vị Thủy (2); Thị xã Long Mỹ (2) |
| Kiên Giang | Huyện An Minh (2); Huyện Châu Thành (1); Huyện Giang Thành (2); Huyện Giồng Riềng (2); Huyện Gò Quao (1); Huyện Kiên Lương (2); Huyện U Minh Thượng (2); Huyện Vĩnh Thuận (1); Thành phố Hà Tiên (1) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Cù Lao Dung (2); Huyện Mỹ Tú (1); Huyện Mỹ Xuyên (2); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Cao Lãnh (1); Huyện Châu Thành (2); Huyện Hồng Ngự (1); Huyện Tam Nông (1) |

## Nguyên tắc cố định
- Đã đi **đủ 13/13 tỉnh cũ**, ba đợt theo địa bàn trên mỗi tỉnh. **Không** có nghĩa tìm đủ mọi cửa hàng ngoài đời.
- Key `province`/`district` **theo địa giới tỉnh, quận/huyện/thị xã/thành phố CŨ** trong `backend/src/districts_old.json`; tuyệt đối không nhập nhầm theo tỉnh mới sau 2025.
- `field_prospects` là **lead nghiên cứu trực tuyến** chờ Sales kiểm chứng; không được báo là khách hàng, điểm đã ghé hoặc cửa hàng đã hoạt động 2026.
- Nguồn công khai bao gồm cửa hàng trên Maps, danh bạ, danh sách nhà phân phối, cơ sở chỉ có đăng ký ngành nghề hoặc bán sỉ. **URL HTTPS không đồng nghĩa nguồn đã được xác minh hoặc cửa hàng có thật/đang mở**. Riêng doanh nghiệp chỉ có mã ngành phải ưu tiên gọi trước khi ghé.
- Mỗi migration insert-only, có source key và chặn trùng exact với khách/lead. Không sửa `customers`, không gán GPS, không tạo visit, không gắn `is_selling`.
- Chỉ sau khi kết thúc vòng nhập đủ 13 tỉnh, mới bắt đầu vòng rà bù; các migration 146–149 là **vòng 2**, không thuộc vòng 1.

## Đối chiếu Neon production toàn bộ (snapshot lịch sử trước migration 150)

| Tỉnh cũ | Lead | Huyện/đô thị có lead | Nhà sách | VPP/đầu mối | Điện thoại |
|---|---:|---:|---:|---:|---:|
| Long An | 95 | 15/15 | 59 | 36 | 65 |
| Tiền Giang | 95 | 11/11 | 37 | 58 | 70 |
| Bến Tre | 77 | 9/9 | 41 | 36 | 54 |
| Trà Vinh | 79 | 9/9 | 21 | 58 | 43 |
| Vĩnh Long | 76 | 8/8 | 33 | 43 | 49 |
| Đồng Tháp | 50 | 12/12 | 34 | 16 | 43 |
| An Giang | 34 | 11/11 | 26 | 8 | 31 |
| Kiên Giang | 39 | 13/15 | 30 | 9 | 31 |
| Hậu Giang | 12 | 6/8 | 11 | 1 | 11 |
| Sóc Trăng | 32 | 9/11 | 22 | 10 | 26 |
| Bạc Liêu | 23 | 5/7 | 19 | 4 | 21 |
| Cà Mau | 30 | 9/9 | 24 | 6 | 19 |
| Cần Thơ | 26 | 9/9 | 21 | 5 | 22 |
| **Tổng** | **668** | **126/134** | **378** | **290** | **485** |

- **659** lead khi hoàn thành nhập lượt đầu toàn 13 tỉnh, **9** lead bổ sung đầu vòng 2 = **668**.
- **668/668** có URL nguồn HTTPS; **668/668** có research_source_key; **668/668** source manual/status new; **668/668** ghi CHƯA GHÉ; **0** có GPS/visit đánh dấu.
- Số có MST: **87**. Không được suy ra số liệu VAT của mọi điểm bán.
- Đã kiểm SQL trùng exact `province+district+name+address`, `research_source_key`, `province+district+phone` và chồng tên/phone với khách chính: **0** xung đột trong các phép kiểm đã chạy. Tương đồng địa chỉ thay đổi, tên tắt, số điện thoại đổi hoặc cùng chuỗi **có thể vẫn trùng**, phải xác minh thực địa.
- CI xanh, API/Auth theo người dùng Sales, màn hình PWA/Android và GPS trên máy thật **chưa được nghiệm thu** qua đợt nhập dữ liệu này. Không deploy Worker hoặc Vercel chỉ vì đổi DB.

## 8 địa bàn cũ chưa có **lead nghiên cứu** (snapshot lịch sử trước migration 150)

| STT | Tỉnh cũ | Địa bàn cũ | Khách chính hiện có |
|---:|---|---|---|
| 1 | Kiên Giang | Huyện Kiên Hải | Không có khách chính theo địa bàn |
| 2 | Kiên Giang | Huyện Giang Thành | Không có khách chính theo địa bàn |
| 3 | Hậu Giang | Huyện Vị Thủy | 1 khách chính: NS Thích |
| 4 | Hậu Giang | Huyện Long Mỹ | 1 khách chính: NS Thể Minh |
| 5 | Sóc Trăng | Huyện Cù Lao Dung | Không có khách chính theo địa bàn |
| 6 | Sóc Trăng | Huyện Trần Đề | Không có khách chính theo địa bàn |
| 7 | Bạc Liêu | Huyện Vĩnh Lợi | Không có khách chính theo địa bàn |
| 8 | Bạc Liêu | Huyện Đông Hải | Không có khách chính theo địa bàn |

**Lưu ý quan trọng:** Huyện Vị Thủy đã có khách chính NS Thích; Huyện Long Mỹ đã có khách chính NS Thể Minh. `0 lead` không có nghĩa `0 khách` hoặc `0 điểm bán ngoài đời`. Không được nhân đôi khách chính thành lead mới.

## 42 địa bàn có 1–2 lead (snapshot lịch sử trước migration 150)

| Tỉnh | Địa bàn ít lead (số) |
|---|---|
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Hồng Ngự (1); Huyện Tam Nông (1); Huyện Cao Lãnh (1); Huyện Châu Thành (2) |
| An Giang | Huyện An Phú (2); Huyện Châu Phú (2); Thị xã Tịnh Biên (1); Huyện Tri Tôn (2); Huyện Châu Thành (1); Huyện Chợ Mới (2); Huyện Thoại Sơn (2) |
| Kiên Giang | Thành phố Hà Tiên (1); Huyện Kiên Lương (2); Huyện Châu Thành (1); Huyện Giồng Riềng (2); Huyện Gò Quao (1); Huyện An Minh (2); Huyện Vĩnh Thuận (1); Huyện U Minh Thượng (2) |
| Hậu Giang | Huyện Châu Thành A (1); Huyện Châu Thành (1); Huyện Phụng Hiệp (1); Thị xã Long Mỹ (2) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Mỹ Tú (1); Huyện Mỹ Xuyên (2); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Bạc Liêu | Huyện Phước Long (2); Huyện Hòa Bình (2) |
| Cà Mau | Huyện Thới Bình (2); Huyện Trần Văn Thời (2); Huyện Năm Căn (2); Huyện Ngọc Hiển (2) |
| Cần Thơ | Quận Ô Môn (2); Quận Bình Thủy (2); Quận Thốt Nốt (2); Huyện Vĩnh Thạnh (2); Huyện Cờ Đỏ (1); Huyện Phong Điền (1); Huyện Thới Lai (1) |

## Vòng 2 đã thực thi — migration và phân loại nguồn

- `146_kien_giang_old_round02_chau_thanh_u_minh_thuong_2026.sql`, commit `592f0c1cb213e972b7f68e730300f3978e32eb7f`: Châu Thành 1 VPP (Quách Lỷ), U Minh Thượng 2 (Cô Nga, Trung Hiếu); tất cả **chưa ghé**.
- `147_soc_trang_old_round02_chau_thanh_kesach_myxuyen_2026.sql`, commit `20999571866fffc52aceb14e9289caf02940a145`: Châu Thành 2 nhà sách (Ngọc Thanh, Phương Thảo), Kế Sách 1 LEDO Books, Mỹ Xuyên 1 Hiệu sách Thông Minh; hồ sơ Phương Thảo chỉ từ đăng ký thuế, **chưa xác minh cửa hàng**.
- `148_soc_trang_old_round02_supplement_2026.sql`, commit `e27f1bc83f2de3d6658385d98455e51fe89faae0`: Mỹ Tú 1 Tạp hóa Bảy Tỷ có dụng cụ học tập, **KHÔNG coi là nhà sách chuyên doanh**.
- `149_bac_lieu_old_round02_supplement_2026.sql`, commit `7681fbbfeb5464964b0428d2e86a24db60cb91d0`: TP Bạc Liêu 1 VPP Tiến Phát, chưa ghé.
- Migrations 146 và 147 đã được đọc từ GitHub và chạy lại trên production, đều trả **0 dòng thêm**. Migration 148/149 cần kiểm tương tự nếu cần tái đối soát.
- Không nhập Công ty TM&DV Trần Đề (MST `2200809070`): nguồn dữ liệu cập nhật 17/09/2026 ghi **không hoạt động tại địa chỉ đã đăng ký**, mặc dù hồ sơ có ngành 4761 sách/VPP, không dùng để làm đẹp độ phủ. Nguồn https://dulieuphapluat.vn/cong-cu/ma-so-thue/2200809070-cong-ty-tnhh-thuong-mai-va-dich-vu-tran-de.html
- Không nhập các hồ sơ công ty VPP Nam Hợp Nhất/Huỳnh Như vào **Đông Hải Bạc Liêu cũ** vì nguồn tra cứu chính xác lại đặt trụ sở ở TP.HCM/Hòa Bình Bạc Liêu cũ; cần tránh sai địa giới và công ty không có quầy bán lẻ.
- Không nhập lại NS Thích Vị Thủy và quầy sách Giáo Hoàng Bạc Liêu vào leads: một là khách chính có sẵn, một dùng cùng số điện thoại với khách VPP Thanh Xuân trong tỉnh.

## Luồng tiếp theo trong vòng rà bù

1. **P0 — 4 địa bàn còn thiếu lead (sau migration 150)**: tìm theo chợ, trường tiểu học/THCS/THPT, ấp/xã lịch sử, danh sách nhà phát hành và tuyến VPP; ưu tiên có vị trí Maps + số điện thoại. Với đảo Kiên Hải và Giang Thành khó tìm nguồn, giữ trạng thái chưa có lead thay vì bịa cửa hàng.
2. **P1 — 42 địa bàn đang có 1–2 lead**: quét ít nhất một lượt theo thị trấn + xã, không chỉ trung tâm huyện; phân biệt cửa hàng lẻ, doanh nghiệp có mã ngành, tiệm photo, tạp hóa có VPP.
3. **P2 — địa bàn còn lại**: tìm biến thể tên/chi nhánh/địa chỉ sau sáp nhập và dùng Sales thực địa kiểm tra GPS 100m khi ghé; không tự cập nhật vị trí đã được xác minh của khách chính.
4. **Mỗi lô**: SQL migration append-only trực tiếp trên `main`, chạy Neon production, đối soát tỉnh/huyện cũ, source URL, trùng key/phone/MST/tên+địa chỉ, kiểm 0 GPS/checkin giả, báo trạng thái CI/API/thiết bị trung thực.

## Các câu SQL đối chiếu ngắn

```sql
SELECT province,district,count(*) total FROM public.field_prospects GROUP BY 1,2 ORDER BY 1,2;
SELECT province,count(*) total,count(DISTINCT district) covered FROM public.field_prospects GROUP BY province ORDER BY province;
SELECT research_batch,count(*) total FROM public.field_prospects GROUP BY research_batch ORDER BY research_batch;
SELECT research_source_key,count(*) FROM public.field_prospects GROUP BY research_source_key HAVING count(*)>1;
```
