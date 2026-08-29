# Đặc tả giao diện: đưa nhắc hạn sang lịch hệ thống

Bản mô tả này để dựng thử giao diện. Chưa có dòng code nào cho tính năng, và chưa chốt sẽ
làm. Phần lý do nằm ở `docs/product-spec.md` mục 7.6.

## 0. Việc này giải quyết cái gì

Nhắc hạn của app là local notification. Chúng chết khi app bị gỡ, khi Android force-stop
app, và khi người dùng đổi điện thoại. Ghi cùng những mốc đó vào **lịch của chính người
dùng** là kênh duy nhất sống sót qua cả ba, vì lịch đồng bộ theo tài khoản của họ và app
Lịch là thứ hệ điều hành không giết để tiết kiệm pin.

Cái giá là quyền. Có hai mức, và chúng là hai tính năng khác nhau chứ không phải hai nấc
tiện lợi:

| Tầng | Quyền | Làm được | Không làm được |
|---|---|---|---|
| **1. Thêm một mục** | không cần gì | Mở giao diện thêm sự kiện của hệ thống, người dùng bấm xác nhận | Không đồng bộ, không sửa, không xoá |
| **2. Gương cả danh sách** | đọc và ghi lịch, đầy đủ | Tạo lịch riêng, ghi, sửa, xoá, giữ đồng bộ | Phải xin quyền đọc toàn bộ lịch |

Tầng 2 bắt buộc phải xin quyền đầy đủ. Không có đường tắt: mức chỉ-ghi của iOS 17 không
cho app đọc lại thứ nó vừa ghi, mà không đọc lại được thì không sửa và không xoá được, nên
mỗi lần đồng bộ lại đẻ thêm một bản trùng.

Trên một app mà lời hứa là *chỉ biết những gì bạn gõ vào*, việc xin đọc lịch là một cái giá
thật. **Nó phải được nói ra ở đúng chỗ xin, không giấu sau một cái công tắc.** Đó là lý do
tồn tại của màn S4 bên dưới.

## 1. Luật của bộ giao diện, đọc trước khi vẽ

Những điều này đã cố định trong app, không phải gợi ý:

- **Khung 390x844.** Ảnh chụp đối chiếu nằm ở `tool/shots/out/`.
- **Không có bóng đổ.** Mọi bề mặt là một đường viền trắng 1px nằm trong. Thẻ vẽ bằng bóng
  đổ sẽ biến mất trên nền gradient. Dùng `SubdockSurface`.
- **Hai bản màu sáng và tối, và bản tối không phải bản sáng đảo ngược.** Độ nổi vẽ bằng
  viền; chữ trên nền accent tô đầy thì đậm màu chứ không trắng.
- **Chữ có hai thứ tiếng, và tiếng Việt dài hơn tiếng Anh khoảng 15 tới 25 phần trăm.**
  Mọi hàng chip và mọi tray hai đoạn phải vừa bản tiếng Việt. Bảng chữ ở mục 8.
- **Màn con giữ tab bar, form thì không.** Màn S3 là màn con, tức là **còn tab bar** và có
  nút Back ở góc trái.
- **Sheet xác nhận: nút tô đầy là nút không phá huỷ.** Nút phá huỷ là chữ đỏ nhạt. Luật này
  áp cho S6, **không** áp cho S4 vì S4 không phá huỷ gì.

Thành phần đã có, dùng lại chứ đừng vẽ mới: `GroupedCard`, `DetailRow`, `DetailRow.nav`,
`SectionLabel`, `Footnote`, `AlertBanner`, `PrimaryButton`, `SecondaryButton`,
`QuietButton`, `AskLine`, `ServiceTile`.

## 2. Danh sách màn cần vẽ

| Mã | Bề mặt | Tầng |
|---|---|---|
| S1 | Nút trên màn Chi tiết | 1 |
| S2 | Hàng mới trong Cài đặt | 2 |
| S3 | Màn Lịch, sáu trạng thái | 2 |
| S4 | Sheet giải thích trước khi xin quyền | 2 |
| S5 | Sheet chọn tài khoản chứa lịch | 2 |
| S6 | Sheet tắt đồng bộ | 2 |
| S7 | Sự kiện trông thế nào trong app Lịch | cả hai |

---

## S1. Nút trên màn Chi tiết

Thêm **một** `QuietButton` vào khối `ACTIONS` của màn Chi tiết, đặt dưới
`Sửa lịch nhắc` và trên `Nhắc lại sau 3 ngày`.

Nhãn: `Thêm vào lịch`.

Bấm là hệ điều hành mở giao diện thêm sự kiện của chính nó. App không vẽ gì thêm, không có
sheet trung gian, không xin quyền. Người dùng bấm lưu hoặc bấm huỷ trong giao diện đó rồi
quay lại.

Sau khi quay lại app không biết họ đã lưu hay chưa, nên **không có toast**. Nói "Đã thêm
vào lịch" cho một người vừa bấm huỷ là đúng kiểu nói dối mà app này tránh.

Không có trạng thái nào khác. Nút luôn hiện, kể cả khi tầng 2 đang bật, vì hai thứ khác
nhau: cái này thêm một sự kiện vào lịch người dùng chọn, cái kia là gương của cả danh sách.

---

## S2. Hàng mới trong Cài đặt

Thêm một `DetailRow.nav` nhãn `Lịch`, đặt **ngay dưới hàng `Nhắc hạn`** trong thẻ đầu tiên.
Lý do đặt ở đó: hai hàng trả lời cùng một câu hỏi, làm sao lời nhắc tới được tay tôi, nên
người đi tìm cái này sẽ tìm ở chỗ có cái kia.

Cột giá trị bên phải theo trạng thái:

| Trạng thái | Giá trị |
|---|---|
| Chưa bật | `Tắt` |
| Đang bật | `24 sự kiện` |
| Bật nhưng quyền đã bị thu hồi | `Cần cấp lại quyền` |

**Thêm một `AlertBanner`** ở đầu màn Cài đặt, cùng chỗ với cảnh báo sao lưu đang có, khi
đồng bộ đang bật mà quyền đã bị thu hồi. Đây là kiểu hỏng im lặng, và im lặng ở đây nghĩa
là người dùng tin vào một bản sao không còn được cập nhật.

---

## S3. Màn Lịch

Màn con, còn tab bar, có nút Back. Cùng hình dạng với màn iCloud và màn File đang có:
`SectionLabel`, `GroupedCard` chứa các `DetailRow`, rồi `Footnote`.

Cần vẽ sáu trạng thái.

### S3a. Chưa bật

Một đoạn giải thích ngắn, rồi `PrimaryButton` **Bật đồng bộ lịch**.

Đoạn giải thích phải nói được ba điều và không nói gì thêm: ghi cái gì, ghi vào đâu, và
quan trọng nhất, **vì sao đáng làm** (nhắc hạn còn sống khi app không còn).

### S3b. Đang bật, mọi thứ bình thường

Khối `Trạng thái`, các `DetailRow` chỉ đọc:

| Nhãn | Giá trị mẫu |
|---|---|
| Lịch | `Subdock` |
| Tài khoản | `tung@viec.co (Google)` |
| Đồng bộ gần nhất | `29/08/2026 lúc 14:08` |
| Sự kiện | `24, tới 08/2029` |

Hàng **Đồng bộ gần nhất ghi tới phút, không chỉ ghi ngày.** Không ai bấm gì để lần đồng bộ
xảy ra, nên một cái ngày trơn không phân biệt được bản ghi lúc sáng với bản ghi ngay sau
lần sửa vừa rồi, mà đó chính là câu người mở màn này đang hỏi.

Khối `Việc có thể làm`, các `DetailRow.nav`:

- `Đồng bộ lại ngay`
- `Đổi tài khoản`
- `Tắt đồng bộ lịch`

`Footnote` dưới cùng: nói rằng app chỉ đụng vào lịch nó tự tạo.

### S3c. Đang đồng bộ

Giống S3b, nhưng hàng `Đồng bộ gần nhất` đổi giá trị thành `Đang ghi...`. Không có spinner
toàn màn, không có thanh tiến trình. Vẽ một trạng thái tĩnh là đủ.

### S3d. Quyền bị từ chối hoặc bị thu hồi

Đây là trạng thái phải làm cho tốt, vì nó là trạng thái người dùng sửa được.

Một `AlertBanner` ở đầu màn, rồi một `SecondaryButton` **Mở Cài đặt hệ thống**. Các hàng
trạng thái vẫn hiện, với `Đồng bộ gần nhất` giữ nguyên ngày cũ, vì cái ngày đó là sự thật:
lịch vẫn còn, chỉ là không được cập nhật thêm.

### S3e. Người dùng đã xoá lịch Subdock trong app Lịch

Một `AlertBanner` nói lịch không còn, và **công tắc tự về tắt**. App không lặng lẽ tạo lại:
xoá lịch đi là một câu trả lời, và tạo lại là cãi lại nó.

Một `SecondaryButton` **Tạo lại lịch** để họ đổi ý.

### S3f. Máy không có tài khoản lịch nào đồng bộ được

Chỉ có lịch cục bộ. Vẫn bật được, nhưng phải nói ra: **lịch cục bộ không đi đâu cả, nó chết
cùng cái điện thoại**, tức là mất đúng cái lý do người dùng bật tính năng này. Một
`Footnote` giọng cảnh báo, không phải một sheet chặn đường.

---

## S4. Sheet giải thích trước khi xin quyền

Mở khi bấm **Bật đồng bộ lịch** ở S3a, **trước** khi hệ thống hiện hộp thoại quyền. Cùng
hình dạng với `DeleteAsk` và `CancelAsk`, dùng `AskLine`.

Đây là chỗ trả giá cho việc xin quyền đọc. Ba `AskLine`, không hơn:

1. **Ghi cái gì.** Mỗi ngày đến hạn là một sự kiện, kèm nhắc trước theo đúng thang đang đặt.
2. **Ghi vào đâu.** Một lịch riêng tên Subdock, và app không đụng vào lịch nào khác.
3. **Vì sao cần quyền đọc.** Hệ điều hành không tách quyền chỉ-ghi ở mức app cần, nên để
   sửa và xoá được sự kiện của chính nó, app phải xin cả quyền đọc.

Hai nút: `Tiếp tục` tô đầy, `Để sau` chữ nhạt.

**Luật nút tô đầy là nút an toàn không áp ở đây.** Sheet này không phá huỷ gì, nó chỉ dẫn
sang một hộp thoại của hệ thống mà người dùng còn từ chối được. Nút tô đầy là `Tiếp tục`.

---

## S5. Sheet chọn tài khoản chứa lịch

Mở ngay sau khi quyền được cấp, và mở lại từ hàng `Đổi tài khoản`.

Một danh sách chọn, mỗi dòng một tài khoản: tên tài khoản, loại (Google, iCloud, Trên máy),
và một dấu chọn. Cùng hình dạng với `LanguageSheet` đang có.

Dòng loại `Trên máy` phải mang một dòng phụ nói nó không đồng bộ đi đâu. Đây là bước dễ bỏ
sót nhất của cả tính năng: mặc định của thư viện là tạo lịch ở nguồn cục bộ, và một lịch cục
bộ chết cùng cái điện thoại, tức là **mất sạch lý do làm tính năng này**.

Nếu chỉ có một tài khoản đồng bộ được thì vẫn hiện sheet, đừng bỏ qua. Người dùng cần thấy
lịch của họ sẽ nằm ở đâu.

---

## S6. Sheet tắt đồng bộ

Mở từ hàng `Tắt đồng bộ lịch`. Đây là sheet **phá huỷ**, nên luật nút tô đầy áp trở lại.

Câu hỏi thật ở đây không phải "có tắt không", mà là **"những sự kiện đã ghi thì sao"**. Bỏ
qua câu đó là để lại rác vĩnh viễn trong lịch của người dùng, và đó là kiểu hỏng tệ nhất
của tính năng này.

Một `AskLine` đếm cái sắp mất: `24 sự kiện trong lịch Subdock`.

Ba nút, theo thứ tự:

- `Giữ lịch lại`, tô đầy. Tắt đồng bộ, để nguyên các sự kiện đã ghi.
- `Xoá lịch Subdock`, chữ đỏ nhạt.
- `Huỷ`, chữ nhạt.

---

## S7. Sự kiện trông thế nào trong app Lịch

Không phải màn của app này, nhưng là thứ người dùng sẽ nhìn nhiều nhất, nên cần vẽ một
khung mô phỏng để chốt chữ.

- **Sự kiện cả ngày**, đặt vào đúng ngày đến hạn.
- **Tiêu đề:** `Netflix gia hạn` hoặc `Hộ chiếu hết hạn`, tuỳ nhóm dùng chữ *Đến hạn* hay
  *Hết hạn*, đúng như cột đếm ngược trong app.
- **Nhắc trước** đặt đúng các nấc trong `leadDays` của mục đó, ví dụ 30 ngày và 7 ngày.
  Alarm của lịch lo phần nhắc trước, nên không cần một sự kiện cho mỗi lần nhắc.
- **Phần ghi chú:** số tiền, chu kỳ, và một dòng nói sự kiện này do Subdock ghi.

### Câu hỏi cần bạn quyết, và nó là câu hỏi thiết kế chứ không phải kỹ thuật

Lịch được chia sẻ và được đồng bộ lên tài khoản, có khi là tài khoản công ty. Dòng
`Hộ chiếu hết hạn` hiện trên một lịch chung là chuyện thật, và app này theo dõi đúng loại
thứ người ta không muốn khoe.

Nên vẽ thêm một phương án tiêu đề kín đáo, để so: tiêu đề chỉ ghi `Subdock`, mọi chi tiết
nằm trong phần ghi chú. Nếu chọn phương án này thì cần một hàng bật tắt ở S3b, và cần chốt
mặc định là kín đáo hay là rõ ràng.

---

## 8. Chữ, hai thứ tiếng

Tiếng Việt dài hơn, và hai chỗ hẹp nhất là nút ở S3a và ba nút của S6.

| Chỗ | English | Tiếng Việt |
|---|---|---|
| S1 nút | Add to calendar | Thêm vào lịch |
| S2 hàng | Calendar | Lịch |
| S2 giá trị, tắt | Off | Tắt |
| S2 giá trị, bật | 24 events | 24 sự kiện |
| S2 giá trị, mất quyền | Permission needed | Cần cấp lại quyền |
| S2 cảnh báo | Calendar sync stopped. Subdock no longer has permission to update the calendar it created. | Đồng bộ lịch đã dừng. Subdock không còn quyền cập nhật cái lịch nó đã tạo. |
| S3a đoạn mở | Subdock can write your dates into your own calendar, with the same reminders. They keep arriving even if this app is removed, or if your phone is replaced. | Subdock ghi được các ngày của bạn sang lịch của chính bạn, kèm đúng những lần nhắc đó. Chúng vẫn tới kể cả khi app này bị gỡ, hoặc khi bạn đổi điện thoại. |
| S3a nút | Turn on calendar sync | Bật đồng bộ lịch |
| S3b nhãn | Calendar / Account / Last synced / Events | Lịch / Tài khoản / Đồng bộ gần nhất / Sự kiện |
| S3b giá trị sự kiện | 24, through 08/2029 | 24, tới 08/2029 |
| S3b hành động | Sync now / Change account / Turn off calendar sync | Đồng bộ lại ngay / Đổi tài khoản / Tắt đồng bộ lịch |
| S3b footnote | Subdock only ever reads and writes the calendar it created. | Subdock chỉ đọc và ghi đúng cái lịch nó tự tạo. |
| S3c giá trị | Writing... | Đang ghi... |
| S3d cảnh báo | Subdock cannot update your calendar. The events already there are unchanged, but new dates are not being written. | Subdock không cập nhật được lịch của bạn. Những sự kiện đã ghi vẫn còn, nhưng ngày mới thì không được ghi thêm. |
| S3d nút | Open system settings | Mở Cài đặt hệ thống |
| S3e cảnh báo | The Subdock calendar is gone. Sync is off. | Lịch Subdock không còn. Đồng bộ đã tắt. |
| S3e nút | Create it again | Tạo lại lịch |
| S3f footnote | This phone has no synced calendar account, so the calendar stays on the device and will not reach a new phone. | Máy này không có tài khoản lịch nào đồng bộ, nên lịch nằm lại trên máy và không sang được điện thoại mới. |
| S4 tiêu đề | Write to your calendar? | Ghi vào lịch của bạn? |
| S4 dòng 1 | Every due date becomes an all-day event, with the reminders you already set. | Mỗi ngày đến hạn thành một sự kiện cả ngày, kèm đúng những lần nhắc bạn đã đặt. |
| S4 dòng 2 | They go in a calendar of their own, named Subdock. Nothing else in your calendar is touched. | Chúng vào một lịch riêng tên Subdock. Không có gì khác trong lịch của bạn bị đụng tới. |
| S4 dòng 3 | The phone does not offer a write-only permission that can also tidy up after itself, so this asks for read access too. Subdock uses it on the Subdock calendar and nowhere else. | Điện thoại không có mức quyền chỉ-ghi mà vẫn dọn dẹp được thứ đã ghi, nên bước này xin cả quyền đọc. Subdock dùng nó đúng trên lịch Subdock, không dùng ở đâu khác. |
| S4 nút | Continue / Not now | Tiếp tục / Để sau |
| S5 tiêu đề | Where should the calendar live? | Đặt lịch này ở đâu? |
| S5 dòng phụ, cục bộ | On this device only. It will not reach a new phone. | Chỉ nằm trên máy này. Nó không sang được điện thoại mới. |
| S6 tiêu đề | Turn off calendar sync? | Tắt đồng bộ lịch? |
| S6 dòng đếm | 24 events in the Subdock calendar | 24 sự kiện trong lịch Subdock |
| S6 nút | Keep the calendar / Delete the Subdock calendar / Cancel | Giữ lịch lại / Xoá lịch Subdock / Huỷ |
| S7 ghi chú | Written by Subdock | Do Subdock ghi |

## 9. Những thứ cố ý không vẽ

- **Không hỏi lúc onboarding.** Onboarding có hai màn và cố ý không xin quyền thông báo;
  quyền lịch còn nặng hơn. Đường vào duy nhất là Cài đặt.
- **Không có thanh tiến trình khi đồng bộ.** Vài trăm sự kiện ghi trong khoảnh khắc, và
  một thanh tiến trình làm việc nhanh trông như việc chậm.
- **Không có màn xem trước danh sách sự kiện sắp ghi.** Danh sách đó chính là màn Sắp tới,
  người dùng đã có rồi.
- **Không có toast sau S1.** Xem lý do ở S1.
