# MCP-FBMN — RÀ BÙ NHÀ SÁCH / VPP HẬU GIANG CŨ — ĐỢT 1 (CHỈ 3 HUYỆN)

**Ngày rà:** 22/11/2026  
**Phạm vi duy nhất:** `Huyện Long Mỹ`, `Huyện Vị Thủy`, `Huyện Phụng Hiệp` — tỉnh **Hậu Giang CŨ**, theo `backend/src/districts_old.json`. Không ghép sang tỉnh mới hoặc các huyện, thị xã khác.  
**Dữ liệu:** Neon production `raspy-bar-51596929` / `br-super-mountain-bdije4mj`; `field_prospects` là nghiên cứu online **chưa ghé**, không phải khách đã xác minh.

## Đối chiếu Neon trước và sau

| Huyện cũ | Trước | Bổ sung migration 159 | Sau | Ghi chú |
|---|---:|---:|---:|---|
| Huyện Long Mỹ | 0 | 0 | **0** | Chưa có cơ sở bán lẻ sách/VPP được nguồn công khai xác nhận đúng **huyện**; không dùng điểm từ **thị xã Long Mỹ** |
| Huyện Vị Thủy | 2 | **2** | **4** | Ưu tiên khu vực Nàng Mau, Vị Thủy; tiếp tục xác minh mặt hàng thực bán |
| Huyện Phụng Hiệp | 2 | **2** | **4** | Ưu tiên Kinh Cùng, Tân Bình, Cây Dương, Hiệp Hưng |
| **Tổng** | **4** | **4** | **8** | Không ghi GPS/lượt ghé giả |

**Toàn hệ thống:** sau migration 159: **730 lead**, **132/134 địa bàn cũ có lead**, **27 địa bàn có 1–2 lead**; `status=new` 730/730; source HTTPS 730/730; research key 730/730; nguồn key trùng 0, dấu GPS/visit 0. Chạy lại nguyên migration thêm **0 bản ghi** (idempotent).

## 4 điểm nghiên cứu mới được chèn

| Huyện cũ | Điểm bán | Địa chỉ nguồn | Số điện thoại | Nguồn / điều cần xác minh |
|---|---|---|---|---|
| Vị Thủy | **Photo - VPP Phương Phương** | 177 Nguyễn Tri Phương, khu Nàng Mau cũ | Chưa công khai | [Maps — place ID ChIJa4wGDwDvoDERYM6aK9UIS6A](https://www.google.com/maps/search/?api=1&query=Photo%20VPP%20Phuong%20Phuong%20Vi%20Thuy&query_place_id=ChIJa4wGDwDvoDERYM6aK9UIS6A) ghi Stationery store; [hồ sơ hộ kinh doanh tên Phương Phương](https://dauthau.asia/businesslistings/detail/HO-KINH-DOANH-PHUONG-PHUONG-158349/) có ngành bán lẻ sách/VPP và hoạt động in ấn, nhưng **chưa chứng minh hai hồ sơ là cùng một điểm** |
| Vị Thủy | **VPP Sáu Cáo** | Đường Lê Hồng Phong, khu Vị Thủy cũ | 0969913698 | [Maps — ChIJVS9aCRjvoDERybCFNONbDqM](https://www.google.com/maps/search/?api=1&query=Van%20Phong%20Pham%20Sau%20Cao%20Vi%20Thuy&query_place_id=ChIJVS9aCRjvoDERybCFNONbDqM), danh mục School supply store; chưa rõ số nhà/xã cũ cụ thể |
| Phụng Hiệp | **VPP Vân Duyên** | 96 QL61, TT Kinh Cùng cũ | Chưa công khai | [Maps — ChIJ31E9w9HzoDERrbOFUqXbKI4](https://www.google.com/maps/search/?api=1&query=Van%20Phong%20Pham%20Van%20Duyen%20Kinh%20Cung&query_place_id=ChIJ31E9w9HzoDERrbOFUqXbKI4), tên cửa hàng VPP và địa chỉ rõ; chưa có chứng cứ danh mục sản phẩm/còn mở |
| Phụng Hiệp | **VPP Việt Chương** | 391 QL61, ấp Tân Phú, xã Tân Bình cũ | Chưa công khai | [Maps — ChIJd4fPriXzoDEROQxT2gCsHQA](https://www.google.com/maps/search/?api=1&query=Van%20Phong%20Pham%20Viet%20Chuong%20Tan%20Binh&query_place_id=ChIJd4fPriXzoDEROQxT2gCsHQA), phân loại Stationery store; chưa có số điện thoại |

- SQL: [`159_hau_giang_old_round02_three_districts_2026.sql`](../backend/migrations/159_hau_giang_old_round02_three_districts_2026.sql), commit [`9d80b89`](https://github.com/milktea-cus/MCP-FBMN/commit/9d80b893f55befb6999d55d3166cba3e3e997e95). Tất cả `source_kind=manual`, `status=new`, `area_visit_id=NULL`, không có GPS. Các điểm mới không được tự coi là cửa hàng đã xác minh hoạt động trong năm 2026.

## Phạm vi rà theo xã/thị trấn và nguồn đối chiếu

| Huyện | Địa bàn đã dùng để tìm nguồn trực tuyến | Kết quả và giới hạn |
|---|---|---|
| **Long Mỹ** | TT Vĩnh Viễn, Lương Tâm, Lương Nghĩa, Vĩnh Thuận Đông, Xà Phiên, Vĩnh Viễn A | Chưa có cửa hàng sách/VPP có địa chỉ chính xác + loại hàng bán đủ chứng cứ. Các kết quả nghi vấn thường chỉ là đăng ký kinh doanh hoặc sai sang thị xã. **Chưa thể kết luận ngoài đời không có cửa hàng.** |
| **Vị Thủy** | TT Nàng Mau, Vị Bình, Vị Thủy, Vị Đông, Vị Thanh; trục Nguyễn Tri Phương/QL61/Lê Hồng Phong | Có 2 ứng viên mới, giữ Hiệu sách Thích trong customers và 2 lead Minh Trí/Quỳnh Như; chưa xác nhận tọa độ GPS của cơ sở mới |
| **Phụng Hiệp** | TT Kinh Cùng, Cây Dương, Búng Tàu, Hiệp Hưng, Tân Bình, Tân Long/Hòa An | 2 ứng viên mới; giữ lead Hải Minh và VPP-Photocopy Kim Ngân; danh mục bản đồ và hồ sơ thiếu xác nhận hoạt động thực tế |

**Địa giới:** Quốc hội ghi nhận từ khi thành lập thị trấn Vĩnh Viễn, huyện Long Mỹ gồm TT Vĩnh Viễn và 7 xã ([nguồn](https://quochoi.vn/pages/tim-kiem.aspx?ItemID=39620)). Đề án Phụng Hiệp ghi TT Kinh Cùng, Cây Dương, Búng Tàu và xã Tân Bình thuộc Phụng Hiệp cũ ([nguồn](https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/De-an-01-DA-UBND-2024-thanh-lap-thi-tran-Tan-Long-thuoc-huyen-Phung-Hiep-Hau-Giang-620152.aspx)).

## Không nhập vì sai huyện / trùng / chưa đủ chứng cứ

1. **Nhà sách Long Mỹ** số 142K đường 30/4, phường Thuận An, **THỊ XÃ Long Mỹ cũ**, không phải Huyện Long Mỹ. [Nguồn chủ thể đăng ký](https://yp.com.vn/listing/cong-ty-tnhh-nha-sach-long-my-6300379580/) và nguồn danh sách điểm bán VPMilk thống nhất thị xã. Không được lấy địa chỉ cũ trước khi tách thị xã làm chứng cứ huyện hiện hành 2025.
2. **NS Thể Minh** số 46 Nguyễn Huệ hiện trong `customers` gán Huyện Long Mỹ nhưng nguồn ngành chỉ ra **Thị xã Long Mỹ cũ**. **Không tự sửa khách chính** vì có thể ảnh hưởng phân quyền Sales và tuyến.
3. **Công ty TNHH Thiết bị Văn phòng Phương Vy** tại ấp 1 TT Vĩnh Viễn: hồ sơ ngành chính bán buôn thiết bị, **không chứng minh có cửa hàng VPP bán lẻ**; không nhập.
4. **Nhà sách Hồng Ân — chi nhánh Vĩnh Viễn**: hồ sơ mã số thuế đã hết hiệu lực, không nhập cửa hàng đã ngừng. [Nguồn](https://masothue.com/1801093287-001-chi-nhanh-cong-ty-tnhh-mot-thanh-vien-phan-dang-nha-sach-hong-an).
5. **VPP Sáu Nên** 77 QL61, TT Kinh Cùng: [danh bạ](https://vietnam.contact.page/locations/vn-vi67-ha-u-giang/listings?page=7) có tên nhưng Google Maps cùng địa chỉ ghi **Hương Giang**, chưa phân biệt đổi tên/trùng gian hàng; không nhập cho đến khi xác minh.
6. **Nhà sách Hải Minh**, **VPP - photocopy Kim Ngân** tại Phụng Hiệp và **Hiệu sách Thích** tại Vị Thủy đã có trong `field_prospects` hoặc `customers`, không tạo lại từ nguồn khác.

## Công việc còn phải xác minh

- **Long Mỹ là huyện P0 vẫn 0 lead:** gọi/kiểm địa phương tại chợ Vĩnh Viễn, gần THPT Tây Đô, THPT Lương Tâm và các trường Vĩnh Thuận Đông; chỉ thêm nếu gặp đúng cửa hàng sách/VPP có tên, địa chỉ, bằng chứng nguồn.
- **Phương Phương:** hỏi hộ kinh doanh và số 177 Nguyễn Tri Phương có trùng cơ sở không; nếu khác phải chỉnh ghi chú và nguồn, không tự gộp.
- **Sáu Cáo:** xác nhận xã/ấp cũ của cửa hàng. **Vân Duyên/Việt Chương:** xác minh bán bút/vở/sách, số điện thoại và còn kinh doanh.
- Bước tiếp theo của tỉnh Hậu Giang cũ: **đợt 2 chỉ 3 địa bàn**; chưa thực hiện. Không coi kết quả tìm trực tuyến là quét hết toàn bộ cửa hàng ngoài đời. Chưa kiểm thử GPS 100m hoặc PWA/Android chỉ từ SQL.
