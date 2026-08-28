# Chạy thử và cài lên iPhone

Tài liệu này hướng dẫn chạy Subdock trên máy ảo và cài lên iPhone thật. Đọc để làm được ba việc: chạy thử nhanh khi đang code, cài lên máy của mình để dùng hàng ngày, và tìm ra chỗ hỏng khi nó không chạy.

Số liệu trong tài liệu lấy từ đúng máy đang phát triển: Flutter 3.47.0, Dart 3.13.0, Xcode 26.5.

## Thuật ngữ

Vài từ dùng xuyên suốt, giải thích trước một lần:

- **Bundle ID**: chuỗi định danh app trên iOS. Của app này là `space.subdock.subdock`.
- **Ký (code signing)**: Apple bắt mọi app phải được ký bằng danh tính nhà phát triển thì iPhone mới chịu chạy. Máy ảo thì không cần.
- **Team**: tài khoản nhà phát triển dùng để ký. Tài khoản Apple thường cũng làm được, gọi là Personal Team, nhưng bị hạn chế, xem mục cuối.
- **Deployment target**: phiên bản iOS thấp nhất app chạy được. Ở đây là **iOS 15.0**.
- **Entitlement**: quyền đặc biệt Apple cấp cho app, khai trong một tệp riêng. Liên quan tới thông báo, xem mục 5.

## 1. Cần gì trước

```bash
flutter --version     # cần 3.47 trở lên
xcodebuild -version   # cần Xcode 16 trở lên
flutter doctor        # phải xanh ở mục Xcode
```

Lần đầu sau khi clone, phải sinh mã cho lớp cơ sở dữ liệu. Tệp `*.g.dart` cố tình không nằm trong repo:

```bash
flutter pub get
dart run build_runner build
```

Bỏ bước này thì trình biên dịch báo thiếu `database.g.dart`. Đó là lỗi cố ý để dễ thấy, hơn là để một tệp sinh cũ nằm cạnh lược đồ đã sửa rồi ánh xạ sai cột mà không báo gì.

**Mọi plugin iOS của dự án đều là Swift Package, từ 27/08/2026.** Gói `icloud_storage` cũ
không hỗ trợ SPM nên Flutter phải bật lại CocoaPods, và in cảnh báo này ở mỗi lần build:

```
The following plugins do not support Swift Package Manager for ios:
  - icloud_storage
```

Gói đó publish lần cuối tháng 1/2023 và đã bỏ, nên cảnh báo không tự hết. Nay thay bằng
`icloud_storage_plus`, gói này có sẵn `Package.swift`. Xem bẫy 48 trong CLAUDE.md cho
những gì đổi theo trong `lib/platform/cloud_backup.dart`.

**CocoaPods đã gỡ hẳn cùng ngày.** Không còn `ios/Podfile`, `ios/Podfile.lock` hay
`ios/Pods/`, và `pod install` không chạy ở lần build nào nữa. Build sạch trên máy này đi
từ 78 giây xuống 65 giây.

Bốn thứ đã sửa, ghi ra vì ba thứ sau không nằm trong `pod deintegrate`:

- `pod deintegrate ios/Runner.xcodeproj` dọn `project.pbxproj`.
- Hai tệp `ios/Flutter/Debug.xcconfig` và `Release.xcconfig` bỏ dòng
  `#include? "Pods/..."`, chỉ còn `#include "Generated.xcconfig"`.
- `ios/Runner.xcworkspace/contents.xcworkspacedata` bỏ `FileRef` trỏ vào
  `Pods/Pods.xcodeproj`. Bỏ sót chỗ này thì workspace trỏ vào một project không còn tồn
  tại, mà `flutter build` vẫn chạy được nên chỉ người mở Xcode mới thấy.
- Xoá `ios/Podfile`, `ios/Podfile.lock` và thư mục `ios/Pods/`.

**`pod deintegrate` cần locale UTF-8, nếu không nó chết giữa chừng** với một vệt Ruby
stack trace và `Encoding::CompatibilityError`, ngay trên dòng cảnh báo nói đúng nguyên
nhân. Chạy `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod deintegrate ...`. Lệnh `pod install`
do Flutter gọi thì không dính, vì Flutter tự đặt locale.

## 2. Chạy trên máy ảo

Cách nhanh nhất, không cần ký, không cần cắm dây:

```bash
flutter devices                    # xem có gì
flutter run -d "iPhone 15"         # chạy, kèm nạp lại nóng
```

Đang chạy thì gõ trong cùng cửa sổ đó:

| Phím | Tác dụng |
|---|---|
| `r` | Nạp lại nóng, giữ nguyên trạng thái màn hình |
| `R` | Khởi động lại app, mất trạng thái |
| `q` | Thoát |

Nếu chỉ muốn biết có biên dịch được không, khỏi chạy:

```bash
flutter build ios --simulator --debug
```

### Chạy test

```bash
flutter test                    # 281 test, không cần máy ảo, khoảng 15 giây
flutter analyze                 # kiểm tra tĩnh
```

Test điều hướng phải chạy trên máy ảo thật, vì nó dựng cả app và bấm qua từng màn hình:

```bash
xcrun simctl list devices available | grep iPhone      # lấy id máy ảo
flutter test integration_test -d <simulator-id>
```

### Kiểm tra migration

`flutter test` chạy toàn bộ trên `NativeDatabase.memory()`. Cơ sở dữ liệu trong bộ nhớ luôn được tạo mới ở lược đồ hiện tại, nên **nó không bao giờ chạy qua migration**. Đó là lý do một migration hỏng ở mọi máy đã cài app vẫn để cả bộ test xanh.

Hai tầng bù vào chỗ đó:

```bash
flutter test test/unit/data/migration_test.dart      # mở tệp v1 thật, không cần máy ảo
flutter test integration_test/migration_test.dart -d <simulator-id>
```

Tầng dưới chạy đúng `openDatabase()` của app trên tệp thật trong máy ảo, rồi bấm Thêm mục và Lưu lên trên tệp vừa nâng cấp. Lược đồ v1 nằm ở `test/fixtures/schema_v1.dart`, **chép nguyên từ một tệp thật**, không phải viết lại từ trí nhớ. Bản viết lại từ trí nhớ chính là thứ để lọt lỗi `no such column: repeatCount`: nó bịa ra cột `riskLevel` chưa từng tồn tại và bỏ sót `stake`, cột mà v2 thật sự xóa.

Lấy lại lược đồ từ một máy đang cài bản cũ:

```bash
sqlite3 "$(xcrun simctl get_app_container booted space.subdock.subdock data)/Library/Application Support/subdock.sqlite" .schema
```

Sửa migration xong mà app vẫn lỗi như cũ thì gần như chắc chắn là do nạp lại nóng. Migration chỉ chạy đúng một lần, lúc `main()` mở cơ sở dữ liệu. Phím `r` không chạy lại `main()`, nên bản vá không có tác dụng gì lên kết nối đang mở. Phải `R` hoặc `q` rồi `flutter run` lại.

Lệnh này ghi đè `build/ios/iphonesimulator/Runner.app` bằng bản dựng riêng của test. Bản đó cần một kênh nối với trình chạy test, nên cài nó lên máy ảo rồi mở tay thì nó bật lên xong tắt ngay, trông y như app bị crash. Chạy `flutter test integration_test` xong mà muốn quay lại app thường thì phải build lại:

```bash
flutter build ios --simulator --debug
```

## 3. Cài lên iPhone thật

### 3.1. Chuẩn bị máy một lần

Trên iPhone, bật Chế độ nhà phát triển: **Cài đặt** › **Quyền riêng tư và bảo mật** › **Chế độ nhà phát triển**, bật lên rồi khởi động lại máy. Mục này chỉ xuất hiện sau khi đã cắm máy vào Xcode ít nhất một lần.

Cắm dây và mở khóa máy. Chọn Tin cậy khi iPhone hỏi.

```bash
flutter devices
```

Máy thật hiện ra kèm một chuỗi id dài, dạng `00008110-000C28AE0140401E`.

Kết nối không dây cũng được, nhưng chỉ sau khi đã cắm dây một lần và tick **Connect via network** trong Xcode. Lần cài đầu tiên nên cắm dây cho chắc.

### 3.2. Đặt team ký, một lần duy nhất

Dự án chưa đặt team, nên bước này bắt buộc và Xcode là chỗ duy nhất làm được:

```bash
open ios/Runner.xcworkspace
```

Trong Xcode:

1. Chọn dự án **Runner** ở cột trái.
2. Chọn target **Runner**, thẻ **Signing & Capabilities**.
3. Tick **Automatically manage signing**.
4. Ở **Team**, chọn tài khoản Apple của bạn. Chưa có thì bấm **Add an Account** và đăng nhập bằng Apple ID thường.

Nếu Xcode báo trùng Bundle ID với app của người khác, đổi nó thành một chuỗi riêng, ví dụ `space.subdock.subdock.tungns`. Sau đó khớp lại trong `ios/Runner.xcodeproj/project.pbxproj` để lần build sau bằng dòng lệnh không bị lệch.

Mở Runner.xcworkspace, không phải Runner.xcodeproj. Xcodeproj thiếu phần gói phụ thuộc.

### 3.3. Cài và chạy

```bash
flutter run -d <device-id> --release
```

Lần đầu chạy, iPhone sẽ từ chối mở app với thông báo về nhà phát triển chưa tin cậy. Vào **Cài đặt** › **Cài đặt chung** › **VPN và quản lý thiết bị**, chọn tên tài khoản của bạn, bấm **Tin cậy**. Chỉ phải làm một lần cho mỗi tài khoản.

Dùng `--release` cho bản để dùng thật: nó nhanh hơn hẳn bản `--debug` và không cần giữ kết nối với máy tính. Bản debug tắt máy tính là app treo.

Muốn cài mà không cần giữ cửa sổ dòng lệnh:

```bash
flutter build ipa --release          # tạo bản cài đặt
flutter install -d <device-id>       # cài bản vừa build
```

> **`flutter install` có thể xoá sạch dữ liệu trên máy.** Khi chữ ký hoặc bundle
> của bản đang có khác bản sắp cài, nó in `Uninstalling old version...` rồi gỡ app
> trước. iOS gỡ app là xoá luôn container của app, tức là mất `subdock.sqlite`.
> App này không có tài khoản và không có máy chủ, nên mọi thứ người dùng đã gõ vào
> nằm hết trong tệp đó và không lấy lại được từ đâu cả.
>
> Đây là chuyện đã xảy ra thật, trên máy thật, và mất hết dữ liệu.
>
> Cài lên **máy đang dùng hàng ngày** thì xuất dữ liệu ra trước (Settings › Backup ›
> Export a backup), hoặc dùng `flutter run -d <device-id>` để Xcode cài đè thay vì
> gỡ. Chỉ dùng `flutter install` khi mất dữ liệu trên máy đó là chuyện không sao.

**Máy khoá màn hình thì `flutter run` hỏng ở khâu cuối**, kèm một dòng lỗi không nói ra
lý do:

```
Could not run build/ios/iphoneos/Runner.app on <device-id>.
Try launching Xcode and selecting "Product > Run" to fix the problem
```

Thủ phạm thường là máy đang khoá chứ không phải bản build. Cài được vào máy khoá, nhưng
**mở app thì không**, và `flutter run` làm cả hai việc nên nó báo hỏng cả cụm. Qua wifi
thì còn dễ gặp hơn vì máy tự khoá trong lúc chờ build.

Tách hai việc ra để thấy rõ. Lệnh này cài đè, không gỡ gì cả, và chạy được cả khi máy
đang khoá:

```bash
flutter build ios --release --device-id <device-id>
xcrun devicectl device install app --device <device-id> build/ios/iphoneos/Runner.app
```

Rồi mở khoá máy và tự bấm vào app. Muốn mở bằng lệnh thì `xcrun devicectl device process
launch --device <device-id> space.subdock.subdock`, nhưng nó chỉ chạy khi máy đã mở khoá.

## 4. Nạp dữ liệu mẫu để xem giao diện

App mới cài thì trống, và màn hình đầu tiên là phần giới thiệu. Muốn xem danh sách với nội dung thật mà không phải gõ tay, ghi thẳng vào cơ sở dữ liệu của máy ảo:

```bash
DB=$(xcrun simctl get_app_container booted space.subdock.subdock data)/Library/Application\ Support/subdock.sqlite
xcrun simctl terminate booted space.subdock.subdock
sqlite3 "$DB" "INSERT OR REPLACE INTO itemRow
 (id, name, kind, categoryId, expiresOn, actByOffsetDays, anchorDate, cycle,
  amountMinor, currency, leadDays, remindAt, nagAfterDue, dateSource, state,
  createdAt)
 VALUES ('netflix','Netflix Premium','RECURRING','entertainment','2026-08-21',
  0,'2026-08-21','MONTHLY',260000,'VND','3','08:30','NONE','USER_ESTIMATED',
  'ACTIVE',1755000000);"
xcrun simctl launch booted space.subdock.subdock
```

Phải liệt kê tên cột. Bản trước của tài liệu này dùng `INSERT ... VALUES` không tên cột, và khi lược đồ đổi từ v1 sang v2 nó **không báo lỗi**: v2 bỏ một cột rồi thêm một cột khác, tổng vẫn 23, nên SQLite nhận đủ số giá trị và nhét lệch hết đi một nấc. Kết quả là `expiresOn` thành `'entertainment'` còn `repeatCount` thành `'MONTHLY'`. Một câu lệnh chạy xong không kêu ca gì mà dữ liệu thì sai.

Phải tắt app trước khi ghi. App theo dõi cơ sở dữ liệu qua luồng của riêng nó và không biết có ai sửa tệp từ bên ngoài, nên ghi lúc app đang chạy thì màn hình không cập nhật.

Cách này chỉ dùng để xem giao diện. Trên máy thật không làm được, và cũng không nên.

## 5. Thông báo, chỗ dễ hụt nhất

Ba tầng phải đúng cả ba thì lời nhắc mới tới. Hụt tầng nào cũng không có lỗi nào hiện ra.

### 5.1. Quyền, người dùng phải bấm đồng ý

App cố tình không hỏi quyền lúc mở lần đầu. Nó hỏi ở màn hình giới thiệu, sau khi đã nói rõ quyền đó để làm gì. Hỏi ngay lúc mở là cách nhanh nhất để bị từ chối vĩnh viễn.

Chưa cấp quyền thì app **không đặt lịch gì cả**. Nếu cứ đặt, thư viện vẫn nhận lệnh và im lặng bỏ hết, rồi bạn tưởng đã đặt xong.

Kiểm tra: **Cài đặt** › **Subdock** › **Thông báo**.

### 5.2. Máy ảo không nhận thông báo hẹn giờ đáng tin

Máy ảo có nhận thông báo, nhưng đồng hồ của nó theo đồng hồ máy tính và trạng thái ngủ khác máy thật. Muốn kiểm tra thật sự lời nhắc có tới không thì phải thử trên iPhone.

### 5.3. Mức ưu tiên Time Sensitive cần quyền riêng, hiện chưa có

Mục mức rủi ro cao đặt thông báo ở mức **Time Sensitive**, mức duy nhất lọt qua chế độ Tập trung và Không làm phiền. Đó là lời hứa cốt lõi của app: hạn mất số điện thoại phải xuyên qua được chế độ im lặng.

Mức này cần một entitlement tên `com.apple.developer.usernotifications.time-sensitive`. **Dự án hiện chưa khai entitlement đó.** Không có nó, iOS âm thầm hạ thông báo xuống mức thường. Không có lỗi, không có cảnh báo, chỉ là lời nhắc đến muộn hơn bạn tưởng.

Chưa khai là cố ý: entitlement này chỉ cấp cho tài khoản trả phí. Khai vào mà ký bằng tài khoản thường thì **build hỏng ngay ở bước ký**, tức là chặn luôn đường cài app.

Khi nào có tài khoản trả phí, bật nó lên như sau:

1. Mở `ios/Runner.xcworkspace`, thẻ **Signing & Capabilities**.
2. Bấm **+ Capability**, thêm **Time Sensitive Notifications**.
3. Xcode tự tạo `ios/Runner/Runner.entitlements` và tự khai vào dự án.
4. Cài lại app rồi kiểm chứng: bật chế độ Tập trung, đặt một mục mức rủi ro cao đến hạn trong vài phút, xem thông báo có xuyên qua không.

Bước 4 không bỏ được. Đây đúng là loại lỗi không tự báo, nên chỉ có cách thử tay mới biết.

## 5bis. Sao lưu lên Google Drive, chỉ Android

Hàng **Google Drive** trong Settings chỉ hiện khi bản build có client id của Google.
Không có nó thì `DriveBackup.isSupported` trả `false`, hàng đó biến mất, và app chạy y
như trước. Đó là chủ ý, để một checkout không có dự án Google đứng sau vẫn build được.

```bash
flutter run -d <android-device> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>
```

`<web-client-id>` là client id của **OAuth client kiểu Web**, không phải kiểu Android.
Bốn bước dựng nó nằm ở `docs/backup-and-sync.md` mục 6.2bis, kèm cái bẫy SHA-1 của Play
App Signing: khai thiếu dấu vân tay đó thì đăng nhập chạy ngon lúc tự thử và hỏng với
mọi người tải từ Store.

Lỗi cấu hình hiện ra dưới dạng một thông báo bắt đầu bằng `Không kết nối được tài
khoản`, kèm nguyên văn phần mô tả Google trả về. Đừng nuốt phần mô tả đó đi, nó là manh
mối duy nhất cho một lỗi không tái hiện được ở bàn làm việc.

## 6. Hạn chế của tài khoản Apple thường

Ký bằng Apple ID thường thì dùng được ngay, không mất tiền, nhưng kèm ba giới hạn thật:

| Giới hạn | Hệ quả |
|---|---|
| App hết hạn sau 7 ngày | Phải cài lại mỗi tuần, nếu không app không mở được nữa |
| Tối đa 3 app trên một máy | Cài app thứ tư thì phải gỡ bớt |
| Không có entitlement nâng cao | Time Sensitive không dùng được, xem mục 5.3 |

Giới hạn 7 ngày là cái đáng cân nhắc nhất với app này. Một app nhắc hạn mà tự nó hết hạn mỗi tuần thì đúng lúc bạn cần nó nhất lại là lúc nó không mở được. Nếu định dùng thật hàng ngày, tài khoản trả phí 99 đô một năm là khoản đáng bỏ ra, vì nó nâng hạn lên một năm và mở luôn Time Sensitive.

## 7. Gỡ rối

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `Target of URI doesn't exist: 'database.g.dart'` | Chưa sinh mã | `dart run build_runner build` |
| Xcode báo `Signing for "Runner" requires a development team` | Chưa đặt team | Mục 3.2 |
| iPhone báo nhà phát triển chưa tin cậy | Chưa tin cậy chứng chỉ | Mục 3.3 |
| Không thấy máy thật trong `flutter devices` | Chưa bật Chế độ nhà phát triển, hoặc máy đang khóa | Mục 3.1, mở khóa máy rồi thử lại |
| App mở được nhưng không có lời nhắc nào | Chưa cấp quyền thông báo | Mục 5.1 |
| Lời nhắc tới nhưng bị chế độ Tập trung chặn | Thiếu entitlement Time Sensitive | Mục 5.3 |
| Lời nhắc tới sai giờ, lệch đúng 7 tiếng | Bảng múi giờ không nạp được | Xem `NotificationScheduler._ensureTimezone` |
| Sửa `tables.drift` xong app chạy như cũ | Chưa sinh lại mã | `dart run build_runner build` |
| `SqliteException: no such column` lúc lưu | Migration thiếu khai báo cột mới | Xem mục Kiểm tra migration ở mục 2 |
| Sửa migration xong vẫn lỗi y hệt | Nạp lại nóng không chạy lại `main()` | `R`, hoặc `q` rồi `flutter run` lại |
| App bật lên rồi tắt ngay, không kịp thấy gì | Đang chạy bản dựng của integration test | `flutter build ios --simulator --debug` rồi cài lại |
| Build hỏng linh tinh sau khi đổi phụ thuộc | Bộ nhớ đệm cũ | `flutter clean && flutter pub get && dart run build_runner build` |

Xem log của app đang chạy trên máy thật:

```bash
flutter logs -d <device-id>
```

## 8. Trước khi phát hành

Chưa tới lúc, nhưng ghi lại để khỏi quên:

- [ ] Đổi Bundle ID sang chuỗi cuối cùng, hiện là `space.subdock.subdock`
- [ ] Thay biểu tượng app, hiện vẫn là biểu tượng mặc định của Flutter
- [ ] Bật entitlement Time Sensitive, mục 5.3
- [ ] Kiểm tra trên máy thấp nhất còn hỗ trợ, iOS 15
- [ ] Thử một vòng đủ: thêm mục, nhận lời nhắc, đánh dấu xong, xuất dữ liệu
