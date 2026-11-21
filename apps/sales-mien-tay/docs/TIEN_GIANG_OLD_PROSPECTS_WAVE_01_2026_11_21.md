# TIỀN GIANG CŨ — ĐỢT 1/3: TP MỸ THO, CHÂU THÀNH, CHỢ GẠO, TÂN PHƯỚC
Ngày nghiên cứu/nhập: **21/11/2026**. Repo: `milktea-cus/MCP-FBMN`, nhánh `main`. DB: Neon production project `raspy-bar-51596929`.

## Phân nhóm 11 địa bàn cũ đúng theo yêu cầu 3 đợt

- **Đợt 1 (4 địa bàn):** Thành phố Mỹ Tho, Châu Thành, Chợ Gạo, Tân Phước.
- **Đợt 2 (4 địa bàn):** Thành phố Gò Công, Gò Công Đông, Gò Công Tây, Tân Phú Đông.
- **Đợt 3 (3 địa bàn):** Thị xã Cai Lậy, huyện Cai Lậy, Cái Bè.

Giữ `province='Tiền Giang'`, tên huyện/thị xã/thành phố **cũ** cho phân quyền Sales; không lấy tỉnh Đồng Tháp mới làm khóa địa bàn. TP Gò Công là thành phố cũ tính đến trước sáp nhập 2025.

## Kết quả thực tế production

| Địa bàn cũ | Migration 113 | Migration 114 (NXB GD) | Tổng | Nhà sách | VPP/đầu mối | Có điện thoại | Có MST |
|---|---:|---:|---:|---:|---:|---:|---:|
| TP Mỹ Tho | 15 | 1 | **16** | 8 | 8 | 15 | 1 |
| Châu Thành | 4 | 1 | **5** | 5 | 0 | 5 | 1 |
| Chợ Gạo | 13 | 0 | **13** | 4 | 9 | 7 | 0 |
| Tân Phước | 5 | 0 | **5** | 0 | 5 | 2 | 1 |
| **TỔNG** | **37** | **2** | **39** | **17** | **22** | **29** | **3** |

**Migrations & commits:**
- `apps/sales-mien-tay/backend/migrations/113_tien_giang_old_wave01_four_district_prospects_2026.sql` — 37 điểm; SHA `69008bbcc06e46c825ad34183d2418bb7bb29af4`.
- `apps/sales-mien-tay/backend/migrations/114_tien_giang_old_wave01_publisher_bookstores_2026.sql` — thêm 2 cơ sở Hùng Vương; SHA `b995aa6b3c715a1afcad842c8cc82ea38bc5ba52`.

Các bản ghi được ghi thẳng `public.field_prospects` với `status='new'`, `source_kind='manual'`, `research_batch`, `research_source_key`, `research_source_url` riêng biệt. Không ghi GPS không có bằng chứng, không tạo visits, không chụp ảnh, không chuyển sang khách chính, không đổi cờ `is_selling`.

## Bằng chứng có thể kiểm lại

1. **FAHASA chính thức**: `https://fahasasg.com.vn/mung-khai-truong-nha-sach-fahasa-my-tho-tai-dia-diem-moi/`: Nhà sách FAHASA Mỹ Tho chuyển đến tầng 3 Vincom, 01A Hùng Vương, 22/06/2022; Nhà sách FAHASA Tiền Giang tại GO!/Big C, 545 Lê Văn Phẩm, là cửa hàng khác. **Không nhập lại FAHASA Mỹ Tho Co.opmart 35 Ấp Bắc cũ** như cửa hàng độc lập vì dữ liệu vị trí đã thay đổi.
2. **Nhà xuất bản Giáo dục Việt Nam** danh sách 2025–2026, trang **14 (số trang in trên PDF)**: `https://nxbgd.vn/Attachments/files/PDF/He%20thong%20cua%20hang%20toan%20quoc%202025-2026.pdf` ghi Nhà sách Hùng Vương tại **04 Lê Văn Duyệt**, **171 Lý Thường Kiệt** (đều TP Mỹ Tho) và **909/5 ấp Cửu Hòa, xã Thân Cửu Nghĩa** (Châu Thành). Có ba địa chỉ khác nhau; migration 114 bổ sung 2 cơ sở chưa nằm trong 113.
3. **Hồng Hà** `https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu` xác nhận Nhà sách Tân Hiệp ấp Me và Nhà sách Cô Huệ tại chợ Vĩnh Kim, Châu Thành. Nhà sách Tân Hiệp có hai bản ghi bản đồ cùng điện thoại; đã gộp một điểm.
4. **Minh Long Book** `https://www.minhlongbook.com.vn/pages/he-thong-phan-phoi` xác nhận Nhà sách Việt Văn tại 19 đường 3/2, TP Mỹ Tho. Nguồn cũ cũng ghi Hùng Vương 22 Hùng Vương nhưng dữ liệu địa điểm mới và NXB GD ghi 4 Lê Văn Duyệt; không tự tạo cửa hàng thứ tư từ khác biệt địa chỉ.
5. **Các Place ID Google Maps**: Minh Châu, Hoa Hồng, Giáo Dục Mỹ Tho, VPP Việt Tiến, Thành Nghĩa, Vĩnh Thành; Thanh Tùng, Nhà sách-VPP Vĩnh Kim; Nhật Duy, Thu Ba, Quỳnh Như, Phương Thảo, Hiệp, Bảo Quyên, Liên, Photo Sang, Trí Nguyễn; VPP Tân Phước và VPP Phước Lộc. Mỗi link có `query_place_id` khi dùng nguồn bản đồ.
6. **Tân Phước ít điểm công khai hơn**: nguồn bản đồ (VPP Tân Phước, Phước Lộc), dữ liệu nhà cung cấp `Giai Phát` (MST 1201673367), hồ sơ nhà thầu `Nguyễn Trung` tham gia cung ứng trường học năm 2025–2026 (`https://dauthau.asia/businesslistings/detail/Ho-kinh-doanh-Van-phong-pham-Photocoppy-Nguyen-Trung-215033/`), và Trung tâm bách hóa Tân Phước có kinh doanh văn phòng phẩm từ `https://kinhte.congthuong.vn/tien-giang-xay-dung-diem-ban-hang-viet-nam-tai-cac-xa-vung-sau-vung-xa-233815.html`.

## Chống trùng và độ tin cậy

- Trước đợt 1, **0** leads `province='Tiền Giang'`, nhưng `customers` có sẵn **7** hồ sơ toàn tỉnh, trong đó Chợ Gạo có **Hiệu Sách - Diễm**, **Minh Đức**, Mỹ Tho có **NPP Lê Phương**, **Siêu Thị 19k**. Không nhập lại các hồ sơ này thành lead. NPP Lê Phương có shop VPP tại 110 Nam Kỳ Khởi Nghĩa; vì đây có thể là cùng doanh nghiệp đã tồn tại, **không** đếm dưới lead mới.
- SQL kiểm trùng `research_source_key`: 0 hàng; trùng exact `district + lower(trim(name)) + lower(trim(address_line))`: 0; trùng tên chính xác khách hàng chính: 0. Đây **không** phải hệ thống phát hiện mọi đổi tên/cùng MST/nhiều chi nhánh (theo contract, MST trùng chỉ cảnh báo).
- Chạy lại migration 114: 0 bản ghi được tạo. Chạy lại migration 113 cần kiểm tra riêng trong báo cáo nghiệp vụ.
- **39/39** có URL HTTPS; **29/39** có điện thoại; **3/39** có MST; **39/39** vẫn **Chưa ghé**, chưa có vị trí GPS xác minh. Tất cả nguồn công khai đều cần Sales đối chiếu tình trạng hiện nay.
- Một số nguồn là doanh nghiệp bán sỉ, photocopy, quà tặng hoặc bách hóa có VPP (VD Giai Phát, Trường An Phát, Moss, Trung tâm Bách hóa Tân Phước); **không khẳng định là cửa hàng sách/VPP bán lẻ đã được xác minh**. Ghi chú cảnh báo trong từng hồ sơ.
- MST hộ Nguyễn Trung có định dạng 12 ký tự từ dữ liệu nhà thầu, **không ghi trực tiếp** vì schema yêu cầu 10 hoặc 13 số; giữ URL và note để đối chiếu chính xác, tránh sửa/bịa MST.

## Khoảng trống — chưa thể tuyên bố FULL 100%

**Mỹ Tho 16** là điểm bước đầu, vẫn có thể còn nhiều VPP nhỏ các phường. **Châu Thành 5** cần tìm thêm quanh Long Định, Kim Sơn, Thân Cửu Nghĩa, chợ Tân Hiệp; **Chợ Gạo 13** cần quét thêm các xã không nổi bật trên Maps, nhiều quầy nhỏ. **Tân Phước chỉ 5 điểm, chưa có nhà sách riêng có nguồn chắc chắn**; cần Sales tìm quanh thị trấn Mỹ Phước cũ, xã Thạnh Mỹ, Tân Hòa Thành, Hưng Thạnh, Phước Lập và chợ/trường khu nông thôn.

Ghi production đạt về số lượng, không tương đương đã Sales đến thực địa hoặc bảo đảm độ phủ tuyệt đối; CI xanh và API/role/PWA/Android smoke chưa được xác minh trong pha import dữ liệu.

## SQL đối chiếu Neon

```sql
SELECT district,COUNT(*) AS total,
 COUNT(*) FILTER(WHERE category='nha_sach') AS bookstores,
 COUNT(*) FILTER(WHERE category='van_phong_pham') AS vpp,
 COUNT(*) FILTER(WHERE phone IS NOT NULL) AS phones,
 COUNT(*) FILTER(WHERE tax_code IS NOT NULL) AS taxes,
 COUNT(*) FILTER(WHERE research_source_url LIKE 'https://%') AS source_urls,
 COUNT(*) FILTER(WHERE last_visit_at IS NOT NULL) AS visits
FROM public.field_prospects WHERE province='Tiền Giang'
GROUP BY district ORDER BY district;
```

**Đợt 2 tiếp theo:** TP Gò Công, Gò Công Đông, Gò Công Tây, Tân Phú Đông. **Đợt 3:** TX Cai Lậy, huyện Cai Lậy, huyện Cái Bè.
