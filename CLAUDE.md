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
lib/domain/      Dart thuần, không import Flutter. Ngày, tiền, chu kỳ, nhắc hạn, nhóm
lib/i18n/        Mọi chữ trên giao diện, hai bản tiếng Anh và tiếng Việt
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

SHOTS_DARK=1 flutter test tool/shots/capture.dart --update-goldens   # cùng chỗ đó,
                                                           # bản tối, ra out/dark_*.png
SHOTS_VI=1 flutter test tool/shots/capture.dart --update-goldens     # bản tiếng Việt,
                                                           # ra out/vi_*.png. Chạy lại
                                                           # sau khi sửa chữ, vì tiếng
                                                           # Việt dài hơn tiếng Anh

flutter test tool/shots/capture.dart --update-goldens      # chụp lại 9 màn ở khung
                                                           # 390x844 vào tool/shots/out/
                                                           # để so với design/handoff

flutter build apk --debug && flutter install -d <device-id>   # cài lên máy Android
adb devices                                                # máy báo "unauthorized" thì
                                                           # phải bấm Allow trên điện thoại
```

Lần build Android đầu tiên sau khi clone mất khoảng nửa tiếng: Gradle tự tải NDK. Không
phải treo.

**`flutter test` trả về exit code 0 ngay cả khi có test hỏng.** Đọc dòng tổng kết cuối
cùng, hoặc chạy với `--reporter github` để thấy số rõ ràng.

**`flutter test` không chạy `integration_test/`.** Phải gọi tên từng file kèm một thiết
bị. Hệ quả đã xảy ra thật: ngày 28/08/2026 phát hiện `backup_test.dart` có 10 trên 11
bài đỏ, và chúng đỏ từ lúc màn Settings được sắp lại nhiều tháng trước mà không ai biết.
Đó lại đúng là những bài mà bẫy 26, 28, 43 và 45 viện làm chốt chặn, tức là bốn cái lưới
đã rơi cùng lúc. Chạy lại cả thư mục sau khi sửa bất kỳ màn hình nào:

```bash
for f in integration_test/*_test.dart; do flutter test "$f" -d <device-id>; done
```

Mất khoảng bốn phút mỗi file trên máy ảo, nên đừng chạy sau từng lần sửa nhỏ. Nhưng
phải chạy trước khi tin rằng một thay đổi về điều hướng hay bố cục đã xong.

## Năm mươi sáu cái bẫy đã vấp, đừng vấp lại

1. **Thêm cột vào `itemRow` phải sửa hai chỗ**: bước migration của chính nó, và danh sách
   `newColumns` ở bước dựng lại bảng v3. Bước đó copy toàn bộ lược đồ hiện tại ra khỏi
   bảng cũ, nên thiếu chỗ thứ hai thì file cũ không nâng cấp được.
   Từ v5 có `test/fixtures/schema_v4.dart` khoá cả hai đường: file v1 đi qua bước dựng
   lại, file v4 đi qua `addColumn`. Thêm cột mới thì thêm luôn tên nó vào cả hai bài test
   trong `migration_test.dart`, không thì đường v4 vẫn hỏng mà test vẫn xanh.
   Từ v6 có **bước dựng lại thứ hai**, chỉ chạy cho file đã ở v3 trở lên, để cột
   `category` nhận được khoá ngoại trỏ sang `categoryRow`. Bảng `categoryRow` phải được
   tạo và seed **trước cả hai** bước dựng lại, vì bước dựng lại nào cũng tạo bảng mới
   theo lược đồ hiện tại, tức là có sẵn khoá ngoại đó.
   Từ v7 có thêm hai điều. Một: **bước thêm cột của v7 nằm trên bước v6 trong file**, cố
   ý và bắt buộc, vì bước dựng lại của v6 đọc theo lược đồ hiện tại nên nó chết ngay nếu
   cột `inTrial` chưa tồn tại. Đổi lại, cột bị bỏ (`trialStart`) tự rụng khi đi qua bất
   kỳ bước dựng lại nào, vì bước đó chỉ chép những cột lược đồ mới có gọi tên. Hai: có
   `test/fixtures/schema_v6.dart`, và nó là đường **duy nhất** có dữ liệu thật để chuyển
   đổi. Hai fixture kia đều không có mục nào đang dùng thử, nên một phép chuyển đổi
   không làm gì cả vẫn xanh ở đó. Migration nào đọc cột cũ để ghi nghĩa của nó vào cột
   mới thì phải khoá bằng fixture v6, và fixture phải có **cả hai** loại hàng.
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

12. **Theme Glass không có bóng đổ, và đó là chủ ý.** Cả `cardLg` lẫn `cardSm` trong bản
    thiết kế đều là một đường viền trắng 1px nằm trong (`inset 0 0 0 1px
    rgba(255,255,255,.75)`). Nền gradient và mặt thẻ chênh nhau vài phần trăm độ sáng, nên
    thẻ vẽ bằng bóng đổ thì **biến mất**, còn thẻ tô trắng đặc thì đọc ra như tờ giấy dán
    lên chứ không phải một phần của nền. Mọi bề mặt đi qua `SubdockSurface`, đừng tự viết
    `BoxDecoration` với `SubdockColors.card` mà không có viền.

13. **`BackdropFilter` chỉ dùng ở tab bar và hai cái sheet: xin quyền thông báo, và
    bộ lọc Upcoming.** Mỗi cái ép một `saveLayer`, và danh sách Upcoming có thể giữ hơn
    chục thẻ một lúc. Làm mờ từng thẻ tốn khung hình thật trên Android mà không được gì,
    vì gradient nền không có chi tiết nào để làm mờ. Ranh giới nằm ở chỗ: một sheet phủ
    toàn màn là **một** `saveLayer` và bên dưới nó có danh sách đang trượt, tức là có thứ
    đáng làm mờ; còn một thẻ nằm yên trên nền gradient thì không. Xem `BlurLayer` trong
    `lib/ui/widgets/glass.dart`.

14. **Dùng thử là một cái cờ, không có ngày nào của riêng nó.** Ngày hết miễn phí và ngày
    bị trừ tiền lần đầu là một ngày, và đó chính là `expiresOn`, tức ô ngày bình thường
    của form. Thêm cột `trialEnd` là mở đường cho hai giá trị nói khác nhau, và mọi nhắc
    hạn trong app đều đã bắn trước `expiresOn`, đúng cái mà một nhắc hạn dùng thử hứa.
    Trước v7 có cột `trialStart`; nó bị bỏ vì ngày bắt đầu không hiện ở đâu ngoài chính
    cái ô đã nhập nó, và bắt người dùng nhập ngày mới bật được cờ là bắt họ trả lời một
    câu hỏi app không cần.

    Hệ quả: **cờ `inTrial` và câu hỏi "hôm nay còn dùng thử không" là hai thứ khác nhau.**
    Cờ không bao giờ tự tắt, vì nó ghi rằng những tháng trước lần trừ tiền đầu là miễn
    phí, mà điều đó thì đúng mãi mãi. Còn `isTrialOn(today)` tắt ngay khi qua `expiresOn`,
    vì tiền đã đi rồi dù người dùng có mở app nói lại hay không. Badge, dòng "Free now" và
    chip lọc `Free trials` đều hỏi `isTrialOn`; chỗ tính tiền hỏi `inTrial`. Hỏi nhầm
    chiều nào cũng sai: hỏi `isTrialOn` trong phép tính tiền thì sáng hôm sau các tháng
    miễn phí đầy tiền trở lại, còn hỏi `inTrial` ở badge thì một gói đã trừ tiền vẫn còn
    dán chữ FREE TRIAL.

    `ItemActions.advanced` xoá hẳn cờ khi người dùng ghi nhận đã trả. Bắt buộc phải xoá:
    lúc đó `expiresOn` vừa nhảy sang tháng sau, nên cờ còn bật là `isTrialOn` bật lại và
    badge quay về.

15. **`paused` không phải giá trị thứ tư của `ItemState`.** Tắt một dịch vụ nghĩa là "im
    đi", còn ba trạng thái kia nói chuyện gì đã xảy ra với chính gói thuê bao. Một gói đã
    huỷ mà còn hạn dùng vẫn tắt được. Gộp hai thứ lại thì không cách nào bật lại một mục
    đã archive.

16. **Cả danh sách lẫn bộ lập lịch nhắc hạn phải hỏi cùng một `isLive`.** Kiểm tra
    `state == ItemState.active` trơn là bỏ sót mục người dùng đã tắt, và lời hứa của cái
    công tắc đó là ngừng gửi nhắc hạn. Một hàm cho cả hai chỗ, để chúng không bao giờ nói
    khác nhau.

17. **Màn con giữ tab bar, form thì không.** `_push` trong `app.dart` bọc màn con
    trong cả một `AppShell`, `_pushForm` thì không. Hai hàm chứ không phải một, vì
    ảnh chụp trong handoff phân biệt rõ: Detail, All services, Reminders, History,
    Payment sources vẫn còn tab bar, còn Add và Edit thì không và có nút Cancel.
    `AppShell` cũng là chỗ vẽ gradient, nên màn nào không đi qua một trong hai hàm
    này sẽ rơi xuống nền xám phẳng `SubdockColors.canvas` và mất sạch lớp kính.
    Đó đúng là lỗi đã có trước đây.

18. **`Icon` của Material hiện ra ô vuông rỗng trong `flutter test`.** Font
    MaterialIcons không được nạp trong môi trường test, kể cả khi
    `uses-material-design: true`. Ảnh golden vì thế cho thấy tab bar toàn ô vuông
    trong khi trên máy thật icon vẽ đúng. Đừng đọc ô vuông trong golden là lỗi.

19. **`Category` là hàng trong bảng, không phải enum.** Người dùng thêm sửa xoá nhóm,
    nên **không chỗ nào trong code được biết mặt một nhóm cụ thể**. Mọi thứ phân loại
    năm giá trị cũ từng lái nay là cột của chính nhóm:

    | Cột | Lái cái gì |
    |---|---|
    | `wording` | chữ *Due* hay *Expires* trên dòng tóm tắt |
    | `nag` | nhắc lại mấy lần sau hạn; `isObligation` và `isTimeSensitive` đều đọc nó |
    | `leadDays` | thang nhắc mặc định của mục mới |
    | `verifyEveryDays` | có nhắc kiểm lại ngày không |
    | `countsTowardSpend` | có tính vào tổng chi tiêu không |

    Hệ quả: nhóm SIM **không còn được ưu tiên bằng code**. Nó là nhóm `PHONE` dựng sẵn,
    ship với `nag: daily` và `wording: expires`, và người dùng kéo nó xuống cuối hay tắt
    nhắc đều được. Đó là chủ ý: một nhóm app tự nâng lên là nhóm người dùng không hạ
    xuống được khi app đoán sai về họ.

    Mục mới phải dựng bằng `TrackedItem.on(category, ...)` chứ không phải constructor
    trơn, nếu không nó không lấy được mặc định của nhóm. Constructor trơn dành cho thứ
    đọc lên từ storage, backup hoặc `copyWith`, tức là những chỗ đã có sẵn giá trị.

    Presenter nào cần nhóm thì nhận `CategoryBook`, không tự đi lấy `defaultCategories`.

20. **Chip "Reminders off" của bộ lọc mở rộng tập nguồn, mọi chip khác thu hẹp nó.**
    Upcoming bỏ hẳn mục đã tắt nhắc, nên không một điều kiện lọc nào chạm tới chúng được.
    Vì vậy `UpcomingFilter` tách làm hai việc: `pool` chọn tập nguồn và chỉ đọc
    `mutedOnly`, `matches` là mọi điều kiện còn lại. Thêm một điều kiện mới thì nó thuộc
    về `matches`, trừ khi nó cũng cần với tới thứ màn hình đang giấu.

    Hệ quả thứ hai: danh sách chip dựng từ **mọi** mục chưa archive, kể cả mục đang tắt
    nhắc, chứ không phải từ tập nguồn hiện tại. Dựng theo tập nguồn thì lúc bấm "Reminders
    off" các hàng chip vẽ lại ngay dưới ngón tay, và chip người dùng vừa chọn biến mất
    khỏi sheet trong khi vẫn còn bật trong bộ lọc.

21. **Chỉ 25 trong 223 mục danh mục có `cancelUrl`.** Tab "Cancel a service" vì thế nói
    thẳng là app không biết trang huỷ, thay vì đưa một nút mở trang tìm kiếm. Nút trông
    như app biết đường mà thực ra không biết thì tệ hơn không có nút. Thứ tự tin cậy nằm ở
    `SavingsPresenter.cancelTarget`: nơi mua thắng trang của hãng, vì gói mua qua App
    Store không hiện trên trang của hãng.

22. **Chart trên màn Money suy ra từ chu kỳ, không đọc lịch sử đã trả.** Mỗi mục đi từ
    `anchorDate` theo `cycle`, kỳ nào rơi vào tháng nào thì cộng vào tháng đó, và không
    bao giờ tính ngược trước `anchorDate`. Trước đây chart đọc `HandledEvent`, nên máy
    vừa cài xong là chart biến mất hẳn dù danh sách đã đủ tiền, ngày và chu kỳ.
    Hệ quả phải nhớ: mục vừa nhập có `anchorDate` bằng đúng ngày đến hạn kế tiếp, tức là
    nằm ở tương lai, nên các tháng trước nó trống. Đó là đúng với những gì app biết, không
    phải lỗi. Chart đầy dần theo thời gian vì `anchorDate` không bao giờ bị sửa.
    Cột của tháng chưa tới vẽ nhạt hơn, vì đó là số tính trước chứ không phải việc đã xảy
    ra, **kể cả khi nó đang là cột được chọn**: chọn vào thì nó tô màu nhấn nhưng nhạt
    bớt, chứ không đặc như tháng đã qua. Trước đây chọn vào là tô đặc và việc nói ra giao
    cho một dòng chữ dưới con số, xem bẫy 24.
    Cùng một phép tính lo cả ba thứ trên card: cột chart, con số lớn, và danh sách By item.
    Thêm điều kiện lọc mới thì sửa ở `_chargesByMonth`, đừng sửa riêng chỗ nào.
    Một mục đang dùng thử bỏ hết các kỳ **trước** `expiresOn`, vì `expiresOn` là lần trừ
    tiền đầu tiên. Đó là điều kiện theo từng kỳ chứ không phải theo mục, nên nó nằm trong
    `countedOccurrences`, không nằm trong `countsTowardSpend`. Trước đây mục dùng thử bị
    loại hẳn khỏi mọi tổng, kể cả sau khi đã bị trừ tiền.

23. **Dấu `≈` trên màn Money chỉ có một nghĩa: đã đem một khoản ngoại tệ nhân với tỉ giá
    đóng gói sẵn.** Nó không nói về phép nhân theo chu kỳ, vì nhân một số tiền đồng với
    12 là số nguyên, không sai một đồng nào. `MixedTotal.converted` là chỗ trả lời câu
    hỏi đó, và cả con số lớn lẫn từng dòng trong Where it goes đều hỏi riêng, vì một card
    có thể có một nhóm toàn tiền đồng đứng cạnh một nhóm có tiền đô. Trước đây `≈` được
    ghép cứng vào con số lớn nên người dùng chỉ có mục tiền đồng vẫn thấy nó, tức là app
    tự nhận một sai số nó không hề mắc.
    Tỉ giá đi kèm ngay dòng quy đổi ra đô, để trong ngoặc, chứ không có dòng riêng dưới
    đáy card. Không kèm ngày nữa: `Fx.total` vứt bỏ tỉ giá cũ quá `Fx.maxDisplayAgeDays`
    thay vì quy đổi bằng nó, nên tỉ giá nào lên được tới màn hình cũng là tỉ giá app dám
    đứng sau. Dòng dưới đáy card giờ chỉ còn lại khi có tiền rơi ra ngoài tổng, và đó là
    một lời cảnh báo chứ không phải chú thích.

24. **Card trên màn Money phải có đúng số dòng như nhau ở mọi tháng.** Người dùng đọc
    card này bằng cách bấm qua lại giữa các cột chart, nên một dòng chữ lúc có lúc không
    sẽ đẩy chart chạy lên chạy xuống ngay dưới ngón tay họ. Vì vậy giữa con số lớn và
    chart **không còn dòng chữ nào**. Hai dòng từng nằm đó đều đã bỏ: số mục đếm được thì
    danh sách By item ngay bên dưới đã nói, còn "tháng này chưa tới" thì cột chart tự nói
    bằng màu.
    Dòng quy đổi ra đô cũng theo luật này: nó hiện ở **mọi** tháng một khi người dùng có
    bất kỳ mục nào tính bằng ngoại tệ, kể cả tháng mà các khoản trong đó toàn tiền đồng.
    Người dùng giữ những loại tiền nào là chuyện của họ, không phải chuyện của tháng Ba.
    Đó là tham số `restate` của `MoneyPresenter.alternateTotal`.
    Dấu `≈` trên con số lớn thì vẫn theo bẫy 23, tức là chỉ có khi tháng đó thật sự có
    quy đổi. Nó là một ký tự nằm cùng dòng, không thêm bớt dòng nào.

25. **Giờ trong ngày là đầu vào của `NotificationPlanner.plan`, không phải trang trí.**
    Nó nhận `LocalDateTime now` chứ không nhận `LocalDate today`. Trước đây lọc bằng
    `isBetween(today, horizon)`, mà cả ngày hôm nay đều lọt qua, nên một mục gửi lúc
    08:30 vẫn giữ nguyên cái nhắc đó tới tận đêm: màn Detail viết "Next reminder 25/08 at
    08:30" vào lúc 18:40, và bộ lập lịch nhận một mốc thời gian đã qua. iOS không bao giờ
    bắn một trigger nằm ở quá khứ, Android thì bắn ngay lập tức, và cả hai đều tiêu mất
    một suất trong ngân sách 50.

    Mốc chặn là `earliest`, tính **theo từng mục** vì giờ gửi là của từng mục: lúc 18:40
    một mục hẹn 08:30 đã hết chuyện để nói trong ngày, còn mục hẹn 21:00 thì chưa. So
    sánh phải là **nhỏ hơn hẳn** (`now.time < item.remindAt`): `LocalTime` không có
    giây, nên một nhắc hạn trùng đúng phút hiện tại có thể đã bắn bốn mươi giây trước, và
    đặt lại nó là bắn thêm một bản thứ hai.

    Hai nhóm alert cư xử khác nhau ở đây, đừng gộp:

    | Loại | Cách dùng `earliest` | Vì sao |
    |---|---|---|
    | `lead`, `snoozed` | `isBetween(earliest, horizon)`, qua rồi thì **mất** | Một nấc lead gọi tên một ngày cụ thể so với hạn. Đẩy sang mai là nói "3 ngày trước" vào ngày còn hai ngày |
    | `nag`, `verify` | `LocalDate.max(x, earliest)`, qua rồi thì **trượt sang mai** | "Vẫn chưa xong" thì mai vẫn đúng. Bỏ nó đi là mục quá hạn im tiếng nốt cái ngày nó quá hạn |

    Hệ quả thứ hai: **đồng hồ chạy mà không có dòng nào trong cơ sở dữ liệu đổi.** Plan
    trước đây chỉ được tính lại trong listener của các stream, nên nó cũ dần suốt phiên
    làm việc. Giờ có `_replan()` trong `app.dart`, chạy cả ở stream lẫn lúc app resume,
    và lúc resume cũng gọi luôn `_refreshPermission()` vì hai quyền của Android được cấp
    ở màn hình cài đặt hệ thống mà app không quan sát được.
    Chưa có hẹn giờ qua nửa đêm: mở app để im từ hôm trước sang hôm sau thì plan vẫn cũ
    cho tới lần resume kế tiếp.

    Nút **Send a test reminder** ở màn Reminders đi qua `zonedSchedule` với độ trễ 10
    giây chứ không gọi `show` của plugin, và đó là chủ ý. `show` chỉ chứng minh là đã có
    quyền; mọi kiểu hỏng thật của app đều nằm trên đường lập lịch, gồm timezone database
    chưa nạp, exact alarm bị từ chối, và trình tiết kiệm pin của hãng nuốt mất alarm. Nó
    báo lại giờ **kèm tên múi giờ**, vì múi giờ sai là lỗi repo này đã dính: không nạp
    timezone database thì nhắc 08:30 tới lúc 15:30. Nó cũng gửi trên kênh Deadlines ồn
    chứ không phải kênh im, vì thứ đáng kiểm tra là đường ồn.

26. **Thêm một cột vào `itemRow` giờ phải sửa ba chỗ, không phải hai.** Ngoài hai
    chỗ ở bẫy 1, còn `lib/domain/backup.dart`. Bỏ sót chỗ thứ ba thì không có gì đỏ
    trên đường thường: app chạy đúng, test lược đồ xanh, và cái cột đó **lặng lẽ không
    nằm trong file sao lưu**. Người dùng chỉ phát hiện ra vào hôm họ khôi phục.

    Chốt chặn duy nhất là test `an item keeps every field it went in with` trong
    `test/unit/domain/backup_test.dart`. Nó dựng một `TrackedItem` **điền hết mọi
    trường nullable và đẩy mọi enum ra khỏi giá trị mặc định**, rồi so từng trường sau
    một vòng mã hoá giải mã. Trường mới quên trong codec sẽ quay về mặc định và phép so
    đó gãy. Vì vậy thêm trường vào `TrackedItem` thì **phải thêm luôn vào cái mẫu trong
    test đó**, không thì chốt chặn vô nghĩa.

    File sao lưu là bản chép của **model**, không phải bản dump SQLite. Đó là chủ ý:
    một bản dump thì chính xác nhưng bản app nào có lược đồ đã đi tiếp cũng không đọc
    nổi, mà đó là mọi bản trong tương lai. Đọc thiếu một trường thì rơi về đúng cái mặc
    định một mục mới nhận được, nên file viết từ nhiều tháng trước vẫn khôi phục vào bản
    app mới. Cùng luật giải mã dễ dãi mà `mappers.dart` đang theo.

    Vài quyết định đi kèm, đừng đảo lại mà không đọc:

    - **Chỉ từ chối file có `version` mới hơn.** File cũ hơn là trường hợp bình thường
      của một bản sao lưu. File mới hơn chứa trường bản này không biểu diễn được, khôi
      phục vào là mất im lặng.
    - **`anchorDate` thiếu thì rơi về `expiresOn`, không rơi về hôm nay.** Mọi phép tính
      chu kỳ đếm từ nó, nên hôm nay sẽ dời lại cả chuỗi sang ngày khôi phục.
    - **Khôi phục là thay, không phải trộn.** Người mất điện thoại phải nhận đúng danh
      sách họ từng có. Trộn theo id để lại mọi mục thêm sau bản sao lưu nằm trong một
      danh sách chúng chưa từng thuộc về, mà không cách nào biết cái nào là cái nào.
    - **Một mục trỏ vào nhóm mà file không mang theo vẫn được đặt xuống**, vào nhóm đầu
      tiên trong file, thay vì để khoá ngoại giết cả lần khôi phục. Lúc đó dữ liệu cũ
      của người dùng đã bị xoá rồi, không có gì để lùi về.
    - **`BackupFiles.pick` đọc qua `readAsBytes`, không đọc theo đường dẫn.** File chọn
      từ iCloud Drive hay Google Drive về dưới dạng content URI không có đường dẫn cục
      bộ, tức là đọc theo đường dẫn sẽ hỏng đúng với người đã cất bản sao lưu ở chỗ an
      toàn.
    - **Trên sheet xác nhận, nút tô đầy là nút *không* làm gì.** Nút phá huỷ là chữ đỏ
      nhạt, cùng hình dạng mà màn Detail dùng cho "Mark as paid" so với "Delete this
      item". Nút đẹp nhất màn hình là nút được bấm bởi người không đọc.

    Và **`flutter install` gỡ app trước khi cài** khi chữ ký hoặc bundle khác bản đang
    có, tức là xoá sạch dữ liệu trên máy. Xem cảnh báo trong `docs/running.md` mục 3.3.

27. **Bảy mục SIM của bảy nhà mạng đã gộp thành một mục `goi-cuoc-dien-thoai`, tên hiển
    thị `Mobile plan`, và nó cố ý không mang giá nào.** `sim-viettel`, `sim-vinaphone`,
    `sim-mobifone`, `sim-vietnamobile`, `sim-itel`, `sim-wintel`, `vnsky` và mục chung
    `goi-cuoc-data` đều không còn. Lý do là app đi đường quốc tế: một mục cho mỗi nhà
    cung cấp trong nước là sai mức, mục chung mới đúng.

    `plans` để rỗng cũng là chủ ý, không phải chưa tra được. Mỗi nhà mạng một bảng giá và
    mỗi người một gói, nên bất kỳ con số nào đặt sẵn ở đây cũng là app đoán hộ, mà đây
    đúng là nhóm mà đoán sai thì mất số điện thoại chứ không phải mất một tháng xem phim.
    Người dùng tự gõ số họ thật sự trả.

    **Alias là thứ duy nhất còn giữ bảy cái tên đó.** Gõ `sim`, `mobifone`, `viettel`,
    `vnsky`, `mobi`, `nha mang` hay `dien thoai` đều phải ra `Mobile plan`. Bỏ bớt một
    alias là một người gõ đúng tên trên vỏ SIM cầm trong tay mà nhận về danh sách rỗng.
    Chốt chặn là bài `typing SIM still finds it, under its English name` trong
    `test/unit/catalog/service_catalog_test.dart`.

    Luật icon phải là `mobile`, **không được là `phone`**: "iPhone 15 trả góp" là thứ
    người ta gõ, và nó không phải cái SIM. Luật `mobile` cũng phải nằm dưới
    `vietnamobile`, theo đúng bẫy 3.

    Hai thứ đi kèm. Một: `PlanOption` giờ mang cả `tier` (slug, dùng để so và nhớ lựa
    chọn) lẫn `label` (chữ trên tile, lấy từ `CatalogPlan.name`). Trước đây tile in thẳng
    slug nên nó viết `standard`, `50gb`; giờ mới đúng là `Standard`, `50GB`. Hai:
    `data/manage-urls.json` còn bảy id nhà mạng nay không mục nào nhận, vì một mục chỉ có
    một `manageUrl`. Muốn nối lại thì phải cho `manageUrl` xuống mức tier.

28. **Xoá một mục đi qua `DeleteAsk`, và cái footnote cũ dưới nút thì nói dối.** Trước
    đây nút `Delete this item` gọi thẳng `repository.delete`, không hỏi gì. Mất mát ở đây
    là toàn phần: `handledEventRow` mang `ON DELETE CASCADE`, nên mọi lần trả tiền người
    dùng tự tay ghi lại đi theo cái mục đó, mà app thì không có tài khoản, không có máy
    chủ, không có gì để lùi về. Nút lại nằm cùng một màn hình đang trượt với
    `Mark as paid`.

    Tệ hơn cả việc không hỏi: dòng `ItemPresenter.deleteConsequence` ngay dưới nút kết
    thúc bằng *"What you have already paid stays under Spending"*, và câu đó sai hai lần.
    Một, lịch sử trả tiền bị cascade xoá cùng. Hai, màn Money đã không đọc bảng đó từ lúc
    nó chuyển sang suy ra theo chu kỳ, xem bẫy 22. Một dòng hứa hẹn tấm lưới an toàn
    không tồn tại thì tệ hơn là không có dòng nào, vì nó được đọc ngay trước cú bấm.
    Chốt chặn là bài `the delete warning does not promise the payments survive` trong
    `test/unit/ui/item_presenter_test.dart`.

    `DeleteAsk` cùng hình dạng với `RestoreAsk`, cùng lý do ở bẫy 26: nút tô đầy là nút
    **không** xoá. Nó đếm hai thứ, và cả hai đều cần thiết. Số lần trả tiền là thứ người
    dùng nhìn thấy được ở màn Detail; số nhắc hạn đang chờ thì **không hiện ở đâu khác
    trong app**, nên nếu sheet không nói thì không ai nói.

    Cả hai đường xoá đều đi qua nó: nút ở màn Detail, và nút `Cancelled` ở tab Cancel
    của màn Savings. Đường thứ hai truyền `pop: false` vì nó xoá từ một danh sách chứ
    không phải từ màn của chính mục đó.

    Sheet nằm trong `app.dart`, tức là **không một widget test nào thấy được nó**: màn
    Detail nhận `onDelete` như một callback do test tự cấp, nên nó bắn trong mọi trường
    hợp. Chốt chặn thật là `integration_test/delete_test.dart`, phải chạy trên máy ảo
    (`flutter test integration_test/delete_test.dart -d <simulator-id>`).

29. **Snooze cộng thêm một nhắc hạn, nó không dời cái ladder.** `ItemActions.snoozed`
    chỉ ghi một trường `snoozedUntil`; `expiresOn`, `anchorDate` và `cycle` không hề bị
    đụng tới, và trong `NotificationPlanner._alertsFor` cái ngày đó sinh ra **một alert
    nằm cạnh** các alert lead chứ không thay thế chúng. Bấm "Remind me again in 3 days"
    vào ngày 26 khi hạn là 28 thì nhắc ngày 27 vẫn bắn như thường.

    Chỗ này từng nói dối, và cái nói dối là giao diện chứ không phải logic. Màn Detail có
    đúng một dòng `Next reminder 29/08 at 08:30`, mà một dòng thì chỉ gọi tên được alert
    sớm nhất. Người dùng vừa bấm xong đọc dòng đó ra thành "app đã dời sang ngày 29", và
    không có chỗ nào khác trên màn hình nói ngược lại. Màn Reminders con cũng không cứu
    được: `RemindersPresenter.ladder` dựng lại thang **từ `item.leadDays`**, nên nó không
    nhìn thấy snooze, không thấy nag, không thấy verify, và không biết nấc 08:30 hôm nay
    đã bắn rồi.

    Nay khối `What happens next` trên màn Detail vẽ nguyên cái plan thành một cột theo
    ngày, và nó **đọc từ `NotificationPlan`**, không dựng lại từ `leadDays`. Đó là điều
    kiện bắt buộc: plan là thứ thật sự đang chờ trên máy, mọi thứ suy lại đều là một câu
    chuyện thứ hai có thể khác câu chuyện thứ nhất.

    Ba quyết định trong `lib/ui/reminder_timeline.dart`, đừng đảo lại mà không đọc:

    - **Mốc hạn nằm trong cùng cột với các nhắc hạn, không nằm ở dòng tiêu đề phía trên.**
      Đó là toàn bộ lý do khối này tồn tại: hạn còn hai ngày mà bấm "remind me in 3 days"
      thì nhắc rơi vào **sau** ngày tiền bị trừ, và chỉ khi hai thứ xếp chung một cột theo
      thứ tự thời gian thì người dùng mới thấy. Alert trùng ngày với mốc hạn thì xếp
      **trên** mốc, vì nhắc 08:30 đúng là tới trước khi hết ngày.
    - **Nag gộp thành một dòng.** Nag hằng ngày liệt kê một alert mỗi ngày tới hết chân
      trời 60 ngày, vẽ thật là năm mươi dòng giống hệt nhau đè chết ba dòng đáng đọc.
      Nhịp lặp đọc từ khoảng cách giữa hai alert đầu tiên chứ không đọc từ `NagPolicy`, để
      dòng chữ không bao giờ khai một nhịp mà plan không giữ.
    - **Nag bị ngân sách cắt thì không đếm vào footnote.** Một mục quá hạn có nag hằng
      ngày tự nó đã tràn ngân sách 50, nên footnote "10 further reminders did not fit"
      hiện ngay dưới dòng hứa nhắc mỗi ngày. Cả hai đều đúng, vì planner chạy lại khi các
      mốc gần trôi qua và nhặt nag về. Còn lead, snooze hay verify bị cắt thì đếm: mỗi cái
      gọi tên đúng một ngày và không có lần thứ hai để gửi.
    - **Mốc hạn mang theo số tiền, và dòng nhắc hạn tự xưng là nhắc hạn.** Cả cột trước
      đây chỉ có ngày với một câu chữ, nên muốn biết dòng nào là thông báo app gửi và
      dòng nào là ngày tiền đi thì phải nhìn cái vòng tròn 4px. Nay dòng nhắc ghi
      `Reminder at 08:30`, mốc hạn ghi số tiền. Chữ `charged` chỉ được viết cho nhóm có
      `wording` là *Due*, tức là nhóm mà có người tự trừ tiền trong ngày đó. Nhóm hết hạn
      như SIM trả trước hay giấy phép thì con số đứng một mình, vì đó là giá gia hạn chứ
      không ai trừ. Ngày đã qua thì bỏ hẳn động từ, vì app không biết khoản đó có đi hay
      không, chỉ biết ngày đã qua.
    - **Dùng thử là một dòng của cột này, không còn là card riêng nằm trên.** Card cũ nói
      ba thứ mà cột đã nói rồi: ngày trừ tiền, số tiền, và nhắc hạn sắp tới. Nói lại bằng
      một giọng thứ hai là mở đường cho hai giọng lệch nhau, trong khi giọng của cột đọc
      thẳng từ plan. Thứ duy nhất chuyển sang là phần mà một cột toàn ngày tương lai không
      tự nói được: hôm nay còn miễn phí, và còn mấy ngày. Dòng đó mang ngày hôm nay vì
      bản thân kỳ dùng thử không có ngày riêng, xem bẫy 14, và nó không bao giờ được đánh
      dấu `next` vì nó không phải thứ app sắp gửi. Ngày hết dùng thử đổi chữ thành
      `First payment`. `isTrialOn` là `today < expiresOn` nên dòng này biến mất ngay sáng
      ngày bị trừ tiền, tức là không bao giờ có chữ "Free for 0 more days".

    Mốc hạn ở lại trên cột **kể cả khi không còn nhắc hạn nào**, và lý do im lặng thì nói
    ra ở footnote (`ReminderTimeline.silence`). Ba lý do khác nhau và người dùng chỉ sửa
    được hai: mục đang tắt nhắc, mục đã đóng, và thang đã chạy hết. Bỏ luôn cả khối trong
    trường hợp đó là vứt đi cái dòng duy nhất còn đáng đọc.

30. **Nút Save của form chốt lại sau cú bấm đầu, và nó bắt buộc phải chốt.** `_saveDraft`
    trong `app.dart` ghi xuống SQLite **trước** khi pop cái route, nên suốt thời gian ghi
    đó form vẫn nằm trên màn hình với nút Save vẫn bật. Bấm lần thứ hai trong khoảng đó
    thì `_saveDraft` chạy song song lần nữa, `id` lấy từ `microsecondsSinceEpoch` nên hai
    lần ra hai id khác nhau: hai mục giống hệt nhau trong danh sách.

    Mất mát thật không nằm ở cái mục thừa, nó nằm ở chỗ khác. Lần lưu thứ nhất mở sheet
    xin quyền thông báo, còn lần thứ hai gọi `maybePop()`, mà `maybePop` lấy route trên
    cùng nên nó **pop chính cái sheet đó**. Sheet đóng trả về `null`, và `null` được đọc
    là "để sau", nên `_declinedAtSave` bị đặt luôn. Kết quả: người dùng chưa từng thấy câu
    hỏi nào, mà app thì im tiếp cho tới lần lưu thứ tư. Với một app mà toàn bộ công việc
    là gửi nhắc hạn thì đó là hỏng hẳn, không phải phiền nhẹ.

    Cái chốt là `_saved` trong `add_item_screen.dart`, và nó **không bao giờ mở lại**: mọi
    đường ra khỏi form đều pop hoặc thay nó, không có đường nào quay lại. Bấm lúc chưa có
    ngày thì không tiêu mất cú bấm, vì lúc đó nút đang tắt. `_saveEdit` dùng chung nút này
    và cần chốt hơn nữa: nó pop hai route rồi mở lại màn Detail, chạy hai lần là bốn route
    rơi khỏi stack.

    Chốt chặn là bài `a second tap on Save does not save a second item` trong
    `test/widget/detail_screens_test.dart`. Hệ quả cho test: một form chỉ lưu được một
    lần, nên bài nào cần hai lần lưu phải dựng hai form, và **form thứ hai phải có `key`**
    vì `pumpWidget` đặt một widget cùng kiểu vào đúng chỗ cũ sẽ giữ nguyên `State`, tức là
    giữ nguyên cái chốt đã tiêu.

31. **Màn Upcoming có hai cách vẽ cùng một danh sách, và lịch không được nói khác danh
    sách.** Tray `List / Calendar` ở hàng điều khiển dưới tiêu đề chỉ đổi cách xếp, không
    đổi tập mục: `CalendarPresenter` gọi đúng `filter.pool` rồi `filter.matches` mà
    `UpcomingPresenter` gọi. Bốn quyết định đi kèm, đừng đảo lại mà không đọc:

    - **Lịch chấm theo `actBy`, không chấm theo `expiresOn`.** Danh sách chia nhóm theo
      `actBy`, nên chấm theo ngày hết hạn là để một mục nằm ở hai ngày khác nhau tuỳ
      người dùng đang xem cách vẽ nào. Cùng lý do với bẫy 16.
    - **Lịch suy ra các kỳ từ chu kỳ, đi tới từ `anchorDate` và không bao giờ lùi trước
      nó**, đúng như chart màn Money ở bẫy 22. Chỉ chấm `item.actBy` thì tháng sau trống
      trơn dù người dùng có Netflix hàng tháng, tức là một cái lịch vô dụng. Hệ quả giống
      bẫy 22: mục vừa nhập có quá khứ trống, đó là đúng chứ không phải thiếu.
    - **Ngày đã qua không tự động tô đỏ.** Chỉ tô đỏ khi ngày đó đúng bằng `item.actBy`
      hiện tại, tức là đúng cái mà danh sách gọi là Overdue. Một gói hàng tháng có
      `anchorDate` từ năm ngoái sinh ra hàng chục kỳ trong quá khứ mà người dùng đã trả
      đúng hạn; tô đỏ chúng là app vu cho họ nợ mười hai tháng.
    - **Ô lịch cao cố định dù có dấu hay không.** Lưới co theo số dấu thì đổi tháng là
      cái card dưới nó nhảy lên nhảy xuống ngay dưới ngón tay, cùng luật với bẫy 24. Một
      ô chứa quá hai dấu thì vẽ một dấu kèm `+n`, chứ không vẽ hai rồi im: hai dấu và im
      lặng là app báo thiếu trên đúng cái màn hình có việc là nói ra cái gì sắp tới.

    Ngày mở sẵn là ngày gần nhất từ hôm nay trở đi có việc, và là hôm nay khi hôm nay có
    việc. Mở lịch ra thấy `Nothing on this day` trong khi lưới đầy dấu là trả lời một câu
    không ai hỏi, vì hôm nay vẫn được vẽ là hôm nay dù có được chọn hay không. Đổi tháng
    thì `_calendarDay` trong `app.dart` phải xoá về null, không thì danh sách dưới lưới
    báo cáo về một ngày không có trong lưới.

    **Nhóm `Free trial · not charged yet` riêng trên Upcoming đã bỏ.** Một kỳ dùng thử
    hết sau hai ngày và một kỳ hết sau hai tháng từng nằm chung một khối trên đầu màn,
    đẩy mục đến hạn ngày mai xuống dưới, tức là mất đúng cái thứ tự duy nhất mà màn này
    xếp theo. Badge `FREE TRIAL` trên dòng đã nói đủ, và chip `Free trial n` ở hàng điều
    khiển là chỗ gom chúng lại khi người dùng thật sự muốn thế. Chip bật đúng điều kiện
    `trialOnly` mà sheet lọc đang có, không phải một trạng thái thứ hai. Nó đếm trên tập
    nguồn chứ không đếm trên danh sách đang hiện, để con số không nhảy khi chính nó bị
    bấm.

32. **Lưới Plan bày mọi chu kỳ cùng lúc, và một ô nhớ bằng cả tier lẫn chu kỳ.** Trước
    đây lưới lọc theo `_cycle` đang chọn, nên bảng giá năm của hãng nằm sau một cái
    nút người dùng chưa hề chạm vào, mà con số năm mới là con số đáng xem trước khi
    quyết. Nay `PlanGrid.optionsFor` trả về mọi kỳ hạn của một vùng, mỗi ô ghi thêm
    `/m` hay `/y` cạnh giá, và bấm một ô là **đặt luôn chu kỳ** chứ không chỉ đặt
    giá. Bỏ phần đặt chu kỳ đi là một giá năm được lưu thành khoản trừ hàng tháng, gấp
    mười hai lần số tiền, mà trên màn hình không có gì nói ngược lại.

    Hệ quả bắt buộc: `selected` của lưới so bằng `PlanOption.id`, tức là tier cộng chu
    kỳ, **không so bằng tier trơn**. Disney+ bán đúng một gói `premium` theo hai kiểu,
    nên so bằng tier là hai ô cùng sáng, đọc ra thành người dùng đã chọn hai giá một
    lúc. Ô `Other amount` nằm cuối lưới thay cho dòng chữ `Paying a different amount?
    Enter it` cũ: câu trả lời "không cái nào" phải cùng một cử chỉ với "cái này".

33. **Hàng chip kỳ hạn của segment thứ ba mở tại chỗ và ở nguyên đó.** Nó thay cái
    sheet cũ, và nó **không đóng lại** sau khi người dùng chọn: lúc đó segment thứ ba
    đang hiện tên kỳ hạn vừa chọn, nên ai muốn đổi sang cái khác sẽ phải tự đoán rằng
    đường đổi câu trả lời là bấm vào chính câu trả lời. Dòng `Currently quarterly` dưới
    hàng chip nói ra điều đó. Mở sẵn cả khi vào màn Edit của một mục không phải hàng
    tháng hay hàng năm, cùng một lý do.

34. **Token màu là một biến toàn cục, và mỗi màn phải tự đăng ký để được vẽ lại.**
    `SubdockColors.ink` không còn là hằng số. Nó là getter đọc từ `_active`, một
    biến trong `theme.dart` mà `SubdockTheme` đặt lại mỗi lần bản màu đổi. Chọn cách
    này vì gần năm trăm chỗ gọi token, và khoảng một phần ba nằm trong hàm tĩnh
    (`SubdockSurface.card`, `TabMark.tint`, các presenter) không có `BuildContext`
    nào để truyền vào.

    Cái giá phải trả nằm ở chỗ **đặt lại biến đó không tự vẽ lại thứ gì.** Flutter
    dựng trang của một route đúng một lần rồi giữ luôn cái widget đó
    (`_ModalScopeState._page`), nên một màn người dùng đã mở sẽ nhận lại đúng widget
    cũ và bị bỏ qua hoàn toàn khi widget cha dựng lại. Đường duy nhất chui được vào
    trong một route đã dựng là phụ thuộc kiểu InheritedWidget, và nó chỉ tới những
    widget đã thật sự đăng ký.

    Vì vậy có đúng một luật: **màn hình, sheet hay dialog nào là gốc của một route
    thì gọi `SubdockTheme.watch(context)` ngay dòng đầu của `build`.** Quên dòng đó
    thì màn hình giữ nguyên bản màu cũ cho tới khi có thứ khác tình cờ dựng lại nó,
    mà lúc hệ thống tự chuyển sang tối thì kết quả là nửa màn sáng nửa màn tối.
    `AppShell` và `GlassBackground` cũng phải tự gọi, vì `_push` nhét chúng vào
    trang đã dựng của route cùng với màn hình chứ không phải bọc từ ngoài.

    Chốt chặn là bài `a screen pushed before the change follows it too` trong
    `test/widget/theme_test.dart`.

    Hai điều đi kèm:

    - **`SubdockTheme` phải nằm trên `MaterialApp`**, vì Navigator nằm trong
      `MaterialApp` và một InheritedWidget chỉ với tới được thứ nằm dưới nó.
    - **Token giờ không phải hằng số, nên widget nào đọc token thì không `const`
      được.** Đó là tính chất tốt chứ không phải phiền: trình biên dịch chỉ ra từng
      chỗ một, và một widget `const` đọc token sẽ giữ màu nướng sẵn lúc biên dịch
      dù cây có dựng lại.

    Giá trị màu nằm ở `lib/ui/theme/palette.dart`, hai bản `light` và `dark`. Thêm
    một màu là thêm một trường ở đó, **điền cả hai bản**, rồi thêm một getter trong
    `SubdockColors`. Bản tối không phải bản sáng đảo ngược, hai luật của nó ngược hẳn
    với phép đảo:

    - **Độ nổi vẽ bằng viền, không bằng bóng đổ.** Bóng đổ trên nền tối không có gì
      để làm sẫm đi, nên `SubdockShadow.sheet`, `toast` và `knob` đều rỗng ở bản tối
      và `sheetEdge` thay chỗ.
    - **Chữ nằm trên nền accent tô đầy thì đậm màu, không phải trắng.** Accent bản
      tối là `oklch(.74 .11 262)`, tức một màu xanh sáng, và chữ trắng trên nó không
      đọc được. Đó là lý do `onAccent` là một token chứ không phải cái
      `Color(0xFFFFFFFF)` từng viết rải rác ở từng chỗ gọi, và `onDanger` với
      `onSavings` cũng vậy. Chữ trong ô icon dịch vụ thì vẫn trắng ở cả hai bản, vì
      nó nằm trên màu thương hiệu chứ không nằm trên nền của app.

    Lựa chọn bản màu lưu trong `ThemeStore`, một store riêng đọc chung bảng
    `settingRow`, đúng kiểu `FilterStore`. Riêng chứ không phải một trường của
    `AppSettings`, vì hai lý do: nó không phải quyết định về *cách app hoạt động*,
    và nó **không được đi theo file sao lưu**. Một danh sách khôi phục sang máy thứ
    hai phải trông giống cái máy đó, không phải giống cái máy nó đi ra.

35. **Danh sách trên màn Upcoming là dòng có kẻ, không phải thẻ.** Cả ba danh sách
    (Overdue, các nhóm theo ngày, và danh sách dưới lưới lịch) đều vẽ mỗi mục là một
    dòng trong suốt với một đường kẻ 1px bên dưới, không nền, không bo góc, không
    khoảng cách giữa hai dòng. Trước đây mỗi dòng là một thẻ kính riêng, tức là bốn
    cạnh viền cộng một rãnh 10px quanh mỗi dòng, nên một màn tám mục đọc ra thành
    tám vật thể rời nhau xếp chồng lên chứ không phải một danh sách. Rãnh và viền
    cộng lại tiêu khoảng một phần năm chiều cao màn hình để nói một điều mà một
    pixel kẻ ngang nói đủ.

    Mất mát phải nói ra: **dòng quá hạn không còn nền đỏ nhạt và viền đỏ nữa**, vì
    không còn thẻ nào để tô. Nó báo bằng viên thuốc đếm ngược màu danger, mà viên đó
    dù sao cũng là thứ to tiếng nhất trên dòng. Tên và số tiền vẫn màu mực bình
    thường, đúng như trước.

    `ItemRowStyle.cards` bật lại kiểu thẻ cũ, truyền qua `UpcomingScreen.rowStyle`.
    Mặc định là `dividers`.

    Đệm dòng là `15px` trên dưới và `2px` hai bên, không phải `13/14`: không có thẻ
    thì dòng không có gì để thụt vào, và tên mục phải bắt đầu đúng lề trái với tiêu
    đề nhóm ngay trên nó.

    Ô icon đi kèm luật này: `ServiceTile.listSize` 46, `listRadius` 11,
    `listFontSize` 19. Bo 11 chứ không phải 9 vì bo 9 trên một ô 46pt đọc ra thành
    hình chữ nhật bo tròn chứ không phải hình vuông mềm như mọi icon app nằm cạnh
    nó trên màn hình chính.

36. **Dòng phụ của một mục đang dùng thử chỉ nói số tiền, trạng thái để cho badge
    nói.** Trước đây nó viết `Free now · then 260,000 đ`, tức là tiêu cả chiều rộng
    dòng để nhắc lại đúng cái badge `FREE TRIAL` nằm cách đó hai milimet, và đẩy con
    số người dùng cần đọc ra sau bốn chữ.

    Một trường hợp dòng này vẫn phải tự trả lời: mục dùng thử **không có giá** thì
    viết `Free now`. Không có số để nói thì chỉ còn trạng thái, và một dòng trống
    hẳn ở đó đọc ra thành một mục app không biết gì về nó.

    Chốt chặn là hai bài `a trial shows the amount, and leaves the state to the
    badge` và `a trial with no amount says it is free rather than nothing` trong
    `test/unit/ui/upcoming_presenter_test.dart`.

37. **Chữ trên giao diện không còn viết thẳng trong widget nữa.** Mọi câu người dùng
    đọc nằm trong `lib/i18n/`, gọi ra bằng `S.t.tênChuỗi`, và có đúng hai bản:
    `strings_en.dart` và `strings_vi.dart`. Giao diện `Strings` chia thành nhiều lớp
    con theo vùng màn hình, mỗi lớp một file trong `lib/i18n/parts/`, để file phải mở
    ra khi sửa chữ màn Money là file nói về màn Money.

    Là phương thức chứ không phải bảng `Map<String, String>`: gõ sai một khoá trong
    bảng là một ô trống lúc chạy, gõ sai ở đây là không biên dịch được. Và **bất cứ
    chuỗi nào có số hoặc tên chèn vào phải là một phương thức**, để bản dịch cầm cả
    câu. Tiếng Việt không đặt số nhiều ở chỗ tiếng Anh đặt, nên một bản dịch nhận về
    `'$n days'` đã lắp sẵn thì không sửa được nữa.

    Hệ quả cho `const`: **widget nào đọc `S.t` thì không `const` được**, đúng như
    widget đọc token màu ở bẫy 34, và vì đúng cái lý do đó. Trình biên dịch chỉ ra
    từng chỗ một.

38. **Ngôn ngữ và loại tiền đi chung một scope với bảng màu, và luật `watch` ở bẫy 34
    lo cả ba.** `SubdockTheme` giờ mang `palette`, `locale` và `currency`; nó đặt cả
    ba biến toàn cục rồi phát chúng qua **một** `InheritedWidget`. Chọn một scope chứ
    không phải ba, vì cả ba có cùng một vấn đề vẽ lại và cùng một cách sửa, còn ba
    inherited widget là ba dòng mỗi màn phải nhớ. Màn nào đã theo luật màu thì theo
    luôn hai cái kia, và màn nào quên thì hỏng cả ba cùng lúc, dễ thấy hơn nhiều so
    với một màn đổi màu mà không đổi chữ.

    Chốt chặn là bài `a screen pushed before the change follows it too` trong
    `test/widget/locale_test.dart`, đối xứng với bài cùng tên bên `theme_test.dart`.

39. **Tên nhóm dựng sẵn dịch lúc đọc, không dịch lúc seed.** `categoryRow` được đổ đầy
    trong một bước migration, tức là rất lâu trước khi onboarding kịp hỏi người dùng
    đọc bằng thứ tiếng nào. Vì vậy nhãn nằm trong cơ sở dữ liệu luôn là nhãn tiếng
    Anh, và `Category.displayLabel` mới là thứ màn hình đọc.

    Luật gói gọn trong một phép so: **một nhóm dựng sẵn còn mang đúng cái nhãn nó được
    seed thì đi theo ngôn ngữ; đổi khác đi một chữ là nhãn của người dùng, giữ nguyên
    ở cả hai thứ tiếng.** Nhóm do người dùng tự tạo không bao giờ được dịch.

    Đừng gọi `category.label` để hiển thị. Nó là giá trị lưu xuống, và là thứ phép so
    ở trên đối chiếu; `displayLabel` mới là thứ đọc lên. Chốt chặn nằm ở nhóm
    `a shipped shelf name` trong `test/widget/locale_test.dart`.

40. **Câu tiếng Việt dài hơn câu tiếng Anh, và có hai hàng trên màn hình không còn chỗ
    thừa.** Hàng điều khiển của Upcoming (tray `List / Calendar`, chip dùng thử, nút
    lọc) và tray hai đoạn trên màn Savings đều vỡ khi bản dịch dài thêm vài ký tự.
    Vì vậy `SHOTS_VI=1` là một phần của việc sửa chữ, không phải việc dọn dẹp sau đó:
    chạy nó và nhìn ảnh trước khi tin rằng một chuỗi mới vừa vào là xong.

    Hai chỗ đã phải rút ngắn bản tiếng Việt cho vừa, và cả hai ghi lý do ngay tại chỗ:
    chip `Dùng thử` (không phải `Đang dùng thử`) và tray `Sang gói năm` (không phải
    `Chuyển sang gói năm`).

    Riêng cột đếm ngược có một quyết định về nghĩa chứ không phải về chiều rộng: dòng
    phụ của một mục quá hạn ghi `4 ngày` chứ không ghi `4 ngày trước`, vì viên thuốc
    `Trễ` ngay trên nó đã nói rồi. Tiếng Anh vẫn giữ `4 days ago`, vì ở đó dòng này
    đứng đúng chỗ mà mọi dòng khác mang một ngày tháng. Đó là `S.t.overdueAgo`, tách
    khỏi `S.t.daysAgo` mà văn xuôi dùng.

41. **Loại tiền app cộng tổng là một biến chạy được, không phải hằng số.** `Fx.base`
    thay cho `Fx.baseCurrency` cũ, và onboarding là chỗ hỏi nó. Không một khoản
    `Money` nào bị viết lại khi giá trị này đổi: mỗi khoản giữ nguyên loại tiền đã
    nhập, mãi mãi, và cái đổi chỉ là loại tiền các phép cộng được phát biểu lại.

    App mang đúng **một** tỉ giá, USD sang VND. `Fx.total` đọc nó theo cả hai chiều,
    vì chọn đếm bằng đồng hay bằng đô là quyết định của người dùng chứ không phải của
    tỉ giá. Chọn loại tiền thứ ba vẫn chạy, từng loại vẫn cộng riêng chính xác, chỉ là
    không còn một con số tổng gộp chung, và `unconvertedCount` là chỗ giao diện nói ra
    điều đó. Màn thứ hai của onboarding nói trước cả khi người dùng bấm.

    `MoneyFormat` hết đoán bên đặt ký hiệu theo số chữ số thập phân. Luật cũ đặt ký
    hiệu yên sau con số vì ký hiệu đồng nằm sau, mà `1,200 ¥` thì không ai viết. Bên
    đặt ký hiệu giờ là một trường của từng loại tiền trong `CurrencyCatalog`, và loại
    tiền nào không có ký hiệu riêng thì in ra chính mã của nó, cách một khoảng trắng.

42. **Onboarding có hai màn, và cố ý không còn xin quyền thông báo lẫn khôi phục
    backup.** Màn đầu ba card, mỗi card chạy một hình động dựng bằng chính widget của
    app: dải mục trôi ngang dùng icon thương hiệu thật, mock màn khoá với thông báo
    rơi xuống, chart chín cột mọc lên. Màn hai hỏi hai câu app không tự trả lời được,
    loại tiền và ngôn ngữ.

    Quyền thông báo vẫn hỏi ở `NotificationAsk`, lúc lưu mục đầu tiên, nơi sheet gọi
    được tên cái ngày người dùng vừa gõ. Đó là chỗ đúng và không đổi. Khôi phục backup
    thì chỉ còn đường qua Settings, và đó là một mất mát có thật: người vừa cài lại
    máy phải tự đi tìm.

    Ba hình động đều tôn trọng Reduce Motion, và đó không phải phép lịch sự thừa. Dải
    trôi ngang và thông báo rơi xuống **lặp mãi**, nên `pumpAndSettle` không bao giờ
    trả về. Mọi test và mọi lần chụp ảnh của màn này đều bật `disableAnimations`, tức
    là đi đúng đường mà máy bật Reduce Motion đi. Tắt animation thì dải đứng ở đầu
    vòng lặp và các thông báo đứng ở khung mà cả hai đều đã hiện, chứ không phải khung
    trống.

43. **`markSaved` nhận kênh làm tham số không bắt buộc, và bỏ trống là ghi vào kênh
    tệp.** Đường ghi lên iCloud trong `app.dart` từng gọi `markSaved(at)` trơn. Nó
    biên dịch được, tải lên thật, rồi đóng dấu ngày vào ô của kênh tệp. Kết quả trên
    màn iCloud là `Trạng thái: Đã lưu` nằm ngay trên `Bản gần nhất: Chưa bao giờ`, còn
    hàng `File` trong Settings mọc ra một ngày cho một tệp người dùng chưa từng xuất.
    Hai câu đối nhau như vậy thì người đọc tin câu tệ hơn, và đó là câu sai.

    **Màn iCloud giờ chỉ còn một dòng, `Lưu gần nhất`, và nó ghi tới phút.** Dòng
    trạng thái cũ đã bỏ: khi nó đúng thì nó nói lại đúng thứ cái ngày đã chứng minh,
    còn khi nó sai thì nó là nửa dối trá ở trên. Không ai bấm gì để lần ghi lên iCloud
    xảy ra, nên một ngày trơn không phân biệt được bản viết lúc sáng với bản viết ngay
    sau lần sửa vừa rồi, mà đó chính là câu người mở màn này đang hỏi. Vì vậy
    `LastBackups` mang `fileAt` và `cloudAt` kiểu `LocalDateTime`; `file` và `cloud`
    chỉ còn là hai getter trả về phần ngày, và hàng `File` vẫn in ngày thôi vì một tệp
    xuất hồi tháng Năm là tệp của tháng Năm dù lưu lúc mấy giờ.

    Hai trạng thái vẫn thắng cái ngày và chiếm luôn dòng đó: chưa đăng nhập iCloud, và
    ghi hỏng. Cả hai là thứ một cái ngày không mô tả được, và `27/08/2026 lúc 14:08`
    đứng cạnh một tài khoản đã đăng xuất từ hôm đó là app báo cáo một bản sao nó đã
    thôi giữ. Chưa ghi lần nào thì viết `Chưa bao giờ`, không viết `Đang chờ có gì
    đổi`: người mở màn này hỏi có bản sao hay không, không hỏi máy đang ở trạng thái gì.

    **Kèm theo là một luật của `DetailRow`, không riêng màn này.** Trước đây nhãn và
    giá trị mỗi bên là một `Flexible`, tức là mỗi bên đúng một nửa bề ngang dù có cần
    hay không, và một `Flexible` cần ít hơn thì bỏ trống phần thừa chứ không nhường.
    Nhãn ngắn cạnh giá trị dài vì thế cho ra một khoảng trống giữa thẻ và một dấu `…`
    ở cuối giá trị, tức là cắt mất đúng cái phần dòng đó sinh ra để nói. Nay nhãn lấy
    đúng phần nó cần và giá trị lấy phần còn lại; nhãn vẫn bị chặn ở `_labelShare`
    (0.55) để một bản dịch tiếng Việt dài thêm vài chữ không đẩy được giá trị ra ngoài.

    Giá trị lưu xuống `settingRow` nay là chuỗi ISO theo giờ máy, không kèm `Z`. Bản
    cài cũ giữ một chuỗi ngày trơn dưới đúng khoá đó, và `_readStamp` vẫn đọc được nó
    thành nửa đêm. Từ chối chuỗi cũ là báo `Chưa bao giờ` cho người đang có bản sao,
    tức là đúng cái lỗi vừa sửa xong.

    Chốt chặn ở ba mức: `the cloud copy is remembered to the minute` và `a date written
    by an older build still reads` trong `test/unit/data/backup_store_test.dart`, nhóm
    `the iCloud page` trong `test/unit/ui/backup_presenter_test.dart`, và bài
    `a cloud write stamps the cloud row, not the file row` trong
    `integration_test/backup_test.dart`. Chỉ bài cuối thấy được chỗ hỏng thật, vì lời
    gọi thiếu tham số nằm trong `app.dart`.

44. **Kênh File có hai tệp, và chỉ một trong hai quay về được.** `Export a backup` ghi
    JSON đầy đủ, `Export as CSV` ghi danh sách dịch vụ thành bảng tính, `Restore from
    a file` chỉ đọc JSON. Không có đường nhập CSV, và đó là chủ ý chứ không phải chưa
    làm: mười cột người đọc được không mang nổi nhóm, nguồn tiền, lịch sử đã trả và
    cài đặt, nên một tệp đi ra rồi quay về sẽ đặt danh sách vào một cái app đã mất sạch
    những thứ đứng sau nó. Chú thích dưới nút nói thẳng điều này.

    Không bỏ JSON đi được. Trên Android không có iCloud, nên tệp JSON là **đường sao
    lưu đầy đủ duy nhất** người dùng tự tay cầm được.

    `_exportCsv` trong `app.dart` **cố ý không gọi `markSaved`**. `Lần xuất gần nhất`
    là ngày tồn tại một tệp có thể dựng lại được app, mà tệp này thì không, nên đóng
    dấu nó là gỡ mất cảnh báo "chưa sao lưu gì" cho một người thật sự chưa có bản sao
    lưu nào.

    Vài chi tiết trong `lib/ui/csv_export.dart` đừng bỏ:

    - **Có BOM và xuống dòng bằng CRLF.** Excel trên Windows đọc tệp UTF-8 không BOM
      theo bảng mã hệ thống, tức là một danh sách tên tiếng Việt mở ra thành ký tự rác.
    - **Số tiền không có dấu phân nhóm.** Dấu phẩy ở đây là dấu ngăn cột, và bảng tính
      đọc `260,000` thành chữ chứ không thành số. Vì vậy không dùng `MoneyFormat`.
    - **Ngày viết kiểu ISO**, không viết ngày trước như trên màn hình. Cột này để sắp
      xếp và lọc trong bảng tính, mà `27/08/2026` là kiểu ngày duy nhất bảng tính đọc
      khác nhau tuỳ máy người đọc đặt ở đâu.
    - **Tiêu đề cột có chuỗi i18n riêng**, không dùng lại nhãn dòng của màn Detail. Tệp
      là một giao kèo với thứ người dùng mở nó lên; sửa chữ trên một màn hình không
      được âm thầm đổi tên một cột ai đó đã viết công thức trỏ vào.
    - **Cột trạng thái viết `Cancelled (still usable)` trong ngoặc, không viết dấu
      phẩy.** Dấu phẩy hợp lệ nhưng bắt trình ghi bọc ngoặc kép cái ô đó ở mọi dòng đã
      huỷ, chẳng để làm gì.
    - **Mục đã cất đi vẫn nằm trong tệp**, kèm cột nói rõ. Màn hình giấu chúng đi, còn
      một tệp thì không phải màn hình.
    - **Cột dùng thử đọc cờ `inTrial`, không đọc `isTrialOn`**, theo đúng bẫy 14: một
      tệp không mang trong mình cái ngày hôm nay.

    Cả `paused` (tắt nhắc) lẫn thang nhắc hạn đều không có cột. Đó là cái giá của bộ
    mười cột đọc được, và JSON vẫn giữ đủ.

45. **Một trường chỉ thật sự chạy khi đủ bốn chỗ, và ba chỗ đầu không đỏ khi thiếu chỗ
    thứ tư.** Cột `note` từng có mặt ở khắp nơi: cột SQLite, `mappers.dart`,
    `backup.dart`, cột CSV, và một dòng trên màn Detail. Chỉ thiếu đúng một thứ, là ô
    nhập trong form, nên `DraftItem` không mang `note` và **không đường nào trong app
    đặt được giá trị đó**. Dòng `Ghi chú` trên màn Detail vì thế in ra một dấu gạch
    ngang với mọi mục, mãi mãi, và không có test nào đỏ vì mỗi mảnh riêng lẻ đều đúng.

    Bốn chỗ đó là: bảng (bẫy 1), `backup.dart` (bẫy 26), `DraftItem` cả ba phần của nó
    (trường, `.of`, `applyTo`), và **lời gọi `TrackedItem.on` trong `_saveDraft` của
    `app.dart`**. Chỗ thứ tư là chỗ nguy hiểm nhất, vì nó nhận tham số **không bắt
    buộc**: bỏ sót một cái thì trình biên dịch im, app chạy, mục được lưu, và câu trả
    lời người dùng vừa gõ biến mất. Đúng hình dạng của bẫy 43.

    Chuyện đó đã xảy ra với hai trường khác nữa, và chúng nằm im rất lâu: `inTrial` và
    `paymentSourceId` **có** ô trên form, đi đúng tới `DraftItem`, rồi không được truyền
    tiếp trong `_saveDraft`. Đường Edit che mất chuyện này, vì `applyTo` trộn vào một
    mục đã có nên nó mang hai trường đó qua bình thường. Mất mát chỉ hiện ở **lần lưu
    đầu tiên của một mục**: bật công tắc dùng thử, chọn thẻ, bấm Lưu, và mục hiện ra
    không dùng thử, không thẻ nào.

    Chốt chặn là `integration_test/add_test.dart`, chạy trên máy ảo
    (`flutter test integration_test/add_test.dart -d <simulator-id>`). Phải là
    integration test: widget test của form chỉ nhìn thấy cái `DraftItem` đi ra, mà cái
    đó vốn đã đúng ở cả ba lần hỏng.

    Hai quyết định về giao diện đi kèm:

    - **Ô rỗng lưu thành `null`, không lưu thành `''`.** Màn Detail hỏi `note == null`
      để quyết định có vẽ dòng đó không, nên một chuỗi toàn dấu cách sẽ vẽ ra một dòng
      trống. `_savedNote` trong `add_item_screen.dart` là chỗ cắt.
    - **Dòng note trên màn Detail không phải `DetailRow`.** `DetailRow` là một dòng
      `maxLines: 1` căn phải, đúng cho một ngày hay một số tiền, và một câu người dùng
      viết đi qua nó thì ra bốn chữ với dấu `…`, tức là cắt mất đúng phần dòng đó sinh
      ra để nói. `_NoteRow` xếp nhãn lên trên và cho chữ xuống dòng hết chiều ngang,
      chữ thường chứ không đậm và `height: 1.45` chứ không phải `1`, vì `rowValue` được
      đặt cho một dòng đứng một mình.

46. **Loại tiền là một danh sách, không còn là một mã.** `CurrencyStore.read` trả về
    `CurrencyPicks`, gồm `codes` (một hoặc hai mã) và `base` (mã mà mọi phép cộng phát
    biểu lại). Đó là hai câu hỏi khác nhau: `codes` là "tôi bị tính tiền bằng những loại
    nào", `base` là "cộng tổng lại thì nói bằng loại nào". Trước đây app chỉ hỏi câu thứ
    hai, nên form nhập tiền phải đoán câu thứ nhất: nó bày `base` cộng nửa còn lại của
    cặp tỉ giá đóng gói sẵn. Người tính tiền bằng đồng và bằng won vì thế có sẵn một chip
    đô la không dùng tới, mà lại không có chip won.

    Không một khoản `Money` nào bị viết lại khi danh sách này đổi, đúng như bẫy 41.

    - **Khoá `base_currency` giữ nguyên tên, và không được đổi.** Bản cài cũ chỉ ghi đúng
      dòng đó, và dòng đó vẫn là một câu trả lời đầy đủ. Thiếu dòng `currencies` thì
      `read` đọc dòng cũ thành danh sách một phần tử. Chốt chặn là bài `a base written by
      an older build reads as one currency` trong `test/unit/data/locale_currency_store_test.dart`.
    - **`CurrencyPicks` dễ dãi lúc dựng**, cùng luật với `mappers.dart`: viết hoa, bỏ
      trùng, cắt còn hai, và kéo `base` vào danh sách nếu nó đứng ngoài. Ném lỗi ở đây là
      để một người không còn loại tiền nào.
    - **Thêm một loại tiền không dời `base`.** "Tôi cũng bị tính bằng loại này" không phải
      "cộng tổng bằng loại này". Ngược lại, `withBase` khi danh sách đã đầy thì **ô base
      nhường chỗ**, không phải ô kia: người đang đổi loại tiền của tổng là đang sửa chính
      câu trả lời đó, còn loại tiền thứ hai là một câu trả lời khác họ cố ý đưa ra.
    - **`CostField.offered` đọc `Fx.declared`, và chỉ nối thêm nửa còn lại của cặp tỉ giá
      khi danh sách có đúng một mã.** Bỏ ngoại lệ đó là lấy mất một chip của người chưa hề
      mở ô thứ hai, để đổi lấy việc họ đã trả lời một câu hỏi trong onboarding. Trần vẫn
      là ba chip, và chỉ một trường hợp chạm tới trần: một mã duy nhất mà app không có tỉ
      giá, cộng cả hai nửa của tỉ giá app có.
    - **Mỗi thẻ loại tiền vẽ một hoá đơn, không vẽ tên loại tiền.** Bảng nằm ở
      `lib/ui/screens/onboarding/currency_samples.dart`. Riêng USD và VND lấy giá thật từ
      danh mục kèm nguồn, vì đó là hai mã hầu hết người dùng sẽ chọn và một con số bịa ở
      đây sẽ bị chính app cãi lại ba cú bấm sau, trên trang của đúng dịch vụ đó. Mười mã
      còn lại là minh hoạ, cùng loại với ngày tháng trong dải trôi ngang ở trang trước.
      Mã không có trong bảng thì thẻ rơi về ký hiệu và tên loại tiền, đó là đúng chứ không
      phải thiếu.
    - **Thẻ bấm được để đổi chính ô đó, và có nút bỏ khi danh sách có hai mã.** Bản thiết
      kế không có đường nào gỡ một loại tiền ra; thiếu nó thì một cú bấm nhầm là vĩnh
      viễn, trên màn hình mà cú bấm kế tiếp là `Bắt đầu`.
    - **Sau onboarding, đường duy nhất là hàng Loại tiền trong Settings**, và nó mở đúng
      khối đó trong một sheet (`CurrencyPicksSheet`). Onboarding chỉ hiện khi danh sách
      mục còn rỗng, nên không có đường này thì câu trả lời đóng băng mãi mãi.

    Hai quyết định về trang thứ hai của onboarding đi kèm:

    - **Ngôn ngữ hỏi trước, và là một hàng mở sheet chứ không còn là hai ô cạnh nhau.**
      Thứ tự có lý do: khối loại tiền bên dưới dài hơn hẳn, và trả lời nó trước bằng một
      thứ tiếng người đọc không đọc được là bắt họ trả lời hai lần. Sheet dùng chung
      `LanguageSheet` với Settings.
    - **Không còn đoạn văn dưới tiêu đề.** Trang là tiêu đề, hai nhãn và hai khối điều
      khiển; mỗi câu thêm vào đẩy thẻ thứ hai và cái nút xuống khỏi khung 390x844. Thứ
      phải nói thì nói ngay chỗ nó áp dụng: dưới hàng chip mặc định, và dưới một loại tiền
      app không có tỉ giá.

    Dòng phụ của thẻ trong tiếng Việt dài hơn tiếng Anh và đã tràn một lần, đúng bẫy 40.
    Đệm thẻ, cỡ ô icon và cỡ số tiền đều đã bóp lại cho vừa `Standard · hàng tháng`. Sửa
    gì ở thẻ này thì chạy `SHOTS_VI=1` rồi nhìn ảnh, đừng tin là xong.

    `tool/shots/capture.dart` chụp thêm khung `onboarding-setup-two`, vì trạng thái hai
    loại tiền là trạng thái bản thiết kế mô tả và là trạng thái duy nhất có hàng chip mặc
    định. Cùng lúc đó sửa một lỗi cũ trong file: khối onboarding ghi cứng bảng màu sáng,
    nên bản `SHOTS_DARK=1` ghi một màn sáng vào tệp tên `dark_`.


47. **Trước khi danh sách đầu tiên về, app không vẽ gì ngoài nền gradient.**
    `_showOnboarding` hỏi `_loaded && _items.isEmpty`, mà `_loaded` chỉ bật khi stream
    drift kêu lần đầu. Nhánh còn lại là `AppShell`, nên trong đúng những khung hình đó
    người vừa cài xong nhìn thấy một màn Upcoming rỗng, đủ tab bar và đủ dòng chữ báo
    không có gì đến hạn, rồi onboarding mới đè lên. Câu đầu tiên app nói với họ là "bạn
    chẳng có gì", phát ra từ đúng cái màn hình chỉ nên tới sau phần giải thích.

    Giữ nền gradient chứ không để trống, để không có lỗ xám và để onboarding rơi xuống
    mà không có gì xê dịch. Không có spinner: đây là một khung hình đọc SQLite ngay trên
    máy, và một cái spinner ở đó chỉ làm một phép đọc tức thời trông như chậm.

    **Đừng sửa theo chiều ngược lại**, tức là đoán onboarding trong lúc dữ liệu còn đang
    về. Nó chỉ đổi cái nháy này lấy cái nháy ngược lại, và cái nháy ngược lại rơi vào
    người đã có sẵn danh sách, tức là người mất nhiều hơn.

    Chốt chặn là `integration_test/first_launch_test.dart`, chạy trên máy ảo
    (`flutter test integration_test/first_launch_test.dart -d <simulator-id>`). Nó pump
    từng khung một chứ không `pumpAndSettle`, và đó là cả bài test: settle nhảy qua đúng
    những khung hình chứa cái nháy. Phải là integration test vì cái cổng nằm trong
    `app.dart`, và `HomePage` lên lịch nhắc hạn ngay ở stream event đầu tiên nên cần một
    nền tảng thật trả lời.


48. **Đọc file trên iCloud phải hỏi metadata query, không hỏi hệ thống tệp.** Plugin
    `icloud_storage` cũ đã bỏ từ tháng 1/2023 và không hỗ trợ Swift Package Manager, nên
    Flutter cảnh báo mỗi lần build iOS. Nay dùng `icloud_storage_plus`, và bản 4 có ba
    cách hỏi xem file có ở đó không. Chỉ một cách đúng cho việc này:

    | Gọi cái gì | Hỏi ai | Thấy gì |
    |---|---|---|
    | `gather` | NSMetadataQuery | Cả file mới chỉ là lời hứa, chưa có mặt trên máy |
    | `listContents` | FileManager | Chỉ file đã có mặt trên hệ thống tệp |
    | `getItemMetadata` | FileManager | Như trên, cho đúng một đường dẫn |

    `CloudBackup.latest` gọi `gather`, và đó là chỗ dễ sửa thành sai nhất, vì hai cách kia
    ngắn hơn và chạy đúng trên máy của người viết code. Người mở màn khôi phục gần như
    luôn là người vừa cài lại máy hoặc vừa đổi điện thoại, mà trên một máy chưa từng thấy
    container thì file chỉ tồn tại dưới dạng một lời hứa metadata query biết còn hệ thống
    tệp thì chưa. Hỏi hệ thống tệp là trả lời `Chưa có bản sao nào trên iCloud` cho đúng
    người mà tính năng này sinh ra để phục vụ, và trả lời đúng cho mọi người khác.

    Đọc nội dung thì `readInPlace`, ghi thì `writeInPlace`. Cả hai đi qua `UIDocument` nên
    không cần file tạm nữa: đường ghi cũ dựng một file trong thư mục tạm rồi mới upload
    theo đường dẫn, và để lại file đó sau mỗi lần sửa. Timeout 20 giây vẫn giữ, vì một lần
    mở có phối hợp trên file máy chưa tải về sẽ nằm chờ iCloud giao dữ liệu, mà iCloud
    không hứa nhanh.

    Lỗi nay có kiểu thay vì so `PlatformException.code` bằng chuỗi.
    `ICloudContainerAccessException` là chưa đăng nhập, tắt iCloud Drive, hoặc từ chối
    quyền, tức là đúng ba thứ `CloudState.signedOut` nói ra;
    `ICloudItemNotFoundException` là `missing`. Bắt hai cái này **trước**
    `ICloudOperationException`, cả hai đều kế thừa từ nó.

    Chốt chặn là `integration_test/cloud_backup_test.dart`, chạy trên máy ảo
    (`flutter test integration_test/cloud_backup_test.dart -d <simulator-id>`). Máy ảo
    không có container nên mọi lời gọi trả `signedOut`, và đó là cả bài test. Plugin không
    được đăng ký sẽ ném `MissingPluginException`, mà nó cũng là `Exception` nên rơi vào
    nhánh bắt tất và thành `CloudState.failed`. Trên màn hình hai thứ đó cách nhau rất xa:
    `signedOut` in ra câu người dùng sửa được, `failed` in ra một lời xin lỗi vì có lỗi.
    `integration_test/backup_test.dart` không thấy được chuyện này, vì nó thay hẳn
    `CloudBackup` bằng một bản giả.

    Sau khi đổi, **mọi plugin iOS của repo đều là Swift Package, và CocoaPods đã gỡ
    hẳn.** Không còn `ios/Podfile`, `ios/Podfile.lock` hay `ios/Pods/`. Build sạch đi từ
    78 giây xuống 65 giây.

    `pod deintegrate` chỉ dọn `project.pbxproj`. Ba chỗ còn lại phải sửa tay, và chỗ thứ
    ba là chỗ im lặng nhất: `contents.xcworkspacedata` còn một `FileRef` trỏ vào
    `Pods/Pods.xcodeproj`, mà `flutter build` không đọc tệp đó nên nó chạy đúng mãi cho
    tới hôm có người mở Xcode lên. Đủ bốn bước ở `docs/running.md` mục 1, kèm chuyện
    `pod deintegrate` chết nếu locale không phải UTF-8.

49. **Cảnh báo KGP lúc build Android là báo động giả, và đường sửa hiển nhiên thì gãy
    build.** Mỗi lần build Android in ra:

    ```
    WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
    flutter_timezone
    Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
    ```

    `flutter_timezone` 5.1.0 đã migrate rồi, và 5.1.0 là bản mới nhất trên pub.dev.
    `android/build.gradle` của nó bọc lời gọi trong một điều kiện:

    ```groovy
    if (agpMajor < 9 || !builtInKotlinEnabled) {
        apply plugin: 'kotlin-android'
    }
    ```

    Repo này chạy AGP 9.1.0 nên nhánh đó không chạy. Nhưng phép dò của Flutter **đọc file
    build của plugin bằng một mẫu tìm chuỗi, không hỏi Gradle xem plugin nào thật sự được
    nạp lúc chạy.** Nó thấy chuỗi `apply plugin: 'kotlin-android'` nằm trong file là kêu,
    không đọc được cái `if` bọc ngoài. Chỗ viết ra điều đó là comment ngay trên
    `getSubprojectPluginState` trong `packages/flutter_tools/gradle/src/main/kotlin/FlutterPluginUtils.kt`
    của SDK. Tác giả plugin trả lời đúng như vậy và đóng
    [issue #63](https://github.com/tjarvstrand/flutter_timezone/issues/63).

    **Đừng lật `android.builtInKotlin` trong `android/gradle.properties` thành `true`.**
    Đó là đường sửa trông có lý nhất, và nó hỏng theo hai kiểu cùng lúc. Một, build gãy ở
    `:android_file_picker:bundleDebugAar` với `aarMetadataCheck ... which doesn't exist`.
    Hai, cảnh báo `flutter_timezone` **vẫn hiện y nguyên**, đúng như phải thế, vì nó đọc
    văn bản file chứ không đọc cái cờ đó. Tức là đổi một build đang chạy lấy đúng con số
    không.

    Cũng đừng bỏ plugin đi. Nó được gọi đúng một chỗ, `FlutterTimezone.getLocalTimezone()`
    trong `lib/platform/notification_scheduler.dart`, và Dart không có đường nào lấy tên
    múi giờ kiểu IANA. Bỏ nó nghĩa là tự viết kênh gọi sang cả hai nền tảng, cho đúng cái
    thứ mà bẫy 25 đã ghi lại là làm nhắc 08:30 tới lúc 15:30 khi sai.

    Thứ đáng để mắt thì có thật, và nó không nằm trong repo này: nếu Flutter biến cảnh báo
    thành lỗi mà vẫn giữ nguyên cách dò bằng chuỗi, repo sẽ gãy dù code của plugin hoàn
    toàn đúng. Đường sửa lúc đó nằm ở phía Flutter hoặc phía plugin, không phải ở đây.

    Kèm theo: mỗi lần build Android đẻ ra `android/.kotlin/`, thư mục nháp của Kotlin
    Gradle Plugin. Nó đã vào `android/.gitignore`.

50. **`maybePop` pop trễ một nhịp, nên đừng đẩy gì lên ngay sau nó.** `_saveDraft` từng
    gọi `Navigator.of(context).maybePop()` rồi mở luôn sheet xin quyền thông báo trong
    cùng một nhịp đồng bộ. `maybePop` hỏi route xem có được đi không, mà phép hỏi đó là
    một `await`, nên nó pop ở microtask sau; lúc quay lại thì trên đỉnh stack là cái
    sheet vừa đẩy lên chứ không phải cái form nó định pop, và nó **lặng lẽ không làm gì**.

    Người dùng vì thế đáp ứng xong lời xin quyền là thấy mình vẫn đứng trong form, với
    nút Lưu đã tắt vì cái chốt ở bẫy 30 đã tiêu. Không có gì trên màn hình nói mục đã
    lưu hay chưa, và cách duy nhất để biết là bấm Cancel rồi thấy nó nằm sẵn ngoài danh
    sách. Với một form vừa hỏi xin quyền thì đó đúng là câu tệ nhất có thể nói: cú bấm
    tiếp theo của một người tưởng mình chưa lưu là lưu lại lần nữa.

    Nay `_saveDraft` gọi `pop()` trơn, đồng bộ và không hỏi ai, rồi mới chờ hết
    `_formExit` (340ms, đúng bằng chuyển cảnh của `MaterialPageRoute` cộng một nhịp) mới
    mở sheet. Thứ tự đó là cả tính năng: sheet gọi tên cái mục vừa lưu, và nó phải nằm
    trên danh sách đang có mục đó chứ không nằm trên một cái form chưa đóng.

    Chốt chặn là bài `saving leaves the form before anything else is asked` trong
    `integration_test/add_test.dart`, chạy trên máy ảo. Phải là integration test vì cả
    lời gọi pop lẫn cái sheet đều nằm trong `app.dart`; widget test của form chỉ thấy
    `DraftItem` đi ra, đúng như bẫy 45.

51. **Cảnh báo sao lưu đo theo *nội dung* bản sao, không đo theo ngày.** Trước đây nó
    chỉ bật khi **chưa từng** sao lưu ở đâu, nên người lưu một lần hồi tháng Năm rồi
    thêm sáu mục phải gọi tổng đài mới có ngày thì app im hoàn toàn. Nay mỗi lần ghi
    thành công, `markSaved` lưu kèm **danh sách id** của những mục `isCostlyToRebuild`
    đang có, và cảnh báo bật khi có mục nào không nằm trong danh sách của bất kỳ kênh
    nào.

    **Là tập id chứ không phải một con số đếm, và đó là cả điểm của nó.** Người sao lưu
    năm ngày, xoá một mục rồi thêm một mục khác vẫn đang có năm, trong khi một ngày
    trong đó không nằm trong bản sao nào. Một con số không nhìn thấy chuyện đó.

    **`null` và tập rỗng là hai chuyện khác nhau, và phân biệt được hai cái đó là điều
    kiện để tính năng này không thành báo động giả.** `null` là bản sao do bản build cũ
    ghi, tức là không biết nó chứa gì; rỗng là bản sao biết chắc không chứa gì đáng giá.
    Gộp hai thứ lại thì mọi bản cài đang chạy sẽ nổ cảnh báo ngay lúc nâng cấp, cho
    những bản sao hoàn toàn tốt. `LastBackups.coverageKnown` là chỗ trả lời, và
    `BackupPresenter.unsavedDates` trả về 0 khi chưa biết.

    **Danh sách id đọc *bên trong* `markSaved`, không truyền vào qua tham số.** Tham số
    không bắt buộc đúng là hình dạng đã hỏng hai lần trong repo này, xem bẫy 43 và 45:
    lời gọi vẫn biên dịch, bản sao vẫn lên, và cái record lặng lẽ khai rằng bản sao đó
    chứa số không.

    Luật `isCostlyToRebuild` nằm ở `TrackedItem` chứ không nằm ở presenter, vì cả tầng
    dữ liệu lẫn màn hình đều hỏi nó. Hai bản sao của luật này lệch nhau sẽ ra một cảnh
    báo không bao giờ tắt hoặc không bao giờ bật.

52. **Android sao lưu lên Drive App Data, và đó không phải ngoại lệ của nguyên tắc
    "không tài khoản".** Nguyên tắc là *Subdock* không có tài khoản và không có máy chủ.
    Bản iOS vẫn ghi vào iCloud của chính người dùng, tức là tài khoản Apple của họ;
    Drive App Data là đúng chuyện đó phía Android. Khác duy nhất là Apple giao container
    mà không hỏi, còn Google hỏi một lần.

    Hai phương án đã cân và loại, đừng đề xuất lại mà không đọc `docs/backup-and-sync.md`
    mục 6.2:

    - **Backend riêng.** Phần rối nhất của Drive là thiết lập đăng nhập Google, mà một
      backend cũng phải làm y hệt phần đó, rồi cộng thêm máy chủ, cơ sở dữ liệu, tiền
      hằng tháng, và trách nhiệm giữ ngày hết hạn SIM cùng số hộ chiếu của người lạ.
    - **Thư mục SAF người dùng tự chọn.** Không chống được mất máy, vì thư mục nằm trên
      chính cái máy đã mất. Nó chỉ sống sót nếu người dùng tình cờ trỏ vào một thư mục
      do dịch vụ đám mây cung cấp, mà app không ép và không kiểm được.

    **Bật Drive trên một danh sách rỗng phải nhìn lên Drive trước khi ghi.** Người mở màn
    này với danh sách rỗng gần như luôn là người vừa cài lại máy, tức là đúng người đang
    có bản sao nằm trên đó. Kết nối rồi ghi ngay là ghi đè bản sao đó bằng danh sách
    rỗng, bằng chính cú bấm họ làm để tự bảo vệ mình, và không có gì để lùi lại. Luật ở
    `_connectCloud` trong `app.dart`, và **từ chối khôi phục cũng không ghi gì**: "không
    muốn lấy lại danh sách cũ" không phải là "vứt nó đi".

    **`CloudState.disconnected` không phải `signedOut`.** `signedOut` là thứ đã hỏng và
    cần sửa; `disconnected` là một lời mời chưa ai nhận. Báo cái thứ hai bằng giọng của
    cái thứ nhất là đổ cho người dùng làm hỏng thứ họ chưa từng bật. Bấm huỷ giữa màn
    đăng nhập cũng rơi về `disconnected`, không phải `failed`: từ chối một lời mời là
    một câu trả lời.

    **Đừng gọi `attemptLightweightAuthentication` lúc mở app.** Tên nó và tài liệu
    của nó đều nói là im lặng, và trên Android thì không. Bản Android gọi hai lần: lần
    đầu chỉ nhìn những tài khoản đã cấp quyền cho app này, và **lần thứ hai, chạy mỗi
    khi lần đầu không thấy gì, mở sheet one-tap trên mọi tài khoản Google có trên máy.**
    Xem chính code của plugin, `google_sign_in_android/lib/google_sign_in_android.dart`,
    hàm `attemptLightweightAuthentication`, khối `if (_hostedDomain == null)`.

    Hậu quả là mở Subdock lên thì bị hỏi đăng nhập Google, với người chưa từng muốn sao
    lưu đám mây, trong một app mà lời hứa đầu tiên là không cần tài khoản nào. Đó là phá
    nguyên tắc chứ không phải phiền nhẹ.

    Vì vậy **app tự nhớ lấy tài khoản**, trong `CloudStore`, một dòng trong `settingRow`.
    Lúc mở app nó đọc đúng dòng đó và không đi đâu cả; `CloudBackup.resume` là `void`
    chứ không phải `Future`, cố ý, để không ai lỡ tay đặt một lời gọi mạng vào đó. Google
    chỉ được chạm tới ở đúng hai chỗ: cái nút người dùng bấm, và một lần xin token im
    lặng khi thật sự có thứ để tải lên.

    Token đó xin qua `GoogleSignIn.instance.authorizationClient`, tức là client dùng
    chung, **không phải qua một `GoogleSignInAccount`**. Muốn có đối tượng account thì
    phải đăng nhập, mà đăng nhập là đúng cái lời gọi phục kích người dùng lúc mở app.
    Client dùng chung chỉ trả token cho scope đã được cấp và trả null nếu chưa, không mở
    gì hết.

    Hệ quả cho chữ trên màn hình: **chưa có tài khoản là `disconnected`, có tài khoản mà
    không xin được token là `signedOut`.** Cái thứ nhất là một lời mời chưa ai nhận, cái
    thứ hai là quyền đã bị thu hồi và sửa bằng một cú bấm. Báo cái thứ hai bằng giọng
    của cái thứ nhất là gỡ tên tài khoản khỏi một màn hình vẫn đang hiện nó.

    Chốt chặn là nhóm `before anyone has connected` trong
    `test/unit/platform/drive_backup_test.dart`, và nó kiểm bằng cách khẳng định **không
    một request nào rời khỏi app**.

    **Client id nằm thẳng trong `drive_backup.dart`, và `--dart-define` giờ chỉ để tắt
    đi.** Chuỗi đó không phải bí mật: nó đi trong mọi bản app đã phát hành và ai cũng
    đọc ra được, nên giấu nó sau một cờ dòng lệnh chỉ đổi lấy việc mỗi lần
    `flutter run` thiếu cờ là hàng Google Drive lặng lẽ biến mất. Thứ phải giữ kín là
    client secret đứng cạnh nó trong Console, chuỗi bắt đầu bằng `GOCSPX`; app này
    không dùng tới nó và nó không được xuất hiện ở đâu trong repo.

    Đường tắt vẫn còn và vẫn cần: `--dart-define=GOOGLE_SERVER_CLIENT_ID=` để rỗng thì
    `isSupported` trả `false`, hàng Google Drive không hiện, và app chạy y như cũ. Đó
    là cho một checkout có dự án Google khác đứng sau, hoặc không có dự án nào.

    Nó là đường tắt chứ không phải tấm lưới. OAuth client kiểu Android khớp theo dấu
    vân tay SHA-1, nên một bản fork build bằng chính id này sẽ thấy hàng Drive và nó
    chết ở `clientConfigurationError` cho tới khi dấu vân tay của họ được khai. Xem
    `docs/backup-and-sync.md` mục 6.2bis.

    **Scope phải giữ nguyên là `drive.appdata`.** Nó thuộc nhóm non-sensitive, nên không
    phải nộp duyệt, không có đánh giá an ninh hằng năm, và không có màn hình "Google
    chưa xác minh ứng dụng này". Nới sang `drive.file` hay `drive` là vứt cả ba đi.

    **Cái bẫy tốn nhiều thời gian nhất không nằm trong code.** Play ký lại app bằng khoá
    riêng của nó, nên dấu vân tay SHA-1 của bản người dùng tải về khác với bản trên máy
    dev. Khai thiếu nó thì đăng nhập chạy hoàn hảo suốt lúc tự thử rồi hỏng với **toàn
    bộ** người tải từ Store, và không tái hiện được ở nhà. Đủ bốn bước ở
    `docs/backup-and-sync.md` mục 6.2bis. Vì lý do đó `DriveBackup._fromSignIn` **giữ
    nguyên phần mô tả** của `clientConfigurationError` thay vì nuốt đi.

    Ghi thì `PATCH` lên id đã có, không `POST` lần nữa: `POST` lần hai để lại hai tệp
    cùng tên trong thư mục và lần đọc sau lấy tệp nào Drive liệt kê trước. Câu truy vấn
    bắt buộc có `spaces=appDataFolder`; thiếu nó là Drive đi tìm trong My Drive, chỗ app
    này không có quyền và cũng không có việc gì phải tìm. Chốt chặn là
    `test/unit/platform/drive_backup_test.dart`, chạy được không cần tài khoản nào.

    **Phép tra tên tệp chạy trước cả `save` lẫn `latest`, và lỗi của nó phải được bắt
    riêng.** `_find` ném `_HttpProblem`, mà `_HttpProblem` không có `toString`, nên
    thiếu mệnh đề `on _HttpProblem` là nó rơi xuống `on Exception` và người dùng đọc
    được đúng chữ `Instance of '_HttpProblem'`. Đường khôi phục in ra to nhất, vì
    `app.dart` lấy thẳng `fetch.detail` đặt vào câu báo lỗi.

    Mất mát không chỉ là một câu xấu. `toResult` và `toFetch` sinh ra để dịch 401 và
    403 thành `signedOut`, tức là một cú bấm kết nối lại. Không bắt thì người vừa gỡ
    Subdock trong phần ứng dụng đã kết nối của Drive nhận về một lời báo lỗi, đúng cái
    mà doc comment của chính `_HttpProblem` gọi là một lời nói dối khoác áo lỗi kỹ
    thuật. Test cũ không thấy vì `serving()` luôn trả 200 cho phép tra; mã lỗi chỉ được
    tiêm vào lượt tải lên.

    **`start()` phải quên đi một lần khởi tạo đã hỏng.** Một `Future` bị reject vẫn
    khác `null`, nên `_started ??= initializePlugin()` trơn giữ luôn cái hỏng đó: bấm
    Connect lỗi một lần là mọi `connect`, `save`, `latest` sau đó await lại đúng nó và
    ném lại đúng lỗi đó, cho tới khi tắt hẳn app. Play Services bận một nhịp là đủ để
    tới đó. Vì vậy `_startOnce` xoá `_started` trong `catch` rồi mới `rethrow`, và
    `initializePlugin` tách ra thành một hàm riêng để test làm nó hỏng được.

    Thêm `google_sign_in` **không** kéo CocoaPods quay lại: `google_sign_in_ios` có
    `Package.swift`. Bẫy 48 vẫn nguyên vẹn, đã kiểm bằng `flutter build ios`.

53. **Cột đếm ngược đổi sang tháng ở mốc hai tháng tròn, và đếm bằng tháng lịch chứ
    không phải chia cho 30.** Trước đây cột này luôn đếm ngày, nên một hộ chiếu còn hạn
    tới năm sau hiện `312d`, một con số không ai trừ ra từ hôm nay và lại chiếm mất
    chiều ngang của cái tên bên cạnh.

    Ba con số trong `UpcomingCopy.when` đều có lý do, đừng đổi mà không đọc:

    - **Mốc là hai tháng, không phải một.** Bốn mươi lăm ngày vẫn là con số người ta
      tính được, còn ghi `1 tháng` cho nó là làm đúng cái việc mà dòng comment cũ trong
      file cảnh báo: một app tỏ ra dễ chịu bằng cách làm tròn một hạn đang tới gần.
      Dưới hai tháng vẫn đếm ngày chính xác từng ngày như cũ.
    - **`LocalDate.monthsUntil` đếm tháng lịch và bỏ phần lẻ, không làm tròn.**
      `2 tháng` nghĩa là cộng hai tháng vào hôm nay thì rơi đúng ngày đó hoặc sớm hơn,
      nên cột không bao giờ cho người dùng nhiều thời gian hơn thứ họ thật sự có. Chia
      ngày cho 30 thì 59 ngày ra `2 tháng`, tức là hứa thừa một tuần.
    - **Từ 12 tháng trở lên đổi sang năm.** Hộ chiếu gia hạn theo chu kỳ mười năm, và
      `120 tháng` thì không phải một câu trả lời.

    Phần lẻ mất đi ở đây chấp nhận được vì ngày đầy đủ nằm ngay dưới cùng một cột, và
    chỉ ở đây. Chốt chặn là nhóm `wording` trong
    `test/unit/ui/upcoming_presenter_test.dart` và nhóm `monthsUntil` trong
    `test/unit/domain/local_date_test.dart`. Lịch tháng dùng chung `UpcomingCopy.when`
    nên nó đi theo, đúng luật ở bẫy 31.

54. **Form Add và Edit phải tự nhận cú bấm ra ngoài để đóng bàn phím.** Trên iOS và
    Android, `TextField` mặc định không làm gì với cú bấm ra ngoài, còn ô tiền và hai ô
    đếm mở bàn phím số, mà bàn phím số không có phím Done. Hệ quả: bàn phím dựng lên rồi
    ở đó, che luôn nút Lưu, cho tới khi người dùng rời hẳn form.

    Vì vậy `build` của `add_item_screen.dart` bọc cả `Column` trong một `GestureDetector`
    với `HitTestBehavior.translucent`, gọi `FocusScope.of(context).unfocus()`. Widget con
    có cử chỉ riêng vẫn thắng trong gesture arena, nên nó chỉ nhặt những cú bấm không ai
    nhận. `ListView` của form và của màn chọn dịch vụ đều thêm
    `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`, vì kéo danh sách
    cũng là một cách nói rằng đã gõ xong.

    Chốt chặn là bài `a tap beside a field gives the keyboard up` trong
    `test/widget/detail_screens_test.dart`, đo bằng `tester.testTextInput.isVisible`.

55. **Giá trên danh sách đi kèm chu kỳ, và đi qua đúng một hàm.** `ItemPresenter.cost`
    là chỗ duy nhất ghép số tiền với hậu tố: `260,000 ₫/m`. Màn Detail đã viết như vậy
    từ lâu, còn hai danh sách thì in số trần, nên cùng một mục đọc ra hai kiểu. Số trần
    còn tệ hơn thế: `1,200,000 ₫` của một gói năm nằm dưới `260,000 ₫` của một gói tháng
    thì mục rẻ hơn lại đứng trên.

    Ba chỗ gọi nó: `UpcomingPresenter.subtitleOf` (lịch tháng ăn theo, đúng bẫy 31),
    `ServicesPresenter._subtitle`, và ô `Giá` của màn Detail. Mục một lần không có hậu
    tố, vì không có chu kỳ nào để gọi tên.

    **Đừng gọi nó cho một con số nói về một ngày cụ thể.** Mốc hạn trên cột
    `reminder_timeline.dart`, dòng trong lịch sử đã trả, và câu trong sheet xin quyền đều
    nói về một lần trừ tiền đã có ngày đứng cạnh; dán `/ tháng` vào đó là nói tiền lại đi
    tiếp vào đúng ngày đó. Màn Money cũng không gọi, vì con số ở đó là tổng của tháng
    đang xem, đã nhân theo số kỳ rơi vào tháng.

    Ba quyết định về chữ, đừng đảo lại mà không đọc:

    - **Đơn vị bên tiếng Anh là một chữ cái: `/w`, `/m`, `/y`.** Hậu tố này đi theo mọi
      giá trên mọi danh sách, mà thứ người ta đọc là cái giá, nên nó phải nhỏ hết mức còn
      đọc được. Hàng quý và nửa năm viết `/3m` và `/6m` chứ không viết `/qtr` và `/6 mo`,
      để không có ô nào phá nhịp một chữ cái. Chu kỳ tự gõ theo cùng luật: `/2w`, `/10d`.
    - **Bản tiếng Việt vẫn viết đủ chữ, `260,000 ₫/tháng`, và không có khoảng trắng quanh
      dấu gạch**, vì đó là cách hoá đơn tiếng Việt viết, và vì dòng phụ màn Tất cả dịch vụ
      đã tràn đúng bẫy 40. Tiếng Việt chưa có cách viết tắt nào đủ rõ cho `tháng` và
      `tuần`, nên nó chưa rút; đó là việc còn để ngỏ chứ không phải đã chốt. Chỗ ghép nằm
      ở `S.t.costEvery`, một phương thức của bản dịch chứ không phải một phép nối trong
      Dart, vì hai thứ tiếng ghép hai kiểu khác nhau.
    - **Khoảng trắng trong số tiền thành khoảng trắng không ngắt khi có hậu tố.** Dòng phụ
      màn Tất cả dịch vụ được phép xuống hai dòng, và không có nó thì `5,290,000` đứng
      cuối dòng trên còn `₫/năm` rơi xuống dòng dưới. Font Be Vietnam Pro cho hai loại
      khoảng trắng cùng bề rộng, đã đo, nên không có gì xê dịch. Hệ quả cho test: chuỗi
      mong đợi phải viết `'260,000\u00A0₫/m'`.
    - **Dòng phụ màn Tất cả dịch vụ nhận `maxLines: 2`.** Bản tiếng Anh vẫn gọn một dòng,
      nên hàng chỉ cao lên ở đúng thứ tiếng cần chỗ. Dòng trên màn Upcoming thì vẫn một
      dòng: ở đó tên nguồn tiền không được cắt, và cắt bớt dòng phụ là luật cũ của
      `_SecondLine`.

56. **Huỷ một gói đi qua `CancelAsk`, và trạng thái `cancelledStillActive` giờ mới thật
    sự kết thúc.** Trước đây nút `Huỷ gói này` gọi thẳng `repository.upsert` rồi pop, không
    hỏi gì, và cái tên trạng thái hứa một điều không code nào thực hiện.

    Ba chỗ hỏng cùng lúc, và chúng nối nhau:

    - **Nút không nói nó làm gì.** Mất mát là mọi nhắc hạn của mục đó bị gỡ, mà với một
      app cả việc là gửi nhắc hạn thì đó là thứ lớn nhất một cú bấm làm được. Tệ hơn, chữ
      `Huỷ gói này` đọc ra được thành "app sẽ huỷ hộ tôi bên nhà cung cấp", việc mà nó
      không làm và không nói ở đâu là không làm.
    - **Kỳ đã trả tiền không bao giờ hết.** `advanced` cuộn mục sang kỳ sau mà giữ nguyên
      `state`, nên một gói đã huỷ nằm trên Upcoming vô hạn.
    - **Chart Money cộng tiền mãi.** `countedOccurrences` đi tới theo chu kỳ và không hỏi
      `state`, nên nó vẽ một cột cho mọi tháng sau đó, cho gói người dùng đã dừng.

    Nay có `ItemActions.hasLapsed` và `lapsed`, cộng `_sweepLapsed()` trong `app.dart`.

    - **Phép quét chạy ở stream mục và lúc app resume, đúng chỗ `_replan()` chạy**, và vì
      đúng lý do ở bẫy 25: đồng hồ đi qua một ngày mà không dòng nào trong cơ sở dữ liệu
      đổi. Nó ghi xuống, và lần ghi đó lại kích hoạt stream gọi nó lần nữa; lần thứ hai
      không tìm thấy gì nên không ghi gì, thế là dừng.
    - **`lapsed` trả `null` khi không có gì để làm, không trả lại chính mục đó.** Trả lại
      mục thì lời gọi không phân biệt được cái nào đã đổi, và phép quét sẽ ghi đè cả bảng
      mỗi lần mở app.
    - **So là *qua hẳn* ngày, không phải đúng ngày.** Ngày cuối của một kỳ đã trả tiền là
      ngày dịch vụ còn chạy. Đóng vào sáng hôm đó là gỡ mục khỏi danh sách trong khi người
      dùng vẫn dùng được nó.
    - **Là một lần ghi chứ không phải phép suy lúc đọc**, ngược với cặp `inTrial` /
      `isTrialOn` ở bẫy 14. Khác nhau ở chỗ cờ dùng thử ghi một sự thật về quá khứ, còn
      đây là một trạng thái mới, và trạng thái thì đi vào tệp CSV lẫn file sao lưu, hai
      thứ không mang theo ngày hôm nay để tự tính lại.

    **`ItemState.archived` đổi tên thành `inactive`, nhưng `wireName` vẫn là `'ARCHIVED'`
    và không được đổi.** `enumFromWire` rơi về `ItemState.active` khi gặp giá trị lạ, nên
    đổi chuỗi lưu xuống sẽ làm **mọi mục đã đóng trong mọi máy đang chạy và mọi file sao
    lưu cũ sống dậy thành đang theo dõi**, kèm nhắc hạn. Tên Dart là thứ đọc trên màn
    hình; wire name là lời hứa với những file đã tồn tại.

    Chart Money bị cắt ở hai chỗ, và cả hai đều cần. `countedOccurrences` dừng sau kỳ
    `expiresOn`, còn `_year` bỏ hẳn mục đã huỷ: `NEXT 12 MONTHS` là một mức chi theo năm,
    và nhân một gói còn đúng một kỳ lên thành mười hai là tính dư mười một lần. Cắt theo
    từng kỳ chứ không bỏ mục ra khỏi cả năm, vì các khoản **trước** lúc huỷ đã đi thật và
    thuộc về đúng tháng chúng rơi vào.

    **Badge `ĐÃ HUỶ` là `StatusBadge(quiet: true)`, không dùng màu nhấn.** `FREE TRIAL`
    nhấn xanh vì đó là tin người đọc muốn nghe. Cái này ngược lại: dòng còn trên màn hình
    chỉ vì chưa hết kỳ, và một danh sách mà những mục đã kết thúc sáng nhất là danh sách
    đọc ngược. Badge có ở cả ba chỗ: Upcoming (`ItemRow`, lịch tháng ăn theo), All services,
    và màn Detail.

    **Một chỗ đặt badge, và huỷ thắng dùng thử.** Hai badge sau cái tên để lại cho tên
    khoảng bốn ký tự, trên đúng cái dòng sinh ra để hiện tên. Huỷ thắng vì nó là điều vừa
    thay đổi và là điều có một quyết định đứng sau; kỳ dùng thử thì đằng nào cũng sắp hết.
    Riêng màn Detail đặt badge **dưới** tên chứ không cạnh tên, vì tiêu đề ở đó xuống hai
    dòng với tên dài nên badge sẽ rơi vào một chỗ khác nhau ở mỗi mục.

    Sheet có hai bản chữ, và chỉ bản huỷ mặc mực đỏ. Nhánh trả góp chỉ ghim số kỳ, không
    đụng nhắc hạn, và sửa lại được bằng cách vào Edit đổi số kỳ; tô đỏ chỗ không mất gì là
    dạy người dùng đọc lướt qua màu đỏ. Ngày trên sheet in **đủ năm**, không dùng
    `shortDate` như dòng danh sách: một gói năm huỷ hôm nay chạy tới một ngày mười một
    tháng nữa, và `05/09` đọc vào tháng Chín là một ngày vừa trôi qua.

    Ba `_Line` giống hệt nhau trong `delete_ask.dart`, `restore_ask.dart` và sheet mới đã
    gộp thành `AskLine` ở `lib/ui/widgets/ask_line.dart`.

    Chốt chặn là `integration_test/cancel_test.dart`, chạy trên máy ảo. Phải là integration
    test vì sheet nằm trong `app.dart`, đúng bẫy 28, và vì phép quét không có nút nào gọi
    nó: bài cuối trong file không chạm vào gì cả, chỉ mở app lên. Một chi tiết của bài đó
    đáng nhớ: `openCancel` cuộn tới `Delete this item` chứ không cuộn tới chính cái nút cần
    bấm, vì màn Detail giữ tab bar (bẫy 17) và dừng cuộn ngay khi nút vừa lọt vào khung sẽ
    để nó nằm dưới tab bar, chỗ mà cú chạm rơi vào khoảng không và bài test đọc ra thành
    "sheet không mở".

    Chuyện đó không chỉ là của bài test mới. Dò tới nơi thì `delete_test.dart` đã đỏ **3
    trên 3** và `navigation_test.dart` đỏ **3 trên 8** từ trước, và đã kiểm bằng cách chạy
    lại ở HEAD trong một worktree riêng. Hai nguyên nhân, cả hai đều là lỗi im lặng đúng
    kiểu CLAUDE.md cảnh báo:

    - **`scrollUntilVisible` dừng quá sớm.** Nó trả về ngay khi widget lọt vào viewport,
      mà viewport chạy xuống **dưới** tab bar vì `AppShell` dùng `Scaffold(extendBody:
      true)` cho lớp mờ có cái để làm mờ. Cú chạm rơi vào `BackdropFilter` của tab bar và
      **không mất đi**, nó chỉ không làm gì, nên bài test đọc ra thành một cái nút không
      phản hồi và người sửa sẽ đi soi cái nút. Danh sách luôn cuộn thêm được, vì
      `SubdockSpacing.screenPadding` đã cộng chiều cao tab bar vào phần đệm đáy. Lời giải
      là `tapPastTabBar` trong `integration_test/scroll_reach.dart`, dùng chung cho cả ba
      file.
    - **`declineReminders` hỏi đúng một lần, và hỏi quá sớm.** Từ bẫy 50, `_saveDraft` pop
      form rồi chờ hết `_formExit` mới mở sheet xin quyền, mà một `Future.delayed` không
      sinh khung hình nào nên `pumpAndSettle` trả về ngay giữa quãng chờ đó. Bài test đi
      tiếp, không bấm `Để sau`, và cái toast xác nhận nó đang kiểm không bao giờ bắn.
      Thấy được widget cũng chưa đủ: sheet trượt lên, nên nút tồn tại trong cây khoảng
      200ms trước khi nó tới chỗ ngón tay chạm được, khung đầu tiên đặt nó ở dưới mép màn
      hình cả một màn rưỡi. Phải chờ nó xuất hiện **rồi** `pumpAndSettle` cho nó vào xong.

## Viết tài liệu

Tài liệu trong repo viết bằng **tiếng Việt**. Chữ trên giao diện app có **hai bản**,
tiếng Anh và tiếng Việt, và cả hai nằm trong `lib/i18n/`; xem bẫy 37. Hook `vn-writing`
sẽ chặn nếu tài liệu tiếng Việt có em-dash hoặc jargon không nền.

Tránh từ **"trục"**: nó là cách dịch thẳng của *axis* và tối nghĩa với người đọc. Viết
thẳng thứ đang nói tới, ví dụ "hai cách phân loại khác nhau".

## Bắt đầu từ đâu

| Muốn biết | Đọc |
|---|---|
| App làm gì và vì sao | `docs/product-spec.md` |
| Giao diện | Canvas `Subdock Glass App.dc.html` bên Claude Design, **không nằm trong repo**. Giá trị màu ở `lib/ui/theme/palette.dart` (hai bản sáng và tối), cách đọc chúng ở `lib/ui/theme.dart`; đọc bẫy 34 trước khi sửa màu. `docs/design-spec.md` đã cũ và có ghi rõ ở đầu file |
| Nguồn tiền, bật tắt dịch vụ, Savings | `lib/ui/savings_presenter.dart`, `lib/ui/services_presenter.dart`, `lib/ui/screens/savings_screen.dart` |
| Dùng thử miễn phí | `lib/ui/screens/add/trial_field.dart` cho cái công tắc, `TrackedItem.isTrialOn` cho câu hỏi hôm nay còn miễn phí không |
| Phần riêng của Android | `android/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/` |
| Danh mục dịch vụ | `docs/research/README.md` |
| Nhóm dịch vụ (category) | `lib/domain/default_categories.dart` cho 22 nhóm dựng sẵn, `lib/domain/category_book.dart` cho cách tra |
| Sáng hay tối | Bẫy 34, `lib/ui/theme/palette.dart` cho giá trị, `lib/data/theme_store.dart` cho lựa chọn của người dùng |
| Chữ trên giao diện, hai thứ tiếng | Bẫy 37 và 38. `lib/i18n/parts/` cho từng vùng màn hình, `lib/i18n/strings_en.dart` và `strings_vi.dart` cho bản dịch, `lib/data/locale_store.dart` cho lựa chọn |
| Loại tiền và tỉ giá | Bẫy 41 và 46. `lib/domain/fx.dart`, `lib/domain/currency_catalog.dart`, `lib/domain/currency_picks.dart`, `lib/data/currency_store.dart`, `lib/ui/widgets/currency_picker.dart` |
| Hai màn onboarding | Bẫy 42 và 46. `lib/ui/screens/onboarding/` |
| Icon | `docs/icon-credits.md` |
| Cái gì sắp xảy ra với một mục | `lib/ui/reminder_timeline.dart` cho phép dựng, `lib/ui/widgets/reminder_timeline_card.dart` cho khối trên màn Detail |
| Bộ lọc màn Upcoming | `lib/domain/upcoming_filter.dart` cho luật khớp, `lib/ui/filter_presenter.dart` cho danh sách chip và dòng tóm tắt, `lib/ui/widgets/filter_sheet.dart` cho sheet |
| Lịch tháng trên Upcoming | `lib/ui/calendar_presenter.dart` cho phép dựng lưới và luật chọn ngày, `lib/ui/widgets/month_grid.dart` cho cái card |
| Sao lưu, khôi phục, và câu hỏi đồng bộ | `docs/backup-and-sync.md`. Bẫy 43 và 44 cho hai kênh tệp, bẫy 48 cho plugin iCloud, bẫy 51 cho cảnh báo theo nội dung, bẫy 52 cho Drive bên Android, `lib/ui/csv_export.dart` cho tệp bảng tính |
| Việc còn dang dở | `data/services/_verify.md` |
| Khối so sánh gói năm và nút trang thuê bao | `docs/design-spec-annual-saving.md`, đã dựng, logic ở `lib/ui/annual_saving_presenter.dart` và `lib/ui/manage_presenter.dart` |
