# Điểm bán tiềm năng — Bến Tre cũ, Nhà sách và Văn phòng phẩm (21/11/2026)

## Phạm vi đã ghi Neon production

- **49 điểm bán tiềm năng tại đủ 9/9 địa bàn Bến Tre cũ**: 17 điểm TP Bến Tre đã nhập trước + **32 điểm bổ sung ở 8 huyện**.
- Theo danh mục `public.field_prospects`, không chuyển dữ liệu vào `public.customers`, không phá bottom Khách hàng, không tự bật `is_selling`.
- 33 `nha_sach`, 16 `van_phong_pham`; 40 có số điện thoại, 8 có MST công khai.
- Hai lô đều 100% **`status='new'` (Chưa ghé)**, không `converted_customer_id`, không lượt ghé, không GPS và không ảnh thực địa.
- Số liệu hậu kiểm: Khách hàng `Bến Tre=14` (`tổng hệ thống=55`), Trường học `Bến Tre=64` (`tổng hệ thống=796`) **không thay đổi**.

| Địa bàn cũ | Nhà sách | Văn phòng phẩm | Tổng |
|---|---:|---:|---:|
| Thành phố Bến Tre | 10 | 7 | 17 |
| Huyện Ba Tri | 3 | 0 | 3 |
| Huyện Bình Đại | 2 | 2 | 4 |
| Huyện Châu Thành | 4 | 3 | 7 |
| Huyện Chợ Lách | 1 | 2 | 3 |
| Huyện Giồng Trôm | 2 | 0 | 2 |
| Huyện Mỏ Cày Bắc | 4 | 1 | 5 |
| Huyện Mỏ Cày Nam | 5 | 0 | 5 |
| Huyện Thạnh Phú | 2 | 1 | 3 |
| **Tổng** | **33** | **16** | **49** |

## Tệp nguồn và migration có thể tái chạy

- [32 điểm bổ sung, tên, huyện, địa chỉ, phân loại, điện thoại, MST, nguồn URL, mức tin cậy và ghi chú](../data/market_prospects_ben_tre_8_districts_2026_11_21.json)
- [17 điểm đã có của Thành phố Bến Tre](../data/market_prospects_ben_tre_city_pilot_2026_11_21.json)
- [Migration 096 — import nguồn công khai, ID bền vững và chống trùng](../backend/migrations/096_ben_tre_old_stores_research_2026.sql)
- [Migration 094 — metadata nguồn nghiên cứu](../backend/migrations/094_market_prospect_research_provenance.sql)
- Bổ sung theo batch `2026-11-21-ben-tre-8-districts-stationery-01` (32 điểm), batch cũ `2026-11-21-ben-tre-city-pilot-01` (17 điểm).
- `research_source_key` có index unique; kiểm trùng tên/địa chỉ hiện hữu khi import; chạy lại migration 096 lần hai trả **0 bản ghi**. Không khóa MST toàn cục vì có thể có nhiều chi nhánh cùng MST.

## Dẫn chứng công khai nổi bật

- **Ba Tri:** [Nhà sách Nguyễn My](https://nsnguyenmy.web-store.online/), [Cửa hàng Sách – Văn hóa phẩm Ba Tri](https://www.viet-biz.com/c%E1%BB%ADa-h%C3%A0ng-s%C3%A1ch-v%C4%83n-h%C3%B3a-ph%E1%BA%A9m-ba-tri-0275-3762-716).
- **Bình Đại:** [Nhà sách Hoàng Kim](https://vn-vi472641-nha-sa-ch-hoa-ng-kim.contact.page/), [Hiệu sách Thiên An](https://vn-vi472794-hie-u-sa-ch-thie-n-an.contact.page/), [VPP Phú Mỹ](https://bentretoplist.com/top-10-dia-chi-ban-giay-goi-qua-o-ben-tre-da-dang-mau-xinh/).
- **Châu Thành:** [Danh sách đối tác Văn phòng phẩm Hồng Hà](https://vpphongha.com.vn/vi/danh-sach-cua-hang-trien-khai-chuong-trinh-tui-mu) (Nhà sách Khánh Quyên, VPP Ba Lai), [Nhà sách Bến Tre 2 — hồ sơ đăng ký](https://masothue.com/1300377802-003-chi-nhanh-cong-ty-co-phan-sach-thiet-bi-ben-tre-nha-sach-ben-tre), [Nhà sách Minh Đăng, Ta Ken](https://bentretoplist.com/top-10-dia-chi-ban-giay-goi-qua-o-ben-tre-da-dang-mau-xinh/).
- **Chợ Lách:** [Chi nhánh Sách – Thiết bị Chợ Lách](https://tracuumst.com/1300377802-004-chi-nhanh-cong-ty-co-phan-sach-thiet-bi-ben-tre-cua-hang-sach-thiet-bi-van-hoa-pham-huyen-ch), [VPP Thái Thanh Thảo](https://www.viet-biz.com/c%E1%BB%ADa-h%C3%A0ng-v%C4%83n-ph%C3%B2ng-ph%E1%BA%A9m-th%C3%A1i-thanh-th%E1%BA%A3o).
- **Giồng Trôm:** [Nhà sách Uyên Phương](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-uy%C3%AAn-ph%C6%B0%C6%A1ng_1O-0275-3892-288), [Cửa hàng sách–thiết bị Giồng Trôm](https://www.viet-biz.com/c%E1%BB%ADa-h%C3%A0ng-s%C3%A1ch-thi%E1%BA%BFt-b%E1%BB%8B-v%C4%83n-h%C3%B3a-ph%E1%BA%A9m-0275-3641-707).
- **Mỏ Cày Bắc:** [Nhà sách Sích](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-s%C3%ADch-0275-3845-015), [Nhà sách Hồng Giang](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-h%E1%BB%93ng-giang-0275-3845-107), [Hiệu sách Lê Hồ](https://bentretoplist.com/top-10-dia-chi-ban-giay-goi-qua-o-ben-tre-da-dang-mau-xinh/).
- **Mỏ Cày Nam:** [Nhà sách Minh Tuyền](https://www.shops1000.com/VN/Ben-Tre/1282459995247072/Nh%C3%A0-S%C3%A1ch-Minh-Tuy%E1%BB%81n), [SGK Út Đạt](https://www.viet-biz.com/c%E1%BB%ADa-h%C3%A0ng-s%C3%A1ch-gi%C3%A1o-khoa-%C3%BAt-%C4%91%E1%BA%A1t), [Nhà sách Phương Nghi](https://bentretoplist.com/top-10-dia-chi-ban-giay-goi-qua-o-ben-tre-da-dang-mau-xinh/).
- **Thạnh Phú:** [Nhà sách Cô Xuân](https://bentretoplist.com/top-10-dia-chi-ban-giay-goi-qua-o-ben-tre-da-dang-mau-xinh/), [Chi nhánh Sách – Thiết bị Thạnh Phú](https://chogia.vn/ma-so-thue/doanh-nghiep/1300377802-005); VPP Đăng Khuê có [hồ sơ Google Maps](https://www.google.com/maps/search/?api=1&query=VPP%20%C4%90%C4%83ng%20Khu%C3%AA%20Th%E1%BA%A1nh%20Ph%C3%BA&query_place_id=ChIJYwztuMwdoDERSjYW0Y3eMu0).

## Những điểm cần xác minh tiếp — không tự suy diễn

- **9/9 huyện có dữ liệu không đồng nghĩa đã kiểm kê đủ 100% các nhà sách và VPP trong mọi xã/ấp**. Danh bạ công khai có thể bỏ sót cửa hàng nhỏ, cơ sở ngừng hoạt động hoặc đổi tên.
- Phải xác minh lại hiện trạng cửa hàng, số điện thoại và GPS bằng Sales. Một số địa chỉ chỉ đến cấp xã/thị trấn: VPP Lê Gia (Bình Đại), VPP Ba Lai (Châu Thành), Nhà sách Trạng Nguyên (Mỏ Cày Nam), VPP Đăng Khuê (Thạnh Phú).
- VPP Phú Mỹ có nguồn ghi **Phú Thuận** và nguồn khác ghi **Châu Hưng** trên ĐT883; dùng địa bàn huyện Bình Đại cũ nhưng chưa khẳng định xã chính xác.
- Nhà sách Bến Tre 1 và VPP Sen Việt tại TP có nhiều nguồn địa chỉ không thống nhất; **không tự nhân bản** điểm bán cũ.
- Một số hồ sơ kinh doanh có MST chi nhánh; MST không xác nhận cửa hàng còn mở. Link Google Maps được dùng để tra cứu địa điểm, không có nghĩa GPS chính xác hoặc đã check-in.
- Giữ 14 Khách hàng chính cũ; không tạo trùng các điểm đã đăng ký bán.

## Kiểm tra thực tế trên app

Đăng nhập https://sales-mien-tay.vercel.app, menu **Điểm bán tiềm năng**, chọn **Bến Tre** rồi từng huyện cũ. Bộ lọc địa bàn/nhà sách/VPP là theo category nội bộ; trước mắt UX có tìm tên và trạng thái, **chưa có bộ lọc loại trực tiếp trên tab**. Tài khoản Admin hoặc Manager có quyền Bến Tre đọc được cả 49 điểm, Sales không có quyền Bến Tre không được xem. Nhấn làm mới để bỏ cache.

Tiếp theo nếu Owner cần **đầy đủ đến cấp xã**, phải khảo sát danh bạ địa phương/chủ tiệm/Google Maps ở từng xã, rà lại điểm nhỏ và xác minh thực địa; không thể xác nhận 49 điểm là toàn bộ thị trường.
