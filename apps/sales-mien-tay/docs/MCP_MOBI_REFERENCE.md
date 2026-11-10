# MCP Field → Sales Miền Tây: customer/field sales product contract

**Nguồn tham chiếu đã đọc:** [`binhnxwjfjxm/mcp-mobi/ui-tham-khao.jpg`](https://github.com/binhnxwjfjxm/mcp-mobi/blob/e8e9bbd99c6d02c93d46ff5458e5e4c5995ab352/ui-tham-khao.jpg) tại commit `e8e9bbd99c6d02c93d46ff5458e5e4c5995ab352`. Repo `mcp-mobi` chỉ có ảnh và README; **không có model dữ liệu, UI tokens hay source Flutter**. Đây là ảnh *inspiration/reference*, **không được tự xưng là chuẩn FBMN chính thức**.

## Năm màn hình thể hiện rõ trong ảnh

1. **Hôm nay**: tuyến hôm nay, tiến độ ghé điểm, đơn hàng, báo cáo, việc cần làm, điểm bán kế tiếp.
2. **Đi tuyến**: danh sách/map, khoảng cách đến điểm bán, chưa ghé/đã ghé, chuyển đến trang điểm bán.
3. **Điểm bán**: ảnh mặt tiền, mã, tên, loại hình, địa chỉ, điện thoại, chủ cửa hàng, lịch sử ghé, check-in, tạo đơn, báo cáo, thử sản phẩm, nhiệm vụ.
4. **Ra đơn**: chọn điểm bán, tìm SKU, số lượng, giá, tạm tính, lưu nháp/tiếp tục.
5. **Báo cáo**: chọn điểm bán/ngày, loại báo cáo (trưng bày, hàng hóa, hoạt động đối thủ, ghi chú), nhiều ảnh, ghi chú, gửi.

## Mô hình dữ liệu chuẩn đề xuất cho sản phẩm

| Nhóm | Field | Lưu trữ | Quy tắc |
|---|---|---|---|
| Định danh | `id`, `client_ref`, `code`, `owner_sub`, `version` | `customers` | `client_ref` UUID idempotent cho offline, `version` chống ghi đè đồng thời |
| Điểm bán | `name`, `category`, `status`, `note` | `customers` | Bắt buộc tên, phân loại, chủ sở hữu |
| Liên hệ | `contact_name`, `phone` | `customers` | PII; quyền theo owner/địa bàn, không public |
| Địa bàn | `province`, `district`, `address_line` | `customers` | Địa giới cũ 13 tỉnh/134 huyện; huyện phải nằm trong tỉnh |
| Vị trí | `latitude`, `longitude`, `location_accuracy_m`, `location_consent` | `customers` | Chỉ ghi khi được đồng ý; GPS không phải bằng chứng chống giả vị trí tuyệt đối |
| Ảnh cửa hàng | `id`, `customer_id`, `object_key`, `mime_type`, `bytes` | R2 + `customer_photos` | Không public R2; ảnh truy cập qua API có Auth; giới hạn 5MB/ảnh |
| Ghé/check-in | `customer_id`, `owner_sub`, `client_ref`, `checkin_at`, `lat/lon`, `accuracy_m`, `distance_m` | `field_visits` | Server timestamp, accuracy <=100m, khoảng cách <=200m, idempotent |
| Phân quyền | `user_sub`, `province`, `district` | `staff_scopes` | Không có phân địa bàn thì không tạo/sửa điểm bán; manager chỉ xem vùng được cấp |
| Audit | actor, action, entity, time | `field_audit_events` | Không lưu số điện thoại/nội dung ảnh vào log |

### Bắt buộc cho phiên bản sản phẩm hoàn chỉnh (chưa làm xong)

- `routes`, `route_stops`, tối ưu tuyến/điểm tiếp theo và danh sách việc trong ngày.
- `products`, `price_lists`, `orders`, `order_items`, tính giá/thuế/khuyến mãi/duyệt đơn rõ ràng.
- `field_reports`, `report_photos`, trạng thái duyệt, liên kết ảnh với báo cáo.
- Thiết bị offline-first có storage được mã hóa, hàng đợi sync và xử lý xung đột rõ ràng.
- Cấu hình OIDC/PKCE đăng nhập thật, quyền cá nhân và địa bàn; admin phân quyền qua giao diện.
- Đảm bảo strip EXIF và chính sách retention/xóa ảnh, Android kiosk qua Device Owner nếu cần cứng hệ điều hành.

## Thiết kế UI tham chiếu (KHÔNG PHẢI token chuẩn FBMN)

- Mobile-first: Trang hôm nay, Đi tuyến, Điểm bán, Đơn hàng, Thêm/báo cáo; mỗi màn một mục tiêu chính.
- Card điểm bán: ảnh cửa hàng, tên, địa chỉ, số điện thoại, khoảng cách có nhãn độ chính xác, ghé gần nhất.
- Form: ngắn, chọn tỉnh -> huyện phụ thuộc, số điện thoại optional, vị trí và ảnh tách khỏi thông tin bắt buộc.
- Thao tác GPS/ảnh luôn xin quyền, báo lỗi và cho retry; không tự động định vị nền.
- Bắt buộc thiết kế loading/empty/error/offline/conflict ở web và Android, touch target >=44dp.
- Màu/icon trong ảnh chỉ dùng làm **tham khảo trực quan**; chưa tìm thấy color tokens, typography, radius, spacing chính thức của FBMN để kiểm tra khác biệt.

## Ranh giới release

**CI xanh = source build**, KHÔNG chứng minh OIDC configured, R2 bound, database migrated, app production hay kiosk. Chỉ deploy nếu có đủ config bảo mật, migration, smoke tests và backup/restore; xem `PRODUCT_RELEASE_GATES.md`.