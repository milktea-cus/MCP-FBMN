# G02 — Shared Premium Glass UI Components (Website Futurebook only)

**Thuộc kế hoạch:** [roadmap duy nhất](roadmap.md) · [Website UI V2](web-component-design-system.md) · [G01 audit](web-glass-g01-audit.md).

## Bộ component dùng chung

Module `components/glass-ui.tsx` chỉ dành cho **Website Futurebook**, sử dụng `app/glass-foundation.css` và token `app/globals.css` từ G01.

| Export | Vai trò | Ngữ nghĩa |
|---|---|---|
| `GlassPageBackdrop` | Wrapper có gradient nền dự phòng | `div`; chưa gắn ảnh R2, không che click |
| `GlassHeader` | Khối header kính (không thay menu hiện tại) | `header`; không tự thay navigation |
| `GlassCard` | Card sản phẩm/tin tức với `strong` / `hover` tùy chọn | `article`; không tự biến card thành nút |
| `GlassPanel` | Khối nội dung/đặc tính glass | `section` |
| `GlassMediaFrame` | Frame trung tính cho ảnh sản phẩm thực | `div` trắng, không phủ màu ảnh |
| `GlassButton` | Nút thao tác thật; `type`, `disabled`, `loading` | `button`, hỗ trợ props native và `aria-busy` |
| `GlassButtonLink` | CTA điều hướng URL thật | Next.js `Link`, cần `href` |
| `GlassChip` | Chọn SKU/biến thể theo state do trang quản lý | `button`, `aria-pressed`, `data-selected` |
| `GlassChipLink` | Điều hướng sang URL SKU đang chọn | Next.js `Link`, `aria-current` khi active |

Các component chỉ bọc HTML + CSS và **không chứa logic sản phẩm**. Khi dùng trong component client có handler, component cha là nơi giữ state và được đánh dấu `"use client"`. Không thêm client hook vào toàn bộ trang server chỉ để áp glass.

## Quy chuẩn style và trạng thái

- Kính có fallback không blur, blur desktop 20px/mobile 12px từ G01; card 24px, panel 20px. Chỉ thêm class opt-in nên các style `.ref-*`, `.catalog-*` hiện hành giữ nguyên.
- `GlassCard hover` kế thừa hover-lift -3px / 200ms khi pointer phù hợp và **không bật reduced motion**. Các nút/chip dùng 190ms token hiện có; no-preference hover không tự động chuyển URL hay chặn hành động.
- Nút thường cao tối thiểu 36px desktop, 44px mobile; font 13px, radius chuẩn 9px. `pill` chỉ là ngoại lệ CTA Website, chip cũng dạng pill; không lan sang Admin.
- Primary tím brand; secondary kính sáng; ghost viền nhẹ. Giữ ngoại lệ CTA đỏ **ở vị trí trang chủ đã duyệt** khi rollout G05, không thay màu cũ trong G02.
- `loading` của `GlassButton` disable click, giữ nhãn và thêm `aria-busy`; `GlassChip` disabled dùng disabled native, trạng thái active có tương phản cao. Link cần `href` thật và không nhận props disabled giả lập.
- `GlassMediaFrame` nền trắng trung tính để ảnh SKU chính xác; khung không tự dựng, suy diễn hoặc làm màu bìa.
- Focus-visible, disabled, hover và reduced motion nằm trong một stylesheet. Không tạo CSS trang riêng để copy các trạng thái này.

## Hướng dẫn tích hợp G03/G05

Ví dụ từ một **client component** sử dụng state thật:

```tsx
"use client";
import { useState } from "react";
import { GlassCard, GlassChip, GlassButtonLink } from "@/components/glass-ui";

export function Example({ sku, quoteUrl }: { sku: string; quoteUrl: string }) {
  const [selected, setSelected] = useState(sku);
  return <GlassCard strong hover>
    <GlassChip selected={selected === sku} onClick={() => setSelected(sku)}>
      {sku}
    </GlassChip>
    <GlassButtonLink href={quoteUrl} pill>Liên hệ báo giá</GlassButtonLink>
  </GlassCard>;
}
```

**Đây chỉ là ví dụ API, không tạo sản phẩm hay CTA mới trong runtime.** G03 phải giữ handler SKU, URL và ảnh thật có sẵn; các component này thay lớp trình bày, không thay luồng business.

## Ranh giới nghiệm thu G02

- Test static contract `tests/web-glass-components.test.mjs`; CI `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`; Codex sạch.
- Không sửa `apps/admin/**`, không đổi API/DB, không đụng trang sản phẩm hiện tại, không thêm R2 URL giả; không deploy.
- G02 xây sẵn component cho **toàn Website**; chưa tuyên bố toàn Website đã mang phong cách kính cho đến G03/G05 và UAT thực tế.
