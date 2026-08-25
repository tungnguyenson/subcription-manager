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

## Hai mươi bốn cái bẫy đã vấp, đừng vấp lại

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
