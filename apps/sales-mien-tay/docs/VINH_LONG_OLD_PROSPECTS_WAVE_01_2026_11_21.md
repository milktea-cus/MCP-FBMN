# VĨNH LONG CŨ — ĐỢT 1/3: TP VĨNH LONG, LONG HỒ, MANG THÍT

Ngày nghiên cứu, nhập và đối chiếu Neon production: **21/11/2026**. Repo `milktea-cus/MCP-FBMN`, nhánh `main`; project `raspy-bar-51596929`, production branch `br-super-mountain-bdije4mj`.

## Chia 8 địa bàn cũ làm ba đợt, không nhập theo tỉnh sau sáp nhập

- **Đợt 1 (3 địa bàn, đã làm):** Thành phố Vĩnh Long, Huyện Long Hồ, Huyện Mang Thít.
- **Đợt 2 (3 địa bàn, chưa làm):** Thị xã Bình Minh, Huyện Bình Tân, Huyện Tam Bình.
- **Đợt 3 (2 địa bàn, chưa làm):** Huyện Trà Ôn, Huyện Vũng Liêm.

Giữ `province='Vĩnh Long'` và `district` theo `backend/src/districts_old.json`. Đặc biệt, **không nhập huyện/xã thuộc Bến Tre cũ hoặc Trà Vinh cũ** dù địa chỉ năm 2026 hiện ghi tỉnh Vĩnh Long. Không đưa nhãn `FULL` khi chưa kiểm kê thực địa.

## Kết quả thực tế trong Neon

| Địa bàn cũ | Nhà sách | VPP / đầu mối cần xác minh | Tổng | Có điện thoại | Có MST |
|---|---:|---:|---:|---:|---:|
| TP Vĩnh Long | 11 | 4 | **15** | 12 | 1 |
| Long Hồ | 1 | 7 | **8** | 4 | 1 |
| Mang Thít | 4 | 5 | **9** | 5 | 2 |
| **Tổng** | **16** | **16** | **32** | **21** | **4** |

- Trước nhập: **0** `field_prospects` Vĩnh Long cũ; **2** khách chính sẵn có là Lan Thì (TP Vĩnh Long) và Lộc Phát (Bình Tân); không sửa hoặc nhân bản khách.
- SQL migration: `backend/migrations/119_vinh_long_old_wave01_vinh_long_long_ho_mang_thit_2026.sql`. Commit: `7aa95f022edc180d8922364beb9cd4bffafd9fba`.
- Batch: `2026-11-21-vinh-long-old-wave-01-three-districts`.
- Neon production sau nhập: **32/32 URL nguồn HTTPS**, **32/32** `research_source_key` riêng, **32/32** `status='new'`, `source_kind='manual'`, **0** có GPS/visit xác minh, **0** thiếu ghi chú `CHƯA GHÉ`.
- Đối chiếu trùng `research_source_key`: **0**; trùng exact tên + địa chỉ trong huyện: **0**; trùng tên hoặc điện thoại với khách đang quản lý ở cùng huyện: **0**.
- Chạy lại migration từ chính nội dung file trên GitHub: **0 dòng được chèn (idempotent đạt)**.
- Hệ thống chỉ ghi lead nghiên cứu chưa ghé; không sinh `field_prospect_visits`, không gắn tọa độ chưa xác minh, không tạo/sửa khách chính, không giả định `is_selling`.

## Nguồn và cách đối chiếu

- **Nguồn chính thức:** FAHASA Vĩnh Long tại tầng 1 Co.opmart 26 đường 3/2, https://fahasasg.com.vn/bookstore/nha-sach-fahasa-vinh-long/; danh sách hệ thống sách NXB Giáo dục 2025–2026: https://nxbgd.vn/Attachments/files/PDF/He%20thong%20cua%20hang%20toan%20quoc%202025-2026.pdf (Trung tâm Sách–TBGD 64 Lê Văn Tám, Nhà sách Tổng hợp 61 đường 3/2).
- **Điểm bản đồ:** Các cơ sở có `query_place_id` riêng, ví dụ Phương Nam Vincom, Trường Giang, Thu Hồng, Phong Hương, Phong Mỹ, Phương Thủy, Yến Dung. Đây là địa điểm công khai, **không phải GPS Sales xác minh**.
- **Nguồn địa phương và danh bạ:** https://www.vinhlongtoplist.com/top-10-nha-sach-tai-vinh-long-day-du-the-loai-gia-tot/ ; https://baovinhlong.com.vn/kinh-te/201308/thi-truong-nam-hoc-moi-mua-sam-de-chung-2565832/ ; https://sonca.vn/top-10-cua-hang-van-phong-pham-tai-vinh-long-uy-tin-nhat/.
- **Hồ sơ ngành nghề/nhà thầu:** Duy Anh MST 1501147238 (https://dauthau.asia/businesslistings/detail/CONG-TY-TNHH-TM-DV-VAN-PHONG-PHAM-DUY-ANH-200010/), Thanh Tiến MST 1500993911 (https://thongtindoanhnghiep.co/1500993911-co-so-mua-ban-van-phong-pham-thanh-tien), Thúy Vy MST 1500969891 (https://thongtindoanhnghiep.co/1500969891-co-so-ban-van-phong-pham-thuy-vy). **Những hồ sơ này KHÔNG đủ chứng minh có cửa hàng bán lẻ đang hoạt động**.
- Bản đồ/ngành hàng không đầy đủ, thông tin số điện thoại và tên cũ có thể đã thay đổi; ghi `verification_note` cho từng dòng để Sales ưu tiên gọi và kiểm tra.

## Các nghi vấn tránh đếm ảo

1. FAHASA số 26 đường 3/2 và một đầu mối giới thiệu sản phẩm NXB Giáo dục cùng địa chỉ: không tạo thêm hai điểm từ một địa chỉ.
2. Hiệu sách 93 có nơi ghi 31 Hưng Đạo Vương, nơi ghi 75 Trưng Nữ Vương: tạm giữ một điểm vì chưa chứng minh hai cửa hàng.
3. Hiệu sách Thanh / Nhà sách Thanh Thanh tại Cái Nhum: có thể một cửa hàng đổi tên; chỉ một điểm; nguồn báo năm 2013 đã cũ.
4. Hồng Ân 132A đường 14/9 là Phường 5 cũ thuộc TP Vĩnh Long; một số địa chỉ hành chính mới ghi Thanh Đức, không gán nhầm huyện Long Hồ.
5. Long Hồ: Thu Hồng 275 vs. 275/18; tránh tách hai điểm.
6. Điểm photo, in ấn, dịch vụ văn phòng và doanh nghiệp có ngành nghề VPP cần gọi xác minh bán lẻ, không tô thành nhà sách hoạt động.
7. Mang Thít nhiều điểm mới có Plus Code/khu vực Cái Nhum; cần Sales xác minh xã, số nhà, liên hệ. Long Hồ nên mở rộng xã Phú Quới, Thanh Đức, Đồng Phú và các tuyến chợ/trường.

## Nghiệm thu và việc tiếp theo

- **Đã đạt:** migration + import Neon thật, đối chiếu số lượng và trùng, chạy lại idempotent, chứng minh không sinh GPS/visit.
- **Chưa đạt:** kiểm kê hết mọi nhà sách/VPP trên thực địa; xác thực API/role, kiểm thử PWA/Android thực tế; không được gọi dữ liệu này `FULL 100%`.
- Không thay đổi Worker/Frontend; không cần redeploy ứng dụng chỉ vì thêm lead DB.
- Đợt 2 tiếp theo: **TX Bình Minh, huyện Bình Tân, huyện Tam Bình**; đợt 3: **Trà Ôn, Vũng Liêm**.

## SQL QA
```sql
SELECT district,COUNT(*) AS total,
 COUNT(*) FILTER(WHERE category='nha_sach') AS bookshops,
 COUNT(*) FILTER(WHERE phone IS NOT NULL) AS phones,
 COUNT(*) FILTER(WHERE tax_code IS NOT NULL) AS tax_codes,
 COUNT(*) FILTER(WHERE research_source_url LIKE 'https://%') AS sources,
 COUNT(*) FILTER(WHERE last_visit_at IS NOT NULL) AS visits
FROM public.field_prospects WHERE province='Vĩnh Long'
GROUP BY district ORDER BY district;
```
