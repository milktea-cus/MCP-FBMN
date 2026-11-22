# MCP-FBMN — KIỂM KÊ 13 TỈNH CŨ: KẾT THÚC VÒNG 1, BẮT ĐẦU VÒNG 2
Ngày: **21/11/2026**. Repository `milktea-cus/MCP-FBMN` branch `main`; Neon production project `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`.

## Cập nhật migration 160 — Hậu Giang cũ, 3 địa bàn đợt 2 (22/11/2026; snapshot hiện hành)

- **Chỉ rà tỉnh Hậu Giang cũ, đúng 3 địa bàn:** `Huyện Châu Thành A`, `Huyện Châu Thành`, `Thị xã Long Mỹ`. Không gộp tỉnh khác. [Báo cáo riêng, kèm nguồn và điểm loại trừ](OLD13_ROUND02_HAU_GIANG_3_DISTRICTS_BATCH02_2026_11_22.md).
- **Migration [`160_hau_giang_old_round02_chau_thanh_a_chau_thanh_tx_long_my_2026.sql`](../backend/migrations/160_hau_giang_old_round02_chau_thanh_a_chau_thanh_tx_long_my_2026.sql)**, commit [`9434b04`](https://github.com/milktea-cus/MCP-FBMN/commit/9434b0446be30cd1f591c8fcf4fa7f9b87581ee4): **4 lead nghiên cứu, chưa ghé**. Châu Thành A +2 (Nhà sách Anh Thư, VPP Thái Ngân), Châu Thành +1 (VPP Trường Tín), Thị xã Long Mỹ +1 (VPP Móm).
- **Neon production sau migration 160:** tổng **734 lead**, **132/134** địa bàn cũ có lead; số địa bàn có 1–2 lead giảm **27 → 24**; lead có số điện thoại **535**. Tất cả **734/734** có HTTPS/source key và trạng thái `new`; **0** được gắn GPS/visit, **0** trùng source key, batch 160 không trùng khách chính theo tên/số điện thoại. Chạy lại SQL 160 **0 dòng thêm**.
- **Độ phủ 3 địa bàn lần này:** Châu Thành A **4** (trước 2), Châu Thành **3** (trước 2), Thị xã Long Mỹ **3** (trước 2). Tất cả chỉ là đầu mối nghiên cứu, không suy diễn còn hoạt động năm 2026.
- **Địa giới cần tránh nhầm:** `VPP Trường Tín` được Maps hiển thị gắn `Châu Thành A`, nhưng `xã Đông Thạnh` theo Nghị định 06/2004/NĐ-CP thuộc **Huyện Châu Thành cũ**, nên nghiên cứu xếp Châu Thành và phải kiểm thực địa. `VPP Móm` ở Chiêm Thành Tấn thuộc **Thị xã Long Mỹ cũ**, không phải huyện Long Mỹ.
- **Điểm không nhập:** VPP Sao Mai/Chợ Bảy Ngàn có nguy cơ trùng `customers.Sao Mai` cùng chợ (không nhân đôi). Cơ sở Ánh Đào và thiết bị VPP Nguyên Phát chỉ có hồ sơ ngành/chưa có bằng chứng cửa hàng thực bán. Điểm `Cửa hàng sách 170 CMT8` của NXB Giáo dục có địa chỉ/số điện thoại nhưng tên riêng không đủ; giữ để tìm tiếp, chưa chèn. Các nhà sách Ngọc Tiến, Minh Thư, Thể Minh và Long Mỹ, VPP Song Di đã có trong DB.
- **Hậu Giang cũ:** đã xử lý 6/8 địa bàn trong 2 đợt nhóm 3, **đợt 3 còn 2 địa bàn** (`Thành phố Vị Thanh`, `Thành phố Ngã Bảy`). `Huyện Long Mỹ` thuộc đợt 1 vẫn **0 lead** (khác thị xã Long Mỹ); **Huyện Vĩnh Lợi/Bạc Liêu cũ** vẫn 0, không được tự thêm điểm khác huyện để đạt 134/134.
- **Nghiệm thu:** chỉ SQL và tài liệu; không deploy Worker/Vercel; kiểm CI của commit cuối riêng; chưa nghiệm thu API/Auth/PWA/Android hay GPS trên thiết bị thật.

## Cập nhật migration 159 — Hậu Giang cũ, chỉ 3 huyện (22/11/2026; snapshot lịch sử trước 160)

- **Phạm vi cố định:** `Huyện Long Mỹ`, `Huyện Vị Thủy`, `Huyện Phụng Hiệp` thuộc **Hậu Giang cũ**; KHÔNG rà lan tỉnh khác trong lô 159. [Báo cáo chi tiết nguồn, địa giới, trùng và các điểm cần Sales xác minh](OLD13_ROUND02_HAU_GIANG_3_DISTRICTS_BATCH01_2026_11_22.md).
- **Migration [`159_hau_giang_old_round02_three_districts_2026.sql`](../backend/migrations/159_hau_giang_old_round02_three_districts_2026.sql)**; commit [`9d80b89`](https://github.com/milktea-cus/MCP-FBMN/commit/9d80b893f55befb6999d55d3166cba3e3e997e95). Đã nhập **4 lead nghiên cứu chưa ghé**: Vị Thủy +2 (`Photo - VPP Phương Phương`, `VPP Sáu Cáo`), Phụng Hiệp +2 (`VPP Vân Duyên`, `VPP Việt Chương`); **Huyện Long Mỹ +0** do chưa thấy nguồn điểm bán đủ chuẩn đúng huyện.
- **Neon production sau migration 159:** **730** lead, phủ **132/134** địa bàn cũ; số địa bàn có 1–2 lead còn **27** (trước 159: 29); số có điện thoại **534**. Toàn bộ 730/730 lead `new`, có HTTPS và source key; GPS/lượt ghé đánh dấu **0**, source key trùng **0**. Chạy lại SQL 159 trả **0** dòng.
- **Độ phủ riêng 3 huyện đã rà:** `Huyện Long Mỹ: 0 lead`; `Huyện Vị Thủy: 4 lead`; `Huyện Phụng Hiệp: 4 lead`. `NS Thể Minh` khách chính nằm ở DB với gán `Huyện Long Mỹ` nhưng nguồn cho thấy thuộc thị xã cũ; không sửa `customers` trong migration lead và không đếm khách chính thành lead.
- **Nguồn loại trừ:** `Nhà sách Long Mỹ` số 142K/30-4 nằm ở **Thị xã Long Mỹ cũ** (không phải Huyện Long Mỹ); `VPP Sáu Nên` Kinh Cùng có danh bạ nhưng tên Google Maps khác (`Hương Giang`), không nhập; `Phương Vy` chỉ có hồ sơ bán buôn thiết bị và chi nhánh `Hồng Ân` tại Vĩnh Viễn đã ngừng, không nhập. Điểm từ nhà sách/VPP đã có trong `customers` hoặc `field_prospects` không thêm lại.
- **Trạng thái:** nghiên cứu nguồn công khai, chưa nghiệm thu cửa hàng đang hoạt động 2026, GPS 100m hoặc thiết bị thật. Chỉ sửa dữ liệu/tài liệu, không deploy lại Worker/Vercel. Đợt tiếp theo tiếp tục Hậu Giang cũ theo nhóm 3 địa bàn mỗi lượt, không trộn tỉnh.

## Cập nhật migration 158 — 22/11/2026 (snapshot lịch sử trước 159)

| Chỉ số | Neon production sau migration 158 |
|---|---:|
| Lead nghiên cứu `field_prospects` | **726** (+2 so với 157) |
| Địa bàn cũ có lead | **132/134** (không đổi) |
| Địa bàn còn 1–2 lead | **29** (giảm từ 31) |
| Lead có source URL HTTPS / source key | **726/726** / **726/726** |
| Lead trạng thái `new`, chưa ghé | **726/726** |
| Có lượt ghé / GPS ghé | **0** |
| Có số điện thoại | **533** |
| `research_source_key` trùng | **0** |

- SQL migration [`158_old_provinces_round02_an_minh_cu_lao_dung_2026.sql`](../backend/migrations/158_old_provinces_round02_an_minh_cu_lao_dung_2026.sql) đã commit trên `main` trước khi nhập Neon; commit [`af5cdc7`](https://github.com/milktea-cus/MCP-FBMN/commit/af5cdc700c22136c8596f0095c4bf138ab80a678). Chèn **2** bản ghi online chưa ghé:
  - `Tiệm Sách Huệ Minh` — `JW6V+8V9`, khu Thứ Mười Một/An Minh, **Kiên Giang cũ**, điện thoại `0398694325`, Google Maps ID `ChIJdUYyjWMrpzERzKzmP-i3JYg`, nguồn https://www.google.com/maps/search/?api=1&query=Ti%E1%BB%87m%20S%C3%A1ch%20Hu%E1%BB%87%20Minh%20An%20Minh&query_place_id=ChIJdUYyjWMrpzERzKzmP-i3JYg . **Chỉ là ứng viên**: Maps hiện xếp danh mục `Grocery store` dù tên Tiệm Sách; Sales cần gọi/ghé xác nhận có bán sách/VPP. Không tự suy ra hoạt động năm 2026.
  - `Cửa hàng văn phòng phẩm Cô Trâm` — `M572+P42`, Đoàn Thế Trung, khu An Thạnh/Cù Lao Dung, **Sóc Trăng cũ**, điện thoại `0939835194`, Google Maps ID `ChIJSUM0MQBJoDERTIfR6fnxeqw`, nguồn https://www.google.com/maps/search/?api=1&query=C%E1%BB%ADa%20h%C3%A0ng%20v%C4%83n%20ph%C3%B2ng%20ph%E1%BA%A9m%20C%C3%B4%20Tr%C3%A2m%20C%C3%B9%20Lao%20Dung&query_place_id=ChIJSUM0MQBJoDERTIfR6fnxeqw . Google Maps xếp `Stationery store`, phản hồi có đề cập mua dụng cụ học tập; vẫn chưa xác minh thực địa.
- Kiểm tra Neon **chạy lại migration 158 trả 0 dòng thêm**, cả 726 lead `new`, không dấu lượt ghé/GPS, `research_source_key` trùng 0. Không tạo khách chính hay gắn quyền Sales giả.
- **Cảnh báo nguồn trùng, không nhập:** `Thiệp cưới Nhung – In áo nhóm – Văn phòng phẩm` tại Ngũ Lạc / Huyện Duyên Hải đã tồn tại trong `field_prospects` (Google Maps ID `ChIJ75kfUDQloDERBqB_sVLHRT0`); không thêm lại từ nguồn Sổ Tay Vàng. `Dịch vụ VPP – Photocopy Đào`, `Hết Loan Ấp 10 Biển` (An Minh); `VPP Giang Thành`, `VPP – Hoa kiểng Phú Mỹ` (Giang Thành) đều đã nhập. `Nhà Sách Trí Oanh` số 9 An Dương Vương/Năm Căn đang chờ phân biệt với `Nhà sách Oanh Oanh` số 83 An Dương Vương/Năm Căn, không nhập để tránh trùng mờ; số điện thoại và Map ID khác nhau nhưng có thể cùng chủ/chuyển địa chỉ.
- **Hai huyện P0 vẫn trắng**: `Huyện Long Mỹ/Hậu Giang cũ` và `Huyện Vĩnh Lợi/Bạc Liêu cũ`. Nguồn rà lại có `Nhà Sách Long Mỹ` ở **thị xã Long Mỹ cũ**, `Công ty TNHH Sách và VPP Hậu Giang` ở **TP Vị Thanh cũ** (không phải huyện Long Mỹ); `Tin học Mực in Nam Phương` và `Tiệm Photo Hoài Nan` tại Vĩnh Lợi chủ yếu được Maps xếp `Print shop`/`Copying supply store`, chưa có chứng cứ bán sách/VPP. Không thêm để đạt chỉ tiêu 134/134.
- Đối chiếu báo cáo gốc và Neon về `NS Thể Minh`: khách chính đang gán Huyện Long Mỹ nhưng địa chỉ nguồn đặt tại **Thị xã Long Mỹ cũ**; giữ nguyên khách chính chờ đối soát chủ dữ liệu, không sửa phân quyền/tuyến. Không deploy Worker/Vercel vì chỉ bổ sung SQL/tài liệu, không được coi là nghiệm thu UI/API/Android.

## Cập nhật migration 157 — 21/11/2026 (snapshot lịch sử trước 158)

| Chỉ số | Neon production sau khi chạy migration 157 |
|---|---:|
| Lead nghiên cứu `field_prospects` | **724** (+1 so với 156) |
| Địa bàn cũ có lead | **132/134** (không đổi) |
| Địa bàn còn 1–2 lead | **31** (giảm từ 32) |
| Lead có URL HTTPS và research source key | **724/724** cho mỗi tiêu chí |
| `status=new`, chưa ghé | **724/724** |
| Có dấu lượt ghé / GPS chuyến ghé | **0** |
| Lead có số điện thoại | **531** |
| Trùng `research_source_key` | **0** |

- Migration [`157_old_provinces_round02_p1_thoi_lai_2026.sql`](../backend/migrations/157_old_provinces_round02_p1_thoi_lai_2026.sql), commit [`e1f8083`](https://github.com/milktea-cus/MCP-FBMN/commit/e1f80831e51507bcc1246db3b327541a3590ea9a): ghi **1 lead nghiên cứu online** `VPP Cô Thảo`, `3H54+QVF, ĐT922, Huyện Thới Lai, Cần Thơ cũ`, SĐT `0917432459`, source key `gmap:ChIJrVQLKQCRoDERsXJin0GU688`. Source: https://www.google.com/maps/search/?api=1&query=VPP%20Co%20Thao%20Thoi%20Lai&query_place_id=ChIJrVQLKQCRoDERsXJin0GU688 . Nguồn Maps ghi tên VPP nhưng phân loại `Store`, **chưa được Sales xác minh mặt hàng VPP, địa điểm hoặc hoạt động năm 2026**. Không thêm GPS, visit, khách chính, trạng thái đã bán.
- Sau đối soát Neon, chạy lại chính SQL migration 157 trả **0 dòng**, xác nhận idempotent; 724/724 research lead vẫn trạng thái `new` và không có dấu ghé.
- **Cảnh báo chống trùng liên địa bàn:** `Nhà Sách-Photocopy-VPP - Trường Long` tại `1087 ĐT926, Trường Long, Huyện Phong Điền cũ`, Maps ID `ChIJRQi6ZfqPoDERBM8Qwhr6zkY`, có số công khai `0967377514`. Số này **đã nằm trên lead `Nhà sách Hưng Thạnh` ở Quận Cái Răng cũ** (`gmap:ChIJVRCgQwCJoDERp0s309Py8jo`), chưa xác định có phải cùng chủ, số bị gán sai, hay trùng thông tin. **Không nhập điểm Trường Long**, không bỏ số để vượt chống trùng; cần gọi/xác minh trước khi quyết định.
- Các ứng viên `Nhà sách Thứ Hai - Công ty B.H` và `Văn phòng phẩm - Coffee - Nước ép Huỳnh Châu` của Huyện Thới Lai đã có trong `field_prospects`, **không nhập lặp**.
- **Hai huyện P0 trắng vẫn là `Huyện Long Mỹ/Hậu Giang cũ` và `Huyện Vĩnh Lợi/Bạc Liêu cũ`**. Điểm `Nhà sách Long Mỹ` xuất hiện trên nguồn thuộc **thị xã Long Mỹ cũ**; không gán sang huyện. Giữ cảnh báo khách chính `NS Thể Minh` gán sai địa bàn, không tự sửa khách chính vì liên quan phân quyền/tuyến Sales.
- Lô 157 chỉ thay đổi dữ liệu và tài liệu: **không deploy lại Worker/Vercel**; CI commit tài liệu được kiểm riêng, không được coi là nghiệm thu API/Auth/PWA/Android hay GPS thiết bị thực.

## Cập nhật migration 156 — 21/11/2026 (snapshot lịch sử trước 157)

| Chỉ số | Neon production |
|---|---:|
| Lead online nghiên cứu | **723** |
| Địa bàn cũ có lead | **132/134** |
| Địa bàn có 1–2 lead | **32** (giảm từ 36 đầu lượt) |
| URL HTTPS và research key | **723/723**; **723/723** |
| Trạng thái chưa ghé `new` | **723** |
| Lượt ghé hoặc GPS ghi vào lead | **0** |
| Có số điện thoại | **530** |

- Migration [`156_old_provinces_round02_p1_chau_thanh_o_mon_thot_not_2026.sql`](../backend/migrations/156_old_provinces_round02_p1_chau_thanh_o_mon_thot_not_2026.sql), commit [`fb5db87`](https://github.com/milktea-cus/MCP-FBMN/commit/fb5db87d93e5ea73914399f8aee765d433030e39): thêm **4** lead chưa ghé gồm VPP Song Di tại **Huyện Châu Thành/Hậu Giang cũ**, VPP Trí Tuệ + Minh Lợi tại **Quận Ô Môn cũ**, Nhà sách Xuân Châu tại **Quận Thốt Nốt cũ**. Nguồn Google Maps, chưa xác minh thực địa.
- Tổng lượt rà này: migrations 155 + 156 = **15 lead mới**, thêm huyện Kiên Hải vào danh sách địa bàn có lead. Còn **Huyện Long Mỹ/Hậu Giang cũ** và **Huyện Vĩnh Lợi/Bạc Liêu cũ** chưa có lead đủ chứng cứ; không gán doanh nghiệp bán buôn/cửa hàng ngoài huyện thành VPP bán lẻ.
- **Cảnh báo gán sai địa bàn khách chính, CHƯA SỬA DB:** `customers` đang gắn `NS Thể Minh` với `province=Hậu Giang`, `district=Huyện Long Mỹ` và địa chỉ `46 Nguyễn Huệ`. Tuy nhiên danh sách điểm bán từ **Tập đoàn Thiên Long** ghi `NS Thể Minh` ở **số 46 Nguyễn Huệ, KV2, phường Bình Thạnh, Thị xã Long Mỹ cũ**. Nguồn: https://thienlonggroup.com/news/don-long-khi-vuot-long-mon-cac-nha-sach-thuc-hien . Khuyến nghị chủ dữ liệu đối chiếu GPS/hồ sơ gốc, rồi mới xét sửa đúng huyện vì có thể ảnh hưởng quyền Sales/tuyến. Không đếm NS Thể Minh thành lead mới tại huyện và không tự di chuyển khách chính bằng migration nghiên cứu.
- Nguồn địa giới `ấp Phú Hòa` thuộc `xã Đông Phú`, **Huyện Châu Thành/Hậu Giang cũ**: https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/De-an-02-DA-UBND-2024-thanh-lap-thi-tran-Dong-Phu-thuoc-huyen-Chau-Thanh-Hau-Giang-640934.aspx.
- Đã loại trùng `Nhà sách Minh Thư` ĐT925/Châu Thành Hậu Giang vì Maps ID `ChIJEwGuv7RhoDER8p_t9-pBiOU` đã nằm trong `field_prospects`. Không nhầm với lead `Nhà sách Minh Thư` tại Cờ Đỏ, vốn có cảnh báo sai ánh xạ tên với `Nhà sách Nhuận Điền`.
- Kiểm lại migration 156: chạy lại thêm **0** bản ghi; batch không trùng tên/điện thoại với khách chính theo SQL, không trùng source key, không có GPS/lượt ghé. Các điểm chỉ có tên và phân loại bản đồ vẫn chờ Sales xác minh loại hàng thực bán và tình trạng hoạt động.
- CI workflow commit cuối, API/Auth, và máy thật cần kiểm riêng; không deploy Worker/Vercel chỉ vì đổi SQL/tài liệu.

### 32 địa bàn còn ít lead

| Tỉnh cũ | Huyện/thị xã/quận cũ (số lead) |
|---|---|
| An Giang | Huyện An Phú (2); Huyện Chợ Mới (2); Huyện Tri Tôn (2) |
| Bạc Liêu | Huyện Phước Long (2); Huyện Đông Hải (1) |
| Cà Mau | Huyện Ngọc Hiển (2); Huyện Năm Căn (2) |
| Cần Thơ | Huyện Phong Điền (2); Huyện Thới Lai (2); Huyện Vĩnh Thạnh (2) |
| Hậu Giang | Huyện Châu Thành (2); Huyện Châu Thành A (2); Huyện Phụng Hiệp (2); Huyện Vị Thủy (2); Thị xã Long Mỹ (2) |
| Kiên Giang | Huyện An Minh (2); Huyện Châu Thành (1); Huyện Giang Thành (2); Huyện Kiên Hải (1); Huyện Kiên Lương (2); Huyện U Minh Thượng (2); Huyện Vĩnh Thuận (2) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Cù Lao Dung (2); Huyện Mỹ Tú (2); Huyện Trần Đề (1); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Cao Lãnh (2); Huyện Châu Thành (2); Huyện Hồng Ngự (2) |

## P0/P1 — migration 155 đối soát 21/11/2026 (snapshot lịch sử trước 156)

| Chỉ số | Neon production |
|---|---:|
| Lead nghiên cứu toàn bộ 13 tỉnh cũ | **719** |
| Huyện/quận/thị xã/thành phố cũ đã có lead | **132/134** |
| Lead có URL nguồn HTTPS / research key | **719/719** / **719/719** |
| Trạng thái `new`, chưa ghé | **719** |
| Có lượt ghé hoặc GPS nghiên cứu bị gắn thành GPS xác minh | **0** |
| Nhà sách / VPP-đầu mối (phân loại nghiên cứu) | **387 / 332** |
| Có số điện thoại | **527** |
| Địa bàn chỉ có 1–2 lead | **34** (trước migration 155: **36**) |

- Migration [`155_old_provinces_round02_p0_kien_hai_p1_five_sparse_2026.sql`](../backend/migrations/155_old_provinces_round02_p0_kien_hai_p1_five_sparse_2026.sql), commit [`2708727`](https://github.com/milktea-cus/MCP-FBMN/commit/2708727eb7255f8339ae236fcff076448c8b51ca): **11 lead nghiên cứu**; Kiên Hải 1, Tịnh Biên 4, Gò Quao 2, Hà Tiên 2, Mỹ Tú 1, Hồng Ngự 1.
- **P0 tiến triển từ 131/134 lên 132/134**: phát hiện điểm `Dịch vụ & VPP Nguyệt Ánh` (Tổ 6 ấp An Phú, xã Nam Du CŨ, huyện Kiên Hải, Kiên Giang cũ; SĐT `0888776303`), Google Maps ID `ChIJfQ_Qv_IDpzERUxMF4hqS_R8`. Nguồn địa giới chính thức: https://kienhai.angiang.gov.vn/lich-su-hinh-thanh-huyen-kien-hai; chưa đến cửa hàng, chưa xác minh trực tiếp tồn tại hoặc bán hàng năm 2026.
- **Còn 2 huyện cũ chưa có lead nghiên cứu:** Huyện Long Mỹ (Hậu Giang cũ) và Huyện Vĩnh Lợi (Bạc Liêu cũ). Không đánh đồng `NS Thể Minh` (khách chính đã có ở Huyện Long Mỹ) với lead chưa nhập. Không gán điểm `Nhà sách Long Mỹ` ở thị xã sang huyện Long Mỹ.
- Phân loại nguồn rõ: `VPP Sa Sa`, `Ty Ty`, `Bảo Khang`, `Anh Khoa` từ Maps tại Tịnh Biên; `Kim Cương`, `Mỹ phẩm Lắm` tại Gò Quao; `Thanh Bình` và tiệm photo tại Hà Tiên; `Gia Linh` tại Mỹ Tú; `Lê Ngô` tại Hồng Ngự. Một số chỉ có loại `Novelty store`/`Wholesaler`, **không coi là đã xác minh có quầy bán lẻ VPP**; Sales phải kiểm trực tiếp. `Thanh Bình` có hồ sơ ngành bán lẻ tại https://thuvienphapluat.vn/ma-so-thue/van-phong-pham-thanh-binh-mst-1701431743.html.
- **Ứng viên chưa nhập cho Long Mỹ**: Công ty TNHH Thiết bị Văn phòng Phương Vy, MST `6300350408`, ấp 1 TT Vĩnh Viễn cũ: nguồn ghi ngành chính **bán buôn máy móc, thiết bị và phụ tùng**, không xác nhận cửa hàng sách/VPP bán lẻ. https://smartvision.com.vn/doanh-nghiep/ho-so/3036579-cong-ty-tnhh-thiet-bi-van-phong-phuong-vy/ . Chỉ làm đầu mối cần gọi xác minh, không tính làm cửa hàng. **Vĩnh Lợi:** các kết quả tìm được chủ yếu nằm TP Bạc Liêu cũ, tạp hóa hoặc hồ sơ đã ngừng; không tự gán sang Vĩnh Lợi.
- **Chất lượng dữ liệu:** các truy vấn kiểm sau migration 155 trả `research_source_key` trùng **0**, tên/điện thoại trùng với `customers` của batch 155 **0**, lượt ghé/GPS **0**. Mọi lead mới là `status=new`, `source_kind=manual`, có URL nguồn; URL không chứng minh cửa hàng còn hoạt động. CI/API, phân quyền và thiết bị thật cần nghiệm thu riêng.

### 34 địa bàn còn 1–2 lead nghiên cứu

| Tỉnh cũ | Địa bàn còn ít lead |
|---|---|
| An Giang | Huyện An Phú (2); Huyện Chợ Mới (2); Huyện Tri Tôn (2) |
| Bạc Liêu | Huyện Phước Long (2); Huyện Đông Hải (1) |
| Cà Mau | Huyện Ngọc Hiển (2); Huyện Năm Căn (2) |
| Cần Thơ | Huyện Phong Điền (2); Huyện Thới Lai (2); Huyện Vĩnh Thạnh (2); Quận Thốt Nốt (2); Quận Ô Môn (2) |
| Hậu Giang | Huyện Châu Thành (1); Huyện Châu Thành A (2); Huyện Phụng Hiệp (2); Huyện Vị Thủy (2); Thị xã Long Mỹ (2) |
| Kiên Giang | Huyện An Minh (2); Huyện Châu Thành (1); Huyện Giang Thành (2); Huyện Kiên Hải (1); Huyện Kiên Lương (2); Huyện U Minh Thượng (2); Huyện Vĩnh Thuận (2) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Cù Lao Dung (2); Huyện Mỹ Tú (2); Huyện Trần Đề (1); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Cao Lãnh (2); Huyện Châu Thành (2); Huyện Hồng Ngự (2) |

## P1: Migrations 153–154 — đối soát Neon production ngày 21/11/2026 (snapshot lịch sử trước 155)

| Chỉ số | Neon production |
|---|---:|
| Lead nghiên cứu (13 tỉnh cũ) | **708** |
| Địa bàn huyện/đô thị cũ có lead | **131/134** |
| URL nguồn HTTPS / source key | **708/708** / **708/708** |
| Trạng thái `new`, chưa ghé | **708/708** |
| Liên kết lượt ghé/GPS đã xác minh | **0** |
| Nhà sách / VPP-đầu mối nghiên cứu | **387 / 321** |
| Có điện thoại | **517** |
| Địa bàn có 1–2 lead | **36** (trước khi bổ sung: **46**) |

**Đã nhập thêm 29 lead nghiên cứu** trong vòng này từ nguồn Google Maps, danh bạ địa phương Sổ Tay Vàng và danh sách đối tác Văn phòng phẩm Hồng Hà. Đây **không phải** số điểm đã ghé hoặc đã xác minh hoạt động năm 2026.

- Migration [`153_old_provinces_round02_p1_sparse_six_provinces_2026.sql`](../backend/migrations/153_old_provinces_round02_p1_sparse_six_provinces_2026.sql): **20 lead / 12 địa bàn / 6 tỉnh cũ**, commit [`7db28c0`](https://github.com/milktea-cus/MCP-FBMN/commit/7db28c02e8da39267a579dafa1c6f58751434846).
- Migration [`154_old_provinces_round02_p1_tamnong_giongrieng_myxuyen_2026.sql`](../backend/migrations/154_old_provinces_round02_p1_tamnong_giongrieng_myxuyen_2026.sql): **9 lead** ở Tam Nông (3), Giồng Riềng (2), Mỹ Xuyên (4), commit [`3bd4432`](https://github.com/milktea-cus/MCP-FBMN/commit/3bd44327fff86ea6e56271e50c305622d81f4c57).
- Migration 153 và 154 đều kiểm **idempotent**: chạy lại trên Neon production thêm **0** bản ghi. Kiểm toàn bảng không có trùng `research_source_key`, kiểm tên/số điện thoại giữa **batch 153+154 với khách chính** có **0** xung đột theo phép so khớp đã chạy. **Không** thay đổi `customers`, không ghi GPS, không gắn visit.
- Một số cơ sở ghi tên đa ngành (photo, máy tính, camera, nước ép) hoặc được trang danh bạ phân loại chung. **Cần Sales kiểm tra thực sự bán sách/VPP**; không được gọi là điểm bán đã xác minh chỉ vì tên hay URL Maps.
- Các ứng viên khác bị loại khi đối soát vì đã có lead trước đó: Cửa hàng sách báo Á Châu (Châu Phú), Nhà sách Châu Thành và Hiệu sách Thái Hưng (An Giang), Nhà sách Ngã Năm 2 (Sóc Trăng), Nhà sách Hà Tiên, Nhà sách Hoa Hồng (Kiên Lương), Nhà sách Gia Hân (Vĩnh Châu), và nhiều cửa hàng khác. Không được thêm nguồn khác để nhân đôi khách.
- Tránh nhầm địa giới sau 2025: huyện Châu Thành thuộc Đồng Tháp **cũ** không tự nhận điểm chỉ ghi `Châu Thành, Đồng Tháp` **mới** (có thể nằm ở Tiền Giang cũ). Hai điểm có tên `VPP Dung`, `Quầy sách Lynh Mai` đang chờ đối chiếu xã cũ; **không nhập** chỉ để tăng số.
- **Ba huyện cũ hoàn toàn chưa có lead** không đổi: Kiên Hải (Kiên Giang), Huyện Long Mỹ (Hậu Giang), Vĩnh Lợi (Bạc Liêu). Đã có [checklist khảo sát thực địa với 15 trường mốc](OLD13_ROUND02_P0_THREE_DISTRICTS_SALES_FIELD_VERIFY_2026_11_21.md); không tạo lead không đủ nguồn.
- Nguồn tham khảo cụ thể cho migration 154: https://sotayvang.com/nha-sach-tran-hung-dao-tt-tram-chim/ ; https://sotayvang.com/hieu-sach-minh-phung-tt-tram-chim/ ; https://sotayvang.com/van-phong-pham-thuy-duong-ban-tan-dinh/ ; https://sotayvang.com/co-so-in-photocopy-van-phong-pham-vu-hien-ban-tan-dinh/ ; https://sotayvang.com/cua-hang-van-phong-pham-trung-hung-tt-my-xuyen/.
- Chưa nghiệm thu API/thiết bị thật từ các thay đổi SQL/tài liệu; không deploy Worker hay Vercel riêng cho dữ liệu này. **CI đợt mới phải kiểm ở GitHub Actions**.

### Danh sách 36 địa bàn còn chỉ 1–2 lead

| Tỉnh cũ | Địa bàn (số lead nghiên cứu) |
|---|---|
| An Giang | Huyện An Phú (2); Huyện Chợ Mới (2); Huyện Tri Tôn (2); Thị xã Tịnh Biên (1) |
| Bạc Liêu | Huyện Phước Long (2); Huyện Đông Hải (1) |
| Cà Mau | Huyện Ngọc Hiển (2); Huyện Năm Căn (2) |
| Cần Thơ | Huyện Phong Điền (2); Huyện Thới Lai (2); Huyện Vĩnh Thạnh (2); Quận Thốt Nốt (2); Quận Ô Môn (2) |
| Hậu Giang | Huyện Châu Thành (1); Huyện Châu Thành A (2); Huyện Phụng Hiệp (2); Huyện Vị Thủy (2); Thị xã Long Mỹ (2) |
| Kiên Giang | Huyện An Minh (2); Huyện Châu Thành (1); Huyện Giang Thành (2); Huyện Gò Quao (1); Huyện Kiên Lương (2); Huyện U Minh Thượng (2); Huyện Vĩnh Thuận (2); Thành phố Hà Tiên (1) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Cù Lao Dung (2); Huyện Mỹ Tú (1); Huyện Trần Đề (1); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Cao Lãnh (2); Huyện Châu Thành (2); Huyện Hồng Ngự (1) |

## P1 migration 152 — đối soát production ngày 21/11/2026 (snapshot lịch sử)

| Chỉ tiêu | Số liệu thực tế |
|---|---:|
| Lead nghiên cứu `field_prospects` | **679** |
| Huyện/quận/thị xã/thành phố cũ có lead | **131/134** |
| Lead có URL HTTPS và source key | **679/679**, **679/679** |
| Lead trạng thái `new`, chưa ghé | **679** |
| GPS hoặc lượt ghé gắn lead | **0** |
| Nhà sách / VPP-đầu mối | **380 / 299** |
| Lead có điện thoại | **489** |
| Địa bàn có 1–2 lead | **46** |

- **Commit dữ liệu:** [`290186e`](https://github.com/milktea-cus/MCP-FBMN/commit/290186e3c9fc17715bc7d5e8e1974e7ad4021e73), file `backend/migrations/152_old_provinces_round02_p1_co_do_cao_lanh_2026.sql` đã được commit **trước khi chạy** trên Neon production.
- **Đã nhập 3 lead P1 chưa ghé:**
  - **VPP Cô Duyên** — Chợ đầu mối, xã Mỹ Hiệp, **Huyện Cao Lãnh / Đồng Tháp cũ**, điện thoại `0939917100`. Nguồn điểm bán Hồng Hà: https://vpphongha.com.vn/vi/gaga ; chợ Mỹ Hiệp được xác nhận thuộc huyện Cao Lãnh cũ bởi Cổng tỉnh Đồng Tháp: https://dongthap.gov.vn/web/cong-thong-tin-dtp/tin-tuc/chi-tiet?id=6639346.
  - **VPP Cường Quyên** — Đường số 12, plus code 3CVJ+GC4, **Huyện Cờ Đỏ / Cần Thơ cũ**, Maps ID `ChIJhR-1vaKZoDERk4xN_5zpbus`. Chưa có số điện thoại / chưa xác minh bán lẻ.
  - **VPP - Sửa chữa vi tính Đại Quang** — Đường Hà Huy Giáp, ấp Thới Bình, plus code 3CRM+M3M, **Huyện Cờ Đỏ / Cần Thơ cũ**, Maps ID `ChIJO-01r2eZoDERyFg2RRfywOU`. Danh mục bản đồ là camera/CCTV, chỉ tên cơ sở có VPP; **Sales phải xác minh có bán VPP**.
- SQL migration chạy lại **0 dòng thêm**, đối soát trong batch với `customers` theo tên/số điện thoại **0 trùng**, toàn bảng không có `research_source_key` trùng, và tất cả 679 lead không có dấu GPS/lượt ghé. **Không tự xác nhận cửa hàng còn hoạt động năm 2026.**
- **Còn 3 huyện P0 không có lead:** Huyện Vĩnh Lợi/Bạc Liêu, Huyện Long Mỹ/Hậu Giang, Huyện Kiên Hải/Kiên Giang. Đã tạo [checklist 15 trường mốc và tuyến khảo sát thực địa](OLD13_ROUND02_P0_THREE_DISTRICTS_SALES_FIELD_VERIFY_2026_11_21.md) (Vĩnh Lợi 10; Long Mỹ 4; Kiên Hải 1). 15 mốc này không có GPS được xác minh và **không phải điểm bán**.
- **Sai ánh xạ nguồn cần xử lý riêng:** một lead `Nhà sách Minh Thư` ở **ấp Thới Bình, Cờ Đỏ** từ batch cũ đang dẫn nguồn Hồng Hà, nhưng Hồng Hà liệt kê địa chỉ này là **Nhà sách Nhuận Điền** (0939688455); Minh Thư thuộc **An Khánh**. Không nhân đôi bằng cách chèn lead Nhuận Điền mới, cũng không tự sửa bản ghi cũ trong migration append-only; cần đối soát và chỉnh lý nguồn có kiểm soát.
- CI của commit `760e078` (đợt trước) đã **success**: https://github.com/milktea-cus/MCP-FBMN/actions/runs/44905191143 . CI của các commit mới phải kiểm riêng. PWA/Android và xác thực GPS chưa nghiệm thu từ các thay đổi chỉ liên quan SQL/tài liệu.

## P0: Migration 151 — đối soát production 21/11/2026 (snapshot lịch sử trước 152)

| Chỉ tiêu | Neon production |
|---|---:|
| Lead nghiên cứu | **676** |
| Địa bàn cũ có lead | **131/134** |
| Lead có URL nguồn HTTPS / source key | **676 / 676** |
| Trạng thái `new`, chưa ghé | **676** |
| Gắn visit hoặc tọa độ ghé thăm | **0** |
| Nhà sách / VPP-đầu mối | **380 / 296** |
| Có điện thoại | **488** |
| Địa bàn chỉ có 1–2 lead | **47** |

- Commit migration `151_old_provinces_round02_tran_de_thay_dong_2026.sql`: [`aa400b4`](https://github.com/milktea-cus/MCP-FBMN/commit/aa400b46fd33456cf8ee87aec3a61f651ac38675), nhập thành công **1** lead `Cơ sở In Ấn - Văn Phòng Phẩm Thầy Đông`, 417 Khu 3 ấp Châu Thành, **Lịch Hội Thượng / Huyện Trần Đề / Sóc Trăng cũ**. Maps listing `ChIJ0YmJgMa1oTERPo9-ZHru8ws`, điện thoại `0914578063`: https://www.google.com/maps/search/?api=1&query=Thay%20Dong%20Van%20Phong%20Pham%20Lich%20Hoi%20Thuong&query_place_id=ChIJ0YmJgMa1oTERPo9-ZHru8ws.
- **LƯU Ý nghiệp vụ:** Maps xếp điểm Thầy Đông là *print shop*, tên cơ sở có `Văn Phòng Phẩm`. Đây chỉ là lead **chờ Sales gọi để xác minh có bán VPP và còn hoạt động**, không phải một nhà sách đã xác minh. Không có GPS, check-in hay khách chính được tạo.
- SQL migration **idempotent**: chạy lần hai trả **0** bản ghi; đối soát `research_source_key` không trùng, tên/số điện thoại với `customers` của batch 151: **0**.
- **Còn 3 địa bàn P0 chưa có lead:** Kiên Giang / Huyện Kiên Hải; Hậu Giang / Huyện Long Mỹ; Bạc Liêu / Huyện Vĩnh Lợi.
- **Ứng viên loại trừ để tránh nhập sai:**
  - **Long Mỹ huyện:** `Dụng Cụ Học Sinh - Trần Bắc` ghi `ĐT930, ấp 2, Long Mỹ, Hậu Giang`, không rõ xã và không phân biệt **huyện** với **thị xã**. Nguồn https://giatot24gio.com/dung-cu-hoc-sinh-tran-bac-dd93082.html — chỉ lưu để nghiên cứu, chưa nhập.
  - **Long Mỹ huyện:** `Chi nhánh Nhà sách Hồng Ân` có hồ sơ chi nhánh đã **ngừng hoạt động và chấm dứt hiệu lực mã số thuế**. Nguồn https://masothue.com/1801093287-001-chi-nhanh-cong-ty-tnhh-mot-thanh-vien-phan-dang-nha-sach-hong-an — không nhập; nguồn còn có các địa chỉ liên quan khác, không tự gán huyện.
  - **Vĩnh Lợi:** `Tạp hóa Cô Ly` tại Châu Hưng A có mô tả VPP từ trang giới thiệu tổng hợp nhưng chưa có bằng chứng độc lập về mặt hàng VPP thực bán. Nguồn https://hanoidep.vn/cua-hang-tap-hoa-co-ly-chau-hung-a-vinh-loi-bac-lieu/ — không nhập. `Tin học Mực in Nam Phương` được bản đồ phân loại tiệm in, chưa đủ căn cứ là **điểm bán sách/VPP**; không nhập.
  - **Kiên Hải:** tìm theo Hòn Tre, Lại Sơn, Hòn Nghệ nhưng chưa tìm được địa chỉ nhà sách/VPP đủ cụ thể để nhập. Các hồ sơ doanh nghiệp và điểm bán điện thoại/đèn không được coi là nhà sách/VPP.
  - **Trần Đề:** `Hồng Gia Phúc` bản đồ định vị ở **Thới An Đông / Bình Thủy, Cần Thơ cũ**, không gán sang Trần Đề chỉ vì trang tổng hợp có từ khóa Trần Đề.
- **Chưa nghiệm thu UI, API, GPS hay thiết bị thật chỉ từ bản ghi SQL.** Đối soát CI phải thực hiện riêng; CI vắng mặt không đồng nghĩa xanh.

## Cập nhật Neon production sau migration 150 — 21/11/2026 (snapshot lịch sử)

> **Snapshot lịch sử trước migration 151**, đã đối soát trực tiếp trên project Neon production `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`. Các bảng phía dưới được giữ lại dưới dạng **snapshot lịch sử trước migration 150** để tránh mất dấu vết kiểm kê.

| Chỉ tiêu | Hiện tại |
|---|---:|
| Lead nghiên cứu `field_prospects` | **675** |
| Địa bàn cũ có lead | **130/134** |
| URL nguồn HTTPS / research source key | **675/675 · 675/675** |
| Lead trạng thái new, chưa ghé | **675/675** |
| Lead liên kết lượt ghé | **0** |
| Nhà sách / VPP-đầu mối | **380 / 295** |
| Lead có số điện thoại | **487** |
| Địa bàn đã có lead nhưng chỉ 1–2 | **46** |

- Migration: `backend/migrations/150_old_provinces_round02_p0_gaps_2026.sql`, commit [`14eeecc`](https://github.com/milktea-cus/MCP-FBMN/commit/14eeecc0f8d17cfc4c27f2e6bb8b49dbae162420), đã có **7 lead** trên Neon: Giang Thành 2, Cù Lao Dung 2, Vị Thủy 2, Đông Hải 1. Tất cả là **nghiên cứu trực tuyến, chưa xác minh tại cửa hàng**.
- **4/134 địa bàn cũ chưa có lead:** Kiên Giang / Huyện Kiên Hải; Hậu Giang / Huyện Long Mỹ (khác **Thị xã Long Mỹ**); Sóc Trăng / Huyện Trần Đề; Bạc Liêu / Huyện Vĩnh Lợi.
- CI: không tìm thấy workflow run hoặc commit status ghi nhận cho commit `14eeecc`; **không được diễn giải là CI xanh**. Chưa nghiệm thu API, phân quyền và app thiết bị thực tế chỉ từ việc import SQL.
- Đối soát vòng này không thấy trùng `research_source_key`, hoặc trùng tên/số điện thoại với khách chính **trong 7 lead của migration 150** theo bộ kiểm SQL; kiểm trùng mờ và việc cửa hàng thực sự hoạt động vẫn cần Sales xác minh.
- Nguồn tìm kiếm thêm ngày 21/11: tên “tạp hóa – văn phòng phẩm Phú Lên” xuất hiện khi tìm Trần Đề nhưng địa chỉ nguồn ghi **ấp Phú Giao, Mỹ Xuyên**, không gán sai Trần Đề (https://giatot24gio.com/tiem-tap-hoa-soc-trang/). “Nhà Sách Long Mỹ” có địa chỉ theo hồ sơ thị trấn Long Mỹ cũ, chưa đủ chắc để gán **Huyện Long Mỹ** thay vì **Thị xã Long Mỹ**, không nhập.
- Chưa có lead mới được nhập từ lượt rà bù bổ sung này. **Không tạo dữ liệu giả để đạt 134/134.**

### 46 địa bàn có 1–2 lead (snapshot hiện hành)

| Tỉnh cũ | Địa bàn (số lead) |
|---|---|
| An Giang | Huyện An Phú (2); Huyện Châu Phú (2); Huyện Châu Thành (1); Huyện Chợ Mới (2); Huyện Thoại Sơn (2); Huyện Tri Tôn (2); Thị xã Tịnh Biên (1) |
| Bạc Liêu | Huyện Hòa Bình (2); Huyện Phước Long (2); Huyện Đông Hải (1) |
| Cà Mau | Huyện Ngọc Hiển (2); Huyện Năm Căn (2); Huyện Thới Bình (2); Huyện Trần Văn Thời (2) |
| Cần Thơ | Huyện Cờ Đỏ (1); Huyện Phong Điền (1); Huyện Thới Lai (1); Huyện Vĩnh Thạnh (2); Quận Bình Thủy (2); Quận Thốt Nốt (2); Quận Ô Môn (2) |
| Hậu Giang | Huyện Châu Thành (1); Huyện Châu Thành A (1); Huyện Phụng Hiệp (1); Huyện Vị Thủy (2); Thị xã Long Mỹ (2) |
| Kiên Giang | Huyện An Minh (2); Huyện Châu Thành (1); Huyện Giang Thành (2); Huyện Giồng Riềng (2); Huyện Gò Quao (1); Huyện Kiên Lương (2); Huyện U Minh Thượng (2); Huyện Vĩnh Thuận (1); Thành phố Hà Tiên (1) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Cù Lao Dung (2); Huyện Mỹ Tú (1); Huyện Mỹ Xuyên (2); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Cao Lãnh (1); Huyện Châu Thành (2); Huyện Hồng Ngự (1); Huyện Tam Nông (1) |

## Nguyên tắc cố định
- Đã đi **đủ 13/13 tỉnh cũ**, ba đợt theo địa bàn trên mỗi tỉnh. **Không** có nghĩa tìm đủ mọi cửa hàng ngoài đời.
- Key `province`/`district` **theo địa giới tỉnh, quận/huyện/thị xã/thành phố CŨ** trong `backend/src/districts_old.json`; tuyệt đối không nhập nhầm theo tỉnh mới sau 2025.
- `field_prospects` là **lead nghiên cứu trực tuyến** chờ Sales kiểm chứng; không được báo là khách hàng, điểm đã ghé hoặc cửa hàng đã hoạt động 2026.
- Nguồn công khai bao gồm cửa hàng trên Maps, danh bạ, danh sách nhà phân phối, cơ sở chỉ có đăng ký ngành nghề hoặc bán sỉ. **URL HTTPS không đồng nghĩa nguồn đã được xác minh hoặc cửa hàng có thật/đang mở**. Riêng doanh nghiệp chỉ có mã ngành phải ưu tiên gọi trước khi ghé.
- Mỗi migration insert-only, có source key và chặn trùng exact với khách/lead. Không sửa `customers`, không gán GPS, không tạo visit, không gắn `is_selling`.
- Chỉ sau khi kết thúc vòng nhập đủ 13 tỉnh, mới bắt đầu vòng rà bù; các migration 146–149 là **vòng 2**, không thuộc vòng 1.

## Đối chiếu Neon production toàn bộ (snapshot lịch sử trước migration 150)

| Tỉnh cũ | Lead | Huyện/đô thị có lead | Nhà sách | VPP/đầu mối | Điện thoại |
|---|---:|---:|---:|---:|---:|
| Long An | 95 | 15/15 | 59 | 36 | 65 |
| Tiền Giang | 95 | 11/11 | 37 | 58 | 70 |
| Bến Tre | 77 | 9/9 | 41 | 36 | 54 |
| Trà Vinh | 79 | 9/9 | 21 | 58 | 43 |
| Vĩnh Long | 76 | 8/8 | 33 | 43 | 49 |
| Đồng Tháp | 50 | 12/12 | 34 | 16 | 43 |
| An Giang | 34 | 11/11 | 26 | 8 | 31 |
| Kiên Giang | 39 | 13/15 | 30 | 9 | 31 |
| Hậu Giang | 12 | 6/8 | 11 | 1 | 11 |
| Sóc Trăng | 32 | 9/11 | 22 | 10 | 26 |
| Bạc Liêu | 23 | 5/7 | 19 | 4 | 21 |
| Cà Mau | 30 | 9/9 | 24 | 6 | 19 |
| Cần Thơ | 26 | 9/9 | 21 | 5 | 22 |
| **Tổng** | **668** | **126/134** | **378** | **290** | **485** |

- **659** lead khi hoàn thành nhập lượt đầu toàn 13 tỉnh, **9** lead bổ sung đầu vòng 2 = **668**.
- **668/668** có URL nguồn HTTPS; **668/668** có research_source_key; **668/668** source manual/status new; **668/668** ghi CHƯA GHÉ; **0** có GPS/visit đánh dấu.
- Số có MST: **87**. Không được suy ra số liệu VAT của mọi điểm bán.
- Đã kiểm SQL trùng exact `province+district+name+address`, `research_source_key`, `province+district+phone` và chồng tên/phone với khách chính: **0** xung đột trong các phép kiểm đã chạy. Tương đồng địa chỉ thay đổi, tên tắt, số điện thoại đổi hoặc cùng chuỗi **có thể vẫn trùng**, phải xác minh thực địa.
- CI xanh, API/Auth theo người dùng Sales, màn hình PWA/Android và GPS trên máy thật **chưa được nghiệm thu** qua đợt nhập dữ liệu này. Không deploy Worker hoặc Vercel chỉ vì đổi DB.

## 8 địa bàn cũ chưa có **lead nghiên cứu** (snapshot lịch sử trước migration 150)

| STT | Tỉnh cũ | Địa bàn cũ | Khách chính hiện có |
|---:|---|---|---|
| 1 | Kiên Giang | Huyện Kiên Hải | Không có khách chính theo địa bàn |
| 2 | Kiên Giang | Huyện Giang Thành | Không có khách chính theo địa bàn |
| 3 | Hậu Giang | Huyện Vị Thủy | 1 khách chính: NS Thích |
| 4 | Hậu Giang | Huyện Long Mỹ | 1 khách chính: NS Thể Minh |
| 5 | Sóc Trăng | Huyện Cù Lao Dung | Không có khách chính theo địa bàn |
| 6 | Sóc Trăng | Huyện Trần Đề | Không có khách chính theo địa bàn |
| 7 | Bạc Liêu | Huyện Vĩnh Lợi | Không có khách chính theo địa bàn |
| 8 | Bạc Liêu | Huyện Đông Hải | Không có khách chính theo địa bàn |

**Lưu ý quan trọng:** Huyện Vị Thủy đã có khách chính NS Thích; Huyện Long Mỹ đã có khách chính NS Thể Minh. `0 lead` không có nghĩa `0 khách` hoặc `0 điểm bán ngoài đời`. Không được nhân đôi khách chính thành lead mới.

## 42 địa bàn có 1–2 lead (snapshot lịch sử trước migration 150)

| Tỉnh | Địa bàn ít lead (số) |
|---|---|
| Trà Vinh | Huyện Duyên Hải (2) |
| Đồng Tháp | Huyện Hồng Ngự (1); Huyện Tam Nông (1); Huyện Cao Lãnh (1); Huyện Châu Thành (2) |
| An Giang | Huyện An Phú (2); Huyện Châu Phú (2); Thị xã Tịnh Biên (1); Huyện Tri Tôn (2); Huyện Châu Thành (1); Huyện Chợ Mới (2); Huyện Thoại Sơn (2) |
| Kiên Giang | Thành phố Hà Tiên (1); Huyện Kiên Lương (2); Huyện Châu Thành (1); Huyện Giồng Riềng (2); Huyện Gò Quao (1); Huyện An Minh (2); Huyện Vĩnh Thuận (1); Huyện U Minh Thượng (2) |
| Hậu Giang | Huyện Châu Thành A (1); Huyện Châu Thành (1); Huyện Phụng Hiệp (1); Thị xã Long Mỹ (2) |
| Sóc Trăng | Huyện Châu Thành (2); Huyện Mỹ Tú (1); Huyện Mỹ Xuyên (2); Thị xã Ngã Năm (2); Thị xã Vĩnh Châu (2) |
| Bạc Liêu | Huyện Phước Long (2); Huyện Hòa Bình (2) |
| Cà Mau | Huyện Thới Bình (2); Huyện Trần Văn Thời (2); Huyện Năm Căn (2); Huyện Ngọc Hiển (2) |
| Cần Thơ | Quận Ô Môn (2); Quận Bình Thủy (2); Quận Thốt Nốt (2); Huyện Vĩnh Thạnh (2); Huyện Cờ Đỏ (1); Huyện Phong Điền (1); Huyện Thới Lai (1) |

## Vòng 2 đã thực thi — migration và phân loại nguồn

- `146_kien_giang_old_round02_chau_thanh_u_minh_thuong_2026.sql`, commit `592f0c1cb213e972b7f68e730300f3978e32eb7f`: Châu Thành 1 VPP (Quách Lỷ), U Minh Thượng 2 (Cô Nga, Trung Hiếu); tất cả **chưa ghé**.
- `147_soc_trang_old_round02_chau_thanh_kesach_myxuyen_2026.sql`, commit `20999571866fffc52aceb14e9289caf02940a145`: Châu Thành 2 nhà sách (Ngọc Thanh, Phương Thảo), Kế Sách 1 LEDO Books, Mỹ Xuyên 1 Hiệu sách Thông Minh; hồ sơ Phương Thảo chỉ từ đăng ký thuế, **chưa xác minh cửa hàng**.
- `148_soc_trang_old_round02_supplement_2026.sql`, commit `e27f1bc83f2de3d6658385d98455e51fe89faae0`: Mỹ Tú 1 Tạp hóa Bảy Tỷ có dụng cụ học tập, **KHÔNG coi là nhà sách chuyên doanh**.
- `149_bac_lieu_old_round02_supplement_2026.sql`, commit `7681fbbfeb5464964b0428d2e86a24db60cb91d0`: TP Bạc Liêu 1 VPP Tiến Phát, chưa ghé.
- Migrations 146 và 147 đã được đọc từ GitHub và chạy lại trên production, đều trả **0 dòng thêm**. Migration 148/149 cần kiểm tương tự nếu cần tái đối soát.
- Không nhập Công ty TM&DV Trần Đề (MST `2200809070`): nguồn dữ liệu cập nhật 17/09/2026 ghi **không hoạt động tại địa chỉ đã đăng ký**, mặc dù hồ sơ có ngành 4761 sách/VPP, không dùng để làm đẹp độ phủ. Nguồn https://dulieuphapluat.vn/cong-cu/ma-so-thue/2200809070-cong-ty-tnhh-thuong-mai-va-dich-vu-tran-de.html
- Không nhập các hồ sơ công ty VPP Nam Hợp Nhất/Huỳnh Như vào **Đông Hải Bạc Liêu cũ** vì nguồn tra cứu chính xác lại đặt trụ sở ở TP.HCM/Hòa Bình Bạc Liêu cũ; cần tránh sai địa giới và công ty không có quầy bán lẻ.
- Không nhập lại NS Thích Vị Thủy và quầy sách Giáo Hoàng Bạc Liêu vào leads: một là khách chính có sẵn, một dùng cùng số điện thoại với khách VPP Thanh Xuân trong tỉnh.

## Luồng tiếp theo trong vòng rà bù

1. **P0 — 4 địa bàn còn thiếu lead (sau migration 150)**: tìm theo chợ, trường tiểu học/THCS/THPT, ấp/xã lịch sử, danh sách nhà phát hành và tuyến VPP; ưu tiên có vị trí Maps + số điện thoại. Với đảo Kiên Hải và Giang Thành khó tìm nguồn, giữ trạng thái chưa có lead thay vì bịa cửa hàng.
2. **P1 — 42 địa bàn đang có 1–2 lead**: quét ít nhất một lượt theo thị trấn + xã, không chỉ trung tâm huyện; phân biệt cửa hàng lẻ, doanh nghiệp có mã ngành, tiệm photo, tạp hóa có VPP.
3. **P2 — địa bàn còn lại**: tìm biến thể tên/chi nhánh/địa chỉ sau sáp nhập và dùng Sales thực địa kiểm tra GPS 100m khi ghé; không tự cập nhật vị trí đã được xác minh của khách chính.
4. **Mỗi lô**: SQL migration append-only trực tiếp trên `main`, chạy Neon production, đối soát tỉnh/huyện cũ, source URL, trùng key/phone/MST/tên+địa chỉ, kiểm 0 GPS/checkin giả, báo trạng thái CI/API/thiết bị trung thực.

## Các câu SQL đối chiếu ngắn

```sql
SELECT province,district,count(*) total FROM public.field_prospects GROUP BY 1,2 ORDER BY 1,2;
SELECT province,count(*) total,count(DISTINCT district) covered FROM public.field_prospects GROUP BY province ORDER BY province;
SELECT research_batch,count(*) total FROM public.field_prospects GROUP BY research_batch ORDER BY research_batch;
SELECT research_source_key,count(*) FROM public.field_prospects GROUP BY research_source_key HAVING count(*)>1;
```
