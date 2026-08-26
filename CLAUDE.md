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

## Hai mươi tám cái bẫy đã vấp, đừng vấp lại

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

## Viết tài liệu

Tài liệu trong repo viết bằng **tiếng Việt**, chữ trên giao diện app viết bằng **tiếng
Anh**. Hook `vn-writing` sẽ chặn nếu tài liệu tiếng Việt có em-dash hoặc jargon không nền.

Tránh từ **"trục"**: nó là cách dịch thẳng của *axis* và tối nghĩa với người đọc. Viết
thẳng thứ đang nói tới, ví dụ "hai cách phân loại khác nhau".

## Bắt đầu từ đâu

| Muốn biết | Đọc |
|---|---|
| App làm gì và vì sao | `docs/product-spec.md` |
| Giao diện | Canvas `Subdock Glass App.dc.html` bên Claude Design, **không nằm trong repo**. Tokens đã chép vào `lib/ui/theme.dart`, đọc doc comment ở đầu file trước khi sửa màu. `docs/design-spec.md` đã cũ và có ghi rõ ở đầu file |
| Nguồn tiền, bật tắt dịch vụ, Savings | `lib/ui/savings_presenter.dart`, `lib/ui/services_presenter.dart`, `lib/ui/screens/savings_screen.dart` |
| Dùng thử miễn phí | `lib/ui/screens/add/trial_field.dart` cho cái công tắc, `TrackedItem.isTrialOn` cho câu hỏi hôm nay còn miễn phí không |
| Phần riêng của Android | `android/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/` |
| Danh mục dịch vụ | `docs/research/README.md` |
| Nhóm dịch vụ (category) | `lib/domain/default_categories.dart` cho 22 nhóm dựng sẵn, `lib/domain/category_book.dart` cho cách tra |
| Icon | `docs/icon-credits.md` |
| Bộ lọc màn Upcoming | `lib/domain/upcoming_filter.dart` cho luật khớp, `lib/ui/filter_presenter.dart` cho danh sách chip và dòng tóm tắt, `lib/ui/widgets/filter_sheet.dart` cho sheet |
| Việc còn dang dở | `data/services/_verify.md` |
| Khối so sánh gói năm và nút trang thuê bao | `docs/design-spec-annual-saving.md`, đã dựng, logic ở `lib/ui/annual_saving_presenter.dart` và `lib/ui/manage_presenter.dart` |
