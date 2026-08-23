# Kế hoạch dựng app

Tài liệu này liệt kê các việc cần làm để dựng **Đến Hạn** theo `product-spec.md`, kèm trạng thái từng việc. Đây là danh sách thi công, cập nhật trong lúc làm.

**Phạm vi lần này:** mọi thứ trừ giao diện. Các màn hình Compose chờ bản thiết kế, xem mục H.

Ký hiệu: `[ ]` chưa làm, `[~]` đang làm, `[x]` xong, `[-]` hoãn.

---

## A. Dựng khung dự án

- [x] A1. Cấu trúc thư mục Kotlin Multiplatform, target iOS và Android
- [x] A2. Danh mục phiên bản thư viện (version catalog)
- [x] A3. Cấu hình Gradle cho từng module
- [x] A4. Đặt cơ sở dữ liệu trong App Group ngay từ đầu (mục 9.0bis của spec)
- [x] A5. Build thử, xác nhận biên dịch được

## B. Tầng nghiệp vụ, Dart thuần, không phụ thuộc Flutter

Đây là phần chứa các lỗi nguy hiểm nhất, nên viết test cho từng phần.

- [x] B1. **Tiền:** số nguyên 64 bit, bảng số chữ số thập phân theo ISO 4217, VND bằng 0
- [x] B2. **Chu kỳ:** tính từ ngày gốc, không cộng dồn. Test bắt buộc: 31/1 cộng 2 tháng phải ra 31/3
- [x] B3. **Mô hình dữ liệu:** `TrackedItem`, `Stake`, `Kind`, `State`, `ItemGroup`, `SimProfile`, `HandledEvent`
- [x] B4. **Suy ra mức rủi ro** từ loại mục
- [x] B5. **Bộ phân bổ thông báo:** hàm thuần nhận danh sách mục, trả về danh sách mốc nhắc, tối đa 50 chỗ, xếp theo mức rủi ro rồi ngày
- [x] B6. **Tỷ giá:** bảng đóng gói sẵn, quy tắc quá cũ thì ẩn
- [x] B7. **Ngày phải làm** tách khỏi ngày hết hạn

## C. Lưu trữ

- [x] C1. Schema SQLDelight
- [x] C2. Các câu truy vấn
- [x] C3. Lớp repository, trả về `Flow`

## D. Dữ liệu đóng gói sẵn

- [x] D1. Danh sách khoảng 80 dịch vụ, gồm quốc tế và Việt Nam
- [-] D2. Cấu hình nhà mạng. Bỏ, SIM dùng mô hình chung

## E. Cầu nối nền tảng iOS

- [x] E1. **Keychain:** `expect/actual` trên `platform.Security`, đặt `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- [x] E2. **Thông báo:** `platform.UserNotifications`, đăng ký category lúc khởi động, giữ tham chiếu delegate
- [x] E3. **Đọc chữ:** `platform.Vision`, hỏi ngôn ngữ lúc chạy, tắt sửa chính tả
- [ ] E4. Phần Swift tối thiểu: gán delegate trong `AppDelegate`

## F. Gọi mạng

- [x] F1. Ktor với engine Darwin
- [x] F2. Client OpenAI, dùng Responses API, schema chặt, mọi trường nullable
- [x] F3. Rẽ nhánh lỗi theo `code` trong thân lỗi, không theo mã HTTP

## G. Xuất và nhập dữ liệu

- [x] G1. Xuất ra JSON
- [x] G2. Xuất ra CSV
- [x] G3. Nhập lại từ tệp, có test đường khôi phục

## H. Giao diện

Dựng theo bản thiết kế `Subdock Graphite`, chốt ngày 16/08/2026.

- [x] H1. Màn hình Sắp đến hạn, gồm gom nhóm và mục xa hơn gập lại
- [x] H2. Form thêm mục, gồm gợi ý từ danh mục dịch vụ
- [x] H3. Màn hình chi tiết mục
- [x] H4. Màn hình chi tiết nhóm, dùng chung cho mọi loại nhóm
- [x] H5. Màn hình Tiền
- [x] H6. Màn hình Cài đặt
- [x] H7. Màn hình đối chiếu kết quả đọc ảnh
- [x] H8. Màn hình lời nhắc
- [x] H9. Màn hình những mục đã xong
- [x] H10. Màn hình giới thiệu lần đầu
- [x] H11. Điều hướng giữa các màn hình, có test chạy thật trên máy ảo
- [x] H12. Hệ màu mức rủi ro, mã hóa ba lớp: màu, đặc hay rỗng, độ đậm chữ

Hai chỗ lệch so với bản thiết kế, đều cố ý:

- Chi tiết nhóm dựng thành màn hình dùng chung. Bản thiết kế còn phần chuyên
  biệt cho SIM, là phần đã bỏ ở mục 4bis của đặc tả sản phẩm.
- Thêm nút cộng ở đầu danh sách. Bản thiết kế không có chỗ nào để thêm mục mới.

## H bis. Giao diện còn thiếu

- [ ] Màn hình sửa từng trường trong chi tiết mục
- [ ] Nút xuất và nhập tệp sao lưu, phần mã đã có và đã có test
- [ ] Khóa bằng Face ID

## I. Việc ngoài code

- [-] I1. Gọi 4 nhà mạng xác minh mốc thu hồi số. Bỏ, vì SIM giờ là mục thường
- [ ] I2. Thử chất lượng đọc chữ tiếng Việt trên 20 tới 30 ảnh chụp thật
- [-] I3. Tra hạn tự động từ app nhà mạng. Bỏ, cùng lý do
