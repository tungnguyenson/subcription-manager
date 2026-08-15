# Đến Hạn

App iOS theo dõi mọi thứ có ngày hết hạn: gói dùng thử sắp bị tính tiền, hạn sử dụng của SIM trả trước, các khoản phải thanh toán, và dịch vụ tự gia hạn hàng tháng.

Viết bằng Kotlin Multiplatform, chạy hoàn toàn ngoại tuyến, không có tài khoản, không có máy chủ.

## Tài liệu

| Tệp | Nội dung |
|---|---|
| [docs/product-spec.md](docs/product-spec.md) | Đặc tả sản phẩm, giải thích vì sao có từng ràng buộc |
| [docs/design-spec.md](docs/design-spec.md) | Đặc tả giao diện, dùng để đưa qua khâu thiết kế |
| [docs/build-plan.md](docs/build-plan.md) | Danh sách thi công và trạng thái từng việc |

## Chạy thử

```bash
./gradlew :shared:jvmTest          # chạy toàn bộ test nghiệp vụ
./gradlew :shared:compileKotlinIosArm64   # kiểm tra biên dịch cho iPhone thật
```

Cần JDK 21 và Xcode. Target JVM chỉ tồn tại để chạy test mà không cần máy ảo.

## Cấu trúc

```
shared/src/commonMain/kotlin/space/denhan/
  domain/      Mô hình và quy tắc nghiệp vụ, Kotlin thuần
  data/        Repository và ánh xạ dữ liệu
  catalog/     Danh sách dịch vụ và cấu hình nhà mạng
  extract/     Bóc dữ liệu từ ảnh bằng mô hình ngôn ngữ
  platform/    Khai báo expect cho phần phụ thuộc nền tảng
  backup/      Xuất và nhập dữ liệu

shared/src/iosMain/kotlin/space/denhan/
  data/        Driver SQLite trong App Group
  platform/    Keychain, thông báo, đọc chữ bằng Vision
```

## Những chỗ dễ sai đã có test canh

Mỗi dòng dưới đây là một lỗi âm thầm, không báo gì khi xảy ra.

| Chỗ | Sai thế nào | Canh ở đâu |
|---|---|---|
| Chu kỳ tháng | Cộng dồn từng tháng làm ngày 31 trôi mất vĩnh viễn | `RecurrenceTest` |
| Tiền VND | Nhân 100 theo thói quen làm mọi số tiền to gấp trăm lần | `MoneyTest` |
| Tràn số | `Int` 32 bit tràn với VND ở khoảng 55 tỷ | `MoneyTest` |
| Tỷ giá | Thiếu tỷ giá mà mặc định bằng 1 biến 20 đô thành 20 đồng | `FxTest` |
| Lịch sử tiền | Tính lại theo tỷ giá hôm nay làm số liệu quá khứ nhảy mỗi ngày | `FxTest`, `BackupTest` |
| Thông báo | iOS chỉ giữ 64 cái chờ, vượt là cái xa nhất bị vứt im lặng | `NotificationPlannerTest` |
| Khóa ngoại | SQLite mặc định không thực thi, nên xóa dữ liệu không dây chuyền | `ItemRepositoryTest` |
| Schema của mô hình | Trường không nullable ép mô hình bịa ra ngày | `ExtractionReviewTest` |
| Mã lỗi 429 | Gộp 5 tình huống, 3 trong đó thử lại vô ích | `OpenAiClientTest` |
| Trạng thái xác thực SIM | Giá trị lạ mà hiểu thành đã xác thực là nguy hiểm nhất | `ItemRepositoryTest`, `BackupTest` |

## Còn thiếu

Giao diện. Đang chờ bản thiết kế, xem mục H trong `docs/build-plan.md`.

Và một việc không giải quyết được bằng code: **gọi bốn nhà mạng xác minh mốc thu hồi số và giá gói giữ số**. Mọi con số hiện có đều lấy từ trang đại lý, không nhà mạng nào công bố chính thức. Với một app mà sai một con số là người dùng mất số điện thoại, đây là điều kiện chặn phát hành.
