# Audit phủ Trường học — 13 tỉnh / 134 huyện cũ — 16/11/2026

Nguồn: truy vấn **Neon production** `public.schools` và danh mục địa giới `backend/src/districts_old.json`.
Phạm vi: **cấp 1 / cấp 2 / cấp 3 và trường liên cấp**. Không coi cấp mầm non là trường phổ thông.
Cảnh báo: số bản ghi hiện có không phải số trường thật hiện hành và 2026 có sáp nhập;
**không công bố hoàn tất địa bàn chỉ vì có ít nhất 1 trường**.

## 1. Baseline đang có trên production

- **277** records; **13/13** tỉnh cũ có ít nhất một record.
- **61/134** huyện cũ có ít nhất một record; **73** huyện cũ hoàn toàn trống.
- **182** bản ghi preliminary có địa chỉ và link nhưng chưa được xác thực độc lập;
  **95** bản ghi audit nguồn 2026 (có thể chưa đầy đủ và còn alias cũ).
- Số GPS được xác minh: **0**. Google Maps là link **tìm kiếm**, không phải tọa độ định tuyến chính xác.

| Tỉnh cũ | Huyện trong danh mục | Có dữ liệu | Trống | Bản ghi |
|---|---:|---:|---:|---:|
| Long An | 15 | 7 | 8 | 18 |
| Tiền Giang | 11 | 4 | 7 | 14 |
| Bến Tre | 9 | 6 | 3 | 15 |
| Trà Vinh | 9 | 3 | 6 | 8 |
| Vĩnh Long | 8 | 4 | 4 | 8 |
| Đồng Tháp | 12 | 3 | 9 | 16 |
| An Giang | 11 | 6 | 5 | 105 |
| Kiên Giang | 15 | 5 | 10 | 10 |
| Hậu Giang | 8 | 7 | 1 | 24 |
| Sóc Trăng | 11 | 4 | 7 | 10 |
| Bạc Liêu | 7 | 3 | 4 | 12 |
| Cà Mau | 9 | 6 | 3 | 24 |
| Cần Thơ | 9 | 3 | 6 | 13 |
| **Tổng** | **134** | **61** | **73** | **277** |

## 2. Danh sách địa bàn hiện trống

- **Long An** (8/15 trống): Huyện Tân Hưng; Huyện Vĩnh Hưng; Huyện Tân Thạnh; Huyện Thạnh Hóa; Huyện Đức Huệ; Huyện Đức Hòa; Huyện Cần Giuộc; Huyện Châu Thành
- **Tiền Giang** (7/11 trống): Thành phố Mỹ Tho; Thành phố Gò Công; Thị xã Cai Lậy; Huyện Tân Phước; Huyện Cai Lậy; Huyện Châu Thành; Huyện Gò Công Tây
- **Bến Tre** (3/9 trống): Huyện Chợ Lách; Huyện Bình Đại; Huyện Ba Tri
- **Trà Vinh** (6/9 trống): Thành phố Trà Vinh; Huyện Càng Long; Huyện Cầu Kè; Huyện Tiểu Cần; Huyện Duyên Hải; Thị xã Duyên Hải
- **Vĩnh Long** (4/8 trống): Huyện Mang Thít; Huyện Vũng Liêm; Huyện Trà Ôn; Huyện Bình Tân
- **Đồng Tháp** (9/12 trống): Thành phố Hồng Ngự; Huyện Tân Hồng; Huyện Hồng Ngự; Huyện Tam Nông; Huyện Cao Lãnh; Huyện Thanh Bình; Huyện Lấp Vò; Huyện Lai Vung; Huyện Châu Thành
- **An Giang** (5/11 trống): Thị xã Tân Châu; Huyện Phú Tân; Thị xã Tịnh Biên; Huyện Tri Tôn; Huyện Châu Thành
- **Kiên Giang** (10/15 trống): Thành phố Rạch Giá; Thành phố Hà Tiên; Huyện Kiên Lương; Huyện Hòn Đất; Huyện An Minh; Huyện Vĩnh Thuận; Thành phố Phú Quốc; Huyện Kiên Hải; Huyện U Minh Thượng; Huyện Giang Thành
- **Hậu Giang** (1/8 trống): Thị xã Long Mỹ
- **Sóc Trăng** (7/11 trống): Thành phố Sóc Trăng; Huyện Châu Thành; Huyện Kế Sách; Huyện Long Phú; Huyện Mỹ Xuyên; Thị xã Ngã Năm; Huyện Thạnh Trị
- **Bạc Liêu** (4/7 trống): Huyện Hồng Dân; Huyện Phước Long; Huyện Đông Hải; Huyện Hòa Bình
- **Cà Mau** (3/9 trống): Huyện Năm Căn; Huyện Phú Tân; Huyện Ngọc Hiển
- **Cần Thơ** (6/9 trống): Quận Ninh Kiều; Quận Ô Môn; Quận Bình Thủy; Quận Cái Răng; Quận Thốt Nốt; Huyện Thới Lai

## 3. Cấp học và trường liên cấp

DB hiện dùng 6 loại hợp lệ: `Tiểu học`, `THCS`, `THPT`, `Tiểu học & THCS`,
`THCS & THPT`, `Tiểu học & THCS & THPT`.

API `GET /api/v1/schools?level=1|2|3` lọc tất cả trường có cấp tương ứng;
`level` sai trả HTTP 400; authorization theo staff territory và customer visibility giữ nguyên.
Flutter có dropdown cấp học (tất cả/1/2/3), nhãn liên cấp và IndexedDB/SQLite cache
được chia theo cấp học. Mỗi trường liên cấp vẫn chỉ một card trong danh mục.

## 4. Chuyển sang một lần ingest toàn bộ, không nhập huyện lẻ

- Nguồn hồ sơ: ưu tiên phương án/quyết định sáp nhập và danh sách công khai từng Sở GDĐT /
  UBND xã năm học 2026–2027. **Không scrape cổng CSDL Bộ nếu cần quyền truy cập**.
- Hợp nhất theo cơ sở **hiện hành** và mã định danh trường nếu nguồn có mã.
  Trường cũ đã sáp nhập thành trường mới chỉ là alias lịch sử, không thành trường độc lập.
- Mỗi dòng dữ liệu đầu vào: `name,education_level,province_old,district_old,address_text,source_url`
  và khuyến nghị `school_code,ward_old,address_detail_level,verification_note`.
- `scripts/schools_bulk_ingest.py` kiểm 13 tỉnh/134 huyện, nguồn HTTPS, 6 loại cấp học,
  khóa định danh và trùng tên trong huyện, tự tạo Maps search khi thiếu.
  Mặc định **từ chối lô chưa phủ đủ 134 huyện**; `--allow-partial` chỉ cho audit/thử nghiệm.
- Script xuất **một SQL migration** review trước, không tự kết nối production;
  sau commit + CI xanh mới thực hiện INSERT idempotent trên Neon qua kết nối chuẩn.
  Không có DELETE, UPDATE hay ghi GPS giả.
- Muốn Sales tìm điểm bán gần *từng địa điểm học thực*, cần danh mục **phân hiệu /
  điểm trường (school_sites)** bên cạnh trường đầu mối để tránh gộp nhiều địa điểm làm một.
  Không làm giả tọa độ hoặc biến phân hiệu thành trường độc lập.

Ví dụ kiểm tra dữ liệu đã đối chiếu:

```sh
python3 scripts/schools_bulk_ingest.py --input school_official_2026.csv --check-only
python3 scripts/schools_bulk_ingest.py --input school_official_2026.csv --batch 2026-11-16-schools-official --output backend/migrations/071_schools_bulk_official.sql
```

## 5. Nguồn gốc về sự thay đổi số trường 2026

- CSDL Bộ GDĐT: https://csdl.moet.gov.vn/ (truy cập phân quyền; **chưa có export được kết nối**).
- Đồng Tháp (tỉnh mới): công bố phương án 1180/PA-UBND và khoảng 375 cơ sở giáo dục sau sáp nhập:
  https://thongkedongthap.nso.gov.vn/tinh-hinh-kinh-te-xa-hoi/159
- An Giang (tỉnh mới): sau sáp nhập còn 562 đầu mối trường mầm non, tiểu học, THCS, liên cấp
  trực thuộc cấp xã; số này **không** thể so trực tiếp với số liệu An Giang cũ:
  https://angiang.gov.vn/vi/an-giang-giam-613-dau-moi-truong-hoc-sau-sap-xep-sap-nhap

**Tình trạng:** tạo cơ chế batch + bộ lọc cấp học; **chưa có nguồn danh sách trường đầy đủ 134 huyện**
để nhập một lần và chưa nghiệm thu 100% trường/phân hiệu hiện hành.

## 6. Chuẩn hóa địa bàn live — đã áp dụng 16/11/2026

- Migration `071_schools_canonical_old_district_names.sql` đã chạy production sau CI xanh.
- Sửa **43 record**, **15 bí danh huyện** (TP/TX thành Thành phố/Thị xã; TX Ngã Bảy thành Thành phố Ngã Bảy) đúng danh mục 134 huyện cũ.
- Đối chiếu Neon sau sửa: **61 địa bàn có trường**, **0 địa bàn sai tên**, **73 địa bàn trống**, tổng trường giữ **277** và không đổi mã nguồn trường.
- Trước sửa có 88 địa bàn không khớp chuẩn trong đó 15 là lỗi nhãn. Không được nhầm số 88 đó với số địa bàn thực sự chưa có trường.
