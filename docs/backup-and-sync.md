# Sao lưu và đồng bộ: quyết định và kế hoạch

> **Trạng thái 26/08/2026.** Bước 0 và Bước 1 đã được chốt là sẽ làm. Bước 2 để ngỏ,
> tài liệu này ghi lại lập luận để sau không phải bàn lại từ đầu.
>
> Phần xuất và nhập tệp bằng tay đã dựng xong ngày 25/08/2026. Bước 0 và Bước 1 dựng
> tiếp trên đó.

Tài liệu này ghi lại một cuộc thảo luận sau khi mất dữ liệu thật, và kế hoạch rút ra
từ đó. Nó dành cho người sẽ làm tiếp, và cho chính chúng ta trong sáu tháng nữa khi
câu hỏi "có nên bán tính năng sao lưu không" quay lại.

---

## 1. Chuyện đã xảy ra

Ngày 25/08/2026, khi đang kiểm chứng một bản sửa, lệnh `flutter install` được chạy lên
iPhone thật của chủ dự án. Lệnh đó in `Uninstalling old version...` rồi gỡ app trước khi
cài bản mới. iOS gỡ app là xoá container của app, nên `subdock.sqlite` biến mất.

App không có tài khoản, không có máy chủ, và lúc đó chưa có xuất dữ liệu. Không còn bản
sao nào. Khoảng ba mươi dịch vụ phải nhập lại bằng tay, trong đó có những mục phải **gọi
điện lên tổng đài nhà mạng** để hỏi lại ngày hết hạn.

Bản sao lưu iCloud của máy thì có chứa dữ liệu, vì `subdock.sqlite` nằm trong
`Application Support` (xem doc comment ở đầu `lib/data/connection.dart`). Nhưng iOS
không cho khôi phục riêng một app: muốn lấy lại phải xoá sạch máy rồi khôi phục toàn bộ
từ bản sao lưu, và mọi thứ khác trên máy cũng lùi về theo. Cái giá đó quá lớn nên phương
án này bị loại.

Ghi lại chi tiết này không phải để tự trách. Ghi vì nó là **bằng chứng thực nghiệm** cho
một rủi ro mà trước đó chỉ nằm trên giấy, và vì nó chỉ ra chính xác chỗ nào của đường
khôi phục là chỗ gãy.

---

## 2. Đặc tả đã gọi đúng chuyện này từ đầu

`docs/product-spec.md` mục **11.2 "Mất máy là mất dữ liệu"** viết:

> Nghiên cứu chỉ ra **mất dữ liệu tự gõ là lý do bỏ app số một** trong ngành này, kể cả
> với những app **có** đồng bộ. Một app không đồng bộ thì rủi ro còn cao hơn.

Rồi kết luận xuất và nhập thuộc **Bước 1**, không phải phần đánh bóng để sau. Lộ trình ở
mục 12 xếp nó vào Bước 1, kèm ghi chú giải thích vì sao nó được nâng lên khỏi vị trí ban
đầu.

Nó không được làm. Bốn gạch đầu dòng của 11.2, tình trạng tới hôm nay:

| Yêu cầu trong 11.2 | Tình trạng |
|---|---|
| Xuất ra JSON và CSV | JSON xong 25/08. **CSV chưa làm** |
| Sao lưu ghi ra tệp qua app Files, khôi phục lại được | Xong 25/08, đi qua sheet chia sẻ của hệ thống |
| Đường khôi phục phải được kiểm thử thật | Xong. `integration_test/backup_test.dart` chạy trên máy ảo thật |
| Xác nhận dữ liệu có nằm trong bản sao lưu thiết bị hay không, và **nói rõ trong giao diện** | **Chưa làm.** Đây là Bước 0 |

Gạch đầu dòng thứ tư là cái đáng chú ý nhất. Hôm 25/08 phải mở mã nguồn đọc comment mới
biết câu trả lời. Người dùng thì không có cửa đó.

CSV chưa làm và chưa quyết định có làm hay không. Xem mục 7.

---

## 3. Nguyên tắc dùng để quyết mọi thứ dưới đây

CLAUDE.md nói việc của app là **ngăn người dùng mất thứ họ không lấy lại được**.

Tới hôm nay, **chính app là nguồn mất mát lớn nhất trong lĩnh vực nó phụ trách**. Không
phải Netflix trừ tiền, không phải SIM bị khoá: là cái cơ sở dữ liệu chết mang theo ba
mươi cái hạn cùng một lúc. Đó không phải một lỗ hổng tính năng, đó là một mâu thuẫn nằm
trong chính sản phẩm.

Mọi lựa chọn dưới đây đo bằng một câu hỏi: **nó có làm app bớt trở thành nguồn mất mát
không.**

---

## 4. Đã dựng xong ngày 25/08

Để người đọc sau biết cái gì đã có mà không phải đi đọc mã nguồn:

| Thành phần | Việc |
|---|---|
| `lib/domain/backup.dart` | Định dạng tệp, Dart thuần, mã hoá và giải mã JSON |
| `lib/data/backup_store.dart` | Đọc cả cơ sở dữ liệu ra, và ghi đè cả cơ sở dữ liệu vào |
| `lib/platform/backup_files.dart` | Sheet chia sẻ và bộ chọn tệp của hệ thống |
| `lib/ui/widgets/restore_ask.dart` | Sheet xác nhận trước khi ghi đè |
| Settings, khối `BACKUP` | `Export a backup`, `Restore from a backup`, kèm một dòng chú thích |

Ba quyết định trong đó cần biết trước khi làm tiếp, chi tiết ghi ở bẫy số 26 trong
CLAUDE.md:

- Tệp sao lưu là bản chép của **model**, không phải bản dump SQLite. Đọc thiếu trường
  thì rơi về đúng mặc định một mục mới nhận được, nên tệp cũ vẫn khôi phục được vào bản
  app mới.
- Khôi phục là **thay**, không phải trộn. Nó dành cho người mất máy.
- Trên sheet xác nhận, nút tô đầy là nút **không** làm gì.

---

## 5. Bước 0: nói ra sự thật, ở đúng chỗ

Mục tiêu: người dùng biết mình đang tin vào cái gì, và người chưa từng nghĩ tới sao lưu
thì được nhắc mà không bị giảng.

### 5.1 Giọng: nói trạng thái, không đưa lời khuyên

Màn Reminders đã có luật này và Bước 0 theo đúng nó. Màn đó không dạy người dùng nên bật
thông báo, nó chỉ nói **"Notifications are off, so nothing is delivered."** Luật ghi
ngay trong `reminder_rules_screen.dart`: *only the state, never the tutorial*.

Áp vào đây: một dòng `Last backup` với giá trị thật, đứng cạnh một danh sách mười hai
mục, **chính là** lời cảnh báo. Không cần câu nào khuyên nhủ.

Dòng đó cũng vượt đúng ngưỡng CLAUDE.md đặt ra cho việc được nằm trên màn Settings: một
sự thật người dùng không thấy được ở bất kỳ đâu khác.

### 5.2 Bốn thay đổi

**a. Dòng `Last backup` trong khối `BACKUP`**

Giá trị là `Never`, hoặc ngày của lần xuất gần nhất. Không có mũi tên chỉ sang phải, vì
nó không dẫn đi đâu cả, giống Currency và Language ở khối trên.

Cần một khoá mới trong bảng `settingRow`, ghi lúc `BackupFiles.save` trả về `true`. Chỉ
ghi khi trả về `true`: người dùng đóng sheet mà không chọn chỗ nào thì không có tệp nào
ra khỏi máy, và ghi nhận lúc đó là nói dối.

**b. Dòng nói dữ liệu có nằm trong bản sao lưu của máy hay không**

Đây là gạch đầu dòng thứ tư của mục 11.2, phần chưa làm.

Câu trả lời **khác nhau giữa hai nền tảng**, nên chữ cũng phải khác nhau. Điều này nhìn
qua có vẻ trái với bẫy số 11 trong CLAUDE.md, cái bắt chữ trên giao diện không được nêu
tên nền tảng nào. Không trái. Bẫy 11 nói về **ngân sách 50 nhắc hạn**, một con số app
lấy từ iOS và không có căn cứ riêng cho Android, nên nêu tên nền tảng ở đó là tỏ ra biết
nhiều hơn mức thật. Ở đây thì sự thật thật sự khác nhau giữa hai hệ điều hành, và nói
khác nhau mới là nói đúng.

Người sửa sau đừng "sửa" chỗ này cho thống nhất với bẫy 11. Lý do nằm ở đây.

**c. Banner khi khoảng cách là thật**

Dùng `AlertBanner`, thành phần đã có sẵn trên màn Settings cho việc báo nhắc hạn bị bỏ
rơi. Hiện khi chưa từng sao lưu **và** danh sách đã đủ đắt để gõ lại.

Ngưỡng "đủ đắt" nên đo bằng **công sức phải bỏ ra để dựng lại**, không phải bằng số mục.
App đã có sẵn tín hiệu đó trong model: **`DateSource.userConfirmed`**. Một ngày mang
nhãn này là ngày người dùng đã đi hỏi nhà cung cấp để có, tức là đúng bằng một cuộc gọi
tổng đài. Ba ngày `userConfirmed` nghĩa là gõ lại tốn ba cuộc gọi.

Ngưỡng cụ thể còn để ngỏ, xem mục 8.

**d. Đường khôi phục ở màn hình khi chưa có gì**

> **Đã dựng rồi bỏ đi.** Onboarding từng có một lối thứ hai, chữ mờ dưới nút chính,
> đại ý *"I already have a backup"*, chạy thẳng vào cùng đường nhập tệp mà Settings
> gọi. Bản onboarding dựng lại theo design mới bỏ nó, theo yêu cầu của chủ dự án, và
> mục này ở lại để người đọc sau biết cái nút đó đã từng có và vì sao nó đáng có.

Lập luận cũ vẫn đúng nguyên: khoảnh khắc người ta cài lại app chính là khoảnh khắc họ
cần khôi phục, mà đường đó nay lại nằm trong Settings, sau một màn giới thiệu nói về
chuyện thêm mục mới. Ai muốn dựng lại thì nút cũ nằm trong lịch sử git, và chỗ đặt nó
là dưới nút chính của màn thứ hai.

### 5.3 Một việc dứt khoát không làm

**Không tiêu một suất nào trong ngân sách 50 thông báo để nhắc chuyện sao lưu.** Ngân
sách đó thuộc về cái SIM của người dùng, không thuộc về việc nội bộ của app. Lý do đầy
đủ nằm ở doc comment của `NotificationPlanner` và ở mục 7.3 của đặc tả sản phẩm.

### 5.4 Thời điểm hỏi, nếu sau này muốn chủ động hỏi

Không nằm trong Bước 0, ghi lại vì đã bàn tới.

App đã có một chỗ làm đúng việc này và làm tốt: sheet `NotificationAsk`. Doc của nó
viết *"The timing is the whole feature"*. Nó không hỏi quyền lúc khởi động, nó hỏi ngay
sau khi người dùng vừa gõ một cái ngày họ sợ quên, tức là lúc câu trả lời dễ là "có"
nhất.

Nếu sau này muốn hỏi chủ động về sao lưu thì hỏi theo cùng cách đó, nhưng **không hỏi ở
mục đầu tiên**: lúc đó chưa có gì để mất, và nó giẫm chân lên lời hỏi quyền thông báo,
cái mà iOS chỉ cho hỏi đúng một lần.

---

## 6. Bước 1: tự động sao lưu lên cloud của chính người dùng

Đây là phương án nằm giữa "xuất tệp bằng tay" và "dựng máy chủ của mình", và nó là thứ
thật sự chữa được chỗ đau.

Ý tưởng: app tự ghi tệp sao lưu lên kho đám mây **của chính người dùng**, cái họ đã đăng
nhập sẵn ở tầng hệ điều hành. Không tài khoản, không máy chủ, không hoá đơn hạ tầng,
không có kho dữ liệu tập trung nào để bị tấn công, và nó chạy mà không cần ai nhớ bấm gì.

### 6.1 iOS: đã dựng ngày 26/08/2026

Chỗ vướng hôm 25/08 rất cụ thể: dữ liệu **có** trong bản sao lưu iCloud của máy, nhưng
iOS không cho khôi phục riêng một app.

Cách gỡ là ghi một tệp vào **iCloud Drive container của chính app**, để nó là một tệp
độc lập lấy lại được riêng, thay vì một mẩu chìm trong bản sao lưu cả máy.

Đã làm:

- `ios/Runner/Runner.entitlements` khai container `iCloud.space.subdock.subdock`, và
  `CODE_SIGN_ENTITLEMENTS` được thêm vào cả ba cấu hình của target Runner.
- Gói `icloud_storage_plus`, bọc sau `lib/platform/cloud_backup.dart` để đổi được về
  sau. Lớp bọc đó đã trả công một lần: gói đầu tiên dùng là `icloud_storage`, và thay
  nó không đụng tới dòng nào ngoài chính tệp ấy.
- Ghi tự động sau mỗi thay đổi dữ liệu, hoãn 12 giây, và đẩy đi ngay khi app chuyển
  xuống nền.
- Dòng `iCloud` trên màn Settings nói ra trạng thái thật của lần ghi gần nhất.

**Ký thành công không có nghĩa entitlement vào được.** Ký tự động có thể lặng lẽ bỏ một
entitlement mà hồ sơ cấp phép không có, và build vẫn xanh. Cách kiểm duy nhất là đọc chữ
ký của bản đã dựng:

```bash
codesign -d --entitlements :- build/ios/iphoneos/Runner.app
```

Ba khoá `icloud-container-identifiers`, `icloud-services` và `ubiquity-container-identifiers`
phải nằm trong đó. Ngày 26/08 đã kiểm và có đủ.

**Khôi phục: một chạm, và đó là bản sửa cho một lỗi đã lộ ra.**

Bản đầu chỉ có ghi lên, còn lấy về thì bắt người dùng tự vào app Files tìm tệp. Thử trên
máy thật xong, câu hỏi đầu tiên của chủ dự án là *"iCloud: Saved, nhưng restore thế
nào?"*. Câu hỏi đó chính là lỗi: app nói nó đã cất, mà không nói được cất ở đâu và lấy
lại kiểu gì, đúng cái kiểu tỏ ra chắc chắn hơn mức nó giúp được.

Nên `CloudBackup` có thêm `latest()`, và giao diện có **hai dòng riêng** thay vì một dòng
tự đoán nguồn:

| Dòng | Nguồn |
|---|---|
| `Restore from iCloud` | Tệp app tự giữ. Chỉ hiện khi nền tảng có cloud |
| `Restore from a file` | Tệp người dùng tự chọn. Tên rút về `Restore from a backup` khi không có dòng trên, vì lúc đó không có gì để phân biệt |

Hai dòng chứ không phải một, vì **cả hai đều xoá đúng những hàng như nhau**, nên thứ
người dùng phải chắc chắn trước khi bấm là *bản nào*. Một dòng lặng lẽ ưu tiên một nguồn
là quyết định hộ họ. Cả hai đi qua cùng một `_restoreFrom`, nên chúng hỏi cùng một câu
hỏi và không thể mọc ra hai cảnh báo khác nhau.

Màn hình khi chưa có gì thì ngược lại: **một nút**, tìm iCloud trước rồi mới rơi xuống bộ
chọn tệp. Ở đó không có danh sách nào để mất, nên đoán đúng nguồn khả dĩ nhất là tiết
kiệm cho người đang vội một quyết định.

`Info.plist` vẫn đặt `NSUbiquitousContainerIsDocumentScopePublic` để thư mục Subdock hiện
trong app Files. Giờ nó không còn là đường khôi phục duy nhất nữa, nhưng vẫn đáng giữ:
**người dùng nhìn thấy tệp sao lưu của chính mình** nên tin được là nó có thật. Một bản
sao lưu không ai kiểm tra được là bản sao lưu chỉ phát hiện ra là rỗng vào đúng hôm cần
tới nó.

Một chi tiết của plugin phải nhớ: hỏi xem tệp có trên iCloud không thì phải hỏi metadata
query bằng `gather`, không hỏi hệ thống tệp bằng `listContents` hay `getItemMetadata`.
Người mở màn khôi phục thường vừa cài lại máy, mà trên máy chưa từng thấy container thì
tệp mới chỉ là một lời hứa metadata query biết còn hệ thống tệp thì chưa. Đọc nội dung
bằng `readInPlace`, ghi bằng `writeInPlace`, cả hai đi qua `UIDocument` nên không cần tệp
tạm. Timeout 20 giây vẫn giữ, vì một lần mở có phối hợp trên tệp máy chưa tải về sẽ nằm
chờ iCloud giao dữ liệu. Đầy đủ ở bẫy 48 trong CLAUDE.md.

**Hệ quả lên cách build:** `icloud_storage_plus` là Swift Package, nên cảnh báo SPM cũ đã
hết và mọi plugin iOS của dự án nay đều là Swift Package. Dự án vẫn còn tích hợp
CocoaPods; xem `docs/running.md` mục 1.

### 6.2 Android: đã chốt Drive App Data, dựng ngày 28/08/2026

CLAUDE.md bắt buộc hỏi: **nền tảng kia làm việc này thế nào, và nếu nó không làm được
thì giao diện có nói ra không.**

Android có hai đường, và đã chọn đường thứ hai:

| Đường | Được | Mất |
|---|---|---|
| Auto Backup for Apps | Gần như miễn phí, chỉ một cờ trong manifest | Mờ đục. Chạy khi máy đang sạc, đang rảnh, có wifi. App không kiểm được nó đã chạy chưa, không gọi nó chạy được, và chỉ trả dữ liệu lúc cài lại app. Giới hạn dung lượng |
| Drive App Data folder | Chắc chắn, kiểm được, ghi ngay sau mỗi thay đổi, khôi phục lúc nào cũng được | Cần đăng nhập Google một lần |

Auto Backup vẫn bật, nó không bị bỏ đi. Nhưng nó không còn là câu trả lời của app cho
câu hỏi "danh sách của tôi có an toàn không", vì app không nhìn thấy nó. Chú thích dưới
card sao lưu vì thế đã đổi giọng: nó nói bản sao lưu của máy có tồn tại và app không
can thiệp vào, thay vì than rằng app không kiểm được. Hai câu chuyện sao lưu cạnh nhau
mà một câu lấp lửng thì người đọc tin câu tệ hơn.

**Chuyện tài khoản không phải ngoại lệ so với nguyên tắc.** Nguyên tắc là *Subdock*
không có tài khoản và không có máy chủ. Bản iOS đã ghi vào iCloud của chính người dùng,
tức là tài khoản Apple của họ; Drive App Data là đúng chuyện đó phía Android, chỉ khác
ở chỗ Apple giao container mà không hỏi còn Google thì hỏi một lần.

#### Ba điều kiện đã kiểm trước khi làm

1. **Scope `drive.appdata` thuộc nhóm non-sensitive.** Trang scope của Drive API xếp nó
   vào mục khuyến nghị, và nó không có tên trong danh sách restricted. Nghĩa là không
   phải nộp app cho Google duyệt, không có khoản đánh giá an ninh hằng năm, và **không
   có màn hình "Google chưa xác minh ứng dụng này"** trước mặt người dùng. Mở rộng scope
   sang `drive.file` hay `drive` là vứt cả ba thứ đó đi.
2. **`google_sign_in_ios` có `Package.swift`**, nên thêm thư viện này không kéo
   CocoaPods quay lại, tức là không phá công cuộc ở bẫy 48. Đã kiểm trong
   `flutter/packages`, và issue flutter/flutter#146904 đã đóng từ 2/2025.
3. **Cấu hình phía Google Cloud Console** là phần phiền nhất, xem mục 6.2bis.

### 6.2bis Cấu hình phải làm bên Google Cloud Console

Không làm phần này thì `DriveBackup.isSupported` trả `false`, hàng Google Drive không
hiện ra, và app chạy y như trước. Đó là chủ ý: một checkout không có dự án Google đứng
sau vẫn build được và vẫn chạy được.

1. Tạo một dự án trên Google Cloud Console, bật **Google Drive API**.
2. Dựng màn hình đồng ý (OAuth consent screen), thêm scope
   `https://www.googleapis.com/auth/drive.appdata`, rồi **chuyển trạng thái sang
   Production**. Để ở Testing thì trần cứng 100 tài khoản, bất kể scope loại gì.
3. Tạo một **OAuth client kiểu Web**. Chuỗi client id của nó là giá trị truyền vào
   `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. Của dự án này là:

   ```
   1014667804289-k3atk3dlklg5fbioc1p1h9urp6koavsm.apps.googleusercontent.com
   ```

   Chuỗi này **không phải bí mật**, nên để trong repo là được. Nó nằm sẵn trong mọi bản
   app đã phát hành và ai cũng đọc ra được. Thứ phải giữ kín là **client secret** đứng
   cạnh nó trong Console, chuỗi bắt đầu bằng `GOCSPX`. App này không dùng tới nó và nó
   không được phép xuất hiện ở đâu trong repo.
4. Tạo một **OAuth client kiểu Android** cho mỗi dấu vân tay SHA-1, và phải đủ ba:
   - keystore debug của từng máy dev,
   - khoá dùng để đóng gói bản phát hành,
   - **khoá do Google Play tạo ra** (Play App Signing).

   Cái thứ ba là cái bẫy. Play ký lại app bằng khoá riêng của nó trước khi giao tới máy
   người dùng, nên dấu vân tay của bản người dùng cài về khác với dấu vân tay trên máy
   bạn. Thiếu nó thì đăng nhập chạy hoàn hảo suốt lúc tự thử và **hỏng với toàn bộ
   người tải từ Store**, mà không tái hiện được ở nhà. Lấy chuỗi đó trong Play Console,
   mục Setup rồi App integrity.

Chạy thử:

```bash
flutter run -d <android-device> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1014667804289-k3atk3dlklg5fbioc1p1h9urp6koavsm.apps.googleusercontent.com
```

Lỗi cấu hình quay về dưới dạng `GoogleSignInException` mã `clientConfigurationError`, và
`DriveBackup._fromSignIn` **giữ nguyên phần mô tả** thay vì nuốt đi, đúng vì lý do ở
trên: đó là manh mối duy nhất cho một lỗi không tái hiện được ở bàn làm việc.

Thêm một việc hành chính: biểu mẫu Data Safety trên Play Console nay phải khai app có
đăng nhập bằng tài khoản Google.

### 6.3 Đã quyết trong lúc dựng

- **Ghi lúc nào:** hoãn 12 giây sau thay đổi cuối, và đẩy đi ngay khi app xuống nền. Mỗi
  ký tự gõ vào ô ghi chú là một lần ghi cơ sở dữ liệu nên là một sự kiện stream; ghi
  từng cái là tiêu pin và dữ liệu của người dùng cho ba mươi bản sao của một câu đang
  được gõ dở. Lúc rời app mới là lúc chắc chắn họ đã ngừng sửa.
- **Giữ bao nhiêu bản:** một, ghi đè. Container hiện ra trong app Files, và một thư mục
  mọc thêm một tệp mỗi lần người dùng sửa một mục là thư mục họ sẽ xoá vì bực. Bản có
  ngày tháng là bản họ tự lưu qua sheet chia sẻ.
- **Chỉ ghi khi ghi được:** `last_backup_on` chỉ được cập nhật khi lần ghi thật sự
  thành công. Ghi nhận cho một lần tải lên hỏng là đặt một cái ngày dưới `Last backup`
  và gỡ cảnh báo khỏi màn hình, cho một tệp không tồn tại.
- **Bật Drive trên một danh sách rỗng phải nhìn trước khi ghi.** Người mở màn này với
  danh sách rỗng gần như luôn là người vừa cài lại máy, tức là đúng người đang có một
  bản sao nằm trên đó. Kết nối rồi ghi ngay là ghi đè bản sao đó bằng danh sách rỗng,
  bằng chính cú bấm họ làm để tự bảo vệ mình, và không có gì để lùi lại. Luật nằm ở
  `_connectCloud` trong `app.dart`: rỗng thì đọc trước, có bản sao thì chuyển sang
  đường khôi phục kèm sheet xác nhận, và **từ chối khôi phục cũng không ghi gì**, vì
  "không muốn lấy lại danh sách cũ" không phải là "vứt nó đi".

Còn để ngỏ:

- Xung đột. Hai máy cùng ghi vào một tệp thì xử lý ra sao. Đây là mầm mống của bài toán
  đồng bộ, và là chỗ Bước 1 dễ trượt thành Bước 2 lúc nào không hay. Ranh giới phải giữ:
  **Bước 1 là sao lưu một chiều, không phải đồng bộ hai chiều.** `CloudBackup` chỉ có
  `save`, không có `read`, đúng vì lý do này.

---

## 7. Bước 2 để ngỏ, và vì sao không bán tính năng sao lưu

Chưa làm. Ghi lại lập luận ở đây để lần sau khỏi bàn lại.

### 7.1 Bán bảo hiểm cho chính lỗi của mình là sai giọng

Nếu sao lưu là tính năng trả phí thì lời chào của bản miễn phí trở thành: "dữ liệu của
bạn có thể bay mất, trả tiền đi thì nó không bay." Với một app mà nguyên tắc xuyên suốt
là **không tỏ ra chắc chắn hơn mức thật**, cái giọng đó lạc điệu.

Sao lưu qua cloud của chính người dùng thì không tốn của dự án đồng nào, nên không có
sức ép kinh tế nào bắt phải thu tiền cho nó.

### 7.2 Máy chủ biến kho dữ liệu thành thứ đáng bị lấy cắp

Lược đồ đã có sẵn một câu trả lời cho chuyện này. Bảng `paymentSourceRow` cố ý không lưu
số thẻ, và comment ghi lý do:

> Storing a PAN would turn an offline, accountless app into something worth stealing.

Một máy chủ làm đúng việc đó với **toàn bộ kho dữ liệu**, kể cả khi trong đó không có số
thẻ nào. Danh sách ai đăng ký dịch vụ gì, hết hạn ngày nào, thẻ nào trả tiền, là dữ liệu
nhạy cảm.

### 7.3 Cái giá vận hành không dừng ở hoá đơn máy chủ

Đăng nhập, quên mật khẩu, xoá tài khoản theo yêu cầu, mã hoá khi lưu, và **giải quyết
xung đột đồng bộ**, thứ chắc chắn xảy ra vì app này chạy ngoại tuyến trước rồi mới nghĩ
tới mạng. Đó là trách nhiệm nhận vào thì vĩnh viễn không bỏ xuống được.

Mã hoá đầu cuối, tức là máy chủ chỉ giữ bản đã mã hoá và không có khoá, là cách làm tử
tế nếu đi đường này. Nhưng khi đó mất passphrase là mất dữ liệu, và đó là ác mộng hỗ trợ
với khách đã trả tiền.

### 7.4 Nếu thu phí thì bán cái khác

**Sao lưu miễn phí. Bán đồng bộ nhiều máy và chia sẻ danh sách.**

Đồng bộ và chia sẻ là thứ khác hẳn: nó **thêm năng lực** chứ không **gỡ rủi ro**, nó
thật sự cần máy chủ, và thu tiền cho nó là sòng phẳng. Lộ trình ở mục 12 của đặc tả vốn
đã xếp "Đồng bộ nhiều máy, chia sẻ" ở Bước 5, kèm điều kiện *chỉ làm nếu sau vài tháng
dùng thật vẫn thấy thiếu*.

### 7.4bis Đối chứng thị trường: SubReady, ra mắt 26/08/2026

Một app cùng loại vừa lên, và nó thu phí gần đúng vào chỗ mục 7.1 nói là không nên.
Ghi lại vì đây là dữ liệu thật, không phải suy đoán.

**SubReady Pro, 199.000 đồng, mua một lần chứ không phải thuê bao.** Ba dòng trên trang
bán:

| Dòng | So với khuyến nghị ở đây |
|---|---|
| Unlimited subscriptions | Không bàn tới. Xem bên dưới, đây mới là dòng đáng lo nhất |
| iCloud sync across devices | **Đúng bằng thứ mục 7.4 khuyên nên bán** |
| CSV export and advanced tools | Chạm vào lằn ranh của mục 7.1 |

Ba điều rút ra:

**Một. Dòng thứ hai là khuyến nghị của tài liệu này, không phải phản ví dụ.** Họ bán
đồng bộ. Và họ bán đồng bộ chạy trên iCloud **của chính người dùng**, tức là đúng cách
làm của Bước 1 ở mục 6, nên nó không đẻ ra hoá đơn hạ tầng nào. Đây là lý do họ tính
được giá mua một lần thay vì thuê bao: thứ họ bán không tốn của họ chi phí chạy hằng
tháng. Cách định giá đó đáng học.

**Hai. Dòng thứ ba chưa kết luận được từ một tấm ảnh.** Ảnh chụp là trang bán, nó không
cho biết bản miễn phí có đường lấy dữ liệu ra hay không. CSV và một bản sao lưu khôi
phục được là hai thứ khác nhau: CSV để đổ vào bảng tính mà đọc, hầu như không app nào
khôi phục lại được từ CSV. Nếu bản miễn phí của họ vẫn có một đường sao lưu khôi phục
được thì họ đang bán tiện lợi, không bán bảo hiểm, và mục 7.1 không bị phản bác.

Muốn kết luận thì phải đi xem bản miễn phí của họ. Chưa làm.

**Ba. Dòng thứ nhất mới là dòng đáng lo, và tài liệu này chưa từng bàn tới nó.** Giới hạn
số mục ở bản miễn phí là cách thu tiền phổ biến nhất và hiệu quả nhất trong loại app này.
Nhưng đặt vào Subdock thì nó nói: *bạn chỉ được phép chống mất mát tới mức này thôi, muốn
chống nữa thì trả tiền*. Với một app mà luận điểm gốc là một cái SIM hết hạn làm mất số
điện thoại dùng mười năm, chặn số mục còn lạc điệu hơn cả bán tính năng sao lưu.

### 7.4ter Lằn ranh, viết lại cho chặt

Đối chứng ở trên buộc phải nói chính xác hơn mục 7.1. Lằn ranh không phải "sao lưu thì
miễn phí, mọi thứ khác thì thu tiền". Nó là:

> **Bản miễn phí không bao giờ được để người dùng ở tình trạng dữ liệu chỉ còn lấy lại
> được nhờ may mắn.** Phải có ít nhất một đường lấy dữ liệu ra, đầy đủ và khôi phục
> được, không mất tiền.

Trên lằn ranh đó thì thu tiền thoải mái: CSV để đổ vào bảng tính, đồng bộ nhiều máy,
chia sẻ, tự động hoá. Cách phát biểu này cho phép bán gần hết những gì SubReady đang bán,
mà không phải nói cái câu ở mục 7.1.

Giới hạn số mục thì nằm **dưới** lằn ranh, vì mục thứ sáu không nhập được là một cái hạn
không ai nhắc. Đó là một quyết định riêng, cần chốt riêng, chưa chốt.

### 7.5 Một câu hỏi phải trả lời trước khi đi đường thu phí

Mục 13 của đặc tả đã ghi: **StoreKit 2 chỉ có API Swift**, Kotlin không gọi được, và
quyết định có bán gói trả phí hay không sẽ đổi cấu trúc dự án. Dự án nay chạy Flutter
trên hai nền tảng, nên câu hỏi đó còn nguyên và còn khó hơn.

---

## 8. Đang để ngỏ

- ~~**Ngưỡng hiện banner.**~~ **Chốt 26/08/2026:** hiện khi chưa từng sao lưu và có ít
  nhất **một** mục mang `DateSource.userConfirmed`. Không dùng ngưỡng theo số mục. Lý do
  giữ đúng lập luận ở mục 5.2c: đo bằng công sức dựng lại, và một ngày đã đi hỏi nhà
  cung cấp là một cuộc gọi tổng đài.
- **Chữ tiếng Anh cho từng dòng mới.** Chưa viết.
- **Android đi Auto Backup hay Drive App Data folder.** Xem 6.2.
- **CSV.** Mục 11.2 yêu cầu cả JSON lẫn CSV. JSON đã có. CSV chưa làm, và chưa rõ ai cần
  nó: JSON đọc được bằng mắt, còn CSV thì không chứa nổi lịch sử thanh toán và các nhóm
  trong cùng một tệp phẳng. Cần quyết định là làm, hay là sửa mục 11.2 cho khớp thực tế.
- ~~**Nhập thêm mà không xoá.**~~ **Chốt 26/08/2026: không làm bây giờ.** Chủ dự án tự
  gõ lại ba mươi mục nên không cần trộn. Nhập giữ nguyên nghĩa thay toàn bộ, đúng với
  việc nó sinh ra để làm. Mở lại nếu sau này có người thật cần ghép hai danh sách.
- **Giới hạn số mục ở bản miễn phí.** Chưa chốt. Xem mục 7.4bis.

---

## 9. Việc còn dang dở ngay bây giờ

**Nhập lại ba mươi mục: chủ dự án tự gõ.** Chốt 26/08/2026. Không cần chế độ nhập thêm,
và nhập giữ nguyên nghĩa thay toàn bộ.

Một điều phải nhớ khi gõ: ngày lấy được từ tổng đài nhà mạng là
`DateSource.userConfirmed`, không phải `userEstimated`. Đó là thứ mạnh nhất app dám nói
về một ngày, và nó cũng là thứ quyết định banner ở mục 5.2c có hiện hay không.

**Bản trên máy chủ dự án vẫn là bản cũ**, chưa có nút xuất dữ liệu lẫn nút gửi thông báo
thử. Phải cài bản mới trước khi nhập lại, và phải cài bằng `flutter run`, đường cài đè.
Xem cảnh báo ở mục 3.3 của `docs/running.md`.
