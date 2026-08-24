# Subdock

App theo dõi mọi thứ có ngày hết hạn, chạy trên iOS và Android. Flutter, hoàn toàn
ngoại tuyến, không tài khoản, không máy chủ, một người dùng trên máy của chính họ.

Hai nền tảng ngang hàng nhau. Thêm bất cứ thứ gì chạm tới hệ điều hành thì câu hỏi bắt
buộc là: **nền tảng kia làm việc này thế nào, và nếu nó không làm được thì giao diện có
nói ra không.** Lịch sử của repo nghiêng về iOS nên vẫn còn comment viết như thể chỉ có
iOS; đó là dấu vết cũ, không phải chủ ý.

## Quản lý công việc

Dự án này theo dõi trong IndieWork với **project KEY là `SUB`**.

- Bảng công việc: https://app.indiework.space/app/p/SUB/overview
- Task được đánh số dạng `SUB-5`. Dùng các tool `mcp__indiework__*` để đọc và cập nhật.

Khi làm một task đã có trong IndieWork: đặt `in_progress` lúc bắt đầu, đặt `in_review`
kèm một comment tóm tắt những gì đã làm lúc xong. **Không tự đặt `done`**, đó là việc của
chủ dự án sau khi duyệt.

## Việc app thật sự làm

Đọc `docs/product-spec.md` trước khi đề xuất tính năng. Điểm dễ hiểu nhầm nhất:

> Đây **không phải** app quản lý chi tiêu. Việc của nó là **ngăn người dùng mất thứ họ
> không lấy lại được**.

Một SIM trả trước hết hạn là mất số điện thoại dùng mười năm. So với việc đó thì Netflix
trừ 260 nghìn là chuyện nhỏ. Hai mục trong cùng một danh sách có thể chênh nhau một nghìn
lần về mức nghiêm trọng, và giao diện phải nói được điều đó.

## Nguyên tắc xuyên suốt: không tỏ ra chắc chắn hơn mức thật

App **không đọc được hồ sơ bên nhà cung cấp**. Nó chỉ biết những gì người dùng gõ vào,
cộng một bảng giá tham khảo đóng gói sẵn. Cả code lẫn dữ liệu đều theo nguyên tắc này:

- `enum DateSource` ghi ngày này từ đâu ra: người dùng đã hỏi nhà cung cấp, người dùng
  nhớ áng chừng, hay app tự tính.
- Mỗi dòng giá trong danh mục bắt buộc có `source` là trang niêm yết của chính hãng và
  `checkedAt`. Không tra được thì để trống kèm lý do, **không đoán, không quy đổi tỉ giá**.
- `enum PurchaseChannel` ghi người dùng mua ở đâu, vì cùng một dịch vụ có ba trang billing
  khác nhau và chỉ họ biết mình mua ở đâu.

Khi thêm bất cứ thứ gì hiển thị một con số hoặc một ngày, câu hỏi đầu tiên là: **con số
này từ đâu ra, và giao diện có nói được điều đó không.**

## Cấu trúc

```
lib/domain/      Dart thuần, không import Flutter. Ngày, tiền, chu kỳ, nhắc hạn
lib/data/        drift + SQLite. tables.drift là nguồn chuẩn của lược đồ
lib/catalog/     Danh mục dịch vụ đóng gói sẵn
lib/ui/          Màn hình và widget. Tự vẽ icon, không dùng icon font
tool/            Script sinh mã và kiểm dữ liệu, chạy bằng python3
data/            Dữ liệu nguồn của danh mục, gộp vào assets/services.json
docs/            Đặc tả và nghiên cứu
```

## Lệnh hay dùng

```bash
dart run build_runner build --delete-conflicting-outputs   # bắt buộc sau khi clone
flutter test                                               # xem dòng tổng kết, không xem exit code
flutter analyze
dart format lib test

python3 tool/validate_services.py data/services/*.json     # kiểm dữ liệu danh mục
python3 tool/merge_services.py --write                     # gộp vào assets/services.json
python3 tool/coverage_table.py > docs/research/catalog-coverage.md
python3 tool/gen_service_marks.py                          # biên dịch icon thành Dart
flutter test test/golden/ --update-goldens                 # sau khi đổi icon

flutter build apk --debug && flutter install -d <device-id>   # cài lên máy Android
adb devices                                                # máy báo "unauthorized" thì
                                                           # phải bấm Allow trên điện thoại
```

Lần build Android đầu tiên sau khi clone mất khoảng nửa tiếng: Gradle tự tải NDK. Không
phải treo.

**`flutter test` trả về exit code 0 ngay cả khi có test hỏng.** Đọc dòng tổng kết cuối
cùng, hoặc chạy với `--reporter github` để thấy số rõ ràng.

## Mười một cái bẫy đã vấp, đừng vấp lại

1. **Thêm cột vào `itemRow` phải sửa hai chỗ**: bước migration của chính nó, và danh sách
   `newColumns` ở bước dựng lại bảng v3. Bước đó copy toàn bộ lược đồ hiện tại ra khỏi
   bảng cũ, nên thiếu chỗ thứ hai thì file cũ không nâng cấp được.
2. **Luật icon khớp theo tên người dùng gõ, không theo id.** Đổi `name` của một mục trong
   danh mục là golden test đỏ ngay.
3. **Trong `_rules` của `service_mark.dart`, cụm dài phải nằm trên từ nằm trong nó**, vì
   `detect` lấy kết quả khớp đầu tiên. `internet viettel` phải trên `viettel`.
4. **Đừng sắp lại khối luật icon cũ theo độ dài.** Thứ tự ở đó mang ý nghĩa ngữ nghĩa:
   `lái xe` phải thắng `giấy phép`, sắp theo độ dài sẽ biến giấy phép lái xe thành chứng chỉ.
5. **Trùng alias làm một mục biến mất khỏi kết quả tìm.** Search trả về kết quả khớp đầu
   tiên. `merge_services.py` chặn việc này, đừng bỏ qua cảnh báo của nó.
6. **jsdelivr trả HTTP 200 cho file không tồn tại**, kèm nội dung là một dòng báo lỗi. Dò
   độ phủ icon bằng mã trạng thái sẽ ra kết quả sai hoàn toàn.
7. **iOS chặn hoàn toàn việc quay số USSD từ app**, và `%23` làm `canOpenURL:` trả `true`
   nên code trông như chạy được trong khi dialer im lặng không mở.
8. **`AnnualSaving.savingMinor` có thể bằng 0.** Có hãng niêm yết gói năm đúng bằng 12
   lần gói tháng và để phần giảm giá ở khuyến mãi. Chỗ nào hiện khoản tiết kiệm phải tự
   loại trường hợp này, không thì ra dòng chữ "Save 0 ₫ a year".
9. **Android tách quyền thông báo và quyền báo thức đúng giờ làm hai.** Có quyền thứ nhất
   mà thiếu quyền thứ hai thì nhắc hạn vẫn tới, nhưng tới lúc hệ thống thức dậy chứ không
   đúng phút đã hẹn. `SCHEDULE_EXACT_ALARM` không được cấp sẵn khi cài mới, với app target
   API 33 trở lên. Tệ hơn: `zonedSchedule` **ném lỗi** chứ không tự hạ cấp, một lần ném là
   hỏng cả vòng `apply` và người dùng mất sạch nhắc hạn. `notification_scheduler.dart` hỏi
   `canScheduleExactNotifications()` trước rồi mới chọn `exact` hay `inexact`, và
   `reminder_rules_screen.dart` nói ra khi đang chạy inexact.
   **Đừng dò quyền này bằng `adb shell dumpsys package`**: nó in `granted=true` cho cả máy
   chưa thật sự cho phép, vì đây là quyền đặc biệt và cổng thật nằm ở AppOps. `cmd appops
   get <pkg> SCHEDULE_EXACT_ALARM` trả `Default mode: default` cũng không kết luận được.
   Chỉ có `canScheduleExactAlarms()` hỏi từ trong app mới ra câu trả lời thật.
10. **`compileSdk` của thư viện bị ghim xuống 36 trong `android/build.gradle.kts`.**
    `flutter_secure_storage` đặt cứng 37 nhưng SDK chỉ có gói tên `android-37.0` còn AGP
    đi tìm `android-37`. Khối override phải nằm **trên** khối `evaluationDependsOn(":app")`
    và phải là `afterEvaluate`; đặt sai một trong hai chỗ là build gãy theo hai kiểu khác
    nhau. Điều kiện gỡ bỏ ghi trong comment ngay tại đó.
11. **Ngân sách 50 nhắc hạn là giới hạn của iOS, đang áp cho cả hai nền tảng.** Không có
    con số công bố cho Android mà app dám trích, nên nó dùng chung con số đã biết thay vì
    đoán một con số to hơn. Chữ trên giao diện vì thế **không được nêu tên nền tảng nào**,
    có test khoá điều này.

## Viết tài liệu

Tài liệu trong repo viết bằng **tiếng Việt**, chữ trên giao diện app viết bằng **tiếng
Anh**. Hook `vn-writing` sẽ chặn nếu tài liệu tiếng Việt có em-dash hoặc jargon không nền.

Tránh từ **"trục"**: nó là cách dịch thẳng của *axis* và tối nghĩa với người đọc. Viết
thẳng thứ đang nói tới, ví dụ "hai cách phân loại khác nhau".

## Bắt đầu từ đâu

| Muốn biết | Đọc |
|---|---|
| App làm gì và vì sao | `docs/product-spec.md` |
| Giao diện | Canvas `Subdock Handoff.dc.html` bên Claude Design, **không nằm trong repo**. `docs/design-spec.md` đã cũ và có ghi rõ ở đầu file |
| Phần riêng của Android | `android/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/` |
| Danh mục dịch vụ | `docs/research/README.md` |
| Icon | `docs/icon-credits.md` |
| Việc còn dang dở | `data/services/_verify.md` |
| Khối so sánh gói năm và nút trang thuê bao | `docs/design-spec-annual-saving.md`, đã dựng, logic ở `lib/ui/annual_saving_presenter.dart` và `lib/ui/manage_presenter.dart` |
