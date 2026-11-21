# VĨNH LONG CŨ — ĐỢT 2/3: TX BÌNH MINH, BÌNH TÂN, TAM BÌNH

Ngày nghiên cứu, ghi DB và đối chiếu: **21/11/2026**. Repo `milktea-cus/MCP-FBMN` branch `main`. Neon production project `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`.

## Phạm vi theo địa giới cũ

- Đợt 1 (đã nhập): Thành phố Vĩnh Long, Huyện Long Hồ, Huyện Mang Thít.
- **Đợt 2 (đã nhập): Thị xã Bình Minh, Huyện Bình Tân, Huyện Tam Bình.**
- Đợt 3 (còn lại): Huyện Trà Ôn và Huyện Vũng Liêm.

Giữ chính xác `province='Vĩnh Long'` và `district` theo tên địa bàn **trước sáp nhập** phục vụ phân quyền và tuyến Sales. Không gom các cơ sở thuộc Bến Tre hoặc Trà Vinh cũ dù đều thuộc tỉnh Vĩnh Long mới.

## Đối soát Neon production

| Địa bàn cũ | Điểm thêm | Nhà sách | VPP/đầu mối | Điện thoại | MST |
|---|---:|---:|---:|---:|---:|
| Thị xã Bình Minh | **9** | 6 | 3 | 7 | 4 |
| Huyện Bình Tân | **5** | 0 | 5 | 1 | 3 |
| Huyện Tam Bình | **7** | 2 | 5 | 3 | 3 |
| **Tổng đợt 2** | **21** | **8** | **13** | **11** | **10** |

- Migration: `backend/migrations/120_vinh_long_old_wave02_binh_minh_binh_tan_tam_binh_2026.sql`; commit `972966fb064631a7c18feef97b65f81ae1a02572`.
- Batch: `2026-11-21-vinh-long-old-wave-02-three-districts`.
- 21/21 hồ sơ có URL nguồn HTTPS, `research_source_key` riêng; `status='new'`, `source_kind='manual'`, `CHƯA GHÉ`, chưa có tọa độ hoặc lượt ghé xác minh.
- Chạy lại chính nội dung SQL đã fetch từ GitHub trên Neon production: **0 dòng thêm** (idempotent).
- Trùng chính xác `district+name+address_line`: **0**; trùng tên hoặc điện thoại với khách chính cùng huyện: **0**. Không tuyên bố đã loại mọi biến thể tên/đổi địa chỉ.
- Không tạo `customers`, không cập nhật cờ đang bán, không tạo lượt ghé, ảnh hoặc GPS giả; khách gốc `Lan Thì` (TP Vĩnh Long) và `Lộc Phát` (Bình Tân) vẫn còn nguyên.

**Tổng Vĩnh Long cũ sau đợt 1–2: 53 điểm tiềm năng tại 6/8 địa bàn**; đợt 1: 32, đợt 2: 21. Có dữ liệu trên 6 huyện/đô thị **không có nghĩa quét FULL 100%**.

## Điểm nổi bật và nguồn công khai

**TX Bình Minh:** Hiệu sách Bình Minh (962 Phan Văn Năm), Hiệu sách Số 1 (718 Phan Văn Năm), Bảo Điệp, Hồng Thắm, Hải Đăng, Quỳnh Anh; VPP An Bình, Kim Phúc Happy (nguồn đăng ký doanh nghiệp), Pinky Shop (cửa hàng đồ dùng học sinh). Nguồn:
- https://www.viet-biz.com/hi%E1%BB%87u-s%C3%A1ch-b%C3%ACnh-minh_5w-0270-3890-459
- https://www.viet-biz.com/hi%E1%BB%87u-s%C3%A1ch-s%E1%BB%91_9l-0270-3890-762
- https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-b%E1%BA%A3o-%C4%91i%E1%BB%87p-0270-3740-252
- https://vpphongha.com.vn/vi/gaga
- https://tracuumst.com/1501164794-cong-ty-tnhh-van-phong-pham-kim-phuc-happy

**Huyện Tam Bình:** Nhà sách Song Phú, Hồng Minh; VPP Lê Thi, photo/VPP Quỳnh Nhi, Nhân Lan, doanh nghiệp Gia Phúc Tam Bình và CTB (đầu mối chỉ có hồ sơ ngành nghề, chưa xác minh cửa hàng thực tế).
- https://happynew.day/vendor/nha-sach-song-phu
- https://sotayvang.com/nha-sach-hong-minh-my-thanh-trung/
- https://www.doanhnghiep.biz/8335731214-001-ho-kinh-doanh-van-phong-pham-quynh-nhi
- https://dauthau.asia/businesslistings/detail/CONG-TY-TNHH-MTV-THIET-BI-VAN-PHONG-CTB-216036/

**Huyện Bình Tân:** Phương Anh (ngành sách/VPP), Tâm Hiếu (tạp hóa/VPP), Trường Thịnh (bán buôn sách/VPP), photo/VPP Phương Đông, Võ Thế Hiệp (hồ sơ ngành sách/VPP cũ); **chưa có nguồn đủ rõ để khẳng định một nhà sách độc lập và đang hoạt động**.
- https://thongtincongty.vn/ma-so-thue/094185014321-ho-kinh-doanh-phuong-anh-to-1-khom-thanh-tam-559287262
- https://dauthau.asia/businesslistings/detail/Ho-kinh-doanh-Tam-Hieu-107016/
- https://thuvienphapluat.vn/ma-so-thue/cong-ty-tnhh-truong-thinh-binh-tan-mst-1501120331.html
- https://mayphotocopyvido.com/tiem-photocopy-mau-trang-den-o-vinh-long-gia-re-chat-luong/

## Chất lượng dữ liệu và tránh đếm ảo

1. **Nhà sách Hải Đăng (Bình Minh)**: danh sách Hồng Hà ghi 135 Lê Văn Dị, nguồn danh bạ khác ghi 129 Lê Văn Vị, nguồn đăng ký kinh doanh ghi 102 tổ 34 khóm 2. Trùng tên/điện thoại nên **gộp một đầu mối**, đánh dấu cần gọi xác nhận số nhà đúng.
2. **Bảo Điệp (Bình Minh)**: địa chỉ bản đồ Ngô Quyền/khóm 1 khác địa chỉ đăng ký thuế tại khóm 1; không tạo hai cơ sở. Hồng Thắm ở gần, Plus Code khác, vẫn cần kiểm tra thực tế xem là hai cửa hàng độc lập.
3. **Bình Tân**: nhiều hồ sơ chỉ có ngành kinh doanh VPP, chưa có địa chỉ cửa hàng trên Maps; tuyệt đối không coi là 5 nhà sách hay 5 điểm đã khảo sát.
4. **Quỳnh Nhi (Tam Bình)**: MST công khai dạng `8335731214-001` được chuẩn hóa `8335731214001` đúng 13 số theo schema. Phương Anh (Bình Tân) có 12 số trong danh bạ nên không đưa vào `tax_code`; giữ URL, cần xác minh.
5. Nhiều cơ sở in ấn, photocopy, quà tặng hoặc bán buôn có thể không bán đủ nhóm sách/dụng cụ học tập và có thể đã ngừng hoạt động; tất cả là **đầu mối chờ Sales xác minh**, không phải cửa hàng xác thực.

## Nghiệm thu / hạn chế

**Đạt:** SQL được commit trực tiếp trên `main`, chạy production, kiểm lại số liệu, chống trùng chính xác, chạy lại không phát sinh dòng; toàn bộ bản ghi giữ `CHƯA GHÉ`.

**Chưa nghiệm thu:** độ phủ mọi cửa hàng nhỏ tại chợ, gần trường và ấp/xã; xác minh kinh doanh trực tiếp, tọa độ mặt tiền; API/Auth với tài khoản Sales, Android/PWA và thiết bị thực tế. Không redeploy frontend/Worker vì không đổi code chạy ứng dụng. GitHub CI cần kiểm tra riêng.

**Ưu tiên đợt 3:** Huyện Trà Ôn, Huyện Vũng Liêm; tiếp tục khảo sát bù Tân Quới, Tân Lược, Thành Trung, Tân Bình, Mỹ Thuận (Bình Tân), Mỹ Thạnh Trung/Song Phú (Tam Bình) và vùng chợ, trường học của Bình Minh. Không ghi nhãn `FULL 100%` nếu chưa kiểm kê hiện trường.

## SQL QA
```sql
SELECT district, count(*) AS total,
 count(*) FILTER (WHERE category='nha_sach') AS bookstores,
 count(*) FILTER (WHERE phone IS NOT NULL) AS phones,
 count(*) FILTER (WHERE tax_code IS NOT NULL) AS tax_codes,
 count(*) FILTER (WHERE research_source_url LIKE 'https://%') AS urls,
 count(*) FILTER (WHERE last_visit_at IS NOT NULL) AS actual_visits
FROM public.field_prospects WHERE province='Vĩnh Long'
GROUP BY district ORDER BY district;

SELECT research_batch,count(*) FROM field_prospects WHERE province='Vĩnh Long'
GROUP BY research_batch ORDER BY research_batch;
```
