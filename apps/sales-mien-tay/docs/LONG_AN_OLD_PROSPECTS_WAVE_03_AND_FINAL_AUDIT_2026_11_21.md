# LONG AN CŨ — ĐỢT 3/3 & TỔNG HỢP 15/15 ĐỊA BÀN
Ngày đối chiếu: 21/11/2026. Repository: `milktea-cus/MCP-FBMN` • Branch: `main` • Neon production: `raspy-bar-51596929`.

## 1. Phạm vi thực hiện đúng theo 3 đợt theo địa bàn cũ

1. Đợt 1: TP Tân An, Bến Lức, Đức Hòa, Cần Giuộc, Cần Đước: **49 điểm**.
2. Đợt 2: Châu Thành, Tân Trụ, Thủ Thừa, Đức Huệ, Thạnh Hóa: **28 điểm**.
3. Đợt 3: **TX Kiến Tường, Mộc Hóa, Tân Thạnh, Tân Hưng, Vĩnh Hưng: 18 điểm**.

Không quét cả Long An ba lần; mỗi đợt cào theo nhóm địa bàn. Giữ **tỉnh/huyện cũ** dù các trang hiện nay ghi tỉnh Tây Ninh.

## 2. Neon production readback — đợt 3

| Địa bàn cũ | Migration 111 | Bổ sung 112 | Tổng | Có số điện thoại | Có MST | Nhà sách | VPP/đầu mối |
|---|---:|---:|---:|---:|---:|---:|---:|
| TX Kiến Tường | 4 | 0 | **4** | 4 | 1 | 2 | 2 |
| Huyện Mộc Hóa | 4 | 0 | **4** | 3 | 0 | 0 | 4 |
| Huyện Tân Thạnh | 3 | 0 | **3** | 2 | 0 | 2 | 1 |
| Huyện Tân Hưng | 2 | 1 | **3** | 2 | 2 | 2 | 1 |
| Huyện Vĩnh Hưng | 2 | 2 | **4** | 0 | 3 | 0 | 4 |
| **Tổng** | **15** | **3** | **18** | **11** | **6** | **6** | **12** |

**Migration:**
- `apps/sales-mien-tay/backend/migrations/111_long_an_old_wave03_five_district_prospects_2026.sql`, commit `50497b2bc87d34d13be6abdd9eb57fdfd7da925e`.
- `apps/sales-mien-tay/backend/migrations/112_long_an_old_wave03_suppliers_2026.sql`, commit `f03b56869d6914fb2740db3ca6228c94fc28fb3e`.

Các điểm nghiên cứu có `status='new'`, `source_kind='manual'`, nguồn HTTPS, `research_source_key` và `research_batch`. **Tất cả đều CHƯA GHÉ**, không gán GPS giả/ảnh giả, không chuyển thành khách chính/đang bán.

## 3. Tổng hợp cuối 3 đợt Long An cũ — SQL đối chiếu

| 15 địa bàn cũ | Điểm |
|---|---:|
| Thành phố Tân An | 10 |
| Huyện Bến Lức | 9 |
| Huyện Đức Hòa | 12 |
| Huyện Cần Giuộc | 9 |
| Huyện Cần Đước | 9 |
| Huyện Châu Thành | 5 |
| Huyện Tân Trụ | 4 |
| Huyện Thủ Thừa | 7 |
| Huyện Đức Huệ | 7 |
| Huyện Thạnh Hóa | 5 |
| Thị xã Kiến Tường | 4 |
| Huyện Mộc Hóa | 4 |
| Huyện Tân Thạnh | 3 |
| Huyện Tân Hưng | 3 |
| Huyện Vĩnh Hưng | 4 |
| **TỔNG** | **95** |

- **Đợt 1: 49 + Đợt 2: 28 + Đợt 3: 18 = 95 điểm**, bao phủ **15/15 địa bàn ở mức có dữ liệu**, không đồng nghĩa 100% cửa hàng trên thực tế.
- **95/95** URL nguồn; **65/95** có số điện thoại; **24/95** có MST. **59** được phân nhóm nhà sách, **36** được phân nhóm VPP/đầu mối; các hồ sơ ngành nghề bán sỉ/thiết bị tin học chưa được xác minh có quầy VPP bán lẻ.
- **95/95** `status='new'`, chưa có lịch sử ghé. Không sửa hai khách hàng chính có sẵn: `NS THÀNH VĂN` Đức Hòa và `Trường Tiến` TP Tân An.

## 4. Nguồn và đối chiếu địa bàn

- Bản đồ địa điểm với Place ID (Nhà sách Thanh Thanh 2, Đồng Tháp Mười, Xuân Nhi, Thuận Phát 3, Cửa hàng Duy Phương, VPP Quỳnh Anh, Hùng Tới, Nhớ, Tường Vy, Kiến Chánh).
- Danh sách điểm bán Thiên Long `https://thienlonggroup.com/news/don-long-khi-vuot-long-mon-cac-nha-sach-thuc-hien` có Nhà sách Thanh Thanh 2 tại Kiến Tường; VPP Gia Nhi tại xã Tân Lập cũ, Tân Thạnh; VPP Hồng Gấm 75 CMT8 Vĩnh Hưng.
- Đăng ký/tra cứu doanh nghiệp công khai: Nhà sách Hải Liên Tân Hưng, VPP Phước Quang Vĩnh Hưng, Thiết bị giáo dục Ánh Hà Tân Hưng, Tin học Tháp Mười Vĩnh Hưng; các hồ sơ bán buôn hoặc đăng ký ngành nghề không được mặc định là cửa hàng có bán lẻ đang mở.
- Chi nhánh Nhà sách Đồng Tháp Mười tại **139 Lý Thường Kiệt, TX Kiến Tường cũ** có nơi ghi địa chỉ huyện Mộc Hóa cũ lịch sử (trước khi chia tách); không được chuyển sang huyện Mộc Hóa mới hơn.
- Chi nhánh LABOCO có MST đã chấm dứt ở Tân Hưng/Vĩnh Hưng/Tân Thạnh: **không nhập các pháp nhân đã chấm dứt thành điểm bán hoạt động**. Nếu còn địa điểm bản đồ độc lập thì phải để trạng thái chưa xác minh.

## 5. Kiểm tra an toàn/trùng lặp

Đã chạy trên Neon production sau migrations 111 và 112:
- Đếm tổng/district: **95 điểm / 15 địa bàn**.
- Cùng `research_source_key`: **0 trùng**.
- Cùng `district + lower(trim(name)) + lower(trim(address_line))`: **0 trùng chính xác**.
- Trùng tên chính xác với khách hàng chính trong cùng địa bàn: **0**.
- **Chạy lại migration 111: 0 thêm**, **migration 112: 0 thêm**, chứng minh idempotency theo nguồn.
- Tất cả vẫn là **chưa ghé**, không thay đổi khách cũ.
- GitHub `get_commit_combined_status` trả `statuses=[]`; **không kết luận CI xanh**. Chưa có chứng cứ kiểm thử API/Auth/PWA/Android hoặc URL live trong pha chỉ nhập DB này.

## 6. Khoảng trống nghiệp vụ cần Sales đi xác minh

**Không thể kết luận “cào FULL = tìm hết 100% cửa hàng” chỉ từ nguồn Internet**. Số lượng thấp tại Tân Thạnh (3), Tân Hưng (3), Mộc Hóa (4), Vĩnh Hưng (4). Chưa có nhà sách được xác minh bằng nguồn đủ chắc chắn ở Mộc Hóa và Vĩnh Hưng; nhiều VPP tại đây chỉ có hồ sơ đăng ký công ty/bán sỉ. Cần kiểm tra từng xã/ấp, chợ, trường TH/THCS/THPT, những điểm nằm sâu ngoài bản đồ và số điện thoại/biển hiệu thực tế, đặc biệt:
- **Huyện Mộc Hóa:** Bình Phong Thạnh, Tân Thành, Bình Hòa Trung, Bình Hòa Tây, Tân Lập...
- **Huyện Tân Thạnh:** thị trấn Tân Thạnh, Tân Lập, các trục QL62 và xã ven.
- **Huyện Tân Hưng:** thị trấn Tân Hưng, Gò Thuyền, các chợ/xã vùng biên.
- **Huyện Vĩnh Hưng:** thị trấn Vĩnh Hưng, khu phố Bầu Sậy, xã Thái Trị và các xã vùng biên.
- **TX Kiến Tường:** các phường đô thị, kiểm tra biển hiệu các cửa hàng Hùng Vương/Lý Thường Kiệt và không nhầm sang huyện Mộc Hóa.

Những hồ sơ cùng MST / cùng số điện thoại / số nhà biến động chỉ cảnh báo, **không hard-block MST** theo contract owner.

## 7. SQL nghiệm thu lại khi cần

```sql
SELECT district,COUNT(*) AS total,
 COUNT(*) FILTER(WHERE phone IS NOT NULL) AS phones,
 COUNT(*) FILTER(WHERE tax_code IS NOT NULL) AS taxes,
 COUNT(*) FILTER(WHERE research_source_url LIKE 'https://%') AS sourced,
 COUNT(*) FILTER(WHERE last_visit_at IS NOT NULL) AS visited
FROM public.field_prospects
WHERE province='Long An'
GROUP BY district ORDER BY district;
```
