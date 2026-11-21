# MCP-FBMN — TIỀN GIANG CŨ, ĐỢT 2/3: TP GÒ CÔNG, GÒ CÔNG ĐÔNG, GÒ CÔNG TÂY, TÂN PHÚ ĐÔNG

**Ngày nghiên cứu & nghiệm thu DB:** 21/11/2026. **Repo:** `milktea-cus/MCP-FBMN`, branch `main`. **DB:** Neon production project `raspy-bar-51596929`.

## Phạm vi theo đúng 3 đợt địa bàn (11 địa bàn cũ = 4+4+3)

- **Đợt 1**: TP Mỹ Tho, Châu Thành, Chợ Gạo, Tân Phước — đã ghi 39 lead, migrations 113/114.
- **Đợt 2**: **TP Gò Công, Gò Công Đông, Gò Công Tây, Tân Phú Đông** — kết quả 31 lead, migrations 115/116.
- **Đợt 3**: TX Cai Lậy, huyện Cai Lậy, huyện Cái Bè — chưa ghi dữ liệu trong pha này.

Tỉnh/địa bàn cũ được giữ ở `province='Tiền Giang'`, `district` theo cấp huyện trước sáp nhập tỉnh thành Đồng Tháp năm 2025, phục vụ phân quyền và kế hoạch Sales. **Xã Tân Trung được chuyển từ huyện Gò Công Đông sang TP Gò Công từ 01/05/2024**, nên điểm Nhà sách Phương Nam 2379 ấp Mỹ Xuân, xã Tân Trung được ghi vào **TP Gò Công**, không phải Gò Công Đông (NQ 1013/NQ-UBTVQH15 và danh sách cấp xã Đồng Tháp 2025).

## Kết quả đợt 2 — đọc lại trực tiếp Neon production

| Địa bàn cũ | Migration 115 | Bổ sung 116 | Tổng | Nhà sách | VPP/đầu mối | Có ĐT | Có MST |
|---|---:|---:|---:|---:|---:|---:|---:|
| TP Gò Công | 12 | 0 | **12** | 5 | 7 | 10 | 2 |
| Huyện Gò Công Đông | 7 | 1 | **8** | 2 | 6 | 6 | 1 |
| Huyện Gò Công Tây | 8 | 0 | **8** | 3 | 5 | 6 | 2 |
| Huyện Tân Phú Đông | 2 | 1 | **3** | 0 | 3 | 1 | 0 |
| **Tổng** | **29** | **2** | **31** | **10** | **21** | **23** | **5** |

- `apps/sales-mien-tay/backend/migrations/115_tien_giang_old_wave02_go_cong_districts_2026.sql` — commit `e194b27dbcd0fc74b698b9066f62b50d091d40e7`.
- `apps/sales-mien-tay/backend/migrations/116_tien_giang_old_wave02_deep_supplement_2026.sql` — commit `63adc125d8adbc816c7a90378fa3f51ceec5e7af`.
- Đợt 2 đủ **31/31 URL nguồn HTTPS**, **31/31 `status='new'` và `last_visit_at IS NULL`** (Chưa ghé); không gán GPS, ảnh, chuyển khách hàng, bán hàng hoặc check-in giả.

## Lũy kế Tiền Giang sau đợt 2

| Địa bàn cũ | Số lead hiện có |
|---|---:|
| TP Mỹ Tho | 16 |
| Châu Thành | 5 |
| Chợ Gạo | 13 |
| Tân Phước | 5 |
| TP Gò Công | 12 |
| Gò Công Đông | 8 |
| Gò Công Tây | 8 |
| Tân Phú Đông | 3 |
| **TỔNG 8/11 địa bàn** | **70** |

Từ 39 đợt 1 + 31 đợt 2: **70 điểm tiềm năng**, **52/70 có điện thoại**, **8/70 có MST**, **70/70 nguồn HTTPS**, **27 nhà sách**, **43 VPP/đầu mối**. Không có visit nào; toàn bộ là đối tượng nghiên cứu, không phải đã xác minh hoạt động bán lẻ.

## Nguồn, gộp trùng và cảnh báo quan trọng

- **Maps Place IDs** cho Nhà sách Gò Công LABOCO, Bảo Long, Thảo Vinh, Quế House, Ngọc Trâm, Cô Dũng, Minh Khuê, Nhà Cầu Vồng, Trung Hiếu, Minh Triết, Thanh Thủy, Phú Khang, Minh Đức, Năng Dẻ, và nhiều đầu mối khác; source URL riêng từng bản ghi.
- **Minh Long Book** hệ thống đại lý tại `https://www.minhlongbook.com.vn/pages/he-thong-phan-phoi`: Nhà sách Việt Văn 01 Hai Bà Trưng, Gò Công.
- **Hồng Hà** điểm bán `https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu`: Nhà sách Gò Công/Nhà sách LABOCO.
- **Nhà sách Phương Nam, xã Tân Trung**: một số directory lịch sử ghi huyện Gò Công Đông; đã kiểm tra ranh giới hành chính từ 2024 để gắn TP Gò Công.
- **Nhà sách Nhật Minh (NS-Nhật Minh)** đã tồn tại trong `customers` tại 17D Rạch Gầm TP Gò Công; không đưa “Nhà sách Nhật Minh 68 Lê Lợi” thành lead mới vì chưa chứng minh hai thực thể độc lập.
- **Nhà sách Cô Dũng** có nhiều Place IDs nhưng cùng số điện thoại, gộp một. **Nhà sách Thanh Thủy** ĐT877 có các số liên lạc khác nhau giữa các nguồn, gộp một và gắn note kiểm tra.
- **VPP Băng Tuyền, 13 Trần Hưng Đạo** có nguồn danh bạ thông báo đóng cửa vào tháng 6/2025, không nhập dưới dạng cửa hàng còn hoạt động.
- **Bổ sung sâu (migration 116)**: Văn phòng phẩm Phu Sương xã Tân Thới cũ, Tân Phú Đông (Plus Code 7HFJ+7QC; thiếu số nhà/điện thoại) và Hoàng Anh Thư STORE, ấp 1 xã Tân Đông cũ, Gò Công Đông (có thông tin in ấn/cửa hàng; cần xác minh mặt hàng VPP và hoạt động). Không dùng địa chỉ “Tân Phú Đông” ở phường cùng tên tại Sa Đéc/Đồng Tháp để nhập nhầm vào huyện Tân Phú Đông cũ Tiền Giang.
- **Bán sỉ/không chắc cửa hàng bán lẻ**: Dương Văn Thiện, Tiến Phú Quí, Bách hóa Vĩnh Lợi, các cửa hàng gas có VPP, Hoàng Anh Thư STORE, Phu Sương. Cần Sales gọi/ghé và xác minh quầy/loại hàng, ghi chú cảnh báo theo từng record.

## Nghiệm thu Neon production & giới hạn

Đã thực hiện:
- Đọc lại nhóm huyện, từng research_batch: **31 thêm**, **70 toàn Tiền Giang**, **8/11 huyện cũ có dữ liệu**.
- SQL trùng `research_source_key`: **0**; trùng chính xác `district + lower(trim(name)) + lower(trim(address_line))`: **0**; trùng chính xác tên khách hàng chính: **0**.
- Chạy lại **migrations 115 và 116** từ file trực tiếp trên `main`: **0 bản ghi mới** trong cả hai lần (idempotency).
- **CI chưa có bằng chứng xanh**: combined commit statuses trên GitHub trả `statuses=[]`. Chưa có UAT API/Auth theo Sales/Manager và PWA/Android. Không đổi mã nguồn frontend/Worker, nên không deploy app riêng trong pha dữ liệu này.

**Không thể gọi FULL = không còn cửa hàng nào sót.** Đặc biệt **Tân Phú Đông chỉ có 3 ứng viên công khai**, không có nhà sách riêng với nguồn đủ rõ; huyện cù lao có nhiều tiệm học phẩm/tiệm tạp hóa quanh chợ, trường, xã Tân Thới, Phú Thạnh, Tân Phú, Phú Tân, Phú Đông, Phú Thạnh. Gò Công Đông/Gò Công Tây còn điểm chợ xã/đường nhỏ cần Sales kiểm tra thực địa. Nhiều thông tin thời gian hoạt động lấy từ directory cũ, chưa xác minh hiện trạng.

## SQL đối chiếu

```sql
SELECT district, COUNT(*) total,
 COUNT(*) FILTER(WHERE phone IS NOT NULL) phones,
 COUNT(*) FILTER(WHERE tax_code IS NOT NULL) taxes,
 COUNT(*) FILTER(WHERE research_source_url LIKE 'https://%') sourced,
 COUNT(*) FILTER(WHERE last_visit_at IS NOT NULL) actual_visits
FROM public.field_prospects WHERE province='Tiền Giang'
GROUP BY district ORDER BY district;
```

**Đợt 3 tiếp theo:** TX Cai Lậy, huyện Cai Lậy, huyện Cái Bè.
