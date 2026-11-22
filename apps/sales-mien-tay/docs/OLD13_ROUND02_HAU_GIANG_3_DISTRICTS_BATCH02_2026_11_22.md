# MCP-FBMN — HẬU GIANG CŨ — VÒNG 2, ĐỢT 2 (3 ĐỊA BÀN)

**Ngày rà trực tuyến:** 22/11/2026. **Tỉnh cũ duy nhất:** Hậu Giang. **Đúng 3 địa bàn:** `Huyện Châu Thành A`, `Huyện Châu Thành`, `Thị xã Long Mỹ`. Không gom sang các tỉnh khác. Địa giới từ `apps/sales-mien-tay/backend/src/districts_old.json`, đối chiếu nghị định Chính phủ. **Kết quả là lead nghiên cứu chờ Sales xác minh; không được coi là cửa hàng đã ghé hoặc đã hoạt động năm 2026.**

## Kết quả Neon production sau migration 160

| Địa bàn Hậu Giang cũ | Trước | Thêm | Sau | Nguồn mới |
|---|---:|---:|---:|---|
| Huyện Châu Thành A | 2 | **2** | **4** | Nhà sách Anh Thư, VPP Thái Ngân |
| Huyện Châu Thành | 2 | **1** | **3** | VPP Trường Tín (Maps đang gán nhầm Châu Thành A) |
| Thị xã Long Mỹ | 2 | **1** | **3** | VPP Móm |
| **Tổng ba địa bàn** | **6** | **4** | **10** | Không thêm trường học/đơn vị bán buôn thuần túy |

**Toàn 13 tỉnh cũ:** `field_prospects=734`, `132/134` địa bàn có lead, **24 địa bàn còn 1–2 lead**, 535 lead có điện thoại; HTTPS/source key `734/734`, trạng thái `new` `734/734`; đánh dấu visit/GPS **0**; trùng source key **0**; kiểm tên/điện thoại batch 160 so với khách chính **0** xung đột. Chạy lại nguyên SQL **0** bản ghi (idempotent).

**Migration:** [`160_hau_giang_old_round02_chau_thanh_a_chau_thanh_tx_long_my_2026.sql`](../backend/migrations/160_hau_giang_old_round02_chau_thanh_a_chau_thanh_tx_long_my_2026.sql); commit [`9434b04`](https://github.com/milktea-cus/MCP-FBMN/commit/9434b0446be30cd1f591c8fcf4fa7f9b87581ee4). SQL commit trên `main` trước khi nhập Neon production, không sửa bảng khách chính, không tạo check-in.

## Bốn lead đã ghi (đều chưa ghé)

| Huyện/thị xã cũ | Tên | Địa chỉ nguồn | SĐT | Nguồn và giới hạn |
|---|---|---|---|---|
| **Châu Thành A** | **Nhà sách Anh Thư** | QL1A, thị trấn Cái Tắc cũ | **0985228303** | [Sổ Tay Vàng](https://sotayvang.com/nha-sach-anh-thu-thi-tran-cai-tac/) có tên, địa chỉ, số điện thoại; listing cũ, không xác nhận cửa hàng còn hoạt động năm 2026 |
| **Châu Thành A** | **VPP Thái Ngân** | **38 QL61, ấp Thị Tứ, TT Rạch Gòi cũ** | Chưa có số đầy đủ | [Contact.page](https://vn-vi422679-cu-a-ha-ng-va-n-pho-ng-pha-m-tha-i-nga-n.contact.page/galleries) ghi tên, địa chỉ và nhóm VPP/thiệp cưới-in ấn. Số điện thoại trên danh bạ chỉ hiển thị một phần, không đoán số |
| **Châu Thành** | **VPP Trường Tín** | **WPMF+C9H, Nguyễn Văn Quang, xã Đông Thạnh cũ** | Không công khai | [Google Maps](https://www.google.com/maps/search/?api=1&query=Van%20phong%20pham%20Truong%20Tin%20Dong%20Thanh%20Hau%20Giang&query_place_id=ChIJ8yU0X6-LoDERHZ-VrrQHv_w) ID `ChIJ8yU0X6-LoDERHZ-VrrQHv_w`; Maps/business listing gán **Châu Thành A** nhưng [Nghị định 06/2004/NĐ-CP](https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Nghi-dinh-06-2004-ND-CP-dieu-chinh-dia-gioi-hanh-chinh-xa-thuoc-huyen-Chau-Thanh-A-thuoc-tinh-Hau-Giang-52395.aspx) xác định **Đông Thạnh thuộc huyện Châu Thành cũ**; cần Sales kiểm tra vị trí đúng |
| **Thị xã Long Mỹ** | **VPP Móm** | **1 Chiêm Thành Tấn, khu phường Thuận An cũ** | Không công khai | [Google Maps](https://www.google.com/maps/search/?api=1&query=Van%20phong%20pham%20Mom%20Chiem%20Thanh%20Tan%20Long%20My&query_place_id=ChIJjyIHLQDloDERNfsifd2KxFE) ID `ChIJjyIHLQDloDERNfsifd2KxFE`; đường Chiêm Thành Tấn thuộc **thị xã Long Mỹ cũ**, không phải huyện Long Mỹ. [Tham chiếu địa giới đường/phường cũ](https://infodoanhnghiep.com/Can-Tho/Phuong-Long-My/) |

**Tài liệu pháp lý Châu Thành A:** [Nghị định 34/2007/NĐ-CP](https://chinhphu.vn/default.aspx?docid=20997&pageid=27160) xác nhận Rạch Gòi/Cái Tắc thuộc huyện Châu Thành A cũ. Địa chỉ hành chính sau 2025 có thể ghi **TP Cần Thơ**; trong DB phải giữ **Hậu Giang cũ**.

## Đã rà nhưng không tạo lead mới

- **Văn phòng phẩm Sao Mai** tại **chợ Bảy Ngàn/7000, Châu Thành A cũ**: nhà sản xuất [Hồng Hà](https://vpphongha.com.vn/vi/gaga) liệt kê số **0902696732**, nhưng `customers` Neon đã có khách **Sao Mai** cùng khu vực chợ Bảy Ngàn, dù khách chưa có điện thoại. Đây là nguy cơ **trùng mờ**, KHÔNG chèn lead để tăng số. Chỉ sau đối chiếu chủ quầy mới quyết định bổ sung số vào khách (luồng chỉnh khách riêng, không tự sửa).
- **Nhà sách Ngọc Tiến** (TT Một Ngàn, Châu Thành A), **Nhà sách Minh Thư** và **VPP Song Di** (Huyện Châu Thành), **Nhà sách Long Mỹ**, **Nhà sách Thể Minh** (Thị xã Long Mỹ) đã có trong `field_prospects`; không nhập lại dù có thêm nguồn [Thiên Long](https://thienlonggroup.com/news/don-long-khi-vuot-long-mon-cac-nha-sach-thuc-hien).
- **Công ty TNHH MTV Ánh Đào** trên đường Hùng Vương, TT Ngã Sáu, Huyện Châu Thành: [hồ sơ ngành chính 4761](https://infodoanhnghiep.com/thong-tin/Cong-Ty-TNHH-MTV-Anh-Dao-52268.html) nhưng **chưa tìm được bằng chứng một điểm bán lẻ sách/VPP thực tế mang tên này**. Chỉ lưu làm đầu mối gọi xác minh, chưa chèn.
- **Hộ kinh doanh cửa hàng thiết bị VPP Nguyên Phát** khu Mái Dầm: mới thấy đăng ký/địa chỉ doanh nghiệp, chưa đối chiếu được bảng hiệu và mặt hàng thực bán, không nhập.
- **Nguyễn Thanh 3 Photocopy** ở Cái Tắc là đơn vị photocopy, chưa có nguồn cho thấy **bán** sách/học phẩm nên chưa nhập.
- [NXB Giáo dục](https://nxbgd.vn/Attachments/files/PDF/He%20thong%20cua%20hang%20toan%20quoc%202025-2026.pdf) có điểm `Cửa hàng sách số 170 CMT8` thuộc **Thị xã Long Mỹ** nhưng không ghi tên định danh riêng; giữ làm mốc tìm/quét tiếp, không tạo lead tên giả. **Không đánh đồng với Huyện Long Mỹ còn 0 lead.**

## Phần chưa xác minh và hành động Sales

- **Anh Thư, Thái Ngân, Trường Tín, Móm:** gọi/đến đúng cửa hàng trước khi đánh dấu đã ghé và xác nhận sản phẩm thực bán. **Không** suy ra giờ mở cửa, số điện thoại thiếu, GPS hay ảnh cửa hàng từ dữ liệu trực tuyến.
- **Trường Tín:** đặc biệt đối chiếu biển tên, số nhà, Plus Code và xã Đông Thạnh cũ với bản đồ thực địa; nguồn bản đồ có điểm **xung đột tên huyện**. Nếu thực địa nằm khác huyện, phải chỉnh lý nguồn/địa bàn với nhật ký; không tự chuyển khách chính.
- **NS Thể Minh:** ở `customers` vẫn gắn `Huyện Long Mỹ`, trong khi nguồn Thiên Long xác nhận `Thị xã Long Mỹ cũ`. Không sửa bảng khách/điều tuyến/phân quyền trong migration này.
- Đợt 3 Hậu Giang cũ chỉ còn **Thành phố Vị Thanh và Thành phố Ngã Bảy** chưa rà trong chuỗi 3 nhóm, tức **2 địa bàn còn lại của tổng 8 địa bàn**. Không chuyển sang tỉnh khác để đủ máy móc ba huyện và không coi việc đã tìm online là đã quét hết cửa hàng thực địa.
