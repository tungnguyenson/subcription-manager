# Link "mở trang quản lý": nghiên cứu

Ngày khảo sát: **2026-08-23**. Mọi kết luận dưới đây gắn với ngày này. Mã USSD và
đường dẫn billing đổi khá thường xuyên, nên đọc lại phần "Bằng chứng" trước khi tin.

## Vì sao có tài liệu này

`DateSource` trong `lib/domain/model.dart` nói thẳng: app không đọc được hồ sơ bên
nhà cung cấp, chỉ biết những gì người dùng gõ vào. Một ngày ở mức
`USER_ESTIMATED` chỉ lên được `USER_CONFIRMED` khi người dùng tự đi xem hồ sơ thật.

Việc app làm được là **rút ngắn quãng đường đó xuống một cú chạm**. Không phải
đồng bộ dữ liệu, chỉ là đưa người dùng tới đúng chỗ có con số thật.

Hai loại "đúng chỗ" khác nhau về bản chất:

| | Dịch vụ web/app | SIM trả trước |
|---|---|---|
| Đích đến | một URL | một mã bấm trên máy, hoặc app nhà mạng |
| Rủi ro nếu quên | mất tiền, mất quyền dùng | **mất số** |
| Mở được từ app? | có, `https://` | **không, trên iOS** (xem §1.3) |

---

# 1. SIM trả trước Việt Nam

## 1.1 Vì sao phần này quan trọng nhất

Với gói streaming, quên hạn thì tệ nhất là bị trừ tiền hoặc mất quyền xem. Với SIM
trả trước, quá hạn đủ lâu là **số bị thu hồi**, mất luôn cái số đã dùng để nhận OTP
ngân hàng, đăng nhập Zalo, khai báo với cơ quan nhà nước. Đây đúng là trường hợp
app này tồn tại để cứu.

Ví dụ chính sách của Wintel (nguồn chính thức, xem §1.4): thuê bao phát sinh cước
sau 22/09/2023 chỉ có **35 ngày** sử dụng kể từ lần phát sinh. Hết hạn thì khoá một
chiều 5 ngày, khoá hai chiều 5 ngày, rồi **thu hồi số**. Tổng cộng khoảng 45 ngày
im lặng là mất số.

## 1.2 Bảng mã và trạng thái xác minh

Chú ý cột **Mức bằng chứng**:

- **A**: trang chính thức của nhà mạng ghi rõ.
- **B**: trang trên tên miền chính thức nhưng là blog marketing của đơn vị thành
  viên (ví dụ `giaiphapsohanoi.mobifone.vn`), không phải trang hỗ trợ chuẩn.
- **C**: chỉ có nguồn bên thứ ba (báo công nghệ, đại lý SIM). **Chưa đủ để ghi vào
  app.**

| Nhà mạng | Mã kiểm tra tài khoản chính + HSD | App chính chủ (App Store ID đã xác minh) | Mức bằng chứng |
|---|---|---|---|
| Viettel | `*101#` (xem cảnh báo §1.5); SMS `TK` gửi `191` | My Viettel, `1014838705` | C cho USSD, C cho SMS |
| VinaPhone | `*101#` | My VNPT, `1017188399` | C |
| MobiFone | `*101#` | My MobiFone, `719320091` | B |
| Vietnamobile | `*101#` | Vietnamobile, `1661082542` | B |
| iTel | `*101#`; SMS `TTTB` gửi `1414` (thông tin thuê bao) | My iTel, `1610306087` | C cho USSD, B cho SMS |
| Wintel | `*102#` (tài khoản khuyến mãi, **không phải** tài khoản chính) | Wintel 055, `1495002378` | A cho `*102#` |
| VNSKY | `*101#` | VNSKY, `6446885068` | C |

**App Store ID là mức A.** Lấy trực tiếp từ iTunes Search API của Apple
(`https://itunes.apple.com/search?term=...&country=vn&entity=software`), đối chiếu
tên nhà phát hành:

| App | ID | Bundle ID | Nhà phát hành |
|---|---|---|---|
| My Viettel | 1014838705 | `com.viettel.ttnd.vietteldiscovery` | Viettel Corporation |
| My VNPT | 1017188399 | `com.vnp.myvinaphone` | VNPT Media Corporation |
| My MobiFone | 719320091 | `vms.com.MyMobifone` | VietNam Mobile Telecom Service |
| Vietnamobile | 1661082542 | `com.vietnamobile.vietnamobile` | Vietnamobile Telecommunications JSC |
| My iTel | 1610306087 | `itelecom.vn.myitel` | Indochina Telecom Mobile JSC |
| Wintel 055 | 1495002378 | `com.mbc.reddi` | Mobicast Joint Stock Company |
| VNSKY | 6446885068 | `vn.vnsky.myvnsky` | Digilife Viet Nam |

Đường dẫn mở app: `https://apps.apple.com/vn/app/id<ID>`. Đây là universal link:
nếu app đã cài, iOS mở thẳng app; nếu chưa, mở App Store.

### Điều chưa xác minh được

Website của **cả bảy nhà mạng** đều render bằng JavaScript hoặc chặn bot.
`wintel.vn` trả 403 qua Cloudflare, `viettel.vn` trả về khung HTML rỗng 177 byte.
Không lấy được nội dung trang hỗ trợ bằng `curl` hay WebFetch. Vì vậy phần lớn mã
USSD chỉ đạt mức C.

**Đề xuất:** trước khi ship, mở từng trang hỗ trợ bằng trình duyệt thật rồi nâng
mức bằng chứng lên A. Đây là loại dữ liệu mà đoán sai thì người dùng bấm một mã vô
nghĩa và mất niềm tin vào app.

## 1.3 iOS chặn USSD, đây là kết luận cứng chứ không phải phỏng đoán

Apple ghi rõ trong tài liệu `PhoneLinks`:

> "To prevent users from maliciously redirecting phone calls or changing the
> behavior of a phone or account, the Phone app supports most, but not all, of the
> special characters in the `tel` scheme. Specifically, if a URL contains the `*`
> or `#` characters, the Phone app does not attempt to dial the corresponding
> phone number."

Ba hệ quả, theo thứ tự cần biết:

**a) Không có cách nào bấm USSD từ app iOS.** Không phải "khó", mà là chặn có chủ
đích ở tầng hệ điều hành. Cả `*` lẫn `#` đều đủ để Phone app từ chối quay số.

**b) `%23` không cứu được.** Percent-encode làm `canOpenURL:` trả về `true`, nên
code trông như chạy được, nhưng Phone app vẫn không mở trình quay số. Đây là cái
bẫy tệ nhất: hàm báo thành công, người dùng không thấy gì xảy ra, và không có log
lỗi nào. Diễn đàn Apple Developer có nhiều luồng về đúng chuyện này (thread
`701865`, `749906`, `14766`, `22114`).

**c) `url_launcher` không thay đổi được gì.** Package này gọi
`UIApplication.openURL:options:completionHandler:`, cùng con đường mà Phone app
đang chặn. Không có cờ, không có tuỳ chọn nào đi vòng được. Các issue trên repo
flutter (`#36634` xin thêm "immediate dial", `#169749`, `#89543`) đều dừng ở đó.

> Nếu vẫn muốn thử `tel:` trên iOS cho trường hợp khác: `#` **phải** viết là `%23`,
> vì `#` thô cắt URL thành fragment và phần sau bị bỏ. Nhưng với USSD thì encode
> hay không cũng vậy, đều không quay số.

### Android thì khác, và khác đủ để đáng ghi chú

- `tel:` với `%23` mở trình quay số **đã điền sẵn mã**, người dùng bấm nút gọi.
  Đây đã là cải thiện thật so với gõ tay.
- Từ Android 8.0 có `TelephonyManager.sendUssdRequest()`: gửi USSD và **nhận kết
  quả ngay trong app**, cần quyền `CALL_PHONE`. Về lý thuyết app đọc được ngày hết
  hạn rồi tự điền vào `USER_CONFIRMED`.

Nhưng dự án này làm **iOS trước**. Xây một luồng USSD chỉ chạy trên Android nghĩa
là hai trải nghiệm khác hẳn nhau cho cùng một mục SIM. Chưa nên làm bây giờ.

## 1.4 Phương án cho iOS: chép mã rồi mở app nhà mạng

Không quay số được thì bỏ tham vọng "một chạm là xong", làm cho tử tế cái còn lại:

1. **Nút chính, "Mở app <nhà mạng>":** universal link
   `https://apps.apple.com/vn/app/id<ID>`. Đây là đường dẫn duy nhất trong phần SIM
   đạt mức bằng chứng A, và nó dẫn tới nơi có con số thật.
2. **Nút phụ, "Chép mã `*101#`":** đưa mã vào clipboard kèm toast
   *"Đã chép. Mở bàn phím gọi rồi dán."* Người dùng vẫn phải qua app Phone, nhưng
   không phải nhớ mã và không gõ nhầm.
3. **Sau khi quay lại app**, hỏi thẳng: *"Hạn dùng là ngày nào?"* rồi ghi
   `USER_CONFIRMED`. Đây mới là chỗ app kiếm được giá trị: bắt lấy con số ngay lúc
   người dùng vừa nhìn thấy nó.

Không bọc bước (2) trong hộp thoại giải thích vì sao iOS không quay số được. Người
dùng không quan tâm chính sách của Apple; họ quan tâm cái mã.

## 1.5 Cảnh báo về một tin đồn: Viettel "bỏ toàn bộ USSD từ 13/5/2026"

Trong lúc tra cứu, nhiều trang SEO (`vietteldata.vn`, `fptshop.com.vn` và các site
đại lý) khẳng định **từ 13/05/2026 Viettel dừng toàn bộ cú pháp USSD** (`*101#`,
`*102#`, `*098#`…) và chỉ còn SMS `TK` hoặc `KTTK` gửi `191`, lý do là "chuẩn bị hạ
tầng 5G".

**Chưa xác minh được, và có nhiều dấu hiệu là tin bịa:**

- Lý do nêu ra vô nghĩa về kỹ thuật. USSD chạy trên kênh báo hiệu, không liên quan
  gì tới băng thông 5G. Không có lý do hạ tầng nào để tắt nó.
- Không tìm thấy thông báo tương ứng nào trên `viettel.vn`.
- Thông báo thật duy nhất tìm được về "Viettel ngừng USSD" là
  `viettelmoney.vn/thong-bao-viettel-money-ngung-cung-cap-phuong-thuc-xac-thuc-bang-ussd/`.
  Đã đọc toàn văn: đó là **tháng 06/2023**, và chỉ về **xác thực giao dịch Viettel
  Money**, không đụng tới `*101#`. Rất giống trường hợp một tin cũ hẹp bị các trang
  SEO thổi thành "toàn bộ USSD chết".

**Kết luận tạm:** coi `*101#` của Viettel là mức C. Cú pháp SMS `TK` gửi `191` cũng
mức C, vì nó xuất hiện cùng chỗ với tin đồn nên không mượn được uy tín từ đâu cả.

Đây chính xác là kiểu sai mà dự án dựng ra để tránh: một thông tin nghe rất hợp lý,
lặp lại trên hàng chục trang, mà không có nguồn gốc nào.

---

# 2. Vấn đề kênh thanh toán

## 2.1 Vấn đề có thật, và chính hãng cũng thừa nhận

Không phải suy đoán. Trung tâm trợ giúp của Anthropic
(`support.claude.com/en/articles/8325617`) chia hướng dẫn huỷ gói thành **ba nhánh
theo nơi mua**:

| Mua ở đâu | Anthropic bảo làm gì |
|---|---|
| Web / Claude Desktop | vào `https://claude.ai/settings/billing` (bài viết đặt liên kết thẳng tới URL này) |
| App iOS | mở app Claude, chạm chữ cái đầu ở góc trên bên phải, Billing, "Manage subscription"; nếu đã gỡ app thì quản lý qua Apple |
| App Android | tương tự, hoặc qua Google Play nếu đã gỡ app |

Nghĩa là: đưa `claude.ai/settings/billing` cho người mua qua App Store thì họ mở ra
và **không thấy gói của mình ở đó**. Tệ hơn cả không có link, vì nó khiến người
dùng tin rằng mình không có gói nào.

Nhân tiện: biến thể `https://claude.ai/new#settings/billing` mà chủ dự án nhắc tới
**không xuất hiện trong tài liệu chính thức**. Cái Anthropic ghi là
`https://claude.ai/settings/billing`. Phần `#settings/billing` là fragment nên
không bao giờ tới server, không kiểm chứng được bằng HTTP, và `/new` chỉ là màn
hình soạn hội thoại mới. Dùng bản Anthropic ghi.

## 2.2 Link chuẩn của hai cửa hàng

### App Store

```
https://apps.apple.com/account/subscriptions
```

Đã kiểm: trả **302** sang `appleid.apple.com`, trong khi đường dẫn rác trên cùng
host trả 404. Apple dùng chính URL này trong tài liệu "Setting up a link to manage
subscriptions".

**Nó mở cái gì trên iOS?** Đây là universal link của App Store, nên iOS mở **app
App Store** vào thẳng mục Subscriptions. Nó **không** mở app Cài đặt. Ba điểm hay
bị nhầm:

- Không cần `itms-apps://`. Scheme đó là di sản từ thời trước universal link.
  `https://apps.apple.com/...` chạy tốt hơn: nếu vì lý do gì đó không mở được app,
  nó vẫn còn là một URL web hợp lệ, còn `itms-apps://` thì hỏng câm.
- Đường "Cài đặt > tên bạn > Đăng ký" mà bài trợ giúp của Apple hay nhắc là thao
  tác thủ công cho người dùng, **không có URL nào tới đó**. Đừng hứa với người dùng
  là app mở được màn hình Cài đặt.
- StoreKit có `showManageSubscriptions(in:)` hiện sheet ngay trong app, nhưng nó
  **chỉ hiện gói do chính app này bán**. Subdock không bán gói Netflix, nên API này
  vô dụng ở đây. Ghi ra để sau này không ai đi lại con đường này.

### Google Play

```
https://play.google.com/store/account/subscriptions
```

Đã kiểm: trả **302** sang `accounts.google.com/v3/signin`, control trả 404.

Play còn hỗ trợ trỏ thẳng tới một gói cụ thể, theo tài liệu Play Billing:

```
https://play.google.com/store/account/subscriptions?package={packageName}&sku={productId}
```

Nhưng Subdock **không dùng được dạng này**. Nó cần `packageName` và `productId` của
gói, mà đó là dữ liệu nội bộ của từng nhà phát hành, không có trong catalog và
không tra được từ ngoài. Dùng URL trần.

## 2.3 Hai phương án, và chọn cái nào

**Phương án A: trường trong catalog liệt kê các kênh có thể mua.**
Ví dụ `availableChannels: ["WEB", "APP_STORE", "PLAY_STORE"]` trên mỗi mục của
`services.json`.

**Phương án B: trường trên chính mục của người dùng, ghi họ mua qua kênh nào.**
Ví dụ `purchaseChannel` trên item, kiểu enum, mặc định `UNKNOWN`.

| | A: catalog | B: trên item |
|---|---|---|
| Trả lời được "người này mua ở đâu?" | **không** | có |
| Dữ liệu có ổn định không? | không, hãng bật/tắt IAP liên tục, phải bảo trì mãi | có, một lần người dùng nói là xong |
| Cần bao nhiêu công cho 224 mục? | tra từng mục trên 3 kênh, khoảng 672 lần kiểm | không tra gì cả |
| Có sinh ra link đúng không? | chỉ thu hẹp còn 2 tới 3 lựa chọn | ra đúng một link |

### Chọn B: trường `purchaseChannel` trên item của người dùng.

Lý do, theo thứ tự sức nặng:

**1. A không giải được bài toán, chỉ làm nó nhỏ đi.** Biết rằng Claude bán qua cả
ba kênh không nói được gì về việc **người dùng cụ thể này** mua ở đâu. App vẫn phải
hỏi, hoặc vẫn phải bày cả ba nút. Một trường phải bảo trì mãi mà cuối cùng vẫn phải
hỏi thì không đáng.

**2. Đây đúng là loại sự thật chỉ người dùng biết, và model đã có sẵn chỗ cho nó.**
`DateSource` tồn tại vì cùng lý do: app không đọc được hồ sơ bên nhà cung cấp, nên
nó ghi lại *người dùng nói gì*. `purchaseChannel` là cùng một hình dạng dữ liệu.
Đặt nó cạnh `DateSource` là nhất quán; nhét vào catalog là đặt một sự thật riêng
của từng người vào bảng tra chung.

**3. A hỏng âm thầm, B hỏng ồn ào.** Catalog nói "dịch vụ này chỉ bán qua web" mà
thực tế hãng vừa bật IAP tháng trước, thì app **giấu mất** nút App Store và người
dùng không bao giờ biết vì sao. Còn `purchaseChannel` sai thì người dùng bấm, thấy
sai chỗ, và tự sửa lại được.

### Luồng đề xuất: đừng hỏi trước, để cú chạm tự trả lời

Không thêm câu hỏi "bạn mua qua kênh nào?" vào form tạo mục. Đó là bắt người dùng
trả giá trước cho một tính năng họ chưa dùng.

Thay vào đó:

1. `purchaseChannel = UNKNOWN` khi mới tạo mục. Màn hình chi tiết hiện nút chính
   **"Mở trang quản lý"** (dùng `manageUrl` của catalog) và một dòng nhỏ bên dưới:
   *"Mua qua App Store?"*.
2. Người dùng chạm dòng nào thì đó **chính là câu trả lời**. Ghi
   `purchaseChannel = APP_STORE` rồi mở `apps.apple.com/account/subscriptions`.
3. Từ lần sau, nút chính là kênh đã ghi. Đổi lại được trong màn hình sửa mục.

Cách này không tốn thêm một câu hỏi nào mà vẫn thu được dữ liệu, giống hệt cách
bước 3 ở §1.4 bắt lấy ngày hết hạn ngay lúc người dùng vừa nhìn thấy nó.

### Khi nào thì A đáng làm lại

Nếu sau này thấy nhiều người chạm nhầm, có thể thêm một cờ **rất hẹp** vào catalog:
`webManageOnly: true` cho những dịch vụ chắc chắn không thể mua qua cửa hàng (tên
miền, VPS, hoá đơn điện nước, giấy tờ). Với những mục đó thì ẩn dòng "Mua qua App
Store?" đi. Đó là gợi ý giao diện, không phải nguồn sự thật, và nó chỉ cần đúng
theo một chiều nên gần như không rot.

Chưa cần cho v1.

---

# 3. Thu thập `manageUrl`

## 3.1 Cách kiểm chứng: mỗi URL đi kèm một phép thử đối chứng

`assets/services.json` có 224 mục. Đã chọn 45 mục phổ biến nhất với người dùng Việt
Nam và kiểm từng cái.

Vấn đề của việc "mở thử xem có 200 không": phần lớn web hiện đại là SPA, trả 200
cho **mọi** đường dẫn, kể cả đường dẫn bịa. Một số khác ở sau Cloudflare và trả 403
cho mọi thứ. Nếu chỉ nhìn mã trả về thì `https://x.com/settings/premium` và
`https://x.com/hoan-toan-bia-dat` trông y hệt nhau, và ta sẽ tự tin ghi vào app một
đường dẫn không tồn tại.

Nên mỗi lần kiểm gọi **hai** lần:

```
URL thật     ->  https://www.dropbox.com/account/plan
URL đối chứng ->  https://www.dropbox.com/zzq-subdock-control-xyz123
```

Chỉ tính là bằng chứng khi **hai kết quả khác nhau**, và URL thật trả 2xx/3xx trong
khi đối chứng trả 404. Nếu giống nhau thì host đó không phân biệt được gì, và kết
quả bị xếp vào `inconclusive` chứ không được đoán bừa.

Ngoài ra chấp nhận tiêu chí thứ hai: **trang trợ giúp chính thức của hãng ghi rõ
đường dẫn**. Ba mục (Netflix, Spotify, Claude) vào được bằng đường này sau khi phép
thử HTTP bó tay.

## 3.2 Kết quả

Ghi ở `data/manage-urls.json`. Số liệu:

| | Số mục |
|---|---|
| Đã kiểm | 45 dịch vụ web, cộng 7 nhà mạng |
| **Có `manageUrl` dùng được** | **35** (28 dịch vụ web, 7 SIM có mã và link app) |
| Bác bỏ vì 404 hoặc soft 404 | 6 |
| Không kết luận được | 21 |

Ba khối trong file, cố ý giữ cả ba:

- `entries`: đã qua kiểm chứng, dùng được.
- `rejected`: **đã thử và sai**. Giữ lại để lần sau không ai đi tra lại rồi kết
  luận ngược.
- `inconclusive`: nghe hợp lý nhưng chưa chứng minh được. **Không phải danh sách
  chờ chép vào app.**

### Vài phát hiện đáng chú ý

**`https://github.com/settings/billing` trả 404.** Đường dẫn ai cũng tưởng là đúng,
và nếu chỉ đoán thì chắc chắn ghi cái này. Bản đúng bây giờ là
`https://github.com/settings/billing/summary`. Đây là minh hoạ gọn nhất cho lý do
phải kiểm: `/settings/copilot` trên cùng host trả 302 bình thường, nên 404 kia là
tín hiệu thật chứ không phải do chặn bot.

**Strava và TradingView đều không có trang quản lý gói công khai.**
`strava.com/settings/subscription` trả 404; `strava.com/subscribe/manage` chỉ đá về
trang bán hàng. `tradingview.com/settings/billing/` trả 404, `tradingview.com/gopro/`
chuyển hướng sang trang bảng giá. Với hai mục này, ghi link nghĩa là dắt người dùng
tới trang chào mời mua thêm. Thà không có link.

**Coursera là soft 404 điển hình.** `coursera.org/payments/manage-subscriptions`
trả 301, nghe như đúng, nhưng đích đến là trang chủ. Chỉ phát hiện được khi đi theo
chuyển hướng đến cùng thay vì dừng ở mã 301.

**Nhóm gắn với tổ chức thì không có URL chung.** Notion, Figma, Slack tính tiền
theo workspace, nên URL quản lý có chứa mã workspace của từng người. 1Password còn
gắn tên tài khoản vào chính hostname. Với nhóm này, một `manageUrl` chung trong
catalog là sai về bản chất, không phải chỉ là chưa tra ra.

**Sáu mục Apple dùng chung một link.** `icloud`, `apple-music`, `apple-tv`,
`apple-arcade`, `apple-fitness`, `apple-news` đều trỏ tới
`https://apps.apple.com/account/subscriptions`. Đây là trường hợp §2 nói tới, chỉ
là ngược lại: với dịch vụ của chính Apple thì App Store gần như luôn là kênh đúng.

## 3.3 Việc còn lại

- 21 mục `inconclusive` cần mở bằng trình duyệt thật hoặc tìm trang trợ giúp chính
  thức. Trong đó đáng làm trước: Netflix đã xong, còn Disney+, Canva, Adobe,
  Crunchyroll, Perplexity là nhóm đông người Việt dùng.
- Mã USSD của sáu nhà mạng vẫn ở mức B và C (§1.2). Đây là món rủi ro nhất trong cả
  tài liệu, vì SIM là loại mục mà sai thì mất số.
- `assets/services.json` đã có sẵn trường `cancelUrl` trên 25 mục. Cần quyết định
  `manageUrl` và `cancelUrl` là hai trường hay một. Ý kiến của tôi: **hai**. "Xem
  hạn còn bao lâu" và "huỷ ngay" là hai ý định khác nhau, và với một app nhắc hạn
  thì cái đầu mới là việc chính.

---

# Nguồn

**Apple (mức A)**
- Phone Links: <https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html>
- iTunes Search API: <https://itunes.apple.com/search?term=My+Viettel&country=vn&entity=software>
- Diễn đàn Apple Developer: <https://developer.apple.com/forums/thread/701865>,
  <https://developer.apple.com/forums/thread/749906>,
  <https://developer.apple.com/forums/thread/14766>,
  <https://developer.apple.com/forums/thread/22114>

**Flutter**
- url_launcher: <https://pub.dev/packages/url_launcher>
- <https://github.com/flutter/flutter/issues/36634>,
  <https://github.com/flutter/flutter/issues/169749>,
  <https://github.com/flutter/flutter/issues/89543>

**Nhà mạng, tên miền chính thức**
- Wintel, kiểm tra tài khoản khuyến mãi (`*102#`): <https://wintel.vn/tin-tuc/huong-dan-kiem-tra-tai-khoan-khuyen-mai-mang-di-dong-wintel> *(403 khi curl; nội dung lấy qua chỉ mục tìm kiếm)*
- Wintel, chính sách thời hạn thuê bao: <https://wintel.vn/tin-tuc/wintel-dieu-chinh-chinh-sach-thoi-han-su-dung-thue-bao-va-thoi-han-khoi-phuc-so-thuong-tu-22-09-2023>
- Vietnamobile, thời hạn SIM trả trước: <https://www.vietnamobile.com.vn/product/ve-vietnamobile/thoi-han-su-dung-sim-tra-truoc/> *(render bằng JS, không đọc được mã)*
- MobiFone, blog đơn vị thành viên (mức B): <https://giaiphapsohanoi.mobifone.vn/cach-kiem-tra-tai-khoan-mobifone.html>
- iTel FAQ (mức B): <https://didong.itelecom.vn/blogs/cau-hoi-thuong-gap> *(tên miền không phân giải được lúc kiểm tra)*
- Viettel Money, ngừng xác thực USSD, 06/2023: <https://viettelmoney.vn/thong-bao-viettel-money-ngung-cung-cap-phuong-thuc-xac-thuc-bang-ussd/>
