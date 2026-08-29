# Nhắc hạn của Subdock: cái gì chắc chắn tới, cái gì không

Tài liệu này giải thích Subdock nhắc bạn bằng cách nào, và quan trọng hơn, **những
trường hợp nó không nhắc được**. Viết để bạn đọc và tự quyết xem còn chỗ nào chưa yên tâm.

Đây không phải tài liệu kỹ thuật cho người sửa code. Mọi thứ ở đây viết cho người dùng
app. Chỗ nào có con số thì con số đó đã được đo trên điện thoại thật, không phải chép lại
từ tài liệu của ai.

## Thuật ngữ

Năm từ dùng suốt tài liệu, định nghĩa một lần ở đây:

| Từ | Nghĩa trong tài liệu này |
|---|---|
| **cái hẹn** | Một lời dặn kiểu "ngày 01/02 lúc 08:30 hãy hiện thông báo này". App giao nó cho điện thoại giữ. |
| **hàng chờ** | Chỗ điện thoại cất các cái hẹn cho tới ngày giờ đã dặn. |
| **suất** | Một chỗ trong hàng chờ. Điện thoại chỉ nhận số lượng có hạn. |
| **nấc nhắc** | Một lần nhắc trước hạn, ví dụ "báo trước 3 ngày". Một mục có thể có nhiều nấc. |
| **nhắc lại sau hạn** | Những lần nhắc **sau** khi ngày hết hạn đã trôi qua, kiểu "vẫn chưa xong". |

## 1. Subdock không tự canh giờ

Đây là điều nền tảng, và mọi thứ còn lại là hệ quả của nó.

Subdock không chạy ngầm và không tự đếm ngày. Khi bạn thêm một mục, app tính ra ngày giờ
cần nhắc rồi **giao cái hẹn cho điện thoại giữ**, sau đó app tắt hẳn. Tới ngày, điện thoại
lấy cái hẹn ra và hiện thông báo, kể cả khi app không được mở lần nào.

Điện thoại không cho app chạy ngầm liên tục, nên đây là cách duy nhất. Và nó có nghĩa là:
**mọi giới hạn của app đều là giới hạn của cái hàng chờ đó.** Điện thoại nhận bao nhiêu cái
hẹn, giữ chúng trong bao lâu, và bỏ cái nào khi quá tải, đều do điện thoại quyết.

## 2. Bốn chỗ có thể đứt

Một lời nhắc tới được tay bạn phải đi qua bốn bước. Đứt ở bước nào cũng là im lặng.

1. **App tính đúng ngày cần nhắc.** Phần này nằm trong code của app và có bộ test khoá lại.
2. **Điện thoại nhận giữ cái hẹn.** Đây là chỗ có giới hạn số lượng.
3. **Điện thoại giữ nó cho tới ngày.** Khởi động lại máy, gỡ app, dọn dẹp bộ nhớ đều động
   tới bước này.
4. **Điện thoại hiện thông báo và bạn nhìn thấy.** Quyền thông báo, chế độ Không làm phiền,
   trình tiết kiệm pin nằm ở đây.

App chỉ nắm chắc bước 1. Ba bước còn lại thuộc về điện thoại, và việc của app là **biết
mình đang bị chặn ở đâu và nói ra**.

## 3. Giới hạn thật, đã đo trên máy

Những con số này thường được chép qua chép lại trên internet mà không ai kiểm. Nên đã đo
lại bằng một bài test chạy trên thiết bị thật, ở `integration_test/notification_ceiling_test.dart`.

| Máy | Nhận giữ tối đa | Quá thì sao |
|---|---|---|
| iPhone, iOS 26.5 | **64 cái hẹn** | Giữ 64 cái **được đưa vào sau cùng**, vứt phần đưa vào trước |
| Pixel 4 XL, Android 13 | **500 cái hẹn** | **Báo lỗi** thay vì bỏ bớt |

Ba điều rút ra, cả ba đều đã đo chứ không suy đoán:

**iPhone giữ đúng 64.** Đưa 65 thì nó giữ 64. Đưa 128 cũng chỉ giữ 64. Subdock chỉ đưa
vào 50, chừa lại 14 suất, nên không bao giờ chạm trần.

**iPhone vứt cái đưa vào trước, không vứt cái xa nhất.** Đây là chỗ trước đây tài liệu của
chính dự án ghi ngược. Hậu quả của việc ghi ngược: app đưa cái quan trọng nhất vào đầu
tiên, nên nếu có ngày nào vượt trần thì đúng những cái đó bị vứt. Đã sửa bằng cách đưa vào
theo thứ tự ngược lại, để cái đáng giữ nhất là cái được trao sau cùng.

**Android báo lỗi chứ không bỏ bớt.** Cái thứ 501 làm hệ thống ném ra một lỗi, và một lỗi
như vậy làm hỏng cả lượt đặt lịch. Nghĩa là vượt trần trên Android thì người dùng mất
**sạch** nhắc hạn chứ không mất bớt vài cái. Đây cũng là máy Google chứ không phải Samsung,
nên đó là giới hạn chung của Android chứ không phải đặc thù một hãng.

**Chưa cấp quyền thông báo thì iPhone không giữ cái nào.** Đưa 40 cái, hỏi lại thì nó nói
đang giữ 0. Quyền không chỉ chặn ở khâu hiện thông báo lên màn hình, nó chặn ngay từ khâu
nhận. Vì vậy Subdock kiểm quyền trước rồi mới đặt lịch, và chưa có quyền thì nó không đặt
gì cả, cũng không tự nhận là đã đặt xong.

## 4. Lỗ hổng lớn nhất, và cách vừa bịt

Đây là phần đáng đọc kỹ nhất, vì nó ảnh hưởng tới **mọi người dùng**, không riêng ai.

### Chuyện đã hỏng

Trước đây mỗi cái hẹn chỉ dùng **một lần**: bắn xong là biến mất khỏi hàng chờ. Và app chỉ
tính cho **kỳ đến hạn gần nhất**, không tính cho các kỳ sau.

Ghép hai điều đó lại: ai không mở app trong khoảng một chu kỳ sẽ mất hết nhắc hạn. Với gói
hàng tháng thì khoảng một tháng.

Điều dễ hiểu nhầm nhất: **chuyện này không liên quan tới trần 64.** Người có ba dịch vụ
cũng tịt sau một tháng y hệt người có ba mươi ba. Cái trần là một vấn đề khác, nhỏ hơn.

### Cách sửa

Điện thoại nhận một kiểu hẹn khác: **hẹn lặp**. Thay vì "ngày 17/09 lúc 08:30", app dặn
"ngày 17 hàng tháng lúc 08:30". Cái hẹn đó tốn đúng **một suất** và bắn mãi mãi, không cần
app chạy lại lần nào.

Điều này quan trọng và dễ bỏ qua: **trần 64 đếm số cái hẹn, không đếm số lần bắn.** Một cái
hẹn lặp chiếm một suất rồi bắn hàng trăm lần. Chính kỹ sư của Apple xác nhận điều đó trên
diễn đàn của họ.

### Nhưng không phải mục nào cũng lặp được

Đây là chỗ tôi suýt viết sai, và nó đáng để bạn kiểm lại.

Điện thoại lặp theo **một ngày cố định trong tháng**. Mà app không đặt lịch vào ngày đến
hạn, nó đặt vào **ngày đến hạn trừ đi số ngày báo trước**. Hai thứ đó không đứng yên như
nhau.

Ví dụ thật: Netflix đến hạn mùng 5, báo trước 7 ngày.

| Kỳ | Đến hạn | Ngày nhắc |
|---|---|---|
| Tháng 1 | 05/01 | 29/12 |
| Tháng 2 | 05/02 | 29/01 |
| Tháng 3 | 05/03 | **26/02** |
| Tháng 4 | 05/04 | 29/03 |

Ngày đến hạn đứng yên ở mùng 5. Ngày nhắc nhảy giữa 26 và 29 vì tháng Hai ngắn. Không có
ngày cố định nào để lặp, nên mục này **không lặp được**, dù nó là gói hàng tháng chính hiệu.

Ngược lại, đến hạn ngày 20 báo trước 3 ngày thì ngày nhắc luôn là 17. Lặp được.

App không tự suy ra bằng công thức. Nó **tính thử 14 kỳ tới** rồi xem các ngày có trùng
nhau không. Trùng thì lặp, không trùng thì thôi. Mười bốn kỳ đủ đi qua một tháng Hai và một
năm nhuận, nên nếu có chỗ lệch thì nó lộ ra.

## 5. Cái gì còn tịt sau một chu kỳ

Danh sách những mục **vẫn** mất nhắc hạn nếu bạn không mở app:

| Loại mục | Vì sao không lặp được |
|---|---|
| Gói hàng tháng có ngày nhắc rơi sang tháng trước | Ngày nhắc trôi, xem ví dụ Netflix ở trên |
| Gói hàng quý, nửa năm | Điện thoại không có kiểu lặp nào khớp |
| Chu kỳ tự gõ, ví dụ mỗi 10 ngày | Như trên |
| Trả góp có số kỳ hữu hạn | Lặp mãi thì nó đòi tiền cả sau khi trả xong kỳ cuối |
| Gói đã huỷ mà còn hạn dùng | Kỳ đã trả tiền kết thúc vào một ngày, chỉ app mở lên mới đóng được |
| Nhắc lại sau hạn | Phải nói khác nhau mỗi lần, và phải dừng ngay khi việc xong |
| Nhắc kiểm lại ngày, mỗi 60 ngày | 60 ngày không khớp kiểu lặp nào |
| Hoãn nhắc lại sau 3 ngày | Bản chất là một lần |

Ước lượng che phủ: với thang mặc định báo trước 3 ngày, khoảng **81%** ngày đến hạn lặp
được. Báo trước 7 ngày thì còn **68%**. Báo trước 30 ngày trên gói hàng tháng thì **không
ngày nào**.

**Điều đáng lo nhất không phải con số đó, mà là bạn không nhìn ra được.** Hai mục nằm cạnh
nhau trong danh sách, một cái nhắc mãi mãi, một cái tịt sau một tháng, và trên màn hình
chúng giống hệt nhau.

## 6. Rủi ro mới vừa nhận vào

Hẹn lặp không miễn phí. Trước đây không cái hẹn nào bắn hai lần, nên app **không bao giờ
nhắc thừa**. Giờ thì nhắc thừa được.

Bạn ghi nhận đã trả sớm, đổi ngày, hay huỷ gói, mà không mở app lại, thì cái nhắc vẫn tới
theo ngày cũ. Nó chỉ được sửa ở lần mở app kế tiếp.

Đó là đổi **im lặng** lấy **sai lệch**. Tôi cho là đáng, vì im lặng làm bạn mất một thứ
không lấy lại được, còn nhắc thừa chỉ tốn một cú vuốt. Nhưng đây là một cuộc đổi chác, và
bạn nên biết mình đang đổi cái gì.

## 7. Những chỗ ngoài tầm với của app

Ba trường hợp app không làm gì được, kể cả khi mọi thứ bên trên đều đúng.

**Android tự tắt app.** Trình quản lý pin của Xiaomi, Oppo, Vivo, Huawei có thể ép dừng
những app ít dùng. App bị ép dừng thì mọi cái hẹn của nó bị huỷ, và chúng không quay lại
cho tới khi người dùng tự mở app. Một app nhắc hạn mở vài lần một năm đúng là loại app dễ
bị nhắm nhất. App không phát hiện được chuyện này từ bên trong.

**iPhone dọn app ít dùng.** Nếu bạn bật *Offload Unused Apps* trong Cài đặt, iPhone có thể
gỡ phần thân app khi máy sắp hết dung lượng, giữ lại dữ liệu. App bị gỡ thì các cái hẹn mất
theo. Apple **không công bố** sau bao lâu thì một app bị coi là ít dùng; điều kiện họ nêu
là sắp hết dung lượng, không phải một khoảng thời gian. Con số "12 ngày" lan truyền trên
internet không có nguồn nào của Apple. Câu hỏi này đã được hỏi trên diễn đàn Apple
Developer từ 2018 và tới nay chưa ai của Apple trả lời.

**Người dùng tắt quyền thông báo về sau.** App phát hiện được và nói ra, nhưng không sửa hộ
được.

## 8. Vậy mục nào của bạn chắc chắn được nhắc

Bảng này là phần đáng dùng nhất khi bạn tự soát danh sách của mình.

| Loại mục | Không mở app một tháng | Không mở app một năm |
|---|---|---|
| Hộ chiếu, bằng lái, giấy tờ hạn nhiều năm | **Vẫn nhắc** | **Vẫn nhắc** |
| Gói hàng năm | **Vẫn nhắc** | **Vẫn nhắc** nếu ngày nhắc cố định |
| Gói hàng tháng, ngày nhắc cố định | **Vẫn nhắc** | **Vẫn nhắc** |
| Gói hàng tháng, ngày nhắc trôi | **Tịt** | Tịt |
| Gói hàng quý, nửa năm | Vẫn nhắc kỳ gần nhất | **Tịt** |
| SIM trả trước, nhắc lại hàng ngày sau hạn | Nhắc trước hạn vẫn tới; nhắc lại sau hạn chỉ có 14 lần | Như bên trái |

Mục hạn dài lại là mục an toàn nhất, và đó là điều ngược với trực giác. Lý do: hộ chiếu còn
500 ngày có một cái hẹn đặt sẵn cho ngày thứ 497, nằm im trong hàng chờ suốt thời gian đó,
không cần app mở lần nào. Còn Netflix hàng tháng thì phụ thuộc vào việc nó có lặp được
không.

## 9. Còn phải làm gì

Hai việc, theo thứ tự.

**Một, một chỗ nói ra tình trạng.** Hiện app chỉ nói "mục này không được đặt lịch" ở trong
màn chi tiết của đúng mục đó. Người có sáu mươi mục không có cách nào biết mười mục đang
im. Cần một chỗ ở cấp toàn app nói ra, và nói cả việc mục nào đang lặp mục nào không.

**Hai, ghi sang lịch của bạn.** Đây là thứ duy nhất bịt được hết những lỗ còn lại. Lịch
không có trần số lượng, nhận mọi ngày cụ thể mà app tính ra, đồng bộ theo tài khoản nên
sang máy mới vẫn còn, và quan trọng nhất: **sự kiện trong lịch không thuộc về Subdock**,
nên app bị gỡ, bị dọn, hay bị ép dừng thì chúng vẫn còn. Bản mô tả giao diện nằm ở
`docs/design-brief-calendar.md`.

Máy chủ đẩy thông báo và gửi email vẫn để ngỏ, không loại bỏ. Lý do và cái giá của nó ghi ở
`docs/product-spec.md` mục 7.6.

## 10. Cách tự kiểm

**Nút Gửi thử một nhắc hạn**, ở màn Nhắc hạn. Nó đi qua đúng đường mà một nhắc hạn thật đi,
chứ không phải hiện một thông báo ngay lập tức. Nó chứng minh được cả bốn bước ở mục 2 đều
thông, và nó báo lại kèm tên múi giờ, vì múi giờ sai từng làm nhắc 08:30 tới lúc 15:30.

**Bài đo trần**, nếu bạn muốn kiểm lại các con số ở mục 3 trên một máy khác:

```bash
flutter test integration_test/notification_ceiling_test.dart -d <android-device-id>

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/notification_ceiling_test.dart \
  -d <ios-device-id>
```

Bài này không bắn thông báo nào vào máy: mọi thứ nó đặt đều cho ngày cách đây một tháng trở
lên, và nó xoá sạch lúc kết thúc. Nhưng vì xoá sạch nên **các nhắc hạn thật trên máy cũng
bị xoá theo**. Mở Subdock lên một lần là chúng được đặt lại.
