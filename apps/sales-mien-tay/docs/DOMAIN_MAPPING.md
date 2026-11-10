# Đối chiếu nghiệp vụ Excel → ứng dụng

Nguồn: `Form_Sales_Mien_Tay_V4_Du_13_Tinh_Huyen_Theo_Tinh.xlsx` và `Form_Ke_Hoach_Sales_Thang.xlsx` do người dùng cung cấp.

## Form khảo sát (file 1)

| Sheet | Bản đồ mô hình | Quy tắc |
| --- | --- | --- |
| `KHẢO SÁT KHÁCH HÀNG` | `kind=survey` | Một điểm bán/một bản ghi khảo sát; tên, loại điểm bán, tỉnh/huyện/xã, địa chỉ, người liên hệ, SĐT, NPP, nhãn, sản lượng, tiềm năng, trạng thái, nhân viên, ngày, ghi chú |
| `TỔNG HIỆN DIỆN` | Dashboard hiện diện theo tỉnh | Đếm khách một lần; KH được tính ở nhiều NPP/nhãn khác nhau; không cộng NPP để ra tổng KH; chỉ 'Có' được tính là hiện diện |
| `DANH MỤC`, `ĐỊA BÀN CŨ` | `districts_old.json` | 13 tỉnh/TP trước sáp nhập 2025, tổng 134 quận/huyện; đổi tỉnh xóa huyện, chọn lại |

NPP: `Thanh Đạt`, `Liên Hiệp`, `Hồng Ân`, `NPP khác`.
Nhãn: `MGP`, `HH`, `Hoa Sen`, `Thành Đạt (đối thủ)`, `Bút Cầu`, `Bến Nghé`, `Nhãn khác`.
**NPP Thanh Đạt không phải nhãn Thành Đạt (đối thủ).**

## Kế hoạch tháng (file 2)

| Sheet | `kind` | Bản đồ trường dữ liệu |
| --- | --- | --- |
| `01_KE_HOACH_THANG` | `target` | Sales, tháng/năm, khu vực, target tháng, đăng ký 5 tuần, việc trọng tâm |
| `02_KH_DU_KIEN` | `forecast` | Khách hàng, tỉnh/huyện, phân loại, nhóm hàng, trạng thái, dự kiến 5 tuần, tổng tháng = tổng 5 tuần, việc cần làm |
| `03_DI_CHUYEN` | `visit` | Tuần, ngày, tỉnh/huyện, tuyến, điểm ghé, mục đích, kết quả cần đạt, ghi chú |
| `04_DAI_LY` | `dealer` | Điểm bán, liên hệ/SĐT, lợi thế, khả năng ký, tuần dự kiến, điều kiện, bước kế tiếp, doanh số kỳ vọng, trạng thái |
| `05_DOI_THU` | `competitor` | Tỉnh, nhãn hàng, chương trình, thưởng/chiết khấu, giá, thời gian, nguồn, nhận định |
| `06_DE_XUAT` | `support` | Địa bàn, vấn đề/cơ hội, hỗ trợ đề nghị, kết quả mong đợi, mức ưu tiên, hạn, trạng thái, bộ phận, ghi chú |
| `DANH MỤC`, `ĐỊA BÀN CŨ` | dữ liệu dùng chung | 13 tỉnh và 134 huyện cũ |

**Quy tắc doanh thu:** Doanh số kỳ vọng từ `dealer` không được tự cộng vào doanh thu tháng. Doanh thu kế hoạch theo khách = tổng 5 tuần của từng `forecast` (không phải số ngày ghé). Chỉ tiêu `target` là kế hoạch đăng ký, phân biệt với `forecast`.

## Đề xuất mô hình dữ liệu production (chưa triển khai)

Bản khởi tạo hiện dùng `sales_records` + JSONB cho phép thử UI/API nhanh. Trước khi vận hành chính thức nên tách thành `outlets`, `outlet_surveys`, `outlet_distributors`, `outlet_brands`, `sales_monthly_targets`, `sales_forecasts`, `sales_visits`, `dealer_opportunities`, `competitor_programs`, `support_requests`, `audit_logs` với khóa ngoại/unique và phân vùng dữ liệu theo tổ đội.

## Những điểm cần hoàn thiện trước production

- Nguồn xác thực OIDC, RBAC theo sales/giám sát/admin, quản trị người dùng/tuyến/địa bàn.
- Tránh trùng điểm bán và một khách trong kế hoạch của một sales/tháng; dedupe theo ID thay vì chỉ tên.
- Giới hạn/phân trang API và thống kê trên server (MVP tải tối đa 200 bản ghi/loại).
- Cơ chế offline mã hóa, hàng đợi đồng bộ, xử lý conflict, lưu nhật ký chỉnh sửa.
- Import lịch sử từ Excel, xuất Excel/PDF, giao việc/thông báo, bảng phân quyền phê duyệt.
- Kiểm tra số liệu/biểu mẫu với sales thực địa trước nghiệm thu.