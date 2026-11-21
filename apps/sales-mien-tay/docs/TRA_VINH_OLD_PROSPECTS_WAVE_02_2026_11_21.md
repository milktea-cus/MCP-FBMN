# TRÀ VINH CŨ — ĐỢT 2/3: TIỂU CẦN, CHÂU THÀNH, CẦU NGANG
Ngày đối chiếu: 21/11/2026. Repo: milktea-cus/MCP-FBMN, nhánh main.

## Phạm vi
- Huyện Tiểu Cần cũ: 6 điểm nghiên cứu.
- Huyện Châu Thành **Trà Vinh cũ**: 5 điểm nghiên cứu; không nhầm với Châu Thành Bến Tre cũ.
- Huyện Cầu Ngang cũ: 6 điểm nghiên cứu.

Tổng 17 điểm được ghi trực tiếp vào public.field_prospects bằng migration 104; 8 điểm có số điện thoại, 5 điểm có MST, 17/17 URL nguồn HTTPS; tất cả status='new', chưa ghé, chưa có GPS xác minh. Một số số điện thoại lấy từ danh bạ cũ nên chưa được gọi xác nhận.

## Mã nguồn và đối chiếu
- Migration: `apps/sales-mien-tay/backend/migrations/104_tra_vinh_d2_three_district_prospects_2026.sql`
- Commit migration: `19506d95983f3750efb38cafca2095c27743f6ff`.
- Neo production đọc lại: Châu Thành 5, Cầu Ngang 6, Tiểu Cần 6.
- Không có mã nguồn trùng, không trùng cặp tên+địa chỉ trong tập Trà Vinh, không có tên trùng khách hàng chính; chạy lại migration 104 trả 0 dòng mới.
- Trước đợt 2: Trà Vinh 42 điểm qua 3 địa bàn; sau đợt 2: **59 điểm qua 6/9 địa bàn cũ**. Ghi thêm 17, không xóa/sửa 42 điểm cũ.

## Kiểm tra rủi ro quan trọng
- Điểm kinh doanh có đăng ký MST, có hồ sơ nhà thầu, hoặc có tên trong danh bạ không chứng minh còn quầy bán lẻ hoạt động. Đặc biệt Cửa hàng Bảy Hồng (Cầu Ngang) có nguồn danh bạ đánh dấu đóng; giữ nghiên cứu, ghi cảnh báo; không đánh dấu đang mở.
- Các điểm chưa rõ số nhà hoặc chỉ có Plus Code: Ngọc Bá 2, VPP Thầy Khoa, VPP Thầy Tâm tại Tiểu Cần. Những điểm này chỉ có dẫn nguồn định vị tìm kiếm, tuyệt đối không ghi tọa độ xác minh.
- Sách Cầu Ngang (262 đường 3/2) và Bảy Hồng (260 đường 3/2) cần Sales kiểm tra là hai cửa hàng riêng hay hai biển hiệu của cùng một cơ sở.
- Chi nhánh 2a Bookstore có địa chỉ cũ Mỹ Long, Cầu Ngang dù trang danh bạ gắn tên TP Trà Vinh.
- Châu Thành đúng tỉnh Trà Vinh cũ, tránh lẫn với tên cùng huyện tại Bến Tre cũ.
- Không tự chuyển thành khách hàng hoặc bật `is_selling`; không sửa ảnh, GPS, tuyến/visit.

## Chưa thể gọi FULL tuyệt đối
Báo cáo chứng minh đã nhập 17 ứng viên có nguồn và kiểm chống trùng, KHÔNG chứng minh không còn cửa hàng VPP/nhà sách tại các xã/ấp chưa có dấu vết online. Cần Sales tìm thực địa tại thị trấn Tiểu Cần, Cầu Quan, thị trấn Châu Thành, Mỹ Long, thị trấn Cầu Ngang và các xã lân cận; rà chợ, trường học, đường nhỏ. Không chế thêm cửa hàng cho đẹp số liệu.

## Đợt 3
Trà Cú, huyện Duyên Hải cũ, thị xã Duyên Hải cũ.

## SQL nghiệm thu
```sql
SELECT district, count(*) AS total,
 count(*) FILTER (WHERE phone IS NOT NULL) AS phones,
 count(*) FILTER (WHERE tax_code IS NOT NULL) AS taxes,
 count(*) FILTER (WHERE research_source_url LIKE 'https://%') AS sourced,
 count(*) FILTER (WHERE last_visit_at IS NOT NULL) AS visits
FROM public.field_prospects
WHERE province='Trà Vinh'
GROUP BY district ORDER BY district;
```
