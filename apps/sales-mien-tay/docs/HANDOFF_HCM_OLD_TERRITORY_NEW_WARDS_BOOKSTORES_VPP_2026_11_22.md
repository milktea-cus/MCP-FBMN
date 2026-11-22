# BÀN GIAO CHAT MỚI — MCP-FBMN: ĐIỂM BÁN NHÀ SÁCH / VPP TẠI TP.HCM CŨ, ĐỊA DANH MỚI

**Ngày:** 22/11/2026. **Yêu cầu mới nhất của Owner:** chỉ thu thập cửa hàng **nhà sách** và **văn phòng phẩm** nằm trong **phạm vi lãnh thổ TP.HCM trước khi sáp nhập tỉnh ngày 01/07/2025**. Địa chỉ kết quả phải sử dụng **tên phường/xã TP.HCM mới**; tuyệt đối không mở rộng sang lãnh thổ **Bình Dương cũ** hoặc **Bà Rịa – Vũng Tàu cũ** dù sau 2025 cùng mang tên TP.HCM. Ưu tiên làm kỹ theo từng nhóm **3 phường/xã mới mỗi lô** để tránh bỏ sót.

## 1. Phân định địa lý cứng (P0 — KHÔNG TỰ MỞ RỘNG)

- **IN SCOPE:** đúng địa giới **TP.HCM cũ**, bao gồm các quận nội thành cũ, **TP Thủ Đức cũ**, và các **huyện Củ Chi, Hóc Môn, Bình Chánh, Nhà Bè, Cần Giờ cũ**. Sau sắp xếp 2025, phạm vi TP.HCM cũ gồm **102 đơn vị cấp xã: 78 phường, 24 xã** (trong đó xã đảo **Thạnh An** giữ nguyên), không phải tất cả 168 đơn vị cấp xã của thành phố hợp nhất.
- **OUT OF SCOPE:** mọi điểm thuộc **Bình Dương cũ** (ví dụ Thủ Dầu Một, Dĩ An, Thuận An, Bến Cát, Tân Uyên, Bàu Bàng, Dầu Tiếng, Bắc Tân Uyên, Phú Giáo) hoặc **Bà Rịa – Vũng Tàu cũ** (ví dụ TP Vũng Tàu, Bà Rịa, Phú Mỹ, Long Điền, Long Đất, Xuyên Mộc, Châu Đức, Côn Đảo); kể cả khi Maps hoặc website ghi “TP.HCM” mới.
- **Nguồn gốc bắt buộc:** [Nghị quyết 202/2025/QH15](https://congbao.cdnchinhphu.vn/CongBaoCP/VanBan/2025/6/45050/56708-1-2025773-774202-2025-qh15.pdf) xác định ba tỉnh/thành cũ hợp thành TP.HCM mới; [Nghị quyết 1685/NQ-UBTVQH15](https://xaydungchinhsach.chinhphu.vn/toan-van-nghi-quyet-so-1685-nq-ubtvqh15-sap-xep-cac-dvhc-cap-xa-cua-thanh-pho-ho-chi-minh-nam-2025-119250616211341304.htm) xác định tên và phạm vi phường/xã mới; [Trung tâm Báo chí TPHCM — 102 phường/xã trên lãnh thổ cũ](https://ttbc-hcm.gov.vn/chi-tiet-102-phuong-xa-moi-cua-tphcm-1018454.html).
- **QUAN TRỌNG:** trong Nghị quyết 1685, các khoản **1–78 (phường)**, **113–135 (xã)** cộng **xã Thạnh An giữ nguyên** thuộc phạm vi TP.HCM cũ. Các khoản xen giữa từ tỉnh cũ khác KHÔNG được kéo vào. Đối chiếu nguồn chính thức và ranh giới thực địa cho từng điểm, nhất là khi tên phường/xã trùng nhau hoặc địa chỉ cũ dùng quận/huyện.
- **Tin 27/08/2026 về 29 xã lên phường:** HĐND mới **tán thành đề án, giao hoàn thiện hồ sơ để cấp có thẩm quyền quyết định** (ví dụ Củ Chi, Bình Chánh, Nhà Bè). **KHÔNG tự coi đổi loại xã→phường đã có hiệu lực** nếu chưa tìm được văn bản quyết định cuối cùng tại thời điểm nhập. Tên và loại địa danh phải theo văn bản đang hiệu lực. Tham khảo [HĐND TP.HCM](https://hdnd.hochiminhcity.gov.vn/tin-tuc/tin-hoat-dong-hdnd-cap-xa/29-xa-thanh-phuong-tai-tp-hcm-phat-trien-kinh-te-thu-nhap-nguoi-dan-se-tot-hon).

## 2. Repo, production và tình trạng trước khi bắt đầu

- GitHub: https://github.com/milktea-cus/MCP-FBMN.git — **branch main**, làm việc trực tiếp, không tạo app/repo/ZIP thay thế.
- Neon production: project `raspy-bar-51596929`, branch `br-super-mountain-bdije4mj`. Dùng plugin Neon đã kết nối; đọc schema, data, ràng buộc trước khi tạo migration, **không sửa/xóa dữ liệu hiện hữu**.
- Backend: Cloudflare Workers; frontend Flutter Web/PWA production Vercel https://sales-mien-tay.vercel.app . Không deploy Worker/Vercel cho SQL/docs-only.
- Snapshot đọc Neon 22/11/2026: **738** bản ghi `public.field_prospects`, phân bổ **13 tỉnh miền Tây cũ**, **0** bản ghi có `province` TP.HCM. Hệ hiện tại được thiết kế cho 13 tỉnh cũ, **KHÔNG lấy mốc 738 để báo tiến độ TP.HCM**.
- Schema `public.field_prospects` hiện có: `name`, `address_line`, `province`, `district`, `category`, `phone`, `tax_code`, `note`, `status`, `source_kind`, `research_source_key`, `research_source_url`, `research_batch`, `area_visit_id`, `last_visit_*` ... **CHƯA CÓ CỘT PHƯỜNG/XÃ MỚI**. Đầu tiên phải audit Backend API, Flutter RegionCatalog/filter, migration và cấu trúc DB, bổ sung **`ward_new` hoặc cấu trúc tương đương** với địa danh mới mà không phá dữ liệu 13 tỉnh cũ. KHÔNG ghi tên phường mới nhầm vào cột `district` (đang là “Huyện cũ”) chỉ để hiển thị.
- Mẫu SQL chuẩn chống trùng và bảo toàn trạng thái nghiên cứu: [migration 162](../backend/migrations/162_tien_giang_old_round02_my_tho_go_cong_2026.sql). **Không sao chép cứng `province/district` Tiền Giang hoặc owner_sub** sang batch TP.HCM trước khi xác định scope/phân quyền.

## 3. Đầu ra mỗi cửa hàng

Tìm **điểm bán lẻ thực tế** (có mặt bằng/quầy bán) thuộc:
1. **Nhà sách:** sách giáo khoa, sách tham khảo, sách thiếu nhi, cửa hàng có bán sách và dụng cụ học tập.
2. **Văn phòng phẩm:** bút, tập vở, giấy A4, dụng cụ học tập, vật tư VPP; tiệm đa ngành chỉ nhận khi có bằng chứng thực sự bán các sản phẩm này.

Ghi và lưu tối thiểu: **tên bảng hiệu**, loại `nha_sach` / `van_phong_pham`, **địa chỉ hiện hành** (số nhà/đường, **phường/xã mới**, **TP.HCM**), địa chỉ **quận/huyện/phường cũ** để đối chiếu, **nguồn và ngày kiểm**, số điện thoại **nếu công khai**, Google Maps URL / place ID / Plus Code, nguồn trực tiếp chứng minh bán sách/VPP, chú thích `chưa ghé/chưa xác minh hoạt động`, khoá nguồn chống trùng, batch. Nếu không tìm thấy số điện thoại thì để NULL, **không tự bịa**.

- **Không nhập:** trường học, nhà in/photocopy đơn thuần không chứng minh bán VPP; công ty chỉ đăng ký ngành bán buôn; địa chỉ công ty không có bằng chứng cửa hàng; doanh nghiệp đã đóng; quầy mập mờ tên/địa chỉ; điểm ở tỉnh sáp nhập; chi nhánh trùng hoặc di chuyển địa chỉ mà chưa đối soát.
- **Không giả GPS:** tọa độ trên Maps là tư liệu định vị nghiên cứu, **không phải** bằng chứng Sales đến nơi; `area_visit_id`, `last_visit_at`, các tọa độ chuyến ghé phải để NULL, `status='new'`. Không thêm vào `customers` hoặc tự đánh dấu đã mở, đã bán.
- **Chống trùng hai lớp:** so với **`public.customers`** và **`public.field_prospects`** theo mã địa điểm, nguồn, số ĐT đã chuẩn hoá, MST, tên + địa chỉ/quan hệ chi nhánh; không dựa duy nhất vào tên. Kiểm số điện thoại trùng nhưng tên khác, cùng số nhà khác bảng hiệu và địa chỉ cũ/mới cùng cơ sở.

## 4. Cách triển khai, không dừng ở kế hoạch

1. **P0-A: Khoá ranh giới và địa danh.** Lập danh mục 102 phường/xã từ nguồn chính thức, kiểm tra loại phường/xã đang có hiệu lực tháng 11/2026. Mỗi bản ghi địa lý có `new_ward`, `old_origin='TP.HCM trước 01/07/2025'`, `old_district`, old ward/address/map boundary; loại hết vùng Bình Dương/BRVT. Dùng điểm tọa độ hoặc đối chiếu xã cũ khi địa giới nghi vấn, không coi Google Maps “TP.HCM” là bằng chứng đủ.
2. **P0-B: Schema & giao diện tương thích.** Audit backend/migrations/API/search, Flutter mobile PWA/Android và Neon. Thiết kế bổ sung lưu địa danh mới **không đổi nghĩa province/district của 738 lead miền Tây**; frontend/API đủ lọc phường mới, tìm lead TP.HCM và phân quyền Sales, vẫn giữ offline-first IndexedDB/SQLite. Chỉ sửa phần cần thiết và test.
3. **P0-C: Thu thập theo lô 3 phường/xã mới.** Chia 102 đơn vị thành từng nhóm không trùng, rà từng tuyến đường lớn, hẻm/chợ/trường (trường chỉ để tìm quầy xung quanh). Tìm từ Maps, website cửa hàng, trang thương hiệu/supplier, danh bạ có xác minh, nguồn mạng xã hội có bài bán hàng. Đối chiếu `customers` + `field_prospects` trước khi insert; **3 đơn vị là phạm vi quét, không phải định mức số lead**.
4. **P0-D: Ghi Neon production có kiểm soát.** Migration SQL idempotent commit trước trên `main`, đọc lại GitHub, insert hàng đủ nguồn vào đúng scope và danh mục, chạy lại 0 dòng, kiểm đếm trước/sau, 0 key trùng, 0 GPS/visit giả. Không tự chỉnh `customers`.
5. **P0-E: Báo cáo theo lô.** Với từng phường/xã: lead cũ / thêm / tổng; số có số ĐT, nguồn Maps, địa chỉ mới, điểm mơ hồ bị loại, khu vực đã tìm, phần trắng cần khảo sát trực tiếp. CI, API, DB, app lọc đúng; deploy production qua plugin khi có thay đổi API/UI và đã qua gate. Không coi CI xanh là app nghiệm thu.

## 5. Kết quả phải bàn giao cho Owner sau mỗi lô

- **Chỉ số:** Đã rà X/102 phường-xã thuộc **TP.HCM cũ**; thêm Y lead nhà sách, Z lead VPP; số địa bàn chưa đủ nguồn; số điểm có ĐT; tỷ lệ URL/source hợp lệ; số trùng bị loại.
- **Bằng chứng:** link migration + commit, kết quả query Neon production và kiểm lại idempotency, link báo cáo per-batch, CI/run ID, trạng thái deploy (nếu có).
- **Ranh giới:** 0 điểm Bình Dương cũ, 0 điểm Bà Rịa – Vũng Tàu cũ; các địa chỉ mơ hồ chưa được chèn.
- **Quy tắc:** làm thật trực tiếp trên repo và production đúng quyền, không nhờ Owner chạy CMD, không đòi lại link/DB đã có, không đánh tráo kế hoạch thành dữ liệu đã nhập.

## 6. Bước thực thi đầu tiên cho chat mới

Đọc tài liệu này và `standards/ui-fbmn/`, kiểm tra `public.field_prospects`, API và catalog địa lý; lập bộ lọc **102 phường/xã thuộc HCM cũ**. Chọn nhóm đầu **3 phường mới ở khu vực trung tâm** (ví dụ **Sài Gòn – Tân Định – Bến Thành**) và rà sâu cửa hàng theo từng khu phố/đường. Lưu ý **Phường Sài Gòn/Tân Định/Bến Thành là địa danh sau 2025**, còn danh bạ cũ có thể ghi Quận 1; phải quy đổi thật đúng với địa chỉ gốc. Sau đó ghi migration đầu tiên nếu đủ bằng chứng, đối soát Neon, báo ngắn kết quả. Không cần hỏi lại Owner phạm vi đã chỉ rõ.

**Cảnh báo tiến độ:** Đây là **bàn giao nhiệm vụ kế tiếp**, **CHƯA** cào/ghi bất kỳ lead TP.HCM nào; snapshot hiện có là 738 lead miền Tây, không phải TP.HCM.
