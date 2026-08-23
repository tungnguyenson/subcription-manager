# Subdock

App iOS theo dõi mọi thứ có ngày hết hạn: gói dùng thử sắp bị tính tiền, hạn sử dụng của thẻ nạp trước, các khoản phải thanh toán, và dịch vụ tự gia hạn hàng tháng.

Viết bằng Flutter, chạy hoàn toàn ngoại tuyến, không có tài khoản, không có máy chủ.

## Tài liệu

| Tệp | Nội dung |
|---|---|
| [docs/product-spec.md](docs/product-spec.md) | Đặc tả sản phẩm, giải thích vì sao có từng ràng buộc |
| [docs/design-spec.md](docs/design-spec.md) | Đặc tả giao diện |
| [docs/build-plan.md](docs/build-plan.md) | Danh sách thi công và trạng thái từng việc |
| [docs/running.md](docs/running.md) | Chạy thử trên máy ảo và cài lên iPhone thật |

## Chạy thử

```bash
dart run build_runner build           # bắt buộc sau khi clone, sinh mã cho lớp dữ liệu
flutter test                          # test nghiệp vụ và giao diện, không cần máy ảo
flutter test integration_test -d <id> # chạy thật trên máy ảo, kiểm tra điều hướng
flutter analyze                       # kiểm tra tĩnh
flutter build ios --simulator --debug # kiểm tra biên dịch cho iPhone
```

Cần Flutter 3.47 trở lên và Xcode. Mã sinh tự động (`*.g.dart`) không nằm trong repo, nên phải chạy `build_runner` sau khi clone và sau mỗi lần sửa `lib/data/tables.drift`.

## Cấu trúc

```
lib/
  domain/      Mô hình và quy tắc nghiệp vụ, Dart thuần, không phụ thuộc Flutter
  data/        Lược đồ drift, repository, ánh xạ hàng dữ liệu sang mô hình
  catalog/     Danh sách dịch vụ dựng sẵn
  extract/     Bóc dữ liệu từ ảnh bằng mô hình ngôn ngữ
  backup/      Xuất và nhập dữ liệu
  platform/    Thông báo cục bộ, Keychain
  ui/
    theme.dart       Bảng màu, thang chữ, bo góc
    widgets/         Thành phần dùng lại giữa các màn hình
    screens/         Mười màn hình, mỗi màn hình một tệp
    *_presenter.dart Chuyển dữ liệu sang chữ hiển thị, thuần, có test riêng
assets/
  services.json      Danh mục dịch vụ
  fonts/             Be Vietnam Pro, bốn độ đậm
```

Mỗi màn hình chỉ nhận dữ liệu đã dựng sẵn và vẽ ra. Phần quyết định chữ nào hiện ra nằm ở các tệp `*_presenter.dart`, thuần và có test riêng, nên cách diễn đạt kiểm chứng được mà không cần dựng widget.

Lớp `domain` không import Flutter. Nhờ vậy mọi quy tắc nghiệp vụ chạy được trong test thuần, không cần máy ảo.

## Những chỗ dễ sai đã có test canh

Mỗi dòng dưới đây là một lỗi âm thầm, không báo gì khi xảy ra.

| Chỗ | Sai thế nào | Canh ở đâu |
|---|---|---|
| Kiểu ngày | `DateTime` của Dart cộng tháng theo kiểu tràn, 31/01 cộng một tháng thành 03/03 | `local_date_test` |
| Chu kỳ tháng | Cộng dồn từng tháng làm ngày 31 trôi mất vĩnh viễn | `recurrence_test` |
| Tiền VND | Nhân 100 theo thói quen làm mọi số tiền to gấp trăm lần | `money_test`, `money_format_test` |
| Tỷ giá | Thiếu tỷ giá mà mặc định bằng 1 biến 20 đô thành 20 đồng | `fx_test` |
| Lịch sử tiền | Tính lại theo tỷ giá hôm nay làm số liệu quá khứ nhảy mỗi ngày | `fx_test`, `backup_test` |
| Thông báo | iOS chỉ giữ 64 cái chờ, vượt là cái xa nhất bị vứt im lặng | `notification_planner_test` |
| Thứ tự thông báo | `List.sort` của Dart không ổn định, mỗi lần chạy lại cắt mất một cái khác | `notification_planner_test` |
| Id thông báo | `hashCode` không cam kết giống nhau giữa hai lần mở app, nên hủy thông báo cũ thất bại | `notification_planner_test` |
| Khóa ngoại | SQLite mặc định không thực thi, nên xóa dữ liệu không dây chuyền | `item_repository_test` |
| Ghi dữ liệu | Hàm sinh sẵn nhận 23 tham số vị trí, đổi chỗ hai trường cùng kiểu vẫn biên dịch được | dùng API có tên của drift |
| Giải mã phản hồi | `http.Response.body` rơi về latin-1 khi máy chủ không khai charset, làm hỏng chữ tiếng Việt | `openai_client_test` |
| Schema của mô hình | Trường không nullable ép mô hình bịa ra ngày | `extraction_review_test` |
| Mã lỗi 429 | Gộp 5 tình huống, 3 trong đó thử lại vô ích | `openai_client_test` |
| Múi giờ | Thiếu bảng múi giờ thì lời nhắc 08:30 đến vào 15:30 | đặt trong `NotificationScheduler` |

## Màn hình

| Màn hình | Vào từ đâu |
|---|---|
| Sắp đến hạn | Tab đầu |
| Tiền | Tab hai |
| Cài đặt | Tab ba |
| Chi tiết mục | Chạm một hàng |
| Chi tiết nhóm | Chạm hàng có mũi tên |
| Lời nhắc | Trong chi tiết mục |
| Những mục đã xong | Trong Cài đặt |
| Thêm mục | Nút cộng ở đầu danh sách |
| Đối chiếu kết quả đọc ảnh | Trong màn hình thêm mục |
| Giới thiệu | Tự hiện khi chưa có mục nào |

## Còn thiếu

- Đọc chữ từ ảnh chưa nối vào Vision, nên nút "Ảnh chụp" và "Dán chữ" chưa làm gì.
- Sửa một trường trong chi tiết mục chưa mở màn hình sửa.
- Xuất và nhập tệp sao lưu đã có mã và test, nhưng chưa gắn nút.
- Khóa bằng Face ID chưa làm.
