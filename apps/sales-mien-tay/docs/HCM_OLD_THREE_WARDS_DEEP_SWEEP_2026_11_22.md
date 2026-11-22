# MCP-FBMN | Rà sâu 3 phường TP.HCM cũ — 22/11/2026

**Phạm vi:** chỉ phường mới Sài Gòn, Tân Định, Bến Thành trong TP.HCM trước 01/07/2025 theo NQ 1685. Địa danh mới lưu `field_prospects.ward_new`; `district` vẫn là `Quận 1` cũ phục vụ ACL. Không lấy Bình Dương, BR-VT cũ, Xuân Hòa, Cầu Ông Lãnh.

## Kết quả trên Neon production

| Phường mới | Nhà sách | VPP | Tổng | Có ĐT | Place ID |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sài Gòn | 20 | 3 | **23** | 19 | 13 |
| Tân Định | 4 | 5 | **9** | 5 | 6 |
| Bến Thành | 4 | 4 | **8** | 7 | 4 |
| **Tổng** | **28** | **12** | **40** | **31** | **23** |

Trước: 738 lead miền Tây, 0 HCM. Sau: 778 lead, trong đó 738 miền Tây nguyên vẹn và 40 HCM. 40/40 có URL nguồn công khai, 0 GPS/ghé thực tế giả, 0 record thuộc phường ngoài lô, 0 số ĐT trùng, 0 Place ID trùng. Re-run migrations 166 và 167: mỗi bản 0 INSERT.

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
