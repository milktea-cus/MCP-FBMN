# QUY TRÌNH GIAO HÀNG GITHUB

Đây là gói **Git-ready** đã giải nén, không phải một Git push thành công. Không có repo Sales đích được xác nhận tại thời điểm tạo.

## Không nhập nhầm

- KHÔNG push vào `milktea-cus/QR-app` chỉ vì repo đó có code và quyền ghi.
- KHÔNG push vào `milktea-cus/MCP-FBMN` khi repo đó đang được coi là **nguồn UI FBMN** và đang trống.
- Nếu muốn dùng `MCP-FBMN` làm repo đích, cần quyết định rõ ràng đây là repo sản phẩm và nguồn UI mới phải chỉ ra riêng.

## Quy trình kết nối GitHub đã có repo đích

1. Xác minh repo và current default branch; mở issue P0-P8 theo `IMPLEMENTATION_PLAN.md`.
2. Tạo branch `feature/sales-mientay-foundation`, commit source đã giải nén cùng docs; tránh bí mật.
3. Chạy kiểm tra static, dependency audit, Flutter analyze/test, TS typecheck; ghi cái nào chưa làm và lý do.
4. Open **draft PR**, ghi source hashes và blocker UI FBMN.
5. Lấy UI gốc, PR theo module, gate nghiệm thu; không merge/deploy tự động.

## Tệp không được đẩy

`.env*` (trừ `.env.example` an toàn), API tokens, DB URL, certificate, signing keys, keystore, secret keys, userdata thật, build cache/binaries không có chính sách quản lý.

## Hướng dẫn Git CLI (nếu có repo Sales đích)

```bash
# Thực hiện trên máy có GitHub credentials phù hợp
# Kiểm tra repo đích TRƯỚC khi chạy
# git clone git@github.com:milktea-cus/<sales-app-repo>.git
# cd <sales-app-repo>
# git switch -c feature/sales-mientay-foundation
# chép các thư mục source từ gói Git-ready, không chép dữ liệu secrets
# git add .
# git diff --cached --stat
# git commit -m "chore(sales): import reviewed foundation and delivery plan"
# git push -u origin feature/sales-mientay-foundation
# Tạo draft PR và chờ review/quality gates
```

Các lệnh trên là ví dụ, **chưa được thực thi**. Repo target chưa có tên rõ ràng; không có action tạo repo mới trong GitHub connector hiện có.