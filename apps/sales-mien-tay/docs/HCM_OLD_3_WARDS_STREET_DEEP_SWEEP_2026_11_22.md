# MCP-FBMN — TP.HCM cũ, rà sâu nhà sách/VPP 3 phường (22/11/2026)

**Phạm vi cứng:** lãnh thổ TP.HCM trước 01/07/2025; chỉ phường mới Sài Gòn, Tân Định, Bến Thành (đối chiếu 1685/NQ-UBTVQH15). Không gồm Bình Dương cũ, BR-VT cũ, phường Xuân Hòa, Cầu Ông Lãnh và các phường ngoài nhóm dù cùng Quận 1 cũ.

**Phương pháp:** ghép kết quả tìm theo địa danh cũ (Bến Nghé, Đa Kao, Tân Định, Phạm Ngũ Lão, Nguyễn Thái Bình), tuyến đường, nguồn Maps, trang nhà sách/nhà xuất bản và thông tin cửa hàng. Địa chỉ mới lưu `ward_new`, cột `district='Quận 1'` vẫn là quận cũ để giữ ACL. Không dùng nhãn Google Maps một mình để xác nhận ranh giới. Điểm không xác định rõ hoặc chỉ có đăng ký kinh doanh thì không nhập.

## Kết quả Neon production (sau migrations 164, 165, 166, 167)

| Phường mới | Nhà sách | VPP | Tổng | Có số điện thoại | Có Google place ID |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sài Gòn | 20 | 3 | **23** | 19 | 13 |
| Tân Định | 4 | 5 | **9** | 5 | 6 |
| Bến Thành | 4 | 4 | **8** | 7 | 4 |
| **Tổng** | **28** | **12** | **40** | **31** | **23** |

Trước nhóm: 738 lead của 13 tỉnh miền Tây cũ, 0 lead TP.HCM. Sau nhóm: 778 tổng lead; **738 miền Tây không đổi, 40 HCM**. Toàn bộ lead HCM có nguồn HTTPS và `ward_new` thuộc đúng 3 phường; không có dấu GPS ghé thực địa. Không trùng số điện thoại hoặc Google Place ID trong nhóm. Các migrations 166, 167 chạy lại **0 dòng chèn**. Số trên là **lead nghiên cứu, chưa phải khách hàng xác minh tại quầy**.

## Tuyến đã tìm và nơi còn dễ sót

- **Sài Gòn:** rà các cụm Nguyễn Huệ, Lê Lợi, Nguyễn Văn Bình (mỗi gian sách là một địa điểm riêng, phân biệt M01 / M06-07 / M08 / M14 / M16-17 / M20), Nguyễn Thị Minh Khai, Nguyễn Bỉnh Khiêm, Đinh Tiên Hoàng. Bổ sung NXB Trẻ M16–17, First News, Alpha Books, Nhà sách Tổng hợp 1, Hải An, Văn Lang, Hồng Ân, VPP Minh Thy/An Huy. **Chưa thể xác nhận quét đủ mọi hẻm/ngách**; cần tiếp tục hai bên Nguyễn Thị Minh Khai, xung quanh trường và chợ nhỏ, đối chiếu thứ tự gian sách thực địa.
- **Tân Định:** rà Trần Quang Khải, Nguyễn Phi Khanh, Nguyễn Văn Nguyễn, Đinh Tiên Hoàng, Hoàng Sa, Nguyễn Văn Thủ, Phan Ngữ. Đã có Hoàng Sa, Meily, Teayou, Tiny Strawee, Tri Văn, Thu Thảo 50, Khang Việt, Khai Tâm, Thúy Nga. **Cần rà tiếp** Lý Văn Phức, Trần Khánh Dư, Trần Quý Khoách, hẻm Trần Quang Khải và cửa hàng sát trường.
- **Bến Thành:** rà Nguyễn Trãi, Cống Quỳnh, Nguyễn Văn Tráng, Lê Lai, Bùi Thị Xuân, Ký Con. Đã có Phương Nam, Kim Đồng, Taipoz, Cây Đầu To, Pages of Passion (tầng 6 khác Cây Đầu To tầng 1), Thu Vũ, Khánh Trang, Nhà sách Tổng hợp 3. **Cần rà tiếp** Phạm Ngũ Lão, Đề Thám, Bùi Viện, Lê Thánh Tôn, Trương Định và chợ/hẻm; không tính cơ sở ngoài phường.

## Đã loại/để chờ bằng chứng

1. FAHASA Tân Định tại **387–389 Hai Bà Trưng**: thực địa giới **phường Xuân Hòa**, ngoài đúng 3 phường đầu; không nhầm tên cơ sở thành địa bàn.
2. Nhà sách Minh Khai **249 Nguyễn Thị Minh Khai** và Nhà sách Tổng hợp Trần Hưng Đạo **310–310A Trần Hưng Đạo**: **phường Cầu Ông Lãnh**, để dành lô phường tương ứng.
3. Nhà sách Phương Nam Vincom **72 Lê Thánh Tôn**: có nguồn cũ nhưng không xuất hiện trong hệ thống chi nhánh chính thức hiện hành, **chưa nhập** vì chưa xác thực hoạt động.
4. VPP công ty bán buôn/ship-only, cửa hàng photocopy đơn thuần, điểm không có tên bảng hiệu/số nhà rõ, doanh nghiệp chỉ đăng ký ngành nghề: **chưa nhập**.
5. Nhà sách Văn Lang **40–42 Nguyễn Thị Minh Khai**: có nguồn 2026 từ chính đơn vị, Google Maps và địa chỉ thuế nghiêng về **Sài Gòn**, song một số footer website ghi Tân Định. Đã lưu nguồn bất nhất trong `note`, Sales cần xác thực khi ghé; không tạo 2 địa điểm.

## Migration và tiêu chí kiểm tiếp

- `backend/migrations/163_hcm_old_ward_prospect_address_fields_2026.sql`: bổ sung địa danh mới/nguồn Maps.
- `backend/migrations/164_hcm_old_sai_gon_tan_dinh_ben_thanh_books_vpp_2026.sql`: 14 lead đầu.
- `backend/migrations/165_hcm_three_wards_street_followup_maps_2026.sql`: 9 lead + liên kết place IDs.
- `backend/migrations/166_hcm_three_wards_street_fill_2026.sql`: thêm 10 lead từ tuyến đường và cửa hàng nhỏ.
- `backend/migrations/167_hcm_old_3_wards_publisher_stores_2026.sql`: thêm 7 nhà sách có xác nhận bán lẻ từ đơn vị nguồn.

**Chưa nghiệm thu FULL 3/102 phường.** Độ phủ 40 điểm không phải số tối đa của địa bàn. Trước khi chuyển nhóm phải kiểm tiếp từng tuyến hai chiều, tìm cửa hàng VPP nhỏ, rà trường học/chợ dân cư, đối chiếu điện thoại và hoạt động tại địa chỉ. Không tự tăng số cho đủ định mức.

**Trạng thái ứng dụng:** thay đổi API/Flutter bộ lọc `ward_new` đã được commit riêng ở lượt trước, nhưng phải xác minh CI, deploy Worker/Vercel và test API/UI production trước khi tuyên bố chức năng đã live. Không trộn nghiệm thu SQL với nghiệm thu ứng dụng.

Nguồn định danh chính:
- NQ 1685: https://xaydungchinhsach.chinhphu.vn/toan-van-nghi-quyet-so-1685-nq-ubtvqh15-sap-xep-cac-dvhc-cap-xa-cua-thanh-pho-ho-chi-minh-nam-2025-119250616211341304.htm
- NXB Trẻ: https://www.nxbtre.com.vn/lien-he/
- NXB Tổng hợp TP.HCM: https://nxbhcm.com.vn/lien-he
- First News: https://firstnews.vn/lien-he
- Alpha Books: https://www.alphabooks.vn/he-thong-nha-sach
- VanlangBooks bài 2026: https://vanlang.vn/blogs/review-sach/sach-hoi-hoa
