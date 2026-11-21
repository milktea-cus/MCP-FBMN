# MCP-FBMN — P0 CHI TIẾT KIỂM THỰC ĐỊA 3 HUYỆN CŨ CHƯA CÓ LEAD

**Ngày đối soát:** 21/11/2026. **Nguồn:** bảng `public.schools`, `public.customers`, `public.field_prospects` trên Neon production `raspy-bar-51596929` / `br-super-mountain-bdije4mj`. Không phải danh sách điểm bán đã xác minh; tên trường dùng **làm mốc đi khảo sát**, không tạo lead tự động.

**Độ phủ:** 679 lead tại 131/134 huyện/đô thị cũ sau migration 152. Cả ba huyện dưới đây vẫn 0 lead, không được coi là 0 nhà sách/VPP ngoài đời.

## Quy trình Sales để bổ sung P0 an toàn

1. Trước khi đi: mở nguồn trường trong bảng, tìm **nhà sách / VPP / photo có bán dụng cụ học sinh** quanh trường, chợ, trục đường chính và ấp/xã cũ; gọi điện xác nhận khi có số.
2. **Đến đúng điểm bán** mới chụp mặt tiền, ghi tên quầy thực tế, nhóm hàng thật sự bán, địa chỉ/ấp/xã và số điện thoại. GPS check-in chỉ khi đứng trong **100 mét** theo quy tắc ứng dụng, không tạo dấu ghé từ việc tìm trên mạng.
3. Đối chiếu tỉnh và **huyện cũ** với `backend/src/districts_old.json`. Đặc biệt **Huyện Long Mỹ ≠ Thị xã Long Mỹ**, tỉnh mới sau 2025 không được ghi đè tỉnh cũ.
4. So khớp `customers` và `field_prospects` theo tên, số điện thoại, địa chỉ, MST, source key trước khi nhập; tránh đăng ký cùng một điểm hai lần.
5. Chỉ chuyển thành khách chính theo đúng nghiệp vụ và phân quyền khi Sales xác minh. Chưa tìm thấy quầy thật thì giữ trống, không thêm trường học/tạp hóa làm lead giả.

## Các tuyến xác minh theo mốc trường học

### Huyện Vĩnh Lợi — Bạc Liêu cũ

**Khu vực cần quét:** TT Châu Hưng/chợ Châu Hưng; Long Thạnh (ấp Phước Thạnh 1, Tân Long); Hưng Hội (ấp Cà Vĩnh); Hưng Thành; Châu Thới; Vĩnh Hưng. Quan sát quầy gần trường và chợ, không tự nhận tạp hóa/photo là điểm VPP nếu không thấy bán học phẩm.

| Mốc trường học (10) | Xã/địa chỉ theo nguồn | Mở Maps |
|---|---|---|
| Trường THCS Long Thạnh (THCS) | Xã Long Thạnh | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20THCS%20Long%20Th%E1%BA%A1nh%2C%20X%C3%A3%20Long%20Th%E1%BA%A1nh%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường THCS Võ Hưng Hội (THCS) | Xã Hưng Hội | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20THCS%20V%C3%B5%20H%C6%B0ng%20H%E1%BB%99i%2C%20X%C3%A3%20H%C6%B0ng%20H%E1%BB%99i%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường THCS Võ Hưng Thành (THCS) | Xã Hưng Thành | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20THCS%20V%C3%B5%20H%C6%B0ng%20Th%C3%A0nh%2C%20X%C3%A3%20H%C6%B0ng%20Th%C3%A0nh%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường THPT Lê Văn Đẩu (THPT) | Ấp Xẻo Chích, Xã Vĩnh Lợi, tỉnh Cà Mau, Việt Nam | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20THPT%20L%C3%AA%20V%C4%83n%20%C4%90%E1%BA%A9u%2C%20%E1%BA%A4p%20X%E1%BA%BBo%20Ch%C3%ADch%2C%20X%C3%A3%20V%C4%A9nh%20L%E1%BB%A3i%2C%20t%E1%BB%89nh%20C%C3%A0%20Mau%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Châu Thới (Tiểu học) | Xã Châu Thới | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20Ch%C3%A2u%20Th%E1%BB%9Bi%2C%20X%C3%A3%20Ch%C3%A2u%20Th%E1%BB%9Bi%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Hoàng Hoa Thám (Tiểu học) | Xã Hưng Hội | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20Ho%C3%A0ng%20Hoa%20Th%C3%A1m%2C%20%E1%BA%A4p%20C%C3%A0%20V%C4%A9nh%2C%20X%C3%A3%20H%C6%B0ng%20H%E1%BB%99i%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Lê Văn Tám (Tiểu học) | Xã Vĩnh Hưng | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20L%C3%AA%20V%C4%83n%20T%C3%A1m%2C%20X%C3%A3%20V%C4%A9nh%20H%C6%B0ng%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Mai Thanh Thế (Tiểu học) | Thị trấn Châu Hưng | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20Mai%20Thanh%20Th%E1%BA%BF%2C%20Th%E1%BB%8B%20tr%E1%BA%A5n%20Ch%C3%A2u%20H%C6%B0ng%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Nguyễn Du (Tiểu học) | Xã Long Thạnh | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20Nguy%E1%BB%85n%20Du%2C%20%E1%BA%A4p%20Ph%C6%B0%E1%BB%9Bc%20Th%E1%BA%A1nh%201%2C%20X%C3%A3%20Long%20Th%E1%BA%A1nh%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Phan Đình Phùng (Tiểu học) | Xã Long Thạnh | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20Phan%20%C4%90%C3%ACnh%20Ph%C3%B9ng%2C%20%E1%BA%A4p%20T%C3%A2n%20Long%2C%20X%C3%A3%20Long%20Th%E1%BA%A1nh%2C%20Huy%E1%BB%87n%20V%C4%A9nh%20L%E1%BB%A3i%2C%20B%E1%BA%A1c%20Li%C3%AAu%2C%20Vi%E1%BB%87t%20Nam) |

**Lưu ý loại trừ:** Tân Nam Phương: hồ sơ MST 1900566590 ghi ngừng/chấm dứt; không tự nhập. Các cửa hàng photo, tin học, tạp hóa chỉ được ghi nhận sau khi xác minh có bán sách/VPP.


### Huyện Long Mỹ — Hậu Giang cũ

**Khu vực cần quét:** Xã Lương Tâm (THPT Lương Tâm); Vĩnh Viễn (THPT Tây Đô, TH Vĩnh Viễn 1); Vĩnh Thuận Đông (TH Vĩnh Thuận Đông 3), mở rộng đến Xà Phiên và Lương Nghĩa theo địa giới huyện cũ. Khi tra Maps mới phải phân biệt huyện Long Mỹ với thị xã Long Mỹ cũ.

| Mốc trường học (4) | Xã/địa chỉ theo nguồn | Mở Maps |
|---|---|---|
| Trường THPT Lương Tâm (THPT) | Xã Lương Tâm | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20THPT%20L%C6%B0%C6%A1ng%20T%C3%A2m%2C%20X%C3%A3%20L%C6%B0%C6%A1ng%20T%C3%A2m%2C%20Huy%E1%BB%87n%20Long%20M%E1%BB%B9%2C%20H%E1%BA%ADu%20Giang%2C%20Vi%E1%BB%87t%20Nam) |
| Trường THPT Tây Đô (THPT) | Xã Vĩnh Viễn | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20THPT%20T%C3%A2y%20%C4%90%C3%B4%2C%20X%C3%A3%20V%C4%A9nh%20Vi%E1%BB%85n%2C%20Huy%E1%BB%87n%20Long%20M%E1%BB%B9%2C%20H%E1%BA%ADu%20Giang%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Vĩnh Thuận Đông 3 (Tiểu học) | Xã Vĩnh Thuận Đông | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20V%C4%A9nh%20Thu%E1%BA%ADn%20%C4%90%C3%B4ng%203%2C%20%E1%BA%A4p%204%2C%20X%C3%A3%20V%C4%A9nh%20Thu%E1%BA%ADn%20%C4%90%C3%B4ng%2C%20Huy%E1%BB%87n%20Long%20M%E1%BB%B9%2C%20H%E1%BA%ADu%20Giang%2C%20Vi%E1%BB%87t%20Nam) |
| Trường Tiểu học Vĩnh Viễn 1 (Tiểu học) | Xã Vĩnh Viễn | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%20V%C4%A9nh%20Vi%E1%BB%85n%201%2C%20%E1%BA%A4p%201%2C%20X%C3%A3%20V%C4%A9nh%20Vi%E1%BB%85n%2C%20Huy%E1%BB%87n%20Long%20M%E1%BB%B9%2C%20H%E1%BA%ADu%20Giang%2C%20Vi%E1%BB%87t%20Nam) |

**Lưu ý loại trừ:** Khách chính NS Thể Minh đã có trong customers Huyện Long Mỹ, điện thoại 0839896969; không nhân đôi. Một cửa hàng tên 'Nhà sách Long Mỹ' có thể thuộc thị xã, không tự chuyển vào huyện.


### Huyện Kiên Hải — Kiên Giang cũ

**Khu vực cần quét:** Ưu tiên Hòn Tre quanh Trường Tiểu học, THCS & THPT Kiên Hải và khu chợ/bến tàu Hòn Tre. Tiếp đó khảo sát xã đảo Lại Sơn/Hòn Sơn, An Sơn/Nam Du, Hòn Nghệ; có thể cần Sales/đầu mối địa phương do Internet thiếu thông tin.

| Mốc trường học (1) | Xã/địa chỉ theo nguồn | Mở Maps |
|---|---|---|
| Trường Tiểu học, THCS và THPT Kiên Hải (Tiểu học & THCS & THPT) | Đảo Hòn Tre, Đặc khu Kiên Hải, tỉnh An Giang, Việt Nam | [Tìm trường](https://www.google.com/maps/search/?api=1&query=Tr%C6%B0%E1%BB%9Dng%20Ti%E1%BB%83u%20h%E1%BB%8Dc%2C%20THCS%20v%C3%A0%20THPT%20Ki%C3%AAn%20H%E1%BA%A3i%2C%20%C4%90%E1%BA%A3o%20H%C3%B2n%20Tre%2C%20%C4%90%E1%BA%B7c%20khu%20Ki%C3%AAn%20H%E1%BA%A3i%2C%20t%E1%BB%89nh%20An%20Giang%2C%20Vi%E1%BB%87t%20Nam) |

**Lưu ý loại trừ:** Không lấy điểm bán điện thoại, vật liệu, dịch vụ tàu và hồ sơ đăng ký ngành nghề làm VPP nếu chưa có bằng chứng mặt hàng.

## P1 — Ba điểm nguồn công khai cần kiểm nghiệp vụ bổ sung

- `Văn phòng phẩm - Sửa chữa vi tính Đại Quang` tại ấp Thới Bình/Cờ Đỏ cũ: tên có VPP nhưng danh mục Maps liên quan camera, chưa xác minh còn bán đồ học sinh.
- `Văn phòng phẩm Cường Quyên` tại Đường số 12/Cờ Đỏ cũ: Maps ghi Book store nhưng chưa có số điện thoại, chưa kiểm hàng thực tế.
- `Văn phòng phẩm Cô Duyên` tại Chợ đầu mối Mỹ Hiệp/Cao Lãnh cũ: Hồng Hà liệt kê với điện thoại 0939917100, chưa xác nhận trực tiếp tình trạng năm 2026.

## Kiểm kê lỗi nguồn cũ, chờ chỉnh lý có kiểm soát

- Lead `field_prospects` Cần Thơ/Huyện Cờ Đỏ hiện có tên **Nhà sách Minh Thư** và địa chỉ **ấp Thới Bình, TT. Cờ Đỏ**, source key `hongha:minhthu:thoibinh-codo`, không có điện thoại. Cùng URL nguồn https://vpphongha.com.vn/vi/gaga lại ghi **Nhà Sách Minh Thư tại đường 21 KDC An Khánh, P. An Khánh**; tên gắn với **ấp Thới Bình, TT. Cờ Đỏ** phải là **Nhà Sách Nhuận Điền**, điện thoại **0939688455**. Đây là **lỗi ánh xạ nguồn cần xác minh/chỉnh lý**, không dùng cách chèn thêm Nhuận Điền để tạo hai lead tại cùng địa chỉ. Không tự sửa customers và không xóa lịch sử.

## Chỉ tiêu nghiệm thu riêng P0

- Một huyện chỉ đánh dấu đã có **lead nghiên cứu** nếu tên + địa chỉ đủ rõ + chứng cứ nguồn hợp lệ, nhưng **không** suy ra đã có điểm bán hoạt động.
- Một điểm chỉ đánh dấu **đã ghé/đã xác minh GPS** sau khi nhân viên thực sự đến theo điều kiện vị trí 100m.
- Tất cả lead mới ở vòng này cần có `research_source_url`, `research_source_key`, `research_batch`, chống trùng, lưu SQL migration ở `main` và đối soát production.
