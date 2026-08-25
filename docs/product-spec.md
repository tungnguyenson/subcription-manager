# Đến Hạn: Đặc tả sản phẩm

Tài liệu này đặc tả **Đến Hạn**, một app iOS cá nhân dùng để theo dõi mọi thứ có ngày hết hạn: gói dùng thử sắp bị tính tiền, hạn sử dụng của SIM trả trước, các khoản phải thanh toán, và những dịch vụ tự động gia hạn hàng tháng.

Tài liệu ghi lại app phải làm được gì và vì sao chọn cách đó, đủ chi tiết để bắt tay viết code. Phần giao diện nằm ở một tài liệu riêng (`design-spec.md`).

Người đọc: chính tác giả app, và bất kỳ ai tiếp nhận code sau này.

---

## 1. Thuật ngữ

App có vài khái niệm riêng. Định nghĩa trước để phần sau khỏi phải giải thích lại.

| Thuật ngữ | Nghĩa trong tài liệu này |
|---|---|
| **Mục** (item) | Một thứ cần theo dõi, gồm một cái tên và một ngày đến hạn. Đơn vị dữ liệu cơ bản của app. |
| **Mức rủi ro** (stake) | Hậu quả nếu bỏ lỡ ngày đó. Có ba mức, xem mục 3. Đây là trục thiết kế chính. |
| **Nhóm** (group) | Nhãn gom nhiều mục liên quan, ví dụ mọi thứ thuộc về một cái SIM. |
| **Mốc nhắc** (lead) | Một lần thông báo, đặt trước ngày đến hạn N ngày. Một mục có nhiều mốc nhắc. |
| **Nhắc dai** (nag) | Nhắc lặp lại sau khi đã quá hạn, tới khi được xác nhận đã xử lý. |
| **Nhắc đối chiếu** (verify) | Nhắc định kỳ để kiểm tra lại xem ngày đã nhập có còn đúng không. Khác với nhắc hạn. |
| **Local notification** | Thông báo do chính máy hẹn giờ và bật lên, không cần server. Đây là cơ chế thông báo duy nhất của app. |
| **Minor unit** | Đơn vị nhỏ nhất của một loại tiền. USD có minor unit là cent (1 đô = 100 cent), VND không có (1 đồng là nhỏ nhất). |

---

## 2. Vấn đề cần giải

Người dùng quên ngày đến hạn và trả giá cho việc đó theo bốn kiểu:

1. **Trial hết hạn mà quên** dẫn tới bị trừ tiền cho dịch vụ không định dùng tiếp.
2. **Gói cước SIM hết hạn** dẫn tới SIM bị khóa, và nếu để lâu thì mất luôn số điện thoại.
3. **Khoản thanh toán đến hạn** mà chưa gom đủ tiền.
4. **Dịch vụ tự gia hạn** (YouTube, Netflix, Claude, OpenAI) trừ tiền âm thầm, không biết mỗi tháng đang trả bao nhiêu.

Cả bốn có cùng hình dạng: một cái tên, một ngày, một hậu quả. Điểm khác nhau duy nhất là **hậu quả nặng nhẹ tới đâu**, và đó là thứ quyết định app phải nhắc sớm bao nhiêu, dai bao nhiêu.

### Không phải vấn đề cần giải

Ghi rõ để tránh phình phạm vi:

- Không quản lý chi tiêu tổng thể. App chỉ biết những khoản người dùng tự nhập.
- Không kết nối ngân hàng, không đọc email tự động, không quét tin nhắn.
- Không tự hủy dịch vụ hộ. App đưa người dùng tới trang hủy, phần còn lại người dùng làm.
- Không chia sẻ cho người khác trong phiên bản đầu.

---

## 3. Mức rủi ro: trục thiết kế chính

Đây là quyết định thiết kế quan trọng nhất của app. Mọi thứ khác đều bám theo nó.

Thay vì phân loại theo *thứ đó là gì* (streaming, viễn thông, hóa đơn), app phân loại theo *mất gì nếu bỏ lỡ*. Lý do: cách phân loại thứ nhất chỉ phục vụ việc thống kê, còn cách thứ hai quyết định trực tiếp hành vi nhắc nhở, tức là công việc chính của app.

| Mức | Tên | Mất gì | Ví dụ |
|---|---|---|---|
| 1 | **Mất luôn** | Thứ không mua lại được bằng tiền, hoặc mua lại rất tốn công | Số điện thoại bị thu hồi, hộ chiếu hết hạn, đăng kiểm xe |
| 2 | **Mất tiền** | Một khoản tiền cụ thể, hoặc phát sinh phí phạt | Trial bị tính tiền, hóa đơn trễ hạn, khoản vay đến hạn |
| 3 | **Chỉ cần biết** | Không mất gì, chỉ là muốn nắm được | Netflix gia hạn, Claude gia hạn, iCloud gia hạn |

Mức rủi ro quyết định bốn thứ, tự động, không cần người dùng cấu hình:

- **Nhắc trước bao nhiêu ngày.** Mức 1 nhắc từ rất sớm, Mức 3 nhắc sát ngày.
- **Có nhắc dai không.** Chỉ Mức 1 và Mức 2 nhắc lại sau khi quá hạn.
- **Kiểu thông báo.** Mức 1 và Mức 2 dùng Time Sensitive để vượt qua chế độ Không làm phiền của iOS. Mức 3 dùng thông báo thường.
- **Ưu tiên khi hết chỗ đặt lịch.** iOS giới hạn 64 thông báo đang chờ, xem mục 7.3.

Người dùng vẫn sửa được từng mục, nhưng mặc định phải đúng ngay từ đầu.

---

## 4. Phân loại: mỗi trục một màn hình

App có ba trục phân loại. Quy tắc giữ cho chúng không giẫm chân nhau: **mỗi trục sở hữu đúng một màn hình**, và không trục nào xuất hiện ở hai nơi.

| Trục | Trả lời câu hỏi | Ai đặt | Sở hữu màn hình |
|---|---|---|---|
| **Mức rủi ro** | Bỏ lỡ thì mất gì? | App suy ra, người dùng sửa được | Màn hình Sắp tới |
| **Danh mục** | Tiền chảy đi đâu? | App điền từ danh sách dựng sẵn | Màn hình Tiền |
| **Nhóm** | Cái này thuộc về vật gì? | Người dùng, khi tạo SIM hoặc xe | Màn hình chi tiết nhóm |

Đây không phải quy ước tùy tiện, mà là bài học từ những app đi trước.

### 4.1 Vì sao phải giới hạn chặt như vậy

Firefly III có bốn trục cùng lúc (budget, category, tag, bill). Tác giả của chính app đó thừa nhận: *"budget, category và tag thực ra thừa, chúng đều dùng để chỉ cùng một thứ"*. App phải viết hẳn một trang tài liệu hướng dẫn dùng cái nào khi nào, và người dùng vẫn hiểu ngược lại: có người dùng tag làm nhóm cha và category làm nhóm con, tức là ngược hoàn toàn với thiết kế.

Wallos đóng cả hai yêu cầu "cho chọn nhiều danh mục" và "thêm tag" với trạng thái **không làm**, tháng 3 năm 2026, dù có nhiều người ủng hộ.

Còn về số lượng danh mục, đây là bài toán chia đơn giản. Một app cá nhân thực tế có 20 tới 30 mục. Wallos mặc định 16 danh mục, chia ra chưa tới 2 mục mỗi danh mục. Lúc đó biểu đồ "chi theo danh mục" chỉ là danh sách các mục được đổi tên, tức là **trả phí phân loại cho từng mục mà không nhận lại được gì**. Các app theo dõi subscription thực tế đều nằm trong khoảng 5 tới 12 danh mục, còn các con số 15 tới 60 thuộc về app quản lý chi tiêu cả gia đình với hàng trăm giao dịch mỗi tháng.

Một chi tiết đáng chú ý trong thiết kế của Wallos: dòng "No category" mang id 1 và là giá trị mặc định. Nghĩa là app được xây để chạy đầy đủ khi không ai phân loại gì. Đây là mặc định đúng và app này áp dụng luôn cho cả mức rủi ro.

### 4.2 Không có ô chọn danh mục trong form

Quyết định quan trọng nhất của mục này: **danh mục do app điền, không do người dùng chọn**.

Tên dịch vụ là một tập hợp đóng và nhỏ gồm các thương hiệu ai cũng biết. Netflix luôn là giải trí, Claude luôn là AI, Viettel luôn là viễn thông. Nên chỉ cần một bảng tra cứu đóng gói sẵn trong app là suy ra được, chính xác gần như tuyệt đối, không cần học máy, không cần internet.

Đây là cách SubTracker làm với hơn 130 dịch vụ. Wallos là ví dụ ngược lại đáng học: nó tự động tìm được logo từ tên dịch vụ, nhưng cố tình không tự điền danh mục, và hậu quả là danh mục trở thành thứ người dùng đi báo lỗi chứ không phải thứ họ dùng.

Người dùng sửa được danh mục trong màn hình chi tiết, nhưng **không được tạo danh mục mới lúc nhập mục**. Đó là cách một danh sách 8 dòng biến thành 30 dòng trong một tuần.

### 4.3 Tám danh mục

| Danh mục | Gồm |
|---|---|
| Giải trí | Netflix, YouTube Premium, HBO, Spotify, FPT Play, game |
| AI và phần mềm | Claude, ChatGPT, Adobe, ứng dụng, tên miền |
| Lưu trữ đám mây | iCloud+, Google One, Dropbox |
| Viễn thông và Internet | SIM, internet nhà, truyền hình cáp |
| Hóa đơn nhà | điện, nước, phí chung cư, rác |
| Vay và trả góp | khoản vay, trả góp, phí thường niên thẻ |
| Bảo hiểm | bảo hiểm y tế, nhân thọ, xe |
| Giấy tờ và thủ tục | hộ chiếu, căn cước, giấy phép lái xe, đăng kiểm |

Cộng thêm một dòng hệ thống "Chưa phân loại", không bao giờ hiện ra để chọn, chỉ dùng làm giá trị dự phòng.

Con số 8 đến từ phép chia ở mục 4.1: 25 mục chia cho 8 ra khoảng 3 mục mỗi danh mục, đủ để biểu đồ có ý nghĩa. Và 8 dòng vừa một màn hình chọn trên điện thoại, không phải cuộn.

Cách đặt tên mượn từ MoMo (Điện, Nước, Internet, Vay tiêu dùng, Bảo hiểm), vì đó là mô hình người dùng Việt Nam đã quen.

### 4.4 Mức rủi ro cũng do app suy ra

Nghiên cứu 1.744 đánh giá trên App Store không tìm thấy app nào tổ chức theo hậu quả bỏ lỡ. Nghĩa là đây vừa là điểm khác biệt, vừa là thứ chưa được kiểm chứng: **không có bằng chứng nào cho thấy người dùng chịu tự phân loại mức rủi ro lúc nhập**.

Nên form nhập **không có ô chọn mức rủi ro**. App suy ra từ loại mục:

| Loại mục | Mức rủi ro suy ra |
|---|---|
| Trả trước, giấy tờ | Mức 1, mất luôn |
| Trial, hóa đơn, khoản vay | Mức 2, mất tiền |
| Dịch vụ định kỳ | Mức 3, chỉ cần biết |

Sửa được trong màn hình chi tiết, và mục không đặt mức rủi ro vẫn chạy bình thường, vẫn nhắc, vẫn xếp theo ngày.

### 4.5 Nhóm chỉ sở hữu màn hình chi tiết

Nhóm gom các mục thuộc về cùng một vật thể ngoài đời: ba mốc hạn của một cái SIM, hoặc đăng kiểm và bảo hiểm của một cái xe.

Đây chính là nhu cầu mà người dùng các app khác hay diễn đạt thành "cho thêm tag", nguyên văn một yêu cầu trên Wallos: *"cho phân loại vào Bảo hiểm rồi gắn tag Xe hoặc Nhà"*. Đó không phải yêu cầu về danh mục, mà là yêu cầu gom bó.

**Nhóm không được trở thành trục lọc hay sắp xếp trên màn hình chính.** Nếu vi phạm, app quay lại đúng mớ bòng bong của Firefly III. Nhóm trả lời đúng một câu hỏi, trên đúng một màn hình: *"cái xe này mỗi năm tốn của tôi bao nhiêu và cần làm những gì?"*

### 4.6 Không có tag

Tag là tính năng được yêu cầu nhiều nhất và dùng ít nhất trong ngành này, theo lời chính tác giả Firefly III. Lý do nó hỏng: hai người dùng khác nhau, hoặc cùng một người cách nhau sáu tháng, sẽ nghĩ ra hai quy ước đặt tag không tương thích.

---

## 4bis. SIM và các dịch vụ trả trước

> **Đã đổi so với bản này.** SIM không còn là một giá trị phân loại riêng trong code. Nó
> nằm trên nhóm `PHONE` dựng sẵn, nhóm này ship với nhắc hằng ngày sau hạn và chữ
> *expires* thay vì *due*. Mọi thứ dưới đây vẫn đúng về mặt sản phẩm, chỉ khác chỗ: các
> mặc định đó là **dữ liệu người dùng sửa được**, không phải luật cứng trong code. Xem bẫy
> số 19 trong `CLAUDE.md`.

SIM được xử lý **như mọi mục khác**: một cái tên, một ngày hết hạn, một mức quan trọng, một ô ghi chú. Không có mô hình riêng, không có cấu hình nhà mạng, không có bảng thời hạn thu hồi.

Lý do ghi lại ở đây vì bản trước của tài liệu này đi theo hướng ngược lại. Nghiên cứu ra rất nhiều chi tiết về quy định viễn thông Việt Nam, và tôi đã biến hết chúng thành tính năng: mô hình ba đồng hồ đếm ngược, tệp cấu hình bốn nhà mạng, cảnh báo thường trực. Đó là độ phức tạp tôi tự tạo ra, không phải thứ người dùng cần.

**Cái người dùng cần:** chọn được mức quan trọng, và nhập được thông tin.

Cả hai đều đã có sẵn trong mô hình chung:

| Nhu cầu | Dùng cái đã có |
|---|---|
| Đánh dấu số điện thoại là thứ mất là mất luôn | Mức rủi ro, đặt thành Mức 1 |
| Ghi nhà mạng, mã tra cứu, ghi chú riêng | Trường `note` |
| Nhắc kiểm tra lại định kỳ vì hạn hay trôi | `verifyEveryDays`, dùng chung với giấy tờ |
| Gom nhiều mốc của cùng một cái SIM | Nhóm, dùng chung với xe cộ và giấy tờ |
| Mở nhanh mã tra cứu của nhà mạng | `actionUrl` kèm `actionLabel` |

Loại mục `PREPAID` áp cho mọi thứ **hết dần nếu không nạp**, không riêng gì SIM: điện trả trước, nước trả trước, tài khoản dịch vụ tính theo lượt dùng. Mặc định của nó là Mức 1 và thang nhắc dài, vì hết mà không nạp thì thường mất thứ khó lấy lại.

Vẫn giữ lại một điều từ phần nghiên cứu, vì nó đúng với mọi mục chứ không riêng SIM: **app chỉ biết cái người dùng gõ vào**. Ngày trong app có thể lệch với ngày thật ở nhà cung cấp, và trường `dateSource` cùng cơ chế nhắc đối chiếu tồn tại để xử lý chuyện đó.

---

## 5. Mô hình dữ liệu

Toàn bộ app xoay quanh một thực thể duy nhất. Không tách bảng riêng cho từng loại, vì mọi loại đều có cùng hình dạng và việc tách chỉ làm code phình ra.

```kotlin
data class TrackedItem(
  val id: Uuid,

  // Nhận dạng
  val name: String,              // "Hạn số", "Netflix Premium"
  val groupId: Uuid?,            // trỏ tới ItemGroup, null nếu mục đứng một mình
  val kind: Kind,                // quyết định giá trị mặc định lúc tạo
  val stake: Stake,              // ASSET | MONEY | INFO
  val categoryId: String?,       // danh mục chi tiêu

  // Thời gian
  val expiresOn: LocalDate,      // ngày thứ đó thật sự hết hạn
  val actByOffsetDays: Int,      // phải làm xong trước hạn mấy ngày, xem mục 5.3
  val anchorDate: LocalDate,     // ngày gốc, dùng để tính chu kỳ, xem mục 5.2
  val cycle: Cycle?,             // null nếu chỉ xảy ra một lần
  val cycleCount: Int,           // đã qua bao nhiêu chu kỳ kể từ anchorDate

  // Tiền
  val amountMinor: Long,         // Long chứ không phải Int, xem mục 6.2
  val currency: String?,         // "VND" | "USD"

  // Hành động
  val actionUrl: String?,        // trang hủy, hoặc tel:// mã tra cứu
  val actionLabel: String?,      // "Hủy Netflix", "Kiểm tra hạn"
  val note: String?,

  // Nhắc nhở
  val leadDays: List<Int>,       // [7, 3, 1, 0]
  val remindAt: LocalTime,       // mặc định 08:30
  val nagAfterDue: NagPolicy,    // NONE | DAILY | WEEKLY

  // Đối chiếu với nguồn thật, xem mục 4bis.3 và 7.5
  val verifyEveryDays: Int?,     // null nếu không cần đối chiếu
  val lastVerifiedAt: LocalDate?,   // lần cuối người dùng xác nhận với nguồn thật
  val dateSource: DateSource,    // ngày này ở đâu ra

  val state: State,
  val createdAt: Instant,
)

// Ngày đến hạn đến từ đâu. Quyết định mức độ tin cậy hiển thị trên giao diện.
enum class DateSource {
  USER_CONFIRMED,   // người dùng vừa đối chiếu với nhà cung cấp
  USER_ESTIMATED,   // người dùng tự nhập theo trí nhớ
  COMPUTED,         // app tính ra từ chu kỳ
  EXTRACTED,        // bóc từ ảnh, chưa đối chiếu
}

enum class Stake { ASSET, MONEY, INFO }

enum class Kind {
  TRIAL,          // gói dùng thử, sắp bị tính tiền
  RECURRING,      // dịch vụ tự gia hạn
  PREPAID,        // hết dần nếu không nạp: SIM, điện nước trả trước
  BILL,           // hóa đơn, khoản phải trả
  DOCUMENT,       // giấy tờ có hạn, không tính vào tổng chi
}

enum class State {
  ACTIVE,                  // đang theo dõi
  CANCELLED_STILL_ACTIVE,  // đã hủy nhưng còn dùng tới hết kỳ
  ARCHIVED,                // không theo dõi nữa, giữ lịch sử
}

enum class NagPolicy { NONE, DAILY, WEEKLY }
```

Lịch sử tách thành bảng riêng, vì nó chỉ ghi thêm và không bao giờ sửa:

```kotlin
data class HandledEvent(
  val id: Uuid,
  val itemId: Uuid,
  val handledAt: Instant,
  val forDueDate: LocalDate,     // xử lý cho mốc nào

  // Ảnh chụp tiền tại thời điểm đó, xem mục 6.3
  val amountMinor: Long?,
  val currency: String?,
  val fxRateScaled: Long?,       // tỷ giá quy đổi, số nguyên đã nhân thang
  val fxRateScale: Int?,
  val fxRateDate: LocalDate?,
  val fxSource: String?,
  val baseAmountMinor: Long?,    // số tiền quy về VND, tính một lần rồi đông cứng
  val actualChargedMinor: Long?, // người dùng nhập tay từ sao kê, ghi đè mọi tính toán
)
```

```kotlin
data class ItemGroup(
  val id: Uuid,
  val name: String,              // "SIM Viettel 0912 345 678"
  val kind: GroupKind,           // SIM | VEHICLE | PERSON | OTHER
  val meta: Map<String, String>, // vd. carrier="viettel", msisdn="0912345678"
)
```


### 5.1 Vì sao lịch sử tách riêng

Hai lý do. Thứ nhất, một mục lặp lại có thể được xử lý hàng chục lần, nhét hết vào một cột JSON sẽ khó truy vấn. Thứ hai, và quan trọng hơn: **lịch sử phải bất biến**. Số tiền đã trả tháng trước là một sự thật đã xảy ra, không được đổi khi tỷ giá đổi. Xem mục 6.3.

### 5.2 Vì sao cần `anchorDate` chứ không chỉ `dueDate`

Đây là một cái bẫy có thật trong thư viện ngày tháng.

`LocalDate.plus(1, DateTimeUnit.MONTH)` của `kotlinx-datetime` tự động lùi về ngày cuối tháng khi ngày đích không tồn tại: 31/1 cộng một tháng ra 28/2. Đúng như mong đợi.

Nhưng nếu tính chu kỳ bằng cách cộng dồn từ kết quả trước đó, ngày sẽ trôi và không quay lại được:

```
31/1 → 28/2 → 28/3 → 28/4 ...   ← SAI, mất luôn ngày 31
```

Cách đúng là luôn tính từ ngày gốc:

```kotlin
fun nthDue(anchor: LocalDate, n: Int, cycle: Cycle): LocalDate =
    anchor.plus(n * cycle.months, DateTimeUnit.MONTH)

// 31/1 + 1 tháng = 28/2
// 31/1 + 2 tháng = 31/3   ← đúng
```

Vì vậy mô hình lưu cả `anchorDate` (ngày gốc, không đổi) lẫn `cycleCount` (đã qua mấy chu kỳ), và ngày đến hạn là giá trị tính ra. Cần một test riêng cho đúng trường hợp 31/1 này.

### 5.3 Ngày phải làm khác ngày hết hạn

Đây là một khái niệm mượn từ Feist, app quản lý hợp đồng của Đức, và nó giải quyết một vấn đề mà mô hình "một ngày duy nhất" không diễn tả được.

**Gần như mọi mục quan trọng đều có một ngày phải hành động sớm hơn ngày hết hạn:**

| Mục | Ngày hết hạn | Ngày phải làm xong |
|---|---|---|
| Trial Claude | ngày bị tính tiền | trước đó, phải hủy trước khi bị trừ |
| SIM | ngày hết hạn sử dụng | trước đó, nạp trước khi bị khóa một chiều |
| Đăng kiểm xe | ngày hết hạn tem | trước đó, phải đi đăng kiểm và có lịch hẹn |
| Hộ chiếu | ngày hết hạn | nhiều tháng trước, nhiều nước yêu cầu còn hạn 6 tháng |

Nếu chỉ lưu một ngày, app sẽ nhắc đúng vào lúc đã quá muộn để làm gì. Nên mô hình lưu `expiresOn` cộng với `actByOffsetDays`, và:

- **Thang nhắc neo vào ngày phải làm**, không neo vào ngày hết hạn.
- **Giao diện hiện cả hai**, để người dùng hiểu vì sao bị nhắc sớm.

Đây là một trường duy nhất trong schema nhưng nó biến mục Mức 1 từ chỗ chỉ gây lo lắng thành chỗ làm được việc.

---

## 6. Tiền và đa tiền tệ

App hỗ trợ VND và USD, cả hai đều là công dân hạng nhất.

### 6.1 Phạm vi thật sự nhỏ hơn tưởng tượng

Kiểm tra lại giá thực tế: Netflix Việt Nam tính bằng đồng (74.000 tới 273.000₫), iCloud+ với Apple ID Việt Nam cũng tính bằng đồng (25.000₫ cho 50GB, 89.000₫ cho 200GB), gói cước viễn thông đương nhiên là đồng.

Chỉ những dịch vụ tính tiền trực tiếp qua thẻ quốc tế mới thật sự là đô: **Claude, OpenAI**, và vài dịch vụ tương tự. Nghĩa là số dòng cần quy đổi rất ít.

Kết luận: xây phần quy đổi cho đúng, nhưng đừng xây to.

### 6.2 Biểu diễn tiền trong code

**Số nguyên 64 bit, đơn vị nhỏ nhất, kèm mã tiền tệ.** Không dùng số thực, vì cộng dồn số thực sinh sai số (0.1 cộng 0.2 ra 0.30000000000000004).

Hai cái bẫy, cả hai đều âm thầm:

**Bẫy thứ nhất: VND không có đơn vị nhỏ hơn.** Theo chuẩn ISO 4217, VND có số chữ số thập phân bằng 0, USD bằng 2.

```
$20.00   → amountMinor = 2000,  currency = "USD"   (scale 2)
₫25.000  → amountMinor = 25000, currency = "VND"   (scale 0)
```

Viết cứng "nhân 100" sẽ làm mọi số tiền VND to gấp 100 lần. Phải tra scale theo mã tiền tệ từ một bảng đóng gói sẵn, và **chấp nhận mọi mã ISO 4217** thay vì liệt kê cứng vài loại tiền.

**Bẫy thứ hai: `Int` 32 bit tràn số với VND.** Số nguyên 32 bit chỉ chứa được tới khoảng 2,1 tỷ. Khi nhân thang để giữ độ chính xác lúc quy đổi tỷ giá, VND vượt qua ngưỡng đó ở khoảng 55 tỷ. Dùng `Long` ở mọi chỗ liên quan tới tiền.

**Về việc bóc số tiền từ ảnh:** người Việt viết `1.290.000₫` dùng dấu chấm phân nhóm, còn nhiều hóa đơn quốc tế dùng dấu phẩy làm dấu thập phân (`12,99`). Đọc nhầm một trong hai kiểu cho ra con số sai 100 hoặc 1000 lần mà nhìn vẫn hợp lý. Đây là lý do schema ở mục 8.5 bắt buộc có trường trích nguyên văn cho số tiền.

### 6.3 Tỷ giá: chụp lại lúc ghi, không tính lại

Đây là quyết định đắt nhất nếu làm sai, và có bằng chứng cụ thể.

Wallos, app theo dõi subscription mã nguồn mở phổ biến nhất, lưu đúng một cột tỷ giá cho mỗi loại tiền, ghi đè mỗi 6 tiếng, không lưu ngày. Hậu quả: **mọi con số lịch sử trong app thay đổi bốn lần một ngày**. Đây là cụm lỗi lớn nhất của dự án đó.

Nguyên tắc kế toán trả lời dứt điểm chuyện này. Chuẩn IAS 21 quy định một khoản chi bằng ngoại tệ được ghi nhận theo tỷ giá tại **ngày phát sinh**, và các khoản đã thanh toán xong thì **không quy đổi lại**. Tiền đã trả tháng trước là chuyện đã rồi.

Nên app tách hai loại số liệu, không dùng chung đường code:

| | Đã qua (lịch sử) | Sắp tới (dự báo) |
|---|---|---|
| Nguồn số | `baseAmountMinor` đã đông cứng trong `HandledEvent` | Tính lại từ tỷ giá hiện tại |
| Có thay đổi không | Không bao giờ | Có, và nên thay đổi |
| Hiển thị | Số chính xác | Có dấu ngã "≈" phía trước |

Con số cụ thể để thấy vấn đề: 20 đô mỗi tháng trong 24 tháng, tính theo tỷ giá từng tháng ra 12.390.420₫. Tính lại hết theo tỷ giá hôm nay ra 12.502.080₫. Sai số 0,9%, nghe nhỏ. Nhưng cùng chuỗi lịch sử đó tính theo tỷ giá của các thời điểm khác nhau cho ra khoảng dao động 4,7%. Vấn đề không phải sai lệch, mà là **một con số người dùng tin là sự thật quá khứ lại nhảy mỗi lần mở app**.

### 6.4 Lấy tỷ giá ở đâu

Ba tầng, tầng sau chỉ là bổ sung cho tầng trước:

**Tầng 0, đóng gói sẵn trong app.** Một bảng tỷ giá nhúng vào binary lúc build, kèm ngày. Đây là cách Bobby (app theo dõi subscription phổ biến trên iOS) đang làm. VND là tiền tệ neo có kiểm soát, trượt khoảng 2% mỗi năm, nên tỷ giá đóng gói 6 tháng trước chỉ lệch khoảng 1%, không nhìn thấy được phía sau dấu "≈". **App chạy đầy đủ mà không cần internet, vĩnh viễn.**

**Tầng 1, cập nhật cơ hội.** Tối đa một lần gọi mỗi ngày, chạy nền, không bao giờ chặn giao diện, không bao giờ hiện vòng xoay chờ trên màn hình Tiền.

**Tầng 2, nhập tay.** Cho người dùng gõ tỷ giá. Người Việt biết tỷ giá Vietcombank, và đây cũng là cách để con số trong app khớp với sao kê thẻ.

Về nguồn tỷ giá, có ba cái bẫy đã kiểm chứng:

- **Không dùng ECB hay Frankfurter v1.** Cả hai đều **không có VND**. Tệ hơn, Frankfurter v1 âm thầm bỏ qua VND thay vì báo lỗi, nên code sẽ nhận về giá trị rỗng mà không biết.
- **Không dùng exchangerate.host.** Đã chuyển sang bắt buộc đăng ký API key.
- **Không đặt tỷ giá mặc định bằng 1** khi thiếu dữ liệu. Firefly III làm vậy và biến khoản 20 đô thành 20 đồng, sai 26.000 lần nhưng trông vẫn giống một con số hợp lý. Thiếu tỷ giá thì hiện dòng đó bằng tiền gốc, loại khỏi tổng, và báo rõ "2 mục chưa quy đổi".

Nguồn dùng được, đã kiểm chứng có VND, không cần key: `open.er-api.com/v6/latest/USD` (chính) và `cdn.jsdelivr.net/npm/@fawazahmed0/currency-api` (dự phòng). Cần backfill lịch sử thì dùng Frankfurter **v2** (`/v2/rate/USD/VND?date=`), có dữ liệu từ 1998.

Ba nguồn này lệch nhau khoảng 0,2% trong cùng một ngày, lớn hơn mọi sai số làm tròn trong code. Vì vậy **phải lưu lại nguồn nào sinh ra tỷ giá đó**, nếu không thì đổi nguồn sẽ âm thầm viết lại lịch sử.

### 6.5 Số tiền thật trên sao kê

Ngân hàng Việt Nam tính thêm phí xử lý ngoại tệ, Vietcombank công bố 2,27% trên giá trị giao dịch. Nghĩa là con số app tính ra luôn thấp hơn thực tế khoảng 2 tới 3%, dù tỷ giá có đúng tới đâu.

Nên `HandledEvent` có trường `actualChargedMinor` cho người dùng nhập số tiền thật từ sao kê. Khi có giá trị này, nó ghi đè mọi tính toán. Đây là cách Firefly III làm và là thứ người dùng Wallos đòi hỏi.

### 6.6 Hiển thị

Không chọn giữa "một tổng duy nhất" và "hai cột tách riêng". Làm cả hai, theo đúng thứ tự:

```
Tháng này
≈ 1.240.000 ₫                    ← số lớn, có dấu ngã
₫ 618.000  ·  $ 22,99            ← chi tiết theo từng loại tiền
tỷ giá 26.046 ₫/$ · cập nhật 14/08   ← luôn hiện ngày của tỷ giá
```

Ba quy tắc bắt buộc:
- Số quy đổi **luôn** có dấu "≈" và **luôn** kèm ngày của tỷ giá. Không bao giờ hiện số quy đổi trần trụi.
- VND làm tròn tới hàng nghìn. Chi tiết dưới mức đó là nhiễu.
- Hiện mã tiền tệ, không chỉ ký hiệu. Ký hiệu `$` dùng chung cho nhiều nước.

---

## 7. Bộ máy nhắc

### 7.1 Đây là chỗ duy nhất app phải thắng

Phân tích 1.744 đánh giá trên App Store của 9 app cùng ngành cho ra một kết luận rõ ràng: **thông báo không chạy là than phiền số một, và nó lặp lại suốt sáu năm liền.**

Với Bobby, app dẫn đầu ngành trên iOS, **35% số đánh giá từ 3 sao trở xuống nhắc tới thông báo hỏng**. Trích vài câu:

> *"Thông báo không còn chạy. Cài lại rồi vẫn vậy. Tránh xa."* (1 sao, 12/2025)

> *"Chuyển hết subscription sang đây. Rồi phát hiện thông báo không chạy. Không chạy tí nào."* (1 sao, 02/2023, người viết là tác giả một app khác)

> *"Thông báo hỏng hơn một năm rồi, tác giả không phản hồi."* (1 sao, 03/2022)

Có một loại lỗi thứ hai còn tệ hơn, vì nó phá hủy lòng tin nhanh hơn cả im lặng: **thông báo có hiện, nhưng nội dung sai.**

> *"Đáng lẽ nói hóa đơn tới hạn ngày mai, nó lại nói còn 2 tuần."* (1 sao, 08/2020)

> *"Nó nói ngày mai là hôm nay, nên mọi thông báo lệch một ngày. Đây là chuyện cơ bản nhất."* (Chronicle, 1 sao, 03/2024)

Nguyên nhân của loại lỗi này thường là tính khoảng thời gian từ sai mốc gốc, hoặc xử lý múi giờ sai.

Kết luận thiết kế: **độ tin cậy của thông báo không phải một tính năng, nó là toàn bộ sản phẩm.** Mọi thứ khác trong app này có thể làm sơ sài, riêng phần này không.

### 7.1bis Khoảng trống không ai lấp

Trong toàn bộ 1.744 đánh giá, **không tìm thấy một app nào cho phép xử lý ngay trên thông báo**. Mọi app đều bắt mở app ra để đánh dấu đã trả.

Nhưng người dùng thì liên tục đòi những thứ xung quanh nó: số đếm trên biểu tượng app, và tích hợp lịch để hệ điều hành lo việc hoãn.

> *"Phần lớn mọi người, kể cả tôi, hoãn thông báo chứ không hoãn lịch."* (Bobby, 3 sao, 01/2020)

Đây là chỗ app này khác biệt được, và nó không tốn nhiều công.

Mô hình nhắc tốt nhất tìm được trong cả ngành thuộc về Chronicle: **một thông báo báo trước, cộng một thông báo vào đúng ngày hết hạn chỉ bật lên nếu mục vẫn chưa được xử lý**, kèm số đếm thường trực trên biểu tượng và tách rõ Sắp tới với Quá hạn. Người dùng Chronicle vẫn đòi thêm nhiều mốc hơn (7 và 5 ngày, hoặc 5 và 3 ngày), nghĩa là thang nhắc nên đặt được theo từng mục.

Mô hình này chỉ làm được nếu **mỗi lần đến hạn là một bản ghi riêng có trạng thái đã xử lý hay chưa**, đó là lý do có bảng `HandledEvent` ở mục 5.

Nên nguyên tắc chung: **ít thông báo, mỗi cái đều đáng đọc, và mỗi cái đều bấm được.**

### 7.2 Lịch nhắc mặc định

Giờ nhắc mặc định **08:30 sáng**.

| Loại mục | Nhắc trước | Sau khi quá hạn | Kiểu |
|---|---|---|---|
| Trả trước (SIM, điện, nước) | 30, 14, 7, 3, 1, 0 ngày | Mỗi ngày | Time Sensitive |
| Giấy tờ | 60, 30, 7 ngày | Mỗi tuần | Time Sensitive |
| Trial | 3, 1, 0 ngày | Một lần duy nhất | Thường |
| Hóa đơn, khoản vay | 7, 1 ngày | Mỗi ngày | Time Sensitive |
| Dịch vụ định kỳ | 3 ngày | Không, tự sang kỳ sau | Thường |

**Time Sensitive** là mức ưu tiên của iOS cho phép thông báo vượt qua chế độ Tập trung và Không làm phiền. Bật bằng một capability trong Xcode, không cần Apple xét duyệt. Không dùng **Critical Alert**, vì mức đó kêu cả khi máy để im lặng và Apple xét duyệt riêng từng app.

### 7.3 Giới hạn 64 thông báo của iOS

iOS chỉ giữ tối đa **64 local notification đang chờ** cho mỗi app. Đặt cái thứ 65 thì cái cũ nhất bị đẩy ra, âm thầm.

Với 5 SIM (mỗi SIM 2 tới 3 mục, mỗi mục 3 tới 5 mốc) cộng 10 dịch vụ, con số vượt trần dễ dàng.

Cái bẫy nằm ở chỗ **mốc xa nhất bị vứt trước**. Với thang nhắc của giấy tờ (180, 90, 60, 30 ngày), chính những cảnh báo sớm nhất trên mục quan trọng nhất là thứ biến mất.

Nên phần đặt lịch không phải là "gọi hàm đặt thông báo cho từng mục", mà là **một bộ phân bổ có giới hạn, chạy lại từ đầu mỗi lần**:

1. **Chạy lại toàn bộ** mỗi khi: mở app, app vào tiền cảnh, sửa bất kỳ mục nào, và khi hệ thống báo đổi múi giờ hoặc đổi giờ đáng kể.
2. **Xóa sạch rồi tính lại**, không cộng dồn vào lịch cũ.
3. **Xếp hạng theo mức rủi ro giảm dần, rồi tới ngày tăng dần.** Mục Mức 1 được cấp trọn thang nhắc trước khi mục Mức 2 được cấp mốc thứ hai.
4. **Chỉ đặt 50 cái, chừa 14 chỗ trống.** Không dùng hết 64 để còn chỗ cho thông báo phát sinh.
5. **Chỉ xét các mốc trong 60 ngày tới.**
6. **Không bao giờ dùng trigger lặp lại** của iOS, vì nó không cho phép nội dung khác nhau theo từng lần.
7. **Nếu phải cắt, ghi lại và hiện cảnh báo trong Cài đặt.** Cắt âm thầm là đúng kiểu lỗi mà mục 7.1 nói tới.

Thêm `BGAppRefreshTask` để iOS tự chạy nạp lại trong nền. Nói thật là iOS tự quyết khi nào chạy và không đảm bảo đúng giờ, nên đây là lớp phòng hờ, lớp chính vẫn là nạp lại lúc mở app.

### 7.3bis Những cách thông báo chết âm thầm

Ngoài giới hạn 64, có bốn cách khác khiến thông báo đã đặt đúng vẫn không tới tay người dùng. Cả bốn đều tạo ra đúng đánh giá một sao ở mục 7.1.

| Nguyên nhân | Biểu hiện | Cách xử lý |
|---|---|---|
| Không giữ tham chiếu tới delegate | Thuộc tính `delegate` là weak, đối tượng khai báo cục bộ bị thu hồi, callback ngừng chạy | Giữ delegate trong một singleton sống suốt vòng đời app |
| Không trả về tùy chọn hiện banner trong `willPresentNotification` | Thông báo bị nuốt im lặng khi app đang mở | Trả về banner và sound tường minh |
| Người dùng bấm "Không cho phép" một lần lúc cài | App thành danh sách trang trí, mà nhìn vẫn như đang chạy | Banner thường trực không tắt được, kèm nút mở thẳng Cài đặt |
| Chế độ Tập trung, Không làm phiền, hoặc Tóm tắt theo lịch | Thông báo bị dồn lại hoặc chặn | Dùng mức Time Sensitive cho Mức 1 và Mức 2 |

Ba cái đầu là lỗi lập trình, cái cuối là hành vi hệ điều hành. Cả bốn đều phải có test hoặc kiểm tra thủ công trước khi phát hành.

### 7.4 Hành động ngay trên thông báo

Không cần mở app. Giữ tay lên thông báo hiện ra:

- **Đã xong** ghi một `HandledEvent`, tính ngày đến hạn kế tiếp, hủy các mốc còn lại của chu kỳ này.
- **Hoãn một ngày** dời đúng 24 giờ.
- **Bỏ qua kỳ này** cho các mục lặp lại, không ghi là đã trả.
- **Nút hành động** mở `actionUrl` nếu mục có.

Ràng buộc kỹ thuật quan trọng: **notification category phải được đăng ký lúc app khởi động, trước khi đặt bất kỳ thông báo nào tham chiếu tới nó.** Sai thứ tự thì thông báo hiện ra không có nút, im lặng.

Quy tắc kèm theo: **mục Mức 1 không tự biến mất**. Vuốt bỏ thông báo không tính là đã xử lý. Ngày mai nó quay lại, tới khi bấm "Đã xong".

Ngoài ra, đặt **số đếm trên biểu tượng app** bằng số mục quá hạn cộng số mục tới hạn hôm nay. Đây là thứ người dùng các app khác đòi nhiều lần mà chưa ai làm tử tế.

### 7.5 Nhắc đối chiếu

Đây là cơ chế riêng, tách hẳn khỏi nhắc hạn, và nó tồn tại vì một lỗ hổng thật:

**App chỉ biết cái người dùng gõ vào.** Nó không đọc được ngày thật từ nhà cung cấp. Với những thứ mà ngày hết hạn dời đi theo hành vi, ví dụ hạn SIM trả trước dời ra mỗi lần nạp tiền, con số trong app từ từ sai đi mà không có gì báo.

Nên mục Mức 1 có thêm `verifyEveryDays`, mặc định 60. Cứ đủ 60 ngày kể từ `lastVerifiedAt`, app hỏi: *"Ngày này bạn xác nhận từ tháng 6, đã kiểm tra lại chưa?"* kèm nút mở `actionUrl` nếu mục có.

Một giới hạn kỹ thuật cần biết nếu `actionUrl` là mã điện thoại: iOS không cho app tự động quay mã USSD, đây là chặn có chủ đích từ 2012 sau một lỗ hổng cho phép trang web xóa máy bằng mã USSD. App điền sẵn được mã, nút gọi vẫn phải người dùng bấm.


---

## 8. Nhập liệu bằng ảnh

### 8.1 Phạm vi và nguyên tắc

Tính năng này **phá vỡ nguyên tắc hoàn toàn ngoại tuyến**, nên phải khoanh vùng rõ:

- Đây là **đường mạng duy nhất bắt buộc** của app (tỷ giá là tùy chọn).
- Nó là **đường phụ**, không phải đường nhập chính. Form nhập tay vẫn là chính và phải thật nhanh.
- Nó **không bao giờ ghi thẳng vào dữ liệu**. Nó chỉ điền sẵn form để người dùng xác nhận.

Nguyên tắc thứ ba là bắt buộc, không phải tùy chọn. Một ngày bị đọc sai trên mục Mức 1 nghĩa là mất số điện thoại. Ngày tháng lại đúng là chỗ mô hình ngôn ngữ sai nhiều nhất.

### 8.2 Bốn nguồn ảnh

| Nguồn | Đặc điểm | Độ khó |
|---|---|---|
| Ảnh chụp email xác nhận | Chữ rõ, bố cục chuẩn, tiếng Anh | Dễ nhất |
| Ảnh chụp trang quản lý subscription | Chữ rõ, nhưng nhiều thông tin nhiễu xung quanh | Dễ |
| Ảnh chụp SMS nhà mạng | Tiếng Việt, viết tắt nhiều, ngắn | Khó, cần prompt riêng |
| Ảnh chụp giấy tờ, hóa đơn giấy | Chụp ngoài đời, nghiêng, lóa, bóng | Khó nhất |

Vì bốn nguồn khác nhau về bản chất, quá trình bóc tách chia **hai tầng**: phân loại ảnh trước, rồi mới bóc dữ liệu theo schema tương ứng.

### 8.2bis Đọc chữ trên máy trước, chỉ gửi chữ đi

iOS có sẵn bộ đọc chữ chạy trên máy (Vision framework), miễn phí, hỗ trợ tiếng Việt. Nó **đọc được chữ nhưng không suy luận được** rằng chữ nào là ngày hết hạn, chữ nào là giá tiền. Việc suy luận vẫn cần mô hình ngôn ngữ.

Ghép hai thứ lại cho ra một phương án tốt hơn cả hai hướng ban đầu:

```
Ảnh → đọc chữ trên máy → người dùng xem và che → gửi chữ cho OpenAI → điền form
```

**Đã kiểm chứng: viết được hoàn toàn bằng Kotlin, không cần một dòng Swift nào.**

`platform.Vision` nằm trong bộ thư viện nền tảng đi kèm Kotlin/Native (tệp `Vision.def` ở trạng thái bật, không phải `.disabled`). Hơn 20 dự án công khai đang gọi `VNRecognizeTextRequest` từ `iosMain`, trong đó có vài app đọc hóa đơn. Đây là đường đã có người đi, không phải giả thuyết.

Lý do chọn phương án này, xếp theo giá trị thật:

1. **Ảnh không bao giờ rời khỏi máy.** Chỉ có chữ được gửi đi, và người dùng thấy đúng cái sắp gửi.
2. **Che thông tin an toàn hơn hẳn.** Xem mục 8.3.
3. **Rẻ hơn, nhưng không nhiều như tôi tưởng.** Chênh lệch thật khoảng 3 lần, tức là 2,60 đô so với 7,72 đô cho 10.000 lần bóc mỗi tháng. **Tiền không phải lý do để chọn phương án này.** Riêng tư mới là.

Cái mất là thông tin về bố cục hai chiều. Chuyện này có số liệu đo được, và kết quả khác với trực giác.

**Với ảnh chụp màn hình, mất bố cục gần như không thiệt hại gì.** Trên bộ dữ liệu WebSRC gồm nội dung trang web, tức là thứ gần nhất với ảnh chụp email và trang billing, điểm số của văn bản thường là 80,5 còn văn bản đã dựng lại bố cục là 80,7. Chênh lệch nằm trong khoảng nhiễu.

**Và với hóa đơn, dựng lại bố cục còn làm kết quả tệ hơn.** Trên bộ dữ liệu hóa đơn SROIE, văn bản thường đạt 79,9 còn văn bản dựng lại bố cục chỉ đạt 77,0. Hóa đơn vốn đơn giản và gần như một cột, nên việc dựng lại bố cục thêm nhiễu nhiều hơn thêm tín hiệu.

Kết luận thực dụng: **chỉ cần sắp xếp các dòng theo tọa độ trên rồi trái, ghép lại bằng xuống dòng. Không chèn tọa độ, không dựng lưới khoảng trắng.** Cách đơn giản nhất cũng là cách tốt nhất cho đúng loại ảnh mà app này xử lý.

Bố cục chỉ thật sự quan trọng với biểu mẫu nhiều cột dày đặc, thứ app này không gặp.

### 8.2bis-2 Toàn bộ sai sót nằm ở khâu đọc chữ

Một con số quyết định hướng đầu tư công sức: khi đưa **văn bản hoàn hảo** cho mô hình ngôn ngữ để dựng ra JSON, độ chính xác đạt **99,51%**. Trong khi bộ đọc chữ tốt nhất trên thị trường chỉ đạt khoảng 86%.

Nghĩa là gần như toàn bộ sai sót đến từ khâu đọc chữ, không phải từ khâu suy luận. Hệ quả:

- **Đừng tốn công chỉnh prompt.** Tốn công vào chất lượng ảnh đầu vào và cấu hình bộ đọc chữ.
- **Kiểm tra chất lượng đọc chữ tiếng Việt là việc quan trọng nhất** trước khi chốt phương án này.

### 8.2bis-3 Ảnh chụp giấy tờ là ngoại lệ

Có một nghịch lý cần xử lý. Dữ liệu đo cho thấy lợi thế của việc gửi thẳng ảnh **thay đổi theo chất lượng tài liệu**:

| Loại tài liệu | Gửi ảnh hơn đọc chữ trước bao nhiêu |
|---|---|
| Ảnh chụp màn hình, chữ số hóa sắc nét | +0,057 |
| Ảnh chụp giấy ngoài đời | +0,127 |

Tức là **trường hợp gửi ảnh có lợi nhất lại chính là trường hợp riêng tư nhất**: ảnh chụp hộ chiếu, bằng lái, hóa đơn giấy.

Cách xử lý, không hy sinh bên nào:

1. **Luôn thử đọc chữ trên máy trước**, với mọi loại ảnh.
2. **Nếu độ tin cậy đọc chữ thấp** (ảnh nghiêng, lóa, chữ nhòe), app nói rõ và **hỏi** người dùng có muốn gửi ảnh gốc không, kèm công cụ che vùng.
3. **Không bao giờ tự động chuyển sang gửi ảnh.** Người dùng phải chủ động đồng ý từng lần.

Với ba nguồn còn lại (email, trang billing, tin nhắn nhà mạng), đọc chữ trên máy là đủ và không cần hỏi gì thêm.

Bốn thiết lập bắt buộc, mỗi cái đều có lý do cụ thể:

| Thiết lập | Giá trị | Vì sao |
|---|---|---|
| `recognitionLevel` | `accurate` | Mức `fast` dùng thuật toán khác, nhận từng ký tự một, kém hẳn với chữ nghiêng hoặc phông lạ |
| `usesLanguageCorrection` | `false` | Sửa chính tả giúp văn xuôi nhưng **làm hỏng số tiền và mã số tham chiếu** |
| `recognitionLanguages` | lấy từ `supportedRecognitionLanguages()` lúc chạy | Xem cảnh báo bên dưới |
| `minimumTextHeight` | không đặt | Đặt vào sẽ âm thầm bỏ qua dòng chữ nhỏ, tức là phần chú thích trên hóa đơn |

**Cảnh báo về mã ngôn ngữ tiếng Việt:** Vision báo tiếng Việt là `vi-VT` trên một số phiên bản chứ không phải `vi-VN`. Hai dự án thật phải tự xử lý chuyện này. Không được viết cứng mã ngôn ngữ, phải hỏi `supportedRecognitionLanguages()` lúc chạy rồi chọn mã máy thật sự báo về.

Thêm một cái bẫy nữa: **mặc định Vision chỉ đọc tiếng Anh.** Phải đặt `recognitionLanguages` tường minh, nếu không thì chữ tiếng Việt bị bỏ qua hoàn toàn.

**Và Vision âm thầm bỏ sót dòng.** Một bộ thư viện thương mại đang chạy thật ghi lại trong mã nguồn: bộ nhận dạng thỉnh thoảng bỏ qua những dòng nó không đọc chắc, hay gặp ở đoạn văn xuống dòng và chỗ nhiều dấu câu. Cách họ xử lý là chạy thêm một lượt **chỉ dò hình học** (`VNDetectTextRectanglesRequest`), rẻ hơn nhiều, để bắt những vùng trông giống chữ mà lượt đọc đã bỏ qua.

Với app này, lượt dò hình học đó không dùng để đọc chữ, mà dùng để **cảnh báo người dùng rằng có vùng chữ chưa được đọc**, kèm gợi ý chụp lại rõ hơn.

Tiếng Việt được hỗ trợ từ iOS 17. Máy chạy iOS thấp hơn thì rơi về phương án gửi thẳng ảnh.

**Còn một việc phải thử trước khi chốt:** chất lượng đọc chữ tiếng Việt có dấu trên ảnh chụp thật. Không có ai đo cái này công khai. Cần thử 20 tới 30 ảnh chụp thật của chính người dùng trước khi cam kết.

### 8.2ter Mô hình ngôn ngữ chạy trên máy: chưa dùng được

iOS 26 có Foundation Models, mô hình ngôn ngữ khoảng 3 tỷ tham số chạy ngay trên máy, miễn phí, hoạt động cả khi không có internet, và có cơ chế ép định dạng đầu ra rất chặt. Tiếng Việt được hỗ trợ từ iOS 26.1.

Nhưng chưa dùng được cho app này, vì bốn lý do:

- **Chỉ có API Swift.** JetBrains ghi hẳn lý do trong tệp cấu hình: *"Disabled: Swift-only framework"*. Không có header Objective-C nên Kotlin không có cách nào chạm tới, kể cả viết cấu hình cinterop thủ công. Bắt buộc phải có một lớp cầu nối Swift.
- **Yêu cầu iOS 26 và máy chạy được Apple Intelligence**, còn giới hạn theo khu vực.
- **Không chạy trong máy ảo giả lập**, nên vòng lặp phát triển bị chậm hẳn.
- **Cửa sổ ngữ cảnh nhỏ và schema ăn vào chính cửa sổ đó.** Apple còn có hẳn một trang tài liệu hướng dẫn sửa prompt mỗi khi model lên phiên bản mới, nghĩa là hành vi không ổn định giữa các bản iOS.

Xếp vào nhóm cân nhắc sau, làm tùy chọn cho người thích riêng tư tuyệt đối, không làm đường mặc định.

### 8.3 Riêng ảnh giấy tờ: cảnh báo quyền riêng tư

Hộ chiếu, bằng lái là dữ liệu cá nhân nhạy cảm. Gửi lên OpenAI nghĩa là số giấy tờ và ngày sinh rời khỏi máy.

Thêm nữa, ảnh chụp SMS ngân hàng hay email hóa đơn thường có kèm số dư tài khoản, bốn số cuối thẻ, mã OTP, địa chỉ. Người dùng đồng ý cho "quét ảnh hóa đơn", không đồng ý cho "gửi số dư tài khoản sang một API ở Mỹ".

Bốn biện pháp bắt buộc:

1. **Màn hình xác nhận nêu đích danh cái gì sẽ rời khỏi máy**, không phải một dòng chấp thuận chung chung.
2. **Cho che trước khi gửi**, theo cách ở mục 8.3bis.
3. **Không lưu ảnh lại** sau khi bóc xong.
4. **Không quét nền, không quét cả thư viện ảnh.** Mỗi lần gửi đều do người dùng chủ động.

### 8.3bis Che chữ, không bôi mờ ảnh

Đây là chỗ trực giác dẫn tới lựa chọn sai, nên nói rõ.

**Bôi mờ hoặc làm vỡ hạt chữ không phải là che, vì nó khôi phục lại được.**

Công cụ Unredacter của Bishop Fox khôi phục được chữ đã làm vỡ hạt, bằng cách đoán từng ký tự rồi so lại với ảnh. Nguyên nhân gốc: làm vỡ hạt chỉ là lấy trung bình từng ô, mỗi điểm ảnh chỉ ảnh hưởng tới ô của chính nó, không có sự khuếch tán. Kết luận của tác giả nguyên văn:

> *"Khi cần che chữ, hãy dùng thanh đen phủ kín. Đừng bao giờ dùng thứ gì khác. Không làm vỡ hạt, không làm mờ, không xoáy."*

Đây không phải chuyện phòng thí nghiệm. Đại học Princeton quét 1,8 triệu tài liệu tòa án Mỹ, tìm được **194 trường hợp che hỏng đã xác nhận**, làm lộ bí mật kinh doanh, hồ sơ y tế, tên nhân chứng và danh tính bồi thẩm đoàn. Gần đây nhất là vụ công bố hồ sơ Epstein tháng 12 năm 2025, nội dung bôi đen lấy lại được chỉ bằng cách chép và dán.

**Riêng công cụ Markup có sẵn của iOS còn là một cái bẫy cụ thể:** bút dạ quang của nó hơi trong suốt. Tô hai ba lớp thì mắt người thấy đặc, nhưng chỉ cần mở ảnh trong một app chỉnh sửa rồi tăng sáng là chữ hiện lại. Đây là lỗi có thật, được ghi nhận nhiều lần ngoài đời.

### Cách làm đúng: che ở tầng chữ, vẽ dấu che lên ảnh

Vì đã đọc chữ trên máy rồi, có một cách vừa an toàn hơn vừa dễ làm hơn:

> Người dùng chạm lên vùng chữ **trên ảnh**, app vẽ vệt che đúng chỗ đó. Nhưng **thứ thật sự gửi đi là chuỗi chữ đã bị cắt bỏ**, không phải ảnh.

Hàm cầu nối làm được việc này là `VNRecognizedText.boundingBox(for:)`, có từ iOS 13, cho phép đổi một đoạn ký tự trong chuỗi thành một hình chữ nhật trên ảnh.

**Điểm mạnh quyết định của cách này: nó an toàn theo cấu trúc, không phải nhờ làm cẩn thận.** Mọi kiểu lộ thông tin khi che ảnh đều xuất phát từ việc dữ liệu gốc vẫn được gửi đi. Nếu chỉ gửi một chuỗi chữ thì không còn dữ liệu gốc nào để lộ. Và nếu bộ đọc chữ bỏ sót một dòng, dòng đó **cũng không được gửi đi**, tức là bỏ sót thành vô hại chứ không thành lỗ hổng.

### Gợi ý tự động chỉ là gợi ý

App gợi ý sẵn những đoạn nên che, nhưng **không bao giờ được coi đó là đủ**. Bằng chứng:

- Trên bộ dữ liệu WebPII gồm gần 45.000 ảnh giao diện có chú thích, ngay cả mô hình chuyên dụng vẫn **bỏ sót khoảng 25%** vùng chứa thông tin cá nhân. Cách dựa trên trích xuất chữ bỏ sót tới 64%.
- Presidio, thư viện che thông tin cá nhân phổ biến nhất, tự ghi trong tài liệu: *"không có gì bảo đảm Presidio sẽ tìm ra hết thông tin nhạy cảm"*.
- Bộ lọc thông tin nhạy cảm của Windows Recall vẫn để lọt số thẻ tín dụng dù đã bật, trong thử nghiệm của báo chí.

Nên gợi ý tự động là để **tiết kiệm thao tác**, còn quyết định cuối cùng luôn là của người dùng, và màn hình phải nói rõ điều đó.

**Cảnh báo về phiên bản iOS:** bộ nhận dạng dữ liệu có sẵn của iOS chia làm hai đời rất khác nhau.

| API | Từ iOS | Nhận được gì |
|---|---|---|
| `NSDataDetector` | 4 | Ngày, địa chỉ, liên kết, số điện thoại. **Không có email, không có số tiền** |
| `DataDetector` trên chuỗi bất kỳ | **26** | Thêm email, số tiền, mã thanh toán, số vận đơn |

Đời sau chỉ dùng được từ iOS 26. Trên các bản thấp hơn phải dùng `NSDataDetector` cộng với biểu thức chính quy tự viết cho email và dãy số giống số thẻ.

### Nếu buộc phải gửi ảnh

Trường hợp máy chạy iOS cũ hoặc đọc chữ thất bại, và người dùng đồng ý gửi ảnh gốc. Khi đó ba việc bắt buộc, thiếu một là lộ:

1. **Xóa thật dữ liệu điểm ảnh** ở vùng che, tô đặc, không vẽ một lớp đè lên.
2. **Kết xuất lại toàn bộ ảnh** thành tệp mới, không ghi đè lên tệp cũ. Lỗi aCropalypse trên điện thoại Pixel và công cụ Snipping Tool của Windows chính là do ghi đè: tệp mới ngắn hơn nên phần đuôi của ảnh gốc còn nguyên trong tệp và lấy lại được.
3. **Xóa dữ liệu mô tả kèm ảnh.** Che điểm ảnh không đụng gì tới phần mô tả này. Tệ hơn, **ảnh thu nhỏ nhúng bên trong có thể vẫn là ảnh gốc chưa che**. Đã có trường hợp che biển số xe mà ảnh thu nhỏ vẫn hiện nguyên biển số.

Trên iOS, `UIImage` vốn không mang theo dữ liệu mô tả, nên vẽ lại ảnh rồi xuất ra tệp sẽ xóa phần đó như một tác dụng phụ. Nhưng đây là hành vi tình cờ, không phải cam kết trong tài liệu, nên **phải có test khẳng định điều này**.

### 8.4 Chọn mô hình và cách gọi

Dùng **Responses API** của OpenAI (`POST /v1/responses`), không dùng Chat Completions. Đây là endpoint được khuyến nghị hiện tại cho phân tích ảnh.

Mô hình mặc định: **`gpt-5.6-luna`**. Chi phí khoảng **0,0008 đô mỗi ảnh**, tức hơn 1.300 lần bóc cho mỗi đô. Có thể cho tùy chọn `gpt-5-nano` rẻ hơn (0,00024 đô) nhưng chênh lệch quá nhỏ để đánh đổi độ chính xác trên một tác vụ mà đọc sai ngày là hỏng việc chính của app.

Ảnh gửi dưới dạng **base64 data URL** trong thân request, không dùng URL công khai. Nội dung hóa đơn của người dùng không được đặt ở nơi ai cũng tải được.

Ba tham số dễ sai và mỗi cái tốn tiền thật:

| Tham số | Đặt thành | Vì sao |
|---|---|---|
| `detail` | `"high"` (đặt tường minh) | Với dòng 5.6, `auto` nghĩa là gửi ảnh nguyên độ phân giải không giới hạn. Ảnh 4K tốn gấp ba lần cần thiết. Không dùng `"low"` vì nó nén quá mạnh, số tiền và ngày tháng nhòe đi. |
| `reasoning.effort` | `"low"` | Token suy luận được tính tiền như token đầu ra. Để mặc định `medium` là khoản tốn nhất trong một request vốn không cần suy luận. |
| `max_output_tokens` | 800 | Và **phải kiểm tra `response.status`** trước khi parse. JSON bị cắt giữa chừng thì không parse được, không phải parse ra một phần. |

### 8.5 Schema: chỗ quyết định chất lượng

Structured Outputs của OpenAI bắt **mọi trường phải nằm trong `required`**. Đây là nguồn ảo giác số một cho tác vụ này:

> Nếu khai `next_charge_date` kiểu `string`, mô hình **bắt buộc** phải trả về một ngày, kể cả khi ảnh không hề có ngày nào. Nó sẽ bịa ra.

Nên **mọi trường đều phải nullable** (`{"type": ["string", "null"]}`), kể cả enum thì cũng phải có `null` trong danh sách.

Biện pháp chống bịa mạnh nhất: **mỗi trường dữ liệu đi kèm một trường trích nguyên văn**. Mô hình phải chép lại đúng từng ký tự đoạn chữ nó nhìn thấy trong ảnh. App kiểm tra chéo phía client: nếu có số tiền mà đoạn trích rỗng thì loại bỏ kết quả. Mô hình bịa ít hơn hẳn khi bị buộc phải chỉ vào bằng chứng, và đây cũng là thứ hiện lên giao diện để người dùng đối chiếu.

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["source_type", "service_name", "service_name_raw",
               "amount_minor", "amount_raw", "currency_code", "currency_symbol_raw",
               "billing_cycle", "billing_cycle_raw",
               "due_date_iso", "due_date_raw", "date_format_detected", "confidence"],
  "properties": {
    "source_type":       { "type": "string",
                           "enum": ["billing_email", "subscription_page", "carrier_sms", "document", "unknown"] },
    "service_name":      { "type": ["string", "null"] },
    "service_name_raw":  { "type": ["string", "null"] },
    "amount_minor":      { "type": ["integer", "null"] },
    "amount_raw":        { "type": ["string", "null"] },
    "currency_code":     { "type": ["string", "null"], "enum": ["VND", "USD", null] },
    "currency_symbol_raw": { "type": ["string", "null"] },
    "billing_cycle":     { "type": ["string", "null"],
                           "enum": ["weekly", "monthly", "quarterly", "yearly", "one_time", null] },
    "billing_cycle_raw": { "type": ["string", "null"] },
    "due_date_iso":      { "type": ["string", "null"], "format": "date" },
    "due_date_raw":      { "type": ["string", "null"] },
    "date_format_detected": { "type": "string",
                           "enum": ["MDY", "DMY", "YMD", "textual_month", "ambiguous", "absent"] },
    "confidence":        { "type": "string", "enum": ["high", "medium", "low"] }
  }
}
```

Ở Responses API, tham số là `text.format` với `type: "json_schema"`, `name`, `schema`, và `strict: true`. Tên `name` nằm ngang hàng với `schema`, không lồng trong một lớp `json_schema` như phiên bản cũ.

### 8.6 Ngày tháng mập mờ

`03/04/2026` là mùng 3 tháng 4 hay mùng 4 tháng 3? Thông tin này **không có trong ảnh**, nên không viết prompt dài hơn để giải quyết được. Bốn biện pháp kết hợp:

1. **Tách trường.** `due_date_raw` (nguyên văn) + `due_date_iso` (ngày chuẩn hóa, nullable) + `date_format_detected`. Khi mô hình trả về `"ambiguous"`, đặt `due_date_iso` bằng null và để giao diện hỏi người dùng.
2. **Đưa ngày hôm nay vào prompt.** Ngày đến hạn phải nằm ở tương lai, điều này loại bỏ một trong hai cách đọc trong phần lớn trường hợp.
3. **Đưa locale của máy vào prompt.** Máy đặt tiếng Việt thì `03/04` gần như chắc chắn là ngày 3 tháng 4.
4. **Dùng tiền tệ làm căn cứ chéo.** Số tiền bằng đồng là bằng chứng mạnh cho định dạng ngày trước tháng.

Ưu tiên tuyệt đối cho tháng viết bằng chữ ("Apr 3, 2026"), vì nó không mập mờ.

### 8.7 Xử lý lỗi khi người dùng tự cắm API key

Đây là phần hay bị làm ẩu và người dùng chịu hậu quả.

**Mã 429 gộp năm tình huống khác nhau, ba trong số đó không bao giờ thử lại được.** Phải rẽ nhánh theo `code` trong thân lỗi, không theo mã HTTP:

| Tình huống | Xử lý | Thông điệp |
|---|---|---|
| `rate_limit` thật | Thử lại, tôn trọng `Retry-After` | "Đang bận, thử lại sau vài giây" |
| `credit_balance_exhausted` | **Không bao giờ thử lại** | "Tài khoản OpenAI hết tiền, cần nạp thêm" |
| `*_spend_limit_exceeded` | **Không bao giờ thử lại** | "Đã chạm giới hạn chi tiêu bạn đặt trên OpenAI" |
| 401 | Không thử lại | "API key không đúng hoặc đã bị thu hồi" |
| 403 | Không thử lại | "Khu vực chưa được hỗ trợ" |
| 500, 503 | Thử lại, giãn dần | "Máy chủ OpenAI đang lỗi" |

Coi mọi 429 là "chờ rồi thử lại" sẽ làm app treo vô tận với người dùng hết tiền. Còn 401 sẽ là lỗi phổ biến nhất khi người dùng tự nhập key.

Ngoài ra, đọc `x-ratelimit-remaining-tokens` từ header phản hồi. OpenAI không còn công bố giới hạn theo bậc trong tài liệu, nên đây là cách duy nhất biết được người dùng còn bao nhiêu hạn mức.

### 8.8 Lưu API key

Lưu trong **iOS Keychain**, không lưu trong `UserDefaults`.

Dùng `KeychainSettings` của thư viện `multiplatform-settings`. Cảnh báo quan trọng: hàm khởi tạo mặc định **không đặt `kSecAttrAccessible`**, nghĩa là API key sẽ nằm trong bản sao lưu iCloud. Phải truyền tường minh `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

Không dùng KVault, thư viện đó phát hành lần cuối tháng 10 năm 2023 và đã dừng phát triển.

---

## 9. Nền tảng kỹ thuật

Toàn bộ phiên bản đã kiểm chứng trên Maven Central và Google Maven ngày 15/08/2026.

| Việc | Thư viện | Phiên bản | Ghi chú |
|---|---|---|---|
| Ngôn ngữ | Kotlin | 2.4.10 | |
| Giao diện | Compose Multiplatform | 1.11.1 | iOS đã ổn định từ 1.8.0. Bản 1.11 nâng sàn lên iOS 14.0 |
| ViewModel | androidx.lifecycle | 2.11.0 | dùng được trong `commonMain` |
| Cơ sở dữ liệu | SQLDelight | 2.3.2 | xem ghi chú bên dưới |
| HTTP | Ktor + engine Darwin | 3.5.2 | Darwin dùng NSURLSession, không dùng CIO trên iOS |
| JSON | kotlinx-serialization-json | 1.11.0 | |
| Ngày tháng | kotlinx-datetime | 0.8.0 | xem cảnh báo bên dưới |
| Keychain | multiplatform-settings | 1.3.0 | |
| Chọn ảnh | FileKit | 0.15.0 | |
| Thông báo | `platform.UserNotifications` | (có sẵn) | gọi thẳng từ `iosMain`, không cần thư viện |

**Chọn SQLDelight thay vì Room.** Room vừa đổi group ID sang `androidx.room3:room3-*` phiên bản 3.0.1, nghĩa là mọi ví dụ code cũ đều sai. Room trên iOS còn bắt buộc DAO phải là hàm `suspend` và cần cấu hình KSP cho từng target. SQLDelight đã chạy trên iOS nhiều năm, vẫn được cập nhật liên tục, và `coroutines-extensions` cho ra `Flow` cắm thẳng vào `collectAsState()` của Compose.

**Cảnh báo `kotlinx-datetime` 0.7.0.** Phiên bản này **đã bỏ** `kotlinx.datetime.Instant` và `kotlinx.datetime.Clock`, chuyển sang `kotlin.time.Instant` và `kotlin.time.Clock` của thư viện chuẩn. Mọi ví dụ code cũ hơn đều sai import.

**Không dùng peekaboo** cho việc chọn ảnh. Thư viện đó phát hành lần cuối tháng 4 năm 2024, có trước khi Compose Multiplatform ổn định trên iOS. FileKit là lựa chọn đang được duy trì, và nó bọc `PHPickerViewController` bằng Kotlin thuần nên không cần viết Swift.

### 9.0bis Quyết định về widget phải ra ngay bây giờ

Widget màn hình khóa là tính năng hiển nhiên nhất người ta sẽ muốn ở một app theo dõi hạn. WidgetKit và ActivityKit **không gọi được từ Kotlin**, nên phần đó chắc chắn là Swift.

Vấn đề: gắn App Group và một kho dữ liệu Swift đọc được vào một tầng lưu trữ đã hoàn thiện là việc đắt. Nên ba quyết định này phải ra từ đầu, kể cả khi Bước 4 mới làm widget:

1. **Chọn SQLDelight** thay vì Room, vì nó tạo ra một tệp SQLite thường, Swift đọc thẳng được.
2. **Đặt cơ sở dữ liệu trong App Group container** ngay từ commit đầu tiên.
3. **Ghi thêm một bản tóm tắt "3 mục gần nhất"** vào App Group mỗi lần dữ liệu đổi, để widget không cần hiểu toàn bộ schema.

### 9.1 Phần bắt buộc phải viết bằng Swift

Gần như mọi thứ gọi được từ Kotlin. Phần Swift thật sự cần chỉ khoảng 5 tới 20 dòng:

- **Điểm khởi động app** (`iOSApp.swift` / `AppDelegate`). Apple bắt buộc gán `UNUserNotificationCenter.delegate` **trước khi app khởi động xong**, và tệp đó là Swift.
- **Đăng ký `BGTaskScheduler`** cho tác vụ nền, cũng nằm ở vòng đời `UIApplicationDelegate`.
- **Widget màn hình khóa** (WidgetKit), nếu làm. Kotlin không chạm tới được.

Ba cái bẫy khi gọi `UserNotifications` từ Kotlin:
1. Kiểm tra biến `granted` chứ không chỉ `error == null` trong callback xin quyền.
2. Giữ một tham chiếu Kotlin sống tới đối tượng delegate. Thuộc tính `delegate` là weak, delegate khai báo trong phạm vi cục bộ sẽ bị thu hồi và thông báo âm thầm ngừng hiện khi app đang mở.
3. Đăng ký notification category lúc khởi động, trước khi đặt bất kỳ lịch nào dùng tới chúng.

Cần thêm `NSCameraUsageDescription` và `NSPhotoLibraryUsageDescription` vào `Info.plist`, nếu thiếu thì app sập ngay lần chọn ảnh đầu tiên.

---

## 10. Màn hình

> Chi tiết giao diện nằm ở `design-spec.md`. Phần này chỉ liệt kê chức năng.

| # | Màn hình | Việc chính |
|---|---|---|
| 1 | **Sắp tới** | Danh sách nhóm theo mức độ gấp: Quá hạn, 7 ngày tới, 30 ngày tới, xa hơn. Các mục cùng nhóm rút thành một dòng. |
| 2 | **Thêm mục** | Form nhập tay (đường chính) và nút quét ảnh (đường phụ). Có danh sách dịch vụ dựng sẵn. |
| 3 | **Chi tiết** | Lịch sử đã xử lý, tổng đã chi, ghi chú, ngày đối chiếu gần nhất, nút hành động. |
| 4 | **Tiền** | Tổng tháng và năm, tách theo loại tiền kèm dòng quy đổi tham khảo. Biểu đồ 12 tháng tới. |
| 5 | **Cài đặt** | Khóa Face ID, giờ nhắc mặc định, API key OpenAI, tỷ giá thủ công, xuất và nhập tệp sao lưu. |

### 10.1 Nhập liệu phải nhanh

Thêm một mục mà mất hai phút thì người dùng sẽ không thêm, và app chết trong tuần đầu. Ba quy tắc:

- **Không bắt tính ngày.** Đăng ký trial thì người ta biết "hôm nay, 14 ngày" chứ không biết "29 tháng 8". Ô nhập nhận cả hai kiểu.
- **Danh sách dựng sẵn.** Chọn "Netflix" là điền sẵn chu kỳ, giá tham khảo, trang hủy, danh mục, mức rủi ro. Chọn "Thêm SIM" là tạo cả nhóm với các mục con.
- **Mặc định phải đúng.** Người dùng chỉ nên phải sửa khi trường hợp của họ khác thường.

---

## 10bis. Những sai lầm đã có người trả giá

Rút từ đánh giá của người dùng trên các app cùng ngành. Mỗi dòng là một quyết định đã làm hỏng một sản phẩm thật.

| Đừng làm | Vì sao | Nguồn |
|---|---|---|
| Danh sách dịch vụ kiểu gửi lên chờ duyệt | Người dùng gọi đó là "hố đen", gửi xong không ai báo gì. Còn là gánh nặng bảo trì vĩnh viễn | Bobby |
| Giới hạn 3 tới 5 mục cho bản miễn phí | Kiểu tính phí bị ghét nhất ngành, vì nó chặn **sau khi** người dùng đã gõ hết dữ liệu vào | nhiều app |
| Bắt trả tiền để dùng giao diện tối | Có đánh giá một sao gỡ app ngay, nêu lý do đau nửa đầu | Bobby |
| Đổi từ đồng bộ iCloud sang máy chủ riêng | Làm hỏng đồng bộ của người dùng cũ, có báo cáo mất sạch lịch sử nhiều năm | Chronicle |
| Đặt tên tính năng gợi ý là có kết nối ngân hàng | Người dùng suy diễn ra khả năng app không có, rồi đánh giá một sao | Touchbits |
| Hứa hoặc gợi ý tự động phát hiện | Mọi đánh giá một sao kiểu "hóa ra nó không tự đọc email!" đều là người dùng suy ra từ cách quảng cáo. Nói đúng: "chụp màn hình rồi điền sẵn form", không nói mạnh hơn | Bobby |
| Danh sách tiền tệ cố định trong code | Đã tốn nhiều bản phát hành chỉ để thêm bốn loại tiền một lần | Bobby |

Và một thứ đáng học về cách tính phí, nếu sau này app có bán: **không giới hạn số mục ở bản miễn phí, chỉ tính phí theo tính năng** (xuất dữ liệu, lịch sử giá).

---

## 11. Bảo mật và riêng tư

| Dữ liệu | Nơi lưu | Ghi chú |
|---|---|---|
| Danh sách mục, lịch sử | SQLite trong App Group container | Không rời khỏi máy. Đặt trong App Group ngay từ đầu để widget đọc được, xem mục 9.1 |
| API key OpenAI | iOS Keychain | Bắt buộc đặt `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Ảnh đưa vào bóc tách | Không lưu | Xóa ngay sau khi có kết quả |
| Tệp sao lưu | Người dùng tự chọn nơi lưu qua app Files | Cảnh báo rõ là tệp không mã hóa |

App khóa bằng **Face ID**, gọi qua `platform.LocalAuthentication.LAContext` từ Kotlin, không cần Swift.

### 11.1 API key phải được đối xử như thẻ thanh toán

Đây là bí mật duy nhất trong một app không có tài khoản, và nó tính tiền trực tiếp vào thẻ của người dùng.

- **Không bao giờ ghi key vào log**, không đưa vào báo cáo sự cố.
- **Không lưu trong `UserDefaults`.**
- **Có nút xóa key** hiện rõ trong Cài đặt.
- **Chặn chi tiêu vượt mức:** không thử lại vô hạn, không quét cả thư viện ảnh, không gửi ảnh nguyên độ phân giải. Thu nhỏ ảnh xuống khoảng 1200px phía client trước khi gửi.

### 11.2 Mất máy là mất dữ liệu

App không có tài khoản, không có bản trên máy chủ. Nghiên cứu chỉ ra **mất dữ liệu tự gõ là lý do bỏ app số một** trong ngành này, kể cả với những app **có** đồng bộ. Một app không đồng bộ thì rủi ro còn cao hơn.

Nên xuất và nhập dữ liệu thuộc Bước 1, không phải phần đánh bóng để sau:

- Xuất ra JSON và CSV.
- Sao lưu ghi ra tệp qua app Files, khôi phục lại được.
- **Đường khôi phục phải được kiểm thử thật**, không chỉ viết ra rồi để đó.
- Xác nhận cơ sở dữ liệu có nằm trong bản sao lưu thiết bị của iOS hay không, và **nói rõ điều đó trong giao diện** để người dùng biết mình đang tin vào cái gì.

---

## 12. Lộ trình

| Bước | Nội dung | Xong khi |
|---|---|---|
| **1** | Mô hình dữ liệu (App Group từ đầu), màn hình Sắp tới, thêm mục bằng tay, bộ phân bổ thông báo, đánh dấu đã xong, **xuất và nhập tệp** | Nhập được các SIM đang lo nhất, nhận được thông báo thật, và lấy dữ liệu ra được |
| **2** | Nút hành động trên thông báo, nhắc dai, nhắc đối chiếu, danh sách dựng sẵn, màn hình Tiền, Face ID | Dùng được hằng ngày, thay thế hẳn cách ghi chú cũ |
| **3** | Nhập bằng ảnh | Bớt được việc gõ tay |
| **4** | Widget màn hình khóa (viết Swift) | Nhìn là thấy, không cần mở app |
| **5** | Đồng bộ nhiều máy, chia sẻ | Chỉ làm nếu sau vài tháng dùng thật vẫn thấy thiếu |

Ba điều chỉnh so với dự tính ban đầu, đều từ kết quả nghiên cứu:

- **Xuất và nhập tệp lên Bước 1.** Mất dữ liệu tự gõ là lý do bỏ app số một trong ngành, và app không đồng bộ thì rủi ro cao hơn hẳn.
- **Danh sách dịch vụ dựng sẵn làm trước tính năng đọc ảnh.** Nó giải quyết cùng một vấn đề (nhập liệu tốn công) nhưng chính xác gần như tuyệt đối, không cần internet, không cần API key, không có vấn đề riêng tư, và phủ đúng danh sách dịch vụ của người dùng trong khoảng 80 dòng dữ liệu.
- **App Group ngay từ commit đầu**, dù Bước 4 mới làm widget.

Thứ tự có chủ đích: đưa app vào tay người dùng thật sớm nhất có thể, vì dùng thật mới biết thiếu gì.


---

## 13. Câu hỏi còn để ngỏ

- Tên app. "Đến Hạn" là tên tạm.
- App có bán gói trả phí của chính nó không? Nếu có thì cần StoreKit 2, và đó là API chỉ có Swift, Kotlin không gọi được. Quyết định sớm vì nó đổi cấu trúc dự án.
- Có làm Android không? Câu trả lời đổi vài lựa chọn thư viện.
