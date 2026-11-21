# LONG AN CŨ — ĐỢT 2/3: CHÂU THÀNH, TÂN TRỤ, THỦ THỪA, ĐỨC HUỆ, THẠNH HÓA

**Ngày:** 21/11/2026. **Repo:** `milktea-cus/MCP-FBMN`, branch `main`. **Neon production:** project `raspy-bar-51596929`.

## Phạm vi và nguyên tắc

Long An cũ có 15 địa bàn cấp huyện, chia đúng 3 đợt (5 địa bàn / đợt). Đợt 1 Tân An/Bến Lức/Đức Hòa/Cần Giuộc/Cần Đước đã có 49 lead. **Đợt 2** chỉ gồm 5 địa bàn cũ: huyện Châu Thành, Tân Trụ, Thủ Thừa, Đức Huệ, Thạnh Hóa. **Đợt 3** còn lại: TX Kiến Tường, Mộc Hóa, Tân Thạnh, Tân Hưng, Vĩnh Hưng.

Giữ `province='Long An'` và `district` tên huyện cũ, dù địa chỉ Maps hiện có thể thuộc Tây Ninh mới. Không tự tạo GPS, check-in, ảnh, đơn hàng hoặc khách hàng chính.

## Kết quả ghi dữ liệu và Neon read-back

| Huyện cũ | Migration 109 | Migration 110 | Tổng đợt 2 | Điện thoại | MST | Nhà sách | VPP |
|---|---:|---:|---:|---:|---:|---:|---:|
| Châu Thành | 4 | 1 | **5** | 4 | 1 | 5 | 0 |
| Tân Trụ | 4 | 0 | **4** | 4 | 0 | 1 | 3 |
| Thủ Thừa | 4 | 3 | **7** | 7 | 0 | 5 | 2 |
| Đức Huệ | 7 | 0 | **7** | 4 | 1 | 4 | 3 |
| Thạnh Hóa | 5 | 0 | **5** | 2 | 0 | 4 | 1 |
| **Tổng đợt 2** | **24** | **4** | **28** | **21** | **2** | **19** | **9** |

Đợt 1 đã ghi 49, do đó lũy kế sau đợt 2 **77 điểm / 10 trên 15 địa bàn Long An cũ**; lũy kế 54 điểm có số điện thoại, 18 có MST, 53 nhà sách và 24 VPP.

## Migration & commits

- `apps/sales-mien-tay/backend/migrations/109_long_an_old_wave02_five_district_prospects_2026.sql` — 24 điểm. Commit: `81ee89764d65d9c0787eae703c2640ae498568bb`.
- `apps/sales-mien-tay/backend/migrations/110_long_an_old_wave02_hongha_rural_supplement_2026.sql` — 4 điểm. Commit: `4766021add8a0e9a348103df576e3291d52e6fb2`.

Các điểm vào `public.field_prospects` với `source_kind='manual'`, `status='new'`, có `research_source_key`/URL HTTPS/`research_batch`, không có `last_visit_at`. Tất cả là **đối tượng nghiên cứu để Sales xác minh**, không phải 28 cửa hàng đã đi thực tế hoặc 28 khách đang bán.

## Bằng chứng và chất lượng nguồn

- Google Maps Place IDs cho phần lớn điểm bán tại Tầm Vu, Tân Trụ, Thủ Thừa, Đông Thành, Thạnh Hóa.
- **Danh mục Nhà xuất bản Giáo dục 2025–2026**, trang 15: `https://nxbgd.vn/Attachments/files/PDF/He%20thong%20cua%20hang%20toan%20quoc%202025-2026.pdf`. Xác nhận Cửa hàng Sách–TBGD Châu Thành, **52A tỉnh lộ 827A, Tầm Vu**, điện thoại **0272 3503 747**.
- **Danh sách điểm bán Hồng Hà**: `https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu`: Hoàng Bảo Ngọc (094D TL817, Mỹ Lạc, Thủ Thừa), Khánh My (ST0362 TL817, Mỹ Thạnh, Thủ Thừa), Thành Trung (132T TL817, Mỹ Lạc, Thủ Thừa), Thanh Thảo (138/5 TL827B, Bình Quới, Châu Thành).
- Ranh giới địa bàn cũ Mỹ Lạc/Mỹ Thạnh thuộc huyện Thủ Thừa và Bình Quới thuộc huyện Châu Thành đối chiếu với tài liệu chính sách địa phương/địa danh. Không lẫn Châu Thành Long An với Châu Thành Bến Tre/Tây Ninh cũ.
- Nhà sách Châu Thành LABOCO 210 TL827, MST 1100112728-008 còn hiển thị đang hoạt động trên một danh bạ doanh nghiệp; Nhà sách Châu Thành 287 TL21 Maps được giữ riêng vì không đủ bằng chứng cùng thực thể. **MST 1100112728-024** tại 287C TL837 đã đóng năm 2015, không gán cho điểm 287 TL21.
- Nhà sách Tân Trụ trên bản đồ tại 81 Nguyễn Trung Trực; hồ sơ chi nhánh MST 1100112728-007 đã ngừng hoạt động, nên **không gán MST cũ** cho điểm có Maps. Cần xác minh pháp nhân hiện nay.
- Chi nhánh Nhà sách Thủ Thừa 26 Nguyễn Khoa Thừa (MST 1100112728-006) và Nhà sách Thạnh Hóa (MST 1100112728-014) có thông tin đã ngưng hoạt động từ năm 2009. **Không nhập các hồ sơ MST này thành doanh nghiệp đang hoạt động**. Các địa điểm bản đồ có tên giống “Nhà sách Thạnh Hóa” vẫn là lead chưa xác minh, không gán MST đã dừng.
- Các tên cùng đường/số gần nhau và các nguồn bán sỉ/online (Văn Hiến, Nhà sách Thạnh Hóa 2, Epicenter) đã được gắn cảnh báo trong note.

## Kiểm thử thực tế

Đã thực thi read-back Neon production, kết quả:
- 28 điểm đợt 2 có URL HTTPS; 21 số điện thoại; 2 MST, tất cả **chưa ghé**.
- Tổng Long An: **77 điểm / 10 địa bàn** (5 địa bàn đợt 3 chưa làm).
- SQL chống trùng `research_source_key`: 0 bản ghi trùng; `district+lower(name)+lower(address)`: 0; trùng exact tên với `customers`: 0.
- Chạy lại migration 109 và 110 trên Neon: trả **0 dòng mới**, kiểm tra idempotent đạt. Không có thay đổi khách hàng cũ.
- GitHub combined status API cho commit 110 trả mảng rỗng `statuses=[]`; **không thể công bố CI xanh** khi chưa kiểm tra Actions chi tiết. Không thay đổi UI/Worker, nên không deploy mới.

## Còn thiếu để gọi 'FULL' theo nghĩa toàn bộ điểm thực tế

Mỗi địa bàn đã có nguồn có thể truy vết, nhưng **không có bằng chứng mọi xã/ấp và cửa hàng nhỏ đều đủ**. Rủi ro lớn: Châu Thành chỉ có 5 lead, Tân Trụ 4; các xã ven và điểm nhỏ không lên Maps còn thiếu. Cần Sales kiểm chứng trực tiếp quanh chợ, trường tiểu học/THCS/THPT, những ấp xa trung tâm và xác nhận người/địa chỉ/điện thoại.

**Tất cả ở trạng thái Chưa ghé**. Không khẳng định cửa hàng nào còn mở chỉ dựa vào MST, lịch hoạt động trên Maps, website bán hàng online hoặc danh bạ cũ. Khả năng hai biển hiệu/chi nhánh cùng cơ sở chưa được loại trừ hoàn toàn.

## SQL đối chiếu production

```sql
SELECT district, count(*) AS total,
 count(*) FILTER(WHERE phone IS NOT NULL) AS phones,
 count(*) FILTER(WHERE tax_code IS NOT NULL) AS taxes,
 count(*) FILTER(WHERE research_source_url LIKE 'https://%') AS sourced,
 count(*) FILTER(WHERE last_visit_at IS NOT NULL) AS visited
FROM public.field_prospects
WHERE province='Long An'
GROUP BY district ORDER BY district;
```
