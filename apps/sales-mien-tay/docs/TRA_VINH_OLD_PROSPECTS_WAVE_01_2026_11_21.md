# BÀN GIAO DỮ LIỆU ĐIỂM BÁN TIỀM NĂNG — TRÀ VINH CŨ, ĐỢT 1/3

Ngày: 21/11/2026. Repo: `milktea-cus/MCP-FBMN`, nhánh `main`.

## Phạm vi

Đợt 1 chỉ gồm 3/9 địa bàn theo đơn vị hành chính **cũ**, không phải quét toàn tỉnh 3 lần:
- Thành phố Trà Vinh cũ
- Huyện Càng Long cũ
- Huyện Cầu Kè cũ

Phân loại: nhà sách, văn phòng phẩm, dụng cụ học tập (các đầu mối giấy tờ/thiết bị liên quan chỉ giữ khi nguồn thể hiện phù hợp). Không trộn dữ liệu sang Trà Cú, Tiểu Cần, Châu Thành, v.v.

## Kết quả thực tế — Neon production

| Địa bàn cũ | Migration 102 | Bổ sung 103 | Tổng |
|---|---:|---:|---:|
| Thành phố Trà Vinh | 26 | 4 | **30** |
| Huyện Càng Long | 7 | 0 | **7** |
| Huyện Cầu Kè | 4 | 1 | **5** |
| **Tổng** | **37** | **5** | **42** |

Dữ liệu lưu vào `public.field_prospects`, `province='Trà Vinh'`, `source_kind='manual'`, `status='new'`, chưa có ghi nhận ghé, không có GPS xác minh. Có **23/42** số điện thoại và **10/42** mã số thuế; tất cả 42 điểm có URL nguồn HTTPS. Mã nghiên cứu có ID ổn định để tránh nhân đôi khi chạy lại. Một khách hàng chính `Liên Sương Trà Vinh` đã tồn tại không được nhập trùng dưới dạng điểm tiềm năng.

## File mã nguồn

- `apps/sales-mien-tay/backend/migrations/102_tra_vinh_d1_three_district_prospects_2026.sql` (37 điểm)
- `apps/sales-mien-tay/backend/migrations/103_tra_vinh_d1_supplement_2026.sql` (5 điểm bổ sung)

Hai migration có thể chạy lại: lọc theo nguồn và kiểm danh mục khách hiện hữu; không chuyển thành khách hàng, không sửa hồ sơ cũ, không ghi tọa độ không có bằng chứng. Chỉ dùng các nguồn công khai: Google Maps với place ID, danh bạ ngành hàng, nguồn phân phối sách, hồ sơ hộ kinh doanh, hồ sơ cung cấp hàng hóa.

## Những việc **chưa được chứng minh là hoàn tất**

- **Không khẳng định FULL = 100% cửa hàng thực tế.** Đặc biệt huyện Cầu Kè hiện chỉ tìm được 5 điểm công khai, huyện Càng Long 7 điểm; cần mở rộng kiểm tra từng xã/ấp, quanh chợ/trường, đường dân sinh bằng nguồn địa phương và Sales thực địa.
- Nguồn đăng ký kinh doanh/nhà cung cấp **không chứng minh có quầy bán lẻ đang hoạt động**. Nhiều hồ sơ có ghi chú phải kiểm tra địa chỉ, biển hiệu, tên trùng tại một địa chỉ hoặc ngừng hoạt động.
- Toàn bộ vẫn ở trạng thái **Chưa ghé**; không có chuyến thăm GPS, hình ảnh xác minh.
- Chưa có kiểm thử thiết bị PWA/Android và chưa xác thực API bằng phiên Admin/Sales tại production trong công việc dữ liệu này. Neon đã được kiểm qua SQL đọc lại và kiểm trùng nguồn.
- Trạng thái CI/GitHub Actions cần xem riêng; commit tồn tại không có nghĩa CI đã xanh.

## Đợt 2 theo lịch Owner đã chốt

Tiểu Cần, Châu Thành, Cầu Ngang (mỗi địa bàn cào đầy đủ trước khi chốt và chuyển tiếp). Đợt 3: Trà Cú, huyện Duyên Hải, thị xã Duyên Hải.

## SQL đối chiếu

```sql
SELECT district,
       COUNT(*) AS total,
       COUNT(*) FILTER (WHERE phone IS NOT NULL) AS phones,
       COUNT(*) FILTER (WHERE tax_code IS NOT NULL) AS tax_codes,
       COUNT(*) FILTER (WHERE research_source_url LIKE 'https://%') AS sourced,
       COUNT(*) FILTER (WHERE last_visit_at IS NOT NULL) AS visits
FROM public.field_prospects
WHERE province='Trà Vinh'
GROUP BY district ORDER BY district;
```
