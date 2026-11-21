# LONG AN CŨ — ĐỢT 1/3: TP TÂN AN, BẾN LỨC, ĐỨC HÒA, CẦN GIUỘC, CẦN ĐƯỚC

Ngày nghiên cứu/ghi DB: 21/11/2026. Repo `milktea-cus/MCP-FBMN` · branch `main` · Neon production project `raspy-bar-51596929`.

## Phân chia 15 địa bàn cũ theo ba đợt (5/đợt)

- **Đợt 1:** Thành phố Tân An, huyện Bến Lức, huyện Đức Hòa, huyện Cần Giuộc, huyện Cần Đước.
- **Đợt 2:** huyện Châu Thành, huyện Tân Trụ, huyện Thủ Thừa, huyện Đức Huệ, huyện Thạnh Hóa.
- **Đợt 3:** thị xã Kiến Tường, huyện Mộc Hóa, huyện Tân Thạnh, huyện Tân Hưng, huyện Vĩnh Hưng.

Giữ khóa `province='Long An'` và tên `district` của **huyện cũ** trong `field_prospects`, dù các nguồn Maps 2026 hiện ghi tỉnh Tây Ninh sau sáp nhập. Không nhầm Cần Giuộc và Cần Đước; không coi danh sách 3 đợt là kết quả xong cả tỉnh trước khi 15/15 địa bàn có dữ liệu.

## Dữ liệu thực tế đã import + read-back Neon production

| Địa bàn cũ | Migration 107 | Bổ sung 108 | Tổng | Điện thoại | MST | Nhà sách | VPP |
|---|---:|---:|---:|---:|---:|---:|---:|
| Thành phố Tân An | 10 | 0 | **10** | 10 | 2 | 6 | 4 |
| Huyện Bến Lức | 9 | 0 | **9** | 7 | 1 | 6 | 3 |
| Huyện Đức Hòa | 10 | 2 | **12** | 9 | 4 | 10 | 2 |
| Huyện Cần Giuộc | 6 | 3 | **9** | 5 | 4 | 5 | 4 |
| Huyện Cần Đước | 7 | 2 | **9** | 2 | 5 | 7 | 2 |
| **TỔNG ĐỢT 1** | **42** | **7** | **49** | **33** | **16** | **34** | **15** |

Ghi trực tiếp bảng `public.field_prospects` trên Neon production theo hai migration cộng thêm:
- `apps/sales-mien-tay/backend/migrations/107_long_an_old_wave01_five_district_prospects_2026.sql` — commit `22e79747c95ab39534fa29ae3ce4a6a268e47f80`.
- `apps/sales-mien-tay/backend/migrations/108_long_an_old_wave01_supplement_2026.sql` — commit `28f816a96aa9da3d41ebb4f89672522479f9de2c`.

Các nguồn có thể truy ngược riêng cho **từng điểm** qua `research_source_url`, `research_source_key`, `research_batch`. Sử dụng Google Maps Place ID, trang chi nhánh chính thức LABOCO (`https://www.laboco.com.vn/cac-chi-nhanh.html`), danh sách điểm bán nhà cung cấp Hồng Hà (`https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu`), danh bạ doanh nghiệp, tra cứu chi nhánh/MST, trang trực tiếp của nhà cung cấp.

**Vì dữ liệu nguồn chưa được Sales xác minh tại chỗ**, 49/49 bản ghi đều `status='new'`, `last_visit_at IS NULL`, `source_kind='manual'`, `research_source_url` HTTPS, không có tọa độ/GPS check-in thật. Không đụng hồ sơ khách hiện tại, ảnh, tuyến, surveys, `is_selling`.

## Chống trùng và tính bền vững

- Trước import: Long An có 0 điểm tiềm năng trong `field_prospects`, và có 2 Khách hàng chính: `NS THÀNH VĂN` tại Đức Hòa và `Trường Tiến` tại TP Tân An.
- Không tự tạo lại hai khách này dưới dạng lead; giữ các chi nhánh **có địa chỉ khác** (VD: `Nhà sách Thành Văn Tân Mỹ` và khách Thành Văn ở Hậu Nghĩa) với **ghi chú yêu cầu đối chiếu** trước khi coi là hai điểm hoạt động.
- SQL check 21/11: 0 trùng `research_source_key`; 0 trùng exact `district + lower(name) + lower(address)`; 0 trùng exact tên khách hàng chính. Chạy lại migration 108 trả **0 dòng mới**.
- Idempotent `research_source_key` + deterministic UUID; chỉ kiểm trùng chính xác, không khẳng định đã xử lý mọi biến thể viết tắt/biển hiệu đổi tên.

## Nguồn chính đã ghi

- TP Tân An: Nhà sách Trung Tâm, FAHASA tại Co.opmart và FAHASA AEON (hai địa điểm khác nhau), An Phát, Phát Lộc, Bình Minh, VPP 29, Châu Lâm, Vĩnh Hưng, An Lộc Việt. `Trường Tiến` đã thuộc khách chính nên không nhập trùng.
- Bến Lức: Anh Thư, Ánh Hồng, Huỳnh Nhi, Văn Hiến, Dân Trí, chi nhánh LABOCO Nguyễn Hữu Thọ, VPP Đình Phùng, Lê Huy, Phương Linh.
- Đức Hòa: Võ Văn Tần, Hậu Nghĩa, Đức Hòa, Ba Văn, Phương Anh, Phương Kha, Lê Thu, Hải Quân, Nguyễn Nhân, chi nhánh Thành Văn Tân Mỹ, Thanh Kiều, Ngọc Nhi.
- Cần Giuộc: Nhà sách Cần Giuộc LABOCO, Nhà sách Cần Giuộc 262 QL50 (trùng **tên**, khác Place ID, cần kiểm tra), Hương Việt, Mũi Tàu, chi nhánh thiết bị GD, VPP Trần Lê, Nhà Yên, VPP Tân Kim, Hoàng Long.
- Cần Đước: Lê Hoàng Rạch Kiến; Nhà sách Cần Đước trên QL50; Nhà sách Cần Đước 2 tại 90A QL50; chi nhánh tại 224 khu 1A; Sách - Thiết bị GD Rạch Kiến tại 97 ấp 5 Long Hòa; Nhà sách Rạch Kiến 360 ĐT826; chi nhánh Sách - Thiết bị GD 86 khóm 5; VPP Liên Hương; VPP Phạm Công Bình.

## Không khẳng định FULL 100% và rủi ro cần xử lý

1. **Cần Đước**: 9 kết quả nhưng số có điện thoại chỉ 2, phần lớn là các chi nhánh/trang hồ sơ doanh nghiệp. Ba mục “Nhà sách Cần Đước”, “Cần Đước 2”, “CN Sách & Dịch vụ Văn hóa” có thể trùng thực thể hay đã đổi địa chỉ; cần Sales xác minh theo quầy/biển hiệu thực, không cộng cứng thành 3 cơ sở đã được xác minh.
2. **Cần Giuộc**: hai kết quả cùng tên Nhà sách Cần Giuộc, hai Place ID khác nhau; chưa thể khẳng định hai cửa hàng độc lập. Nhà Yên, Hoàng Long, VPP Trần Lê có ngành hàng/loại bán sỉ cần xác minh.
3. **Bến Lức**: Nhà sách Anh Thư có thông tin địa chỉ 180/182 Nguyễn Hữu Thọ và danh bạ nói có thể đã đóng. Nhà sách Bến Lức 78/4 Võ Công Tồn đã bị một nguồn nói ngừng hoạt động nên **không import** như lead bán lẻ đang mở. Nhà sách Văn Hiến Bến Lức vs. thông tin một điểm tên Văn Hiến ở Thủ Thừa cần đối chiếu.
4. **Đức Hòa**: Nhà sách Thành Văn địa chỉ 117 ĐT823 đã là khách hàng; chi nhánh Tân Mỹ ĐT822 có hồ sơ riêng cần xem thực địa. Nhà sách Ba Văn có bản đồ/danh bạ hai vị trí khả nghi, chưa nhân đôi tùy tiện.
5. **Tân An**: Không nhập trùng Trường Tiến; các điểm nhà sách/VPP có số điện thoại nhưng chưa gọi xác nhận.
6. Không có bằng chứng hoàn thành *cào đủ mọi xã/ấp, đường nhỏ quanh trường/chợ*, không tuyên bố không còn cửa hàng nhỏ. Chú thích `note` tách rõ điểm có Maps, có MST và chỉ bán buôn; không tạo GPS giả để hợp thức hóa check-in.
7. Chưa chạy UAT API/Auth theo vai trò hoặc PWA/Android trên production. Commit và DB read-back **không thay** CI xanh; GitHub combined statuses cho commit chỉ trả `statuses=[]`. Không cần tái deploy Worker/Vercel cho hai migration chỉ ghi dữ liệu này.

## Đợt tiếp theo

**Đợt 2 — 5 địa bàn cũ:** Châu Thành, Tân Trụ, Thủ Thừa, Đức Huệ, Thạnh Hóa. Tiếp tục các từ khóa “nhà sách”, “văn phòng phẩm”, “dụng cụ học sinh”, “cửa hàng sách thiết bị giáo dục” theo xã/phường và nguồn nhà phân phối/hộ kinh doanh công khai.

## SQL kiểm chứng

```sql
SELECT district,count(*) total,
 count(*) FILTER(WHERE phone IS NOT NULL) phones,
 count(*) FILTER(WHERE tax_code IS NOT NULL) taxes,
 count(*) FILTER(WHERE research_source_url LIKE 'https://%') sourced,
 count(*) FILTER(WHERE last_visit_at IS NOT NULL) actual_visits
FROM public.field_prospects WHERE province='Long An'
GROUP BY district ORDER BY district;
```
