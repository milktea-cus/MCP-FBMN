# VĨNH LONG CŨ — ĐỢT 3/3 (TRÀ ÔN, VŨNG LIÊM) VÀ ĐỐI SOÁT 8/8 ĐỊA BÀN

Ngày rà soát và nhập Neon: **21/11/2026**. Repo `milktea-cus/MCP-FBMN`, branch `main`. Neon production `raspy-bar-51596929` / `br-super-mountain-bdije4mj`. Đối tượng: **lead nhà sách / VPP từ nguồn công khai**, không phải khách hàng hoặc điểm đã ghé thực tế.

## Ba đợt đúng theo địa giới Vĩnh Long cũ

- **Đợt 1:** Thành phố Vĩnh Long (15), Long Hồ (8), Mang Thít (9), tổng 32.
- **Đợt 2:** Thị xã Bình Minh (9), Bình Tân (5), Tam Bình (7), tổng 21.
- **Đợt 3:** Trà Ôn (12), Vũng Liêm (11), tổng 23.

Giữ `province='Vĩnh Long'`, `district` tên đơn vị **cũ** trong `backend/src/districts_old.json`, không nhập các cửa hàng thuộc **Bến Tre/Trà Vinh cũ** vào Vĩnh Long cũ dù hiện cùng tỉnh mới.

## Kết quả migration 121 (đã áp dụng production)

| Địa bàn cũ | Điểm mới | Nhà sách | VPP/đầu mối | Điện thoại | MST |
|---|---:|---:|---:|---:|---:|
| Huyện Trà Ôn | **12** | 4 | 8 | 8 | 2 |
| Huyện Vũng Liêm | **11** | 5 | 6 | 9 | 0 |
| **Tổng** | **23** | **9** | **14** | **17** | **2** |

- File SQL: `backend/migrations/121_vinh_long_old_wave03_tra_on_vung_liem_2026.sql`.
- Commit SQL: `8b54708dbbfcf78c710b9761678b476bdea77f0e`.
- Batch: `2026-11-21-vinh-long-old-wave-03-two-districts`.
- **23/23** có URL HTTPS, key nguồn riêng, trạng thái `new`, `source_kind='manual'`, ghi chú `CHƯA GHÉ`. Không có GPS, visits hoặc cờ đã bán; **không** tạo hồ sơ khách.
- Migration chống trùng exact nguồn, tên + địa chỉ, cùng số điện thoại/MST trong huyện và khách chính. Chạy lại nội dung SQL đã fetch từ GitHub trên Neon production: **0 bản ghi mới**.

## Điểm cụ thể đã nhập và nguồn công khai

**Trà Ôn (12):**

1. Nhà sách **Thanh Phong**, đường Thống Chế Điều Bát: [Viet-Biz](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-thanh-phong_1S-0270-3770-626) và [hồ sơ nhà thầu](https://dauthau.asia/businesslistings/detail/NHA-SACH-THANH-PHONG-189349/); năm 2025 trúng thầu giấy/VPP. Cần xác minh số 12 hay 12/1, **không tạo hai cơ sở**.
2. Nhà sách **Thanh Vân**, 13 Lê Lợi: [Viet-Biz](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-thanh-v%C3%A2n-0270-3770-216) phân loại là tạp hóa dù tên nhà sách, cần xác minh hàng sách/VPP.
3. Nhà sách **Cô Ánh**, 6 tổ 19 khu phố: [Sổ Tay Vàng](https://sotayvang.com/nha-sach-co-anh-tra-on/) và Maps; cần đối chiếu khu vực Vĩnh Xuân/Trà Ôn, không gán nhầm xã cũ.
4. Nhà sách **Thầy Tám**, Hựu Thành cũ, Plus Code X35M+MVX: [Sổ Tay Vàng](https://sotayvang.com/nha-sach-thay-tam-huu-thanh/).
5. VPP **Trấn Nghiệp**, Trà Côn, Plus Code 2X8R+G7G: [Sổ Tay Vàng](https://sotayvang.com/van-phong-pham-tran-nghiep-tra-con/).
6. VPP **Ngọc Anh**, Lê Lợi (XW79+WHG): bản đồ Google Place ID `ChIJO6AjvCtkoDER8m9RJD21nQ0`.
7. VPP **Bửu Gia**, 19 Gia Long (XW8C+FCF): bản đồ `ChIJceEgYytkoDERsk-VYzai-Gk`.
8. VPP **Cô Thùy**, Lục Sĩ Thành (XW45+HG6): Maps `ChIJf-pYSwBnoDERdMXSJcm9imM`. Nhóm bán buôn; chưa chứng minh quầy bán lẻ.
9. **Điện thoại – VPP – photo Tiến Đạt**, Lục Sĩ Thành (XW46+2R7): Maps `ChIJ56l5K2pnoDERXULr65bpMWQ`. Nguồn pha trộn điện thoại/VPP.
10. **Photo Phước Tín**, Trà Côn (XXR5+453), Maps `ChIJHw5oH5BloDER5XutK7360CQ`; được phân loại stationery nhưng phải xác minh.
11. **Shop quần áo – VPP Vân Anh**, 229 ấp Tích, Maps `ChIJTSsWCwBpoDERSsT8VryyShw`; cần xác minh có kinh doanh VPP thật.
12. **In ấn – Quảng cáo Hải Thông**, số 129 khu 6 xã Trà Ôn hiện hành, [đăng ký kinh doanh](https://dulieuphapluat.vn/cong-cu/ma-so-thue/1501142769-cong-ty-tnhh-mtv-in-an-va-quang-cao-hai-thong.html) có mã ngành bán lẻ sách VPP; **chưa xác minh quầy bán lẻ**, cần đối chiếu địa giới thị trấn Trà Ôn/Tích Thiện cũ.

**Vũng Liêm (11):**

1. Nhà sách **Nguyễn Khanh**, 275 ĐT902: [Viet-Biz](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-nguy%E1%BB%85n-khanh-0270-3870-010).
2. Nhà sách **II / Vân Anh**, 181 ĐT902: [Viet-Biz](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-ll-0270-3870-729), [Sổ Tay Vàng](https://sotayvang.com/nha-sach-van-anh-vung-liem/); cùng số nhà và điện thoại nên **gộp 1**, không tính thành 2.
3. Nhà sách **Hồng Nhan**, Nam Kỳ Khởi Nghĩa: [HappyNew.Day](https://happynew.day/vendor/nha-sach-hong-nhan), Maps `ChIJ83ECd8wNoDERnXRWcY6Qoec`. **Địa chỉ không nhất quán 91/103**, cần gọi xác minh; không tạo hai bản ghi.
4. Nhà sách **Lan Phương**, Nam Kỳ Khởi Nghĩa (35PQ+VMX): [Viet-Biz](https://www.viet-biz.com/nh%C3%A0-s%C3%A1ch-lan-ph%C6%B0%C6%A1ng-0270-3976-124).
5. Nhà sách **Nhật Duyên**, QL53/Hiếu Phụng (34M9+GFW), Maps `ChIJSS-mfABzoDERqUbS2wXWz_E`; gần Phúc Hảo, cần kiểm tra cửa hàng độc lập.
6. VPP **Minh Thư**, 907 ấp Trung Tín: [Sổ Tay Vàng](https://sotayvang.com/van-phong-pham-minh-thu-vung-liem-ap-trung-tin/).
7. VPP **Lam Chi**, 228 ĐT902 Quới An: Maps `ChIJWUoCX_oNoDERh58--nKS6uA`.
8. **Thiết bị văn phòng Quốc Đạt**, ĐT902 (35RQ+94W): Maps `ChIJ_SyFKe8MoDERKdLgAHosFpQ`, cần xác nhận nhóm hàng học phẩm.
9. **Photocopy – VPP Phúc Hảo**, QL53 Hiếu Phụng: [Sổ Tay Vàng](https://sotayvang.com/cua-hang-van-phong-pham-phuc-hao-hieu-phung/); Maps có hai Plus Code rất sát, cùng tên/điện thoại nên **gộp 1**.
10. **Shop VPP Phương Anh**, 135 Nam Kỳ Khởi Nghĩa: Maps `ChIJi6gTGaANoDER4hiZKsKuspE`, cần xác minh tên biển hiệu và nhóm hàng.
11. **VPP Thanh Hùng**, Quới An (5578+52J): Maps `ChIJDZs8nCkLoDERtmA-uW98zJg`; chưa có số nhà/điện thoại.

## Tổng kết Neon production — 8/8 địa bàn cũ CÓ dữ liệu

| Địa bàn | Tổng | Nhà sách | Có điện thoại | Có MST |
|---|---:|---:|---:|---:|
| Thành phố Vĩnh Long | 15 | 11 | 12 | 1 |
| Long Hồ | 8 | 1 | 4 | 1 |
| Mang Thít | 9 | 4 | 5 | 2 |
| Vũng Liêm | 11 | 5 | 9 | 0 |
| Tam Bình | 7 | 2 | 3 | 3 |
| TX Bình Minh | 9 | 6 | 7 | 4 |
| Trà Ôn | 12 | 4 | 8 | 2 |
| Bình Tân | 5 | 0 | 1 | 3 |
| **Tổng** | **76** | **33** | **49** | **16** |

- Đợt 1: **32**, đợt 2: **21**, đợt 3: **23**.
- Kiểm production: **76/76** có `research_source_key` và URL HTTPS; **76/76** `new`, `manual`, `CHƯA GHÉ`, không GPS/lượt ghé; không phát hiện trùng exact tên+địa chỉ trong huyện, source key, số điện thoại/MST cùng huyện.
- Đối chiếu khách chính trong cùng tỉnh/huyện theo tên/số điện thoại: **0** trùng; hai khách chính `Lan Thì` (TP Vĩnh Long), `Lộc Phát` (Bình Tân) không thay đổi.
- **Chưa nghiệm thu** 100% độ phủ ngoài thực tế, nhất là Bình Tân 5, Tam Bình 7, Long Hồ 8, Mang Thít 9 và các xã/chợ vùng sâu Trà Ôn, Vũng Liêm. Nhiều hồ sơ chỉ là doanh nghiệp có mã ngành VPP hoặc cửa hàng photo/quà tặng; không coi tất cả là cửa hàng sách đang mở.
- **Không triển khai Worker/Vercel mới** vì chỉ bổ sung lead bằng migration SQL. CI kiểm riêng và smoke API/Auth/PWA/Android thực tế chưa thực hiện trong đợt import.

### SQL kiểm sản lượng

```sql
SELECT district,COUNT(*) total,
 COUNT(*) FILTER (WHERE category='nha_sach') bookstores,
 COUNT(*) FILTER (WHERE phone IS NOT NULL) phones,
 COUNT(*) FILTER (WHERE tax_code IS NOT NULL) tax_codes,
 COUNT(*) FILTER (WHERE research_source_url LIKE 'https://%') sources,
 COUNT(*) FILTER (WHERE last_visit_at IS NOT NULL) visits
FROM public.field_prospects WHERE province='Vĩnh Long'
GROUP BY district ORDER BY district;

SELECT research_batch,count(*) FROM public.field_prospects WHERE province='Vĩnh Long'
GROUP BY research_batch ORDER BY research_batch;
```
