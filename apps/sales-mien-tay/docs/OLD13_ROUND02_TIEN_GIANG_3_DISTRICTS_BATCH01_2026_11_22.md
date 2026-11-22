# MCP-FBMN — TIỀN GIANG CŨ / RÀ BÙ VÒNG 2 — ĐỢT 1: BA HUYỆN

**Ngày tra cứu:** 22/11/2026. **Chỉ một tỉnh cũ:** Tiền Giang. **Đúng ba huyện:** `Huyện Tân Phú Đông`, `Huyện Tân Phước`, `Huyện Cai Lậy`. Địa giới key theo `apps/sales-mien-tay/backend/src/districts_old.json`. Không trộn `Huyện Cai Lậy` và `Thị xã Cai Lậy`. Đây là thu thập **điểm bán nhà sách/VPP**, trường học chỉ dùng làm mốc khảo sát, **không nhập trường học làm lead**.

## 1. Đối chiếu Neon production

| Huyện cũ | Trước | Lead nhập từ migration 161 | Sau | Nhận định |
|---|---:|---:|---:|---|
| **Huyện Tân Phú Đông** | 3 | **0** | **3** | Nguồn mới chưa đủ để xác định cửa hàng sách/VPP khác ba lead hiện có; chờ rà sâu qua xã/chợ và Sales thực địa |
| **Huyện Tân Phước** | 5 | **0** | **5** | Nguồn mới chủ yếu là đăng ký doanh nghiệp; một ứng viên có MST đã chấm dứt, không nhập |
| **Huyện Cai Lậy** | 5 | **+1** | **6** | Tiệm đa ngành Chip Chip có bài đăng tháng 7/2026 liệt kê sản phẩm VPP/Thiên Long thực bán |
| **Tổng đúng 3 huyện** | **13** | **+1** | **14** | Không tự tăng lead để đủ chỉ tiêu |

**Production** `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj` sau lô: **735** `field_prospects`, **132/134** địa bàn cũ có lead, **24** địa bàn còn 1–2 lead; số có điện thoại **536**. `735/735` có source key/HTTPS, `735/735` `status=new`, không có dấu GPS/lượt ghé, **0** trùng `research_source_key`; batch 161 không trùng khách chính theo tên trong huyện hay số điện thoại trên toàn bảng. **Chạy lại nguyên SQL migration 161 trả 0 dòng**.

**Migration:** [`161_tien_giang_old_round02_tan_phu_dong_tan_phuoc_cai_lay_2026.sql`](../backend/migrations/161_tien_giang_old_round02_tan_phu_dong_tan_phuoc_cai_lay_2026.sql) — commit [`267b2aa`](https://github.com/milktea-cus/MCP-FBMN/commit/267b2aa4684e05474213a29af8ecec70de339b60). Commit trước khi chạy SQL trên Neon. Không ghi GPS, khách chính, lượt ghé, vị trí đã xác minh, doanh thu hay `is_selling`.

## 2. Lead mới có bằng chứng trực tiếp về mặt hàng

**Trà Sữa Chip Chip - Mỹ Phẩm - Văn Phòng Phẩm**

- **Địa chỉ công khai:** ấp 6, **xã Mỹ Thành Nam**, **Huyện Cai Lậy/Tiền Giang cũ**, hiện thuộc Đồng Tháp.
- **Số điện thoại công khai:** `0989522814`.
- **Nguồn chính:** [Bản lưu trang mạng xã hội và bài đăng 18/07/2026](https://www.beautynailhairsalons.com/VN/Cai-Lay/107850801671011/Tr%C3%A0-S%E1%BB%AFa-Chip-Chip---M%E1%BB%B9-Ph%E1%BA%A9m---V%C4%83n-Ph%C3%B2ng-Ph%E1%BA%A9m) (website tổng hợp, không phải xác nhận thực địa). Bài đăng liệt kê trực tiếp sản phẩm Thiên Long sẵn tại tiệm: tập 96/200 trang, tập 4 ô ly, bút bi, bút gel, bút xóa, bút lông dầu, thước, gôm, bào chì, màu sáp/nước, hồ dán, nhãn tập, giấy A4. Cơ sở **đa ngành** trà sữa/mỹ phẩm/VPP; mục tiêu là đầu mối VPP đang nghiên cứu, không coi như nhà sách chuyên doanh.
- **Nguồn địa giới:** [Thông tư 18/2017/TT-BTNMT](https://thuvienphapluat.vn/van-ban/Tai-nguyen-Moi-truong/Thong-tu-18-2017-TT-BTNMT-Danh-muc-dia-danh-dan-cu-son-van-thuy-van-kinh-te-xa-hoi-Tien-Giang-359826.aspx) ghi ấp 6 xã Mỹ Thành Nam thuộc **huyện Cai Lậy cũ**; [nguồn bưu chính](https://vntracuu.com/branch_vnpost/info/864300) cũng thể hiện địa giới này.
- **Khác biệt dữ liệu:** Một bài đăng gần đây có nghĩa từng rao hàng năm 2026, **không xác minh hôm nay cửa hàng vẫn mở hoặc vị trí GPS chính xác**. Sales cần gọi số trên, yêu cầu xác nhận còn bán sản phẩm Thiên Long và mặt tiền trước khi đến; check-in 100m chỉ phát sinh khi trực tiếp đến đúng nơi.

## 3. 2 huyện chưa có lead mới và những nguồn đã loại

### Huyện Tân Phú Đông — vẫn 3 lead

- Đã có: `VPP Hồng Phúc` (ấp Tân Phú, xã Phú Thạnh), `VPP Phu Sương` (xã Tân Thới), `VPP Thúy Nguyên` (ĐH10, chưa rõ xã cũ). Không thêm lại do tên/nguồn khác.
- [Contact.page Tiền Giang, trang 8](https://vietnam.contact.page/locations/vn-vi30-tie-n-giang/listings?page=8) trong kết quả tìm kiếm cùng trang có `Nhà sách Hướng Dương`, nhưng khi mở đầy đủ, **địa chỉ thực là 34 Trần Quốc Toản, TP Mỹ Tho**, không phải chợ Tân Thới/Tân Phú Đông; chợ Tân Thới nằm ở **cửa hàng thức ăn gia súc Thanh Nhã** ngay sau đó, **không nhập nhầm**.
- Chưa tìm được lead mới đủ tên + địa chỉ cũ + dấu hiệu thật sự bán sách/VPP tại Phú Đông, Phú Tân, Tân Thới, Tân Phú, Phú Thạnh. Không coi thiếu nguồn online là không có điểm bán ngoài đời; cần Sales khảo sát các chợ, trường, tuyến ĐH10.

### Huyện Tân Phước — vẫn 5 lead

- Đã có `VPP Tân Phước`, `VPP Phước Lộc`, `VPP–Photocopy Nguyễn Trung`, `Trung tâm Bách hóa Tân Phước`, `Công ty VPP Giai Phát`. Không thêm bằng nguồn MST khác.
- **Công ty TNHH MTV Hoàng An Khang**, MST `1201659796`: Maps có listing `Office supply store` và số `0369345388`; [tra cứu mã số thuế](https://tracuumst.com/1201659796-cong-ty-tnhh-mtv-hoang-an-khang) ghi ngành chính 4761 **nhưng trạng thái ngừng hoạt động và đã hoàn thành thủ tục chấm dứt hiệu lực MST**. [Danh bạ doanh nghiệp cũ](https://infodoanhnghiep.com/Tien-Giang/Huyen-Tan-Phuoc/trang-2/) ghi `ấp 4, xã Tân Lập 1` còn thuế mới ghi `ấp 5, xã Tân Phước 3`; **vừa xung đột địa chỉ vừa đã chấm dứt MST, không chèn lead retail** chỉ vì Maps có ghim.
- Nguồn đăng ký khác có ngành 4761, trụ sở doanh nghiệp không phải bằng chứng có điểm bán lẻ; giữ chờ đối chiếu trước khi coi là lead. Chưa tìm thêm cửa hàng chắc chắn ở Mỹ Phước, Tân Lập 1/2, Thạnh Mỹ, Phước Lập, Tân Hòa Tây.

### Huyện Cai Lậy — từ 5 lên 6 lead

- **Đã có trong Neon:** `Nhà sách Lam Phương` (ấp 4 xã Phú An), `VPP Lê` (Bình Phú), `VPP Ngọc Lan` (Phú Nhuận), `VPP Phát Giàu` (Ngũ Hiệp), `VPP – Quà lưu niệm Cô Hạnh` (Mỹ Long). Không thêm trùng.
- [Danh sách điểm bán Hồng Hà](https://vpphongha.com.vn/vi/gaga) ghi `VPP Lam Phương` cùng địa chỉ ấp 4 xã Phú An nhưng số điện thoại `0901539539` khác số `0984211211` trong Neon của `Nhà sách Lam Phương`. Rất có thể một điểm hoặc số đã đổi; **không tạo lead thứ hai**, không tự ghi đè điện thoại; đề nghị Sales gọi đối chiếu.
- [FAHASA chính thức](https://fahasasg.com.vn/chao-don-khai-truong-nha-sach-fahasa-cai-be-nha-sach-mang-thuong-hieu-fahasa-thu-4-tai-tinh-tien-giang/) ghi `Nhà sách FAHASA Cai Lậy` ở Co.opmart, đường 30/4 **phường 1 Thị xã Cai Lậy cũ**, **không thuộc huyện Cai Lậy**. `Bí Bo photocopy–VPP` ở khu phố 1 của đô thị Cai Lậy, `Hiệu Sách Trung` đường 868 thị trấn Cai Lậy cũ cũng có nguy cơ tương tự, chưa đưa vào huyện.
- [Nhà Sách Giáo Dục Cai Lậy](https://www.google.com/maps/search/?api=1&query=Nh%C3%A0%20S%C3%A1ch%20Gi%C3%A1o%20D%E1%BB%A5c%20Cai%20L%E1%BA%ADy&query_place_id=ChIJ8aMD3EmXCjERtpWv2N9HL2Q) trên Maps dùng địa chỉ `Thanh Tâm, Cai Lậy, Đồng Tháp`, **chưa đủ xã/phường cũ để xác định huyện hay thị xã**, chưa nhập.

## 4. Tiếp theo theo quy tắc 3 huyện/tỉnh

- **Không rà tiếp Hậu Giang**: Owner yêu cầu bỏ qua để tập trung **Tiền Giang cũ**. Sau đợt 1 này, vẫn ở Tiền Giang, chọn **ba huyện/đô thị khác** ở đợt 2 để không rà chồng lấn.
- Mốc khảo sát thực địa không tự động thành lead; với huyện có ít thông tin online, yêu cầu Sales xác minh ở chợ/trường, chụp ảnh mặt tiền thật, xác nhận hàng hóa và tuân thủ GPS dưới 100m trước khi đánh dấu đã ghé. Tình trạng hoạt động của 14 lead ở ba huyện chưa được nghiệm thu thực địa.
- Không deploy Cloudflare Worker/Vercel cho batch SQL + docs. CI kiểm theo commit hiện hành, không đồng nghĩa nghiệm thu PWA/Android.
