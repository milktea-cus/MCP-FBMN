# MCP-FBMN — TRÀ VINH CŨ: ĐỢT 3/3 VÀ ĐỐI CHIẾU TOÀN TỈNH

Ngày nghiên cứu và đối chiếu DB: **21/11/2026**. Branch: `main`. Neon project: `raspy-bar-51596929`.

## Ranh giới đợt 3

Làm đúng ba địa bàn **cũ**, không quét toàn tỉnh lặp ba lần:

1. Huyện Trà Cú (Trà Vinh cũ)
2. **Huyện Duyên Hải** (thị trấn Long Thành, Ngũ Lạc, Long Vĩnh, Đôn Châu, Đông Hải...)
3. **Thị xã Duyên Hải** (phường 1/2, xã Dân Thành, Trường Long Hòa, Long Hữu... theo ranh giới cũ).

Các địa chỉ hành chính mới có thể ghi tỉnh Vĩnh Long; `province='Trà Vinh'` và `district` giữ tên đơn vị cũ phục vụ tuyến Sales.

## Kết quả SQL migration 106 (ghi production)

| Địa bàn cũ | Điểm mới | Có điện thoại | Có MST |
|---|---:|---:|---:|
| Huyện Trà Cú | 9 | 5 | 4 |
| Huyện Duyên Hải | 2 | 1 | 1 |
| Thị xã Duyên Hải | 8 | 5 | 3 |
| **Tổng đợt 3** | **19** | **11** | **8** |

- File: `apps/sales-mien-tay/backend/migrations/106_tra_vinh_old_wave03_tra_cu_duyen_hai_2026.sql`.
- Commit: `984137db8ee7fd117be2fa47e894a781d7011d62`.
- Mỗi điểm có `research_source_key` riêng, URL công khai HTTPS, chú thích chất lượng dữ liệu và cảnh báo khi cần xác minh.
- `source_kind='manual'`, `status='new'`, chưa ghé, không có GPS xác minh. Không tạo/sửa khách hàng chính, không cập nhật `is_selling`, không tạo ảnh/visit giả.
- Các cửa hàng có thể thuộc danh mục bán sỉ hoặc có hồ sơ ngành nghề VPP nhưng chưa chứng minh có quầy bán lẻ; được gắn ghi chú rõ ở trường `note` để Sales gọi và ghé kiểm chứng.
- **0 điểm đợt 3 có bằng chứng đủ rõ để gắn nhãn `nha_sach` riêng biệt**; 19 được gắn `van_phong_pham` hoặc đầu mối cung cấp ngành hàng. Đây là khoảng trống nghiên cứu cần kiểm tra, KHÔNG có nghĩa ngoài đời không có nhà sách.

## Những điểm chính đã nhập

- **Trà Cú:** VPP Kim Hạnh; Photocopy–VPP Nhật Thu; VPP Cô Quyên; Shop Minh Nhật (xã Đại An cũ); tạp hóa–VPP Thức Hường (An Quảng Hữu cũ); VPP–Photocopy Thọ (Long Hiệp cũ); Lâm Thành Niên (Tập Sơn cũ); hộ kinh doanh Lê Thị Thu Năm; Diệp Phúc Thịnh (Hàm Giang cũ).
- **Huyện Duyên Hải:** Thiệp cưới Nhung – In áo nhóm – VPP (Ngũ Lạc cũ); VPP Linh Linh TV (khóm 4, thị trấn Long Thành cũ).
- **Thị xã Duyên Hải:** VPP Kim Liên; Lan Nhã; Gia Phát; Tường Duy; VPP–Photocopy Mỹ Hiền (xã Dân Thành cũ); Vi tính Tâm Việt CN Duyên Hải; Máy tính Triệu Ngân; TT máy vi tính–VPP An Khang.

## Loại bỏ/nghi vấn và kiểm chứng

- DNTN VS-HT-Phát Lộc MST `2100690583` tại xã Long Vĩnh **không được import**: nguồn tra cứu thuế ghi *không hoạt động tại địa chỉ đã đăng ký*; không tô đẹp số liệu.
- Lan Nhã: nguồn điểm bản đồ và nguồn danh bạ khác số điện thoại (0294 3832701 vs. 0359 576276) và độ chính xác số nhà; đã ghi số từ bài giới thiệu và cảnh báo trong note.
- VPP Kim Liên và Mỹ Hiền thuộc **xã Dân Thành, thị xã Duyên Hải cũ**; không đẩy sang `Huyện Duyên Hải`.
- Tên tương tự có thể là cùng cơ sở; hiện chỉ chống trùng exact source key, exact tên+địa chỉ và trùng với danh bạ khách chính; chưa bảo đảm bắt được mọi biến thể tên viết tắt, nhiều chi nhánh hoặc địa chỉ hành chính khác nhau.
- VPP Thức Hường, VPP Thọ, Lâm Thành Niên, Lê Thị Thu Năm, Diệp Phúc Thịnh, Triệu Ngân và một số hồ sơ doanh nghiệp chưa chắc là điểm bán lẻ, cần gọi hoặc ghé để xác định; KHÔNG coi là đã xác minh hoạt động.

## Lũy kế ba đợt — Neon production readback

| Địa bàn cũ | Điểm |
|---|---:|
| Thành phố Trà Vinh | 30 |
| Càng Long | 7 |
| Cầu Kè | 5 |
| Tiểu Cần | 6 |
| Châu Thành | 5 |
| Cầu Ngang | 7 |
| Trà Cú | 9 |
| Huyện Duyên Hải | 2 |
| Thị xã Duyên Hải | 8 |
| **Tổng 9/9 địa bàn có dữ liệu** | **79** |

- Đợt 1: 42 (migrations 102, 103)
- Đợt 2: 18 (migrations 104, 105)
- Đợt 3: 19 (migration 106)
- Tổng **79/79** có URL nguồn HTTPS; **43/79** có điện thoại; **23/79** có MST; **79/79** chưa ghi nhận ghé thực địa.
- SQL kiểm trùng `research_source_key`: 0 kết quả; trùng exact tên+địa chỉ trong cùng huyện: 0; đối chiếu tên với `customers`: 0; chạy lại migration 106: 0 dòng thêm.

## Nghiệm thu trung thực / khoảng trống cần xử lý

**Đã đạt: 3 đợt hoàn thành theo địa bàn và 9/9 địa bàn CÓ dữ liệu. Chưa đạt: 'FULL' nghĩa là không còn nhà sách, VPP hoặc đại lý học phẩm nào bị sót trên thực tế.**

Ưu tiên khảo sát bù **huyện Duyên Hải** (chỉ 2 điểm online): Long Thành, Long Khánh, Ngũ Lạc, Long Vĩnh, Đông Hải, Đôn Châu/Đôn Xuân, các chợ, trường học và các đường nhánh. Tiếp tục rà những điểm Trà Cú ở Hàm Giang/Đại An/Tập Sơn và địa bàn xã ven TX Duyên Hải. Nên tách cột 'chỉ có hồ sơ doanh nghiệp / có điểm trên Maps / Sales đã xác minh' trong đợt kiểm kê thực địa; không đồng nhất việc có MST với điểm bán thật.

**Chưa nghiệm thu:** CI xanh (GitHub combined statuses cho commit chỉ trả `statuses=[]`), API/Auth theo vai trò thật, PWA/Android hiển thị điểm vừa nhập. Không yêu cầu deploy web/Worker mới vì thay đổi lần này chỉ là import DB/migration; không có kiểm chứng URL live trong lượt này.

## Các SQL đối chiếu

```sql
SELECT district, COUNT(*) AS total,
 COUNT(*) FILTER (WHERE phone IS NOT NULL) AS phones,
 COUNT(*) FILTER (WHERE tax_code IS NOT NULL) AS tax_codes,
 COUNT(*) FILTER (WHERE research_source_url LIKE 'https://%') AS urls,
 COUNT(*) FILTER (WHERE last_visit_at IS NOT NULL) AS visits
FROM public.field_prospects WHERE province='Trà Vinh'
GROUP BY district ORDER BY district;

SELECT research_source_key,COUNT(*) FROM public.field_prospects
WHERE province='Trà Vinh'
GROUP BY research_source_key HAVING COUNT(*)>1;
```
