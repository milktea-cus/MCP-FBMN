# MCP-FBMN · Business Applications

Monorepo của dự án. Các ứng dụng kinh doanh được đặt riêng tại `apps/`; các tiêu chuẩn UI có nguồn gốc xác thực được quản lý tại `standards/ui-fbmn/`.

## Trạng thái

- `apps/sales-mien-tay/`: ứng dụng Sales Miền Tây Flutter/Dart (Android + PWA), Cloudflare Workers API, Neon PostgreSQL. Đang triển khai theo pha, **không phải bản production**.
- `standards/ui-fbmn/`: chưa có bộ quy tắc UI FBMN gốc trong repo tại thời điểm khởi tạo. Không đồng nhất Material 3 hoặc mã của `QR-app` với tiêu chuẩn FBMN khi chưa đối chiếu được nguồn.

Mọi thay đổi chức năng đi theo branch → PR → CI → review → merge. Không chứa secrets hoặc dữ liệu khách hàng thật trong mã nguồn. Các bước deploy production cần build, test và môi trường xác thực.

Tài liệu triển khai: [Sales Miền Tây](apps/sales-mien-tay/README.md).

## Quy định deploy Vercel hiện hành (Owner chốt 13/11/2026)

GitHub Actions của repo **đã hết quota**, vì vậy Field Work **deploy Vercel production thủ công qua plugin/API Vercel hoặc công cụ do trợ lý trực tiếp vận hành**; không chạy workflow issue-comment `/deploy production`, không yêu cầu Owner chạy CMD và không tạo preview/project thay thế. Vẫn phải build Flutter Web từ đúng `main` SHA bằng môi trường ngoài GitHub Actions, kiểm thử, xác nhận Neon + Worker, kiểm tra URL production và lưu bằng chứng ở Issue #3. Không bỏ cổng nghiệm thu chỉ vì deploy thủ công.

Chi tiết: [MASTER_CHECKLIST_2026-11-13.md](apps/sales-mien-tay/docs/MASTER_CHECKLIST_2026-11-13.md).
