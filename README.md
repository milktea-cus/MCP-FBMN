# MCP-FBMN · Business Applications

Monorepo của dự án. Các ứng dụng kinh doanh được đặt riêng tại `apps/`; các tiêu chuẩn UI có nguồn gốc xác thực được quản lý tại `standards/ui-fbmn/`.

## Trạng thái

- `apps/sales-mien-tay/`: ứng dụng Sales Miền Tây Flutter/Dart (Android + PWA), Cloudflare Workers API, Neon PostgreSQL. Đang triển khai theo pha, **không phải bản production**.
- `standards/ui-fbmn/`: chưa có bộ quy tắc UI FBMN gốc trong repo tại thời điểm khởi tạo. Không đồng nhất Material 3 hoặc mã của `QR-app` với tiêu chuẩn FBMN khi chưa đối chiếu được nguồn.

Mọi thay đổi chức năng đi theo branch → PR → CI → review → merge. Không chứa secrets hoặc dữ liệu khách hàng thật trong mã nguồn. Các bước deploy production cần build, test và môi trường xác thực.

Tài liệu triển khai: [Sales Miền Tây](apps/sales-mien-tay/README.md).
