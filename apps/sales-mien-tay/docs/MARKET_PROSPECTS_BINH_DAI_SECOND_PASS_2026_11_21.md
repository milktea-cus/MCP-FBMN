# Rà lần hai — Điểm bán Nhà sách / Văn phòng phẩm Bình Đại cũ (21/11/2026)

## Vì sao phải rà lại
Owner đi thực tế Bình Đại thấy hơn 10 cửa hàng, trong khi đợt đầu DB chỉ có 4 điểm **tiềm năng**. Đối chiếu Neon production trước khi làm: 4 `field_prospects` + **9 Khách hàng chính** tại huyện Bình Đại cũ (trong đó có các Nhà sách/VPP). Đếm 4 tiềm năng không có nghĩa cả huyện chỉ có 4 cửa hàng. Những cửa hàng nhỏ không đăng Google Maps, không có website, hoặc đã đổi địa chỉ hành chính sang Vĩnh Long mới dễ bị bỏ sót.

## Kết quả ghi vào Neon production
- Bổ sung **6** lead mới trong `field_prospects` theo batch `2026-11-21-binh-dai-second-pass-book-stationery-01`.
- Sau nhập: **Bình Đại 10 lead (3 nhà sách, 7 VPP)** + **9 Khách hàng chính có trước** = 19 hồ sơ trên *hai danh bạ* (chưa xác minh 19 cửa hàng độc lập).
- Toàn tỉnh Bến Tre cũ: `49 -> 55` điểm tiềm năng, vẫn 9/9 địa bàn có ít nhất một bản ghi. Tổng `customers=55`, `schools=796` **không đổi**.
- **6/6** có `research_source_url`, **3/6** có điện thoại công khai, **2/6** MST đã đối chiếu nguồn, 6/6 `status='new'`. Không tạo visits, photos, GPS, converted hoặc trạng thái đang bán. Replay migration 097: **0** row; không có trùng tên nội bộ cùng huyện.
- ACL production readback: Admin và **hai Manager được giao Bến Tre thấy 10/10**, Sales không được giao Bến Tre không thấy (0/10).

### 6 điểm bổ sung
| Cơ sở | Địa chỉ cũ / ghi chú | Loại & nguồn |
|---|---|---|
| Văn phòng phẩm Nhân Vi | KP2, TT Bình Đại (5MPR+W3M) | VPP, địa điểm Google Maps |
| Văn phòng phẩm Huỳnh Thi | xã Thừa Đức (5Q77+PGX); Maps nay ghi Thới Thuận | VPP, [danh bạ](https://sotayvang.com/van-phong-pham-huynh-thi-thua-duc/) |
| Cửa hàng Bách hóa – VPP Đông Chính | ĐT883, khu vực Trần Trung (5MPV+FHC) | VPP kiêm bách hóa, hồ sơ địa điểm Google Maps |
| Văn phòng phẩm Ngọc Thu | 96 KP1, TT Bình Đại | VPP, [MST 1301117028](https://dailychukyso.com.vn/mst/1301117028-doanh-nghiep-tu-nhan-van-phong-pham-ngoc-thu/) |
| Văn phòng phẩm Gia Phát | 182 ấp Lộc Thới, xã Lộc Thuận | VPP, [MST 1301017217](https://chogia.vn/ma-so-thue/doanh-nghiep/1301017217) |
| Nhà sách Minh Thảo | 143 ấp Vinh Hội, xã Vang Quới Tây cũ (nay Lộc Thuận) | Nhà sách, [đăng ký hộ kinh doanh](https://tracuunhanh.vn/8755115112-001-ho-kinh-doanh-nha-sach-minh-thao) |

**Phân loại độ tin cậy:** 3 điểm có hồ sơ bản đồ + phone, 3 có đăng ký kinh doanh/địa chỉ nhưng **chưa đủ bằng chứng cửa hàng bán lẻ còn hoạt động tại chỗ**; không khẳng định 6/6 đã xác minh thực địa. Thuộc tính chi tiết `confidence`, `evidence`, `verification_note` lưu tại file JSON; ghi chú tương ứng đã được nạp vào `field_prospects.note`.

## Điểm phát hiện nhưng chủ động KHÔNG đưa thành cửa hàng mới
- **VPP Huỳnh Mai:** [hồ sơ MST 1301116426](https://infodoanhnghiep.com/Vinh-Long/Xa-Binh-Dai/) ghi **32A KP1 TT Bình Đại**, trùng **địa chỉ khách VPP Vũ** trong DB. Không giả định là hai cửa hàng riêng khi chưa đối chiếu chủ và tên biển hiệu.
- **Công ty Kim Sa Thủy:** ngành bán lẻ sách/VPP, MST `1301114394`, nhưng [Công an Vĩnh Long thông báo sự cố cháy cơ sở ngày 08/06/2026](https://congan.vinhlong.gov.vn/tin-tuc-an-ninh-trat-tu/khoi-to-bat-tam-giam-doi-tuong-phong-hoa-4069.html); không có bằng chứng đã mở lại điểm bán, **không seed như cửa hàng đang hoạt động**.
- **Nhà sách Phú Mỹ** có tên/địa chỉ tương tự **VPP Phú Mỹ** đã có trong `field_prospects`, dữ liệu điện thoại mâu thuẫn giữa các nguồn. Không tạo hai điểm trừ khi Sales xác nhận khác nhau.
- **VPP Quyên, VPP Hồng Phấn, VPP Vũ, NS Phương Nam, NS Phước Nguyễn** và các Khách hàng khác có sẵn phải giữ trong danh bạ chính, không sao chép sang tiềm năng.
- Tiệm **chỉ photocopy/in ấn** không mặc định thuộc VPP nếu không có bằng chứng bán đồ dùng học tập.

## Tái lập có kiểm soát
- [Nguồn JSON và các hồ sơ cần loại/đối chiếu](../data/market_prospects_binh_dai_second_pass_2026_11_21.json).
- [Migration 097, idempotent, chống trùng trong cùng huyện](../backend/migrations/097_binh_dai_second_pass_2026.sql).
- Mã `source_key` / MST áp dụng theo quy tắc của Issue #5. **Không gắn tọa độ GPS giả** chỉ vì có Google Maps Place ID.

## Còn thiếu / không nên gọi là “đã tìm hết”
- Chưa rà đủ từng xã/ấp, từng điểm bán lẻ không có website, nhất là các tiệm tạp hóa kiêm VPP và nhà sách tư nhân không có tên chuẩn online.
- Các địa chỉ chỉ đến KP/ấp, hoặc nơi chỉ có trụ sở đăng ký cần người bán/anh em Sales xác minh. MST trùng không đồng nghĩa 2 chi nhánh giống nhau; cũng không đủ chứng minh 1 cửa hàng còn mở.
- Cần rà tiếp các huyện khác trong Bến Tre: số lead tại **Giồng Trôm 2**, **Ba Tri 3**, **Chợ Lách 3**, **Thạnh Phú 3** là tín hiệu thiếu nguồn, không thể dùng `9/9 huyện có dữ liệu` làm nghiệm thu đầy đủ thị trường.
- Để hoàn thiện có bằng chứng: phân chia theo xã cũ, Google Maps + danh bạ + trang phân phối + chính quyền/doanh nghiệp, so với Khách hàng chính, Sales đi bổ sung điểm không có mặt trên internet; ghi nguồn, loại và độ chắc chắn cho từng điểm, không tự ghép/gộp.

**Nghiệm thu UX:** PWA/APK hiện tại đọc dữ liệu Neon ngay qua Worker, không cần build/deploy frontend cho một lô import. Admin hoặc Manager được giao Bình Đại xem 10 điểm tiềm năng, 9 hồ sơ chính vẫn ở Khách hàng; bấm làm mới trên tab.
