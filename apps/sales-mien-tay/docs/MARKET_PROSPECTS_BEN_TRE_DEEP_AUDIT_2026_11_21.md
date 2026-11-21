# Bến Tre cũ — rà sâu dữ liệu Điểm bán tiềm năng: Nhà sách và Văn phòng phẩm
Ngày rà nguồn và nhập Neon: **21/11/2026**. Dữ liệu online phục vụ khai thác Sales, **không phải tổng điều tra toàn bộ điểm bán thực địa**.

## 1. Kết quả ghi thật vào Neon production

Cơ sở dữ liệu Neon `raspy-bar-51596929` / branch production. Dữ liệu trong `public.field_prospects`, không tạo Customer, không đánh dấu đang bán, không GPS/visit/ảnh giả.

- Trước đợt rà sâu: **55** lead Bến Tre cũ.
- Import `098`: **+14** điểm (mỗi huyện có thêm ít nhất 1 ứng viên).
- Import `100`: **+6** điểm bản đồ địa phương (Ba Tri, Chợ Lách, Giồng Trôm, Thạnh Phú).
- Sau: **75 điểm** (39 Nhà sách, 36 Văn phòng phẩm), 9/9 huyện cũ; **52** có điện thoại, **12** MST có nguồn; **75** có URL nguồn và khóa chống trùng riêng.
- **14 Khách hàng chính Bến Tre** trong `public.customers` không đưa vào leads; toàn hệ thống `customers=55` và `schools=796` vẫn nguyên; Bến Tre `schools=64`.
- `status='new'` cả **75**, `converted_customer_id=NULL`, không có `last_visit_at/GPS`; visits **0**, ảnh thực địa **0**; không tự cập nhật `is_selling`.

| Địa bàn cũ | Nhà sách | Văn phòng phẩm | Tổng điểm |
|---|---:|---:|---:|
| Thành phố Bến Tre | 12 | 8 | 20 |
| Huyện Bình Đại | 3 | 8 | 11 |
| Huyện Châu Thành | 4 | 4 | 8 |
| Huyện Ba Tri | 3 | 4 | 7 |
| Huyện Chợ Lách | 2 | 4 | 6 |
| Huyện Giồng Trôm | 4 | 1 | 5 |
| Huyện Mỏ Cày Bắc | 4 | 2 | 6 |
| Huyện Mỏ Cày Nam | 5 | 1 | 6 |
| Huyện Thạnh Phú | 2 | 4 | 6 |
| **Tổng** | **39** | **36** | **75** |

**Chú ý:** tổng theo bảng cuối cùng là 39 nhà sách, 36 VPP. Các con số dùng dữ liệu group-by đọc lại DB, không cộng tay dự đoán.

## 2. File nguồn và SQL tái lập

- [Lô ban đầu TP Bến Tre — 17 điểm](../data/market_prospects_ben_tre_city_pilot_2026_11_21.json).
- [Lô 8 huyện — 32 điểm](../data/market_prospects_ben_tre_8_districts_2026_11_21.json).
- [Bình Đại rà lần hai — 6 điểm](../data/market_prospects_binh_dai_second_pass_2026_11_21.json).
- [Lô rà sâu 9 huyện — 14 điểm, kèm `confidence`, bằng chứng và 5 trường hợp không nhập](../data/market_prospects_ben_tre_deep_research_2026_11_21.json).
- [Lô địa điểm nhỏ từ Google Maps — 6 điểm](../data/market_prospects_ben_tre_local_maps_sweep_2026_11_21.json).
- [Migration 098](../backend/migrations/098_ben_tre_9_districts_deep_research_2026.sql), [Migration 100](../backend/migrations/100_ben_tre_additional_local_map_research_2026.sql): hai import có `ON CONFLICT research_source_key DO NOTHING`, so tên/địa chỉ với cả Khách hàng và lead; chạy lại trả **0 bản ghi**.
- [Migration 099](../backend/migrations/099_ben_tre_research_verification_flags_2026.sql): 4 cảnh báo nguồn có thể lỗi thời/địa chỉ khác nhau; chạy lại trả **0 bản ghi**, không thay trạng thái.

## 3. Điểm có chứng cứ mạnh

- `SURI Shop Ba Tri` 116 Vĩnh Phú: hồ sơ điểm bán và điện thoại 0985833750; cửa hàng kết hợp văn phòng phẩm/quà tặng.
- `VPP Tâm Như` thị trấn Giồng Trôm: [Trang Vàng](https://www.yellowpages.vn/lgs/1187803632/van-phong-pham-tam-nhu.html).
- `VPP Lâm Trang`, 57 Trần Hưng Đạo thị trấn Ba Tri: [Danh bạ Contact.page](https://vietnam.contact.page/locations/vn-vi43-be-n-tre/listings?page=25).
- `Nhà sách Tố Quyên`, 6 đường 3 Tháng 2: [VietBiz](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-t%E1%BB%91-quy%C3%AAn-0275-3829-140).
- `Nhà sách Giồng Trôm`: [hồ sơ đăng ký MST 1301003140](https://tracuunhanh.vn/1301003140-nha-sach-giong-trom), nhưng địa chỉ trong hồ sơ đăng ký KP2 thị trấn khác mô tả xã Bình Thành của danh bạ khác, cần kiểm tra.
- `Hiệu sách Anh Luân`, `Nhà sách Thanh Trúc`, `VPP Phi Long`, `Mẹ Bông Store`, `VPP–photocopy Cô Huy`: có Place ID riêng từ bản đồ công khai, một số chỉ có Plus Code.
- Các hồ sơ chỉ có danh bạ cũ, địa chỉ đăng ký hoặc tên cửa hàng hỗn hợp phải **xác minh còn hoạt động** trước chuyến ghé.

## 4. Cảnh báo chất lượng dữ liệu (đã gắn vào ghi chú DB)

| Cơ sở | Bằng chứng và xử lý |
|---|---|
| Cửa hàng Sách – Văn hóa phẩm Ba Tri | [Chi nhánh MST 1300377802-006](https://chogia.vn/ma-so-thue/doanh-nghiep/1300377802-006) được nguồn thuế cập nhật 30/08/2026 ghi chấm dứt hiệu lực. Chưa kết luận mặt bằng bán hàng đã đóng. |
| Cửa hàng Sách – Thiết bị – Văn hóa phẩm Thạnh Phú | [Chi nhánh MST 1300377802-005](https://chogia.vn/ma-so-thue/doanh-nghiep/1300377802-005) cũng được nguồn thuế ghi chấm dứt hiệu lực; cần xác minh hiện trạng. |
| Văn phòng phẩm Thái Thanh Thảo, Chợ Lách | [VietBiz](https://www.viet-biz.com/c%E1%BB%ADa-h%C3%A0ng-v%C4%83n-ph%C3%B2ng-ph%E1%BA%A9m-th%C3%A1i-thanh-th%E1%BA%A3o) đã đánh dấu đóng từ 31/05/2023; chưa có chứng cứ mở lại. |
| Nhà sách Phương Nghi, Mỏ Cày Nam | [Thiên Long](https://thienlonggroup.com/news/58-cua-hang-chuan-thien-long-da-co-mat-tren-toan-quoc) ghi **116 ấp Bình Thành**, hồ sơ trước ghi **ấp Bình Thạnh**; không tự ghi đè địa chỉ cho tới khi đối chiếu. |

Các cảnh báo **không tự chấm dứt/đóng lead**, không ghi GPS hay xác nhận Sales đã đến. Chúng giúp Sales ưu tiên xác minh qua điện thoại hoặc hiện trường.

**Không nhập các nguồn có nguy cơ trùng:** VPP Sen Việt 34D/265B Nguyễn Văn Tư; Nhà sách Bến Tre 1 ở 8 Nguyễn Văn Tư với chi nhánh đăng ký 52 Nguyễn Trãi; Nhà sách Kim Hòa ở 19 Đồng Khởi với VPP Kim Hòa ở 3 Đồng Khởi; Nhà sách Quốc Tế Hùng Vương với NhaSachBenTre.Com; NS Hòa Bình 20 Nguyễn Trung Trực với NS Hòa Bình trong Khách hàng tại 228 Nguyễn Huệ. Danh mục nghi vấn được lưu ở JSON `excluded_needing_verification`.

## 5. Nghiệm thu DB/API và ranh giới hoàn thiện

- **75/75** nguồn có URL và `research_source_key`; không trùng tên (không phân biệt hoa/thường) trong cùng huyện.
- Import 098, 099, 100 đều idempotent khi chạy lại.
- Permission readback `sales_market_prospect_allowed`: Admin **75/75**; hai Manager có quyền Bến Tre **75/75**; Sales không có quyền Bến Tre **0/75**. Không tự cấp thêm quyền.
- **Chưa** nghiệm thu GPS/camera thực địa hay việc mọi cửa hàng còn hoạt động. Dữ liệu nghiên cứu có thể thiếu tiệm nhỏ, tạp hóa kiêm VPP, nhà sách không hiện trên Internet.
- **9/9 huyện có dữ liệu ≠ đã rà 100% từng xã/ấp**. Không có nguồn đáng tin cậy để xác nhận tổng số cửa hàng thực tế. Để được đánh dấu kiểm kê đầy đủ, cần Sales đối chiếu từng xã cũ, gọi/xác minh các điểm nghi vấn và bổ sung tiệm không có mặt trực tuyến.

## 6. Kiểm thử trên app

https://sales-mien-tay.vercel.app → menu **Điểm bán tiềm năng** → tỉnh cũ **Bến Tre** → chọn từng huyện cũ → nhấn làm mới.
Vẫn là hai danh mục **Điểm bán tiềm năng** vs **Khách hàng** riêng biệt. Khi nhân viên thực tế ghé, chỉ khi đó GPS và ảnh mới được ghi nhận. Import dữ liệu từ Neon không cần build/deploy lại app v14.
