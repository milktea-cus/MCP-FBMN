# MCP-FBMN | Rà sâu 3 phường TP.HCM cũ — 22/11/2026

**Phạm vi:** chỉ phường mới Sài Gòn, Tân Định, Bến Thành trong TP.HCM trước 01/07/2025 theo NQ 1685. Địa danh mới lưu `field_prospects.ward_new`; `district` vẫn là `Quận 1` cũ phục vụ ACL. Không lấy Bình Dương, BR-VT cũ, Xuân Hòa, Cầu Ông Lãnh.

## Kết quả trên Neon production

| Phường mới | Nhà sách | VPP | Tổng | Có ĐT | Place ID |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sài Gòn | 20 | 5 | **25** | 22 | 16 |
| Tân Định | 4 | 7 | **11** | 6 | 8 |
| Bến Thành | 4 | 10 | **14** | 11 | 12 |
| **Tổng** | **28** | **22** | **50** | **39** | **36** |

Trước: 738 lead miền Tây, 0 HCM. Sau vòng rà VPP đến migration 170: 788 lead, trong đó 738 miền Tây nguyên vẹn và 50 HCM. 50/50 có URL nguồn công khai, 0 GPS/ghé thực tế giả, 0 record thuộc phường ngoài lô, 0 số ĐT trùng, 0 Place ID trùng. Re-run migrations 166 và 167: mỗi bản 0 INSERT.

## Tuyến đường & hướng rà bù

- **Sài Gòn:** rà Nguyễn Huệ, Lê Lợi, Nguyễn Văn Bình (các gian M01, M06-07, M08, M14, M16-17, M20 và các gian không ghi số), Nguyễn Thị Minh Khai, Nguyễn Bỉnh Khiêm, Đinh Tiên Hoàng. Nhập mới các nhà sách Hải An, Văn Lang, NXB Trẻ M16-17, First News, Alpha Books, NXB Tổng hợp 1, Hồng Ân và các VPP Minh Thy, An Huy. **Còn:** hẻm, trục trường học, hai bên các tuyến, số gian chưa tìm được nguồn.
- **Tân Định:** rà Trần Quang Khải, Nguyễn Phi Khanh, Nguyễn Văn Nguyễn, Đinh Tiên Hoàng, Hoàng Sa, Nguyễn Văn Thủ, Phan Ngữ; có Hoàng Sa, Meily, Teayou, Tiny Strawee, Tri Văn, Thu Thảo 50, Khang Việt, Khai Tâm, Thúy Nga. **Còn:** Lý Văn Phức, Trần Khánh Dư, Trần Quý Khoách, hẻm gần trường/chợ.
- **Bến Thành:** rà Nguyễn Trãi, Cống Quỳnh, Nguyễn Văn Tráng, Lê Lai, Bùi Thị Xuân, Ký Con; có Phương Nam, Kim Đồng, Taipoz, Cây Đầu To lầu 1, Pages of Passion lầu 6 (hai cửa hàng khác nhau), Thu Vũ, Khánh Trang, Nhà sách Tổng hợp 3. **Còn:** Phạm Ngũ Lão, Đề Thám, Bùi Viện, Lê Thánh Tôn, Trương Định, các hẻm/cửa hàng nhỏ.

**Ngoài lô, không nhập:** FAHASA Tân Định 387-389 Hai Bà Trưng thực thuộc phường Xuân Hòa; Minh Khai 249 Nguyễn Thị Minh Khai và Nhà sách Tổng hợp 310-310A Trần Hưng Đạo thuộc phường Cầu Ông Lãnh. Cửa hàng Phương Nam Vincom 72 Lê Thánh Tôn: hoạt động hiện tại chưa xác minh nên giữ ngoài. Không nhập trường, photocopy thuần túy, doanh nghiệp chỉ đăng ký bán buôn, điểm thiếu địa chỉ hoặc trùng.

**Cần chú ý:** Nhà sách Văn Lang 40-42 Nguyễn Thị Minh Khai có các thông tin phường mâu thuẫn nhau ngay trên website (một bài 2026 + Maps + địa chỉ thuế cho Sài Gòn, một số footer ghi Tân Định). Đã ghi chú sai khác và cần Sales xác thực khi ghé. First News và Alpha Books ở Đường sách được website chính thức xác nhận, **chưa rõ số kiosk nên không bịa số**.

## Migrations và nguồn chứng minh

- `163_hcm_old_ward_prospect_address_fields_2026.sql`: cột phường mới riêng.
- `164_hcm_old_sai_gon_tan_dinh_ben_thanh_books_vpp_2026.sql`: 14 điểm.
- `165_hcm_three_wards_street_followup_maps_2026.sql`: 9 điểm.
- `166_hcm_three_wards_street_fill_2026.sql`: 10 điểm.
- `167_hcm_old_3_wards_publisher_stores_2026.sql`: 7 điểm.

Nguồn: [NQ1685](https://xaydungchinhsach.chinhphu.vn/toan-van-nghi-quyet-so-1685-nq-ubtvqh15-sap-xep-cac-dvhc-cap-xa-cua-thanh-pho-ho-chi-minh-nam-2025-119250616211341304.htm), [NXB Trẻ](https://www.nxbtre.com.vn/lien-he/), [NXB Tổng hợp](https://nxbhcm.com.vn/lien-he), [First News](https://firstnews.vn/lien-he), [Alpha Books](https://www.alphabooks.vn/he-thong-nha-sach), [Văn Lang 2026](https://vanlang.vn/blogs/review-sach/sach-hoi-hoa).

**Chưa khẳng định đã quét FULL 3 phường hoặc toàn bộ 102 phường.** Chưa có Sales xác minh thực địa. API/Flutter lọc phường được commit ở lượt trước nhưng cần kiểm CI + deployment Worker/Vercel và API/UI production riêng; SQL nhập Neon không đồng nghĩa tính năng lọc đã live.


## Cập nhật rà bù VPP tuyến nhỏ — migrations 168–170

- **Migration 168 (commit 6cc2944e): 8 lead VPP**. Sài Gòn: Hồng Duyên 60 Ngô Đức Kế. Tân Định: Phạm Xuân Hòa 2A Đinh Tiên Hoàng; Lê Khanh 16 Nguyễn Văn Giai. Bến Thành: Thu 111 Ký Con; Bình Minh 110 Lê Lai; Tri Thức 27 Lê Công Kiều; Duy Hùng 71 Nguyễn Thái Bình; Hùng 135 Nguyễn Thái Bình.
- **Migration 169 (commit cabd242a): 4 lead cũ được bổ sung liên hệ/bản đồ**, không thêm mới: Cây Đầu To số điện thoại; Tân Tiến số và Place ID; Taipoz và NXB Tổng hợp 3 Place ID.
- **Migration 170 (commit 5fba07ce): 2 lead VPP nghiên cứu**. Ngô Thoại Hoa 54 Lê Lợi (tên cửa hàng được nguồn doanh nghiệp định danh; Maps hiển thị tên chung và 0 đánh giá), cửa hàng 77 Nguyễn Thái Bình (tên bảng hiệu chưa rõ, chỉ dùng tên mô tả). **Cả hai cần xác minh hoạt động hiện tại tại quầy**; không coi là khách hàng đã khảo sát.
- Chạy lại cả 3 migration **168/169/170 => 0 INSERT/UPDATE**, kiểm tra **0 trùng phone**, **0 trùng Place ID**, **0 trùng phone với bảng customers**, **0 tự ghi ghé thăm**, **0 lệch 3 phường**, **50/50 có nguồn**.
- **Không nhập**: Bookbuy.vn 9 Lý Văn Phức (thiên về nhà sách online và văn phòng), Hiếu Cường 55 Hồ Tùng Mậu (địa chỉ lầu 2, nhà phân phối, chưa chứng minh quầy bán), Phúc Thảo 52 Đinh Tiên Hoàng/Minh Chánh 15 vs 15K NTMK (địa chỉ hoặc hoạt động chưa nhất quán), VPP Xương 34 Lê Lợi (nguồn cũ nhưng Maps hiện mô tả cửa hàng thêu/thời trang), VPP Thành 99B Bùi Thị Xuân (địa chỉ chung nhiều cơ sở khác), VPP 58 Nguyễn Bỉnh Khiêm (trùng nhiều doanh nghiệp, chưa xác minh shop), VPP 365 ở 365 Nguyễn Công Trứ (nguồn mới/cũ bất đồng phường).
- **Lưu ý nghiệp vụ:** Đây là **điểm tiềm năng nghiên cứu** (field_prospects), không phải dữ liệu khách hàng đã được Sales ghé chốt. Không ấn định đã rà FULL theo phường. Khi Sales ghé phải kiểm đúng tên bảng hiệu, địa chỉ, hàng hóa bán, khả năng gọi, GPS và phường thực tế.

### Tình trạng code/production tại thời điểm rà

API `market_prospects.ts` và Flutter UI lọc `ward_new` có trên GitHub `main` và CI đã có các job Flutter regression / IndexedDB / Cloudflare typecheck đạt. Tuy nhiên **Worker `field-sales-api` Cloudflare ghi lần sửa cuối 21/11/2026**, và **production Vercel READY còn ở commit 000f7365 (trước thay đổi lọc ward)**. Vì vậy **chưa được tuyên bố tính năng lọc phường mới đã live**; cần triển khai đúng artifact CI và **giữ toàn bộ secrets/bindings hiện có**. Không thay mã Worker bằng source TypeScript chưa bundle.

### Tiếp theo làm gì

1. Rà VPP hẻm và sát trường/chợ phường Tân Định (Trần Khánh Dư, Trần Quý Khoách, Bà Lê Chân, Lý Văn Phức), rồi Sài Gòn (Pasteur/Lý Tự Trọng/Hàm Nghi) và Bến Thành (Phạm Ngũ Lão/Đề Thám/Trương Định). Đối chiếu thực tế trước khi gán phường hoặc mở rộng lô.
2. Kiểm tất cả CI jobs trên `main` xong/đạt; triển khai backend/frontend qua connected platform khi có đúng build artifact tương thích và kiểm trực tiếp API Auth/ACL + UI filter ở URL production. Không tạo preview hay yêu cầu Owner thao tác CMD.
3. Rà trùng theo Place ID, địa chỉ, phone và khách hàng từng lô; riêng điểm thiếu bảng hiệu/hay nguồn cũ yêu cầu Sales ghé xác nhận trước khi chuyển thành khách hàng.

