# Đến Hạn: Đặc tả thiết kế giao diện

> **Không còn hiệu lực từ 23/08/2026.** Nguồn chuẩn hiện tại là
> `Subdock Handoff.dc.html` (bản chốt) cùng bản dựng tham chiếu
> `Subdock Layered.dc.html`. So với tài liệu này, những thứ đã đổi:
>
> - Nền sáng, chữ **tiếng Anh**, Be Vietnam Pro + IBM Plex Mono.
> - **Không còn trục "mức rủi ro"** (mục 2.1, 2.2 dưới đây).
> - Một item chỉ còn **một trục phân loại** `category`: Subscription · Bill ·
>   Insurance · Document · Other. Không còn `kind`, không còn 8 nhóm chi tiêu.
> - **Không còn nhóm nhiều mốc trong một đối tượng** — màn SIM group đã bỏ.
> - Chu kỳ có giới hạn ("payment 4 of 6") và hoãn nhắc là phần mới.
>
> Giữ lại để tra phần lý do đằng sau các quyết định về ngày tháng và cách đặt
> tên — những phần đó vẫn đúng.

Tài liệu này mô tả giao diện của **Đến Hạn**, app iOS theo dõi mọi thứ có ngày hết hạn. Nó dành cho người thiết kế màn hình, và đi kèm `product-spec.md` (đặc tả chức năng, giải thích vì sao có những ràng buộc dưới đây).

Đọc trước khi thiết kế: mục 1 (bối cảnh) và mục 2 (ba nguyên tắc). Phần còn lại là chi tiết từng màn hình.

---

## 1. Bối cảnh: đây không phải app quản lý chi tiêu

Điểm dễ hiểu nhầm nhất. App này nhìn giống app theo dõi subscription, nhưng công việc thật của nó khác:

> **Ngăn người dùng mất thứ họ không lấy lại được.**

Người dùng giữ nhiều SIM ở nhiều nhà mạng, trong đó có những số gần như không dùng nhưng mất là mất luôn số điện thoại dùng mười năm. So với việc đó, chuyện Netflix trừ 260 nghìn là chuyện nhỏ.

Hệ quả cho thiết kế: **hai mục trong cùng một danh sách có thể chênh nhau một nghìn lần về mức độ nghiêm trọng**, và giao diện phải nói được điều đó mà không cần người dùng đọc chữ.

### 1.1 Người dùng và bối cảnh dùng

Một người, dùng trên iPhone của chính mình. Không có tài khoản, không chia sẻ cho ai.

Hai tình huống dùng thật, và chúng rất khác nhau:

| Khi nào | Ở đâu | Cần gì |
|---|---|---|
| Nhận thông báo lúc 8:30 sáng | Đang đi làm, một tay | Hiểu trong 2 giây và xử lý ngay trên thông báo, không mở app |
| Thỉnh thoảng mở app ra xem | Rảnh, ngồi yên | Nắm được toàn cảnh, thêm mục mới, xem tiền |

Tình huống thứ nhất quan trọng hơn và xảy ra nhiều hơn. Thiết kế cho nó trước.

---

## 2. Ba nguyên tắc

### 2.1 Mức độ nghiêm trọng phải thấy được, không phải đọc được

App chia mọi thứ làm ba mức theo hậu quả nếu bỏ lỡ:

| Mức | Tên | Nghĩa | Ví dụ |
|---|---|---|---|
| 1 | **Mất luôn** | Không mua lại được bằng tiền | SIM bị thu hồi số, hộ chiếu, đăng kiểm |
| 2 | **Mất tiền** | Mất một khoản cụ thể | Trial bị tính tiền, hóa đơn trễ |
| 3 | **Chỉ cần biết** | Không mất gì | Netflix, Claude, iCloud gia hạn |

Đây là trục tổ chức chính của app. Người dùng **không tự chọn mức này**, app suy ra từ loại mục.

Yêu cầu thiết kế: ba mức phải phân biệt được bằng hình thức (màu, độ đậm, ký hiệu), không chỉ bằng nhãn chữ. Người dùng liếc một cái phải thấy ngay dòng nào nguy hiểm.

Lưu ý về màu: **màu báo mức độ nghiêm trọng là hệ màu riêng, tách khỏi màu thương hiệu của app.** Đừng lấy màu nhấn của app làm màu cảnh báo.

### 2.2 Mỗi trục phân loại sở hữu đúng một màn hình

App có ba cách nhóm dữ liệu. Quy tắc cứng để chúng không giẫm chân nhau:

| Trục | Sở hữu màn hình | Không được xuất hiện ở |
|---|---|---|
| Mức rủi ro | Sắp tới | Màn hình Tiền |
| Danh mục chi tiêu | Tiền | Màn hình Sắp tới |
| Nhóm (một cái SIM, một cái xe) | Chi tiết nhóm | Bộ lọc hay sắp xếp ở màn hình chính |

Vi phạm quy tắc này là cách những app đi trước tự làm rối chính mình. Nếu thấy cần đưa danh mục lên màn hình chính, đó là dấu hiệu thiết kế đang đi sai, không phải dấu hiệu cần thêm bộ lọc.

### 2.3 Không có ô phân loại nào trong form nhập

Form thêm mục **không có** ô chọn mức rủi ro, **không có** ô chọn danh mục. App tự điền cả hai từ tên dịch vụ. Sửa được, nhưng ở màn hình chi tiết, không phải lúc nhập.

Lý do: thêm một mục mà mất hai phút thì người dùng không thêm, và app chết trong tuần đầu.

---

## 3. Giọng và cách viết chữ

Toàn bộ chữ trong app bằng **tiếng Việt**, xưng hô trung tính, không dùng "bạn" trong nhãn nút.

| Nguyên tắc | Đúng | Sai |
|---|---|---|
| Nút nói đúng việc nó làm | "Đã nạp tiền" | "OK" |
| Nói bằng ngôn ngữ đời thường | "Còn 3 ngày" | "T-3" |
| Không hứa cái app không làm được | "Chụp màn hình rồi điền sẵn form" | "Tự động phát hiện subscription" |
| Cảnh báo nói rõ phải làm gì | "Nạp tiền không cứu được việc này. Cần xác thực danh tính." | "Cảnh báo: rủi ro" |
| Số quy đổi luôn có dấu xấp xỉ | "≈ 1.240.000 ₫" | "1.240.000 ₫" |

Nguyên tắc thứ ba quan trọng hơn nó có vẻ. Mọi đánh giá một sao kiểu "hóa ra nó không tự đọc email của tôi" đều là người dùng suy diễn ra khả năng app không có, từ cách app tự mô tả.

### 3.1 Ngày tháng

Cách viết ngày là chi tiết dễ làm mất lòng tin nhất. Đánh giá một sao nhiều nhất trong ngành này là loại "thông báo nói còn 2 tuần trong khi mai là hạn".

- Trong 7 ngày tới: viết theo số ngày còn lại ("Còn 3 ngày", "Hôm nay", "Ngày mai").
- Xa hơn: viết ngày cụ thể ("15/09").
- Quá hạn: "Quá hạn 4 ngày", chữ đậm, màu cảnh báo.
- **Không bao giờ làm tròn theo hướng làm người dùng yên tâm.** Còn 10 ngày thì viết "còn 10 ngày", không viết "khoảng 1 tuần nữa".

---

## 4. Điều hướng: ba tab

App chỉ có ba màn hình gốc, đặt ở thanh tab dưới cùng:

| Tab | Nhãn | Việc của nó |
|---|---|---|
| 1 | Sắp đến hạn | Màn hình mở app, xem mục 5 |
| 2 | Tiền | Mỗi tháng đang trả bao nhiêu, xem mục 9 |
| 3 | Cài đặt | Quyền thông báo, tỷ giá, sao lưu |

Ba chứ không phải năm. Mọi màn hình còn lại (chi tiết mục, chi tiết nhóm, thêm mục, lịch sử) đều mở ra từ một dòng hoặc một nút, nên thanh tab không phải mang một đích đến mà người dùng không có lý do thường trực để ghé.

### 4.1 Icon từng tab

Thanh tab là chỗ duy nhất trong app dùng icon. Ràng buộc: **mỗi icon phải nói được tab đó làm gì khi bị che mất nhãn chữ.** Hình trang trí thuần hình học (một hình vuông, một hình tròn) không đạt yêu cầu này, dù nhìn có gọn.

| Tab | Icon | Vì sao |
|---|---|---|
| Sắp đến hạn | Tờ lịch: khung bo góc, một gạch ngang dưới đầu khung, một chấm đặc bên trong | Câu hỏi người dùng mang vào tab này là câu hỏi về ngày |
| Tiền | Ký hiệu ₫ trong vòng tròn | ₫ là ký hiệu người Việt đọc ra "tiền" nhanh nhất. Vòng tròn để nó thành một dấu hiệu, chứ không thành một chữ cái lạc giữa hai icon vẽ |
| Cài đặt | Ba thanh trượt, mỗi thanh một núm ở vị trí khác nhau | Ba gạch ngang trơn đọc thành "menu" chứ không phải "cài đặt". Cái núm mới là thứ tạo ra khác biệt |

Icon **vẽ trong code**, không lấy từ bộ icon có sẵn. Lý do: màn hình của app gần như thuần chữ, một icon Material hay SF Symbol mang vào đây một ngôn ngữ nét vẽ khác hẳn, và nhìn ra ngay là đồ đi mượn.

Ràng buộc hình thức để ba icon thành một bộ: cùng khung 22×22, nét 2px. Riêng vòng tròn của ₫ để nét 1,5px, lấy chỗ cho chữ bên trong đủ lớn để đọc được.

Núm thanh trượt vẽ đặc, không vẽ viền khoét lỗ nền: ở cỡ 22px lỗ khoét bẹp thành khe hở, và cả icon đọc thành mấy vạch đứt.

### 4.2 Tab đang chọn

Icon của tab đang chọn dùng màu nhấn, icon còn lại dùng chữ mờ 40%. **Không dựa vào riêng màu:** nhãn chữ của tab đang chọn đồng thời sáng hơn và đậm hơn, để người khó phân biệt màu vẫn thấy mình đang ở đâu.

---

## 5. Màn hình 1: Sắp tới

Màn hình chính, mở app là thấy.

### 5.1 Việc nó phải làm

Trả lời trong hai giây: **có gì sắp chết không, và tôi cần làm gì hôm nay.**

### 5.2 Cấu trúc

Danh sách chia nhóm theo mức độ gấp, theo đúng thứ tự:

```
Quá hạn            ← nếu rỗng thì ẩn hẳn cả nhóm
7 ngày tới
30 ngày tới
Xa hơn             ← thu gọn được
```

Chia theo thời gian chứ không chia theo mức rủi ro, vì câu hỏi người dùng mang vào màn hình này là câu hỏi về thời gian. Mức rủi ro thể hiện bằng hình thức của từng dòng.

### 5.3 Một dòng gồm gì

Thông tin cần có, xếp theo độ quan trọng:

1. **Dấu hiệu mức rủi ro** (hình thức, không phải chữ)
2. **Tên mục**
3. **Còn bao lâu**
4. **Số tiền**, nếu có
5. **Dấu hiệu thuộc nhóm nào**, nếu có

Người thiết kế tự quyết cách sắp xếp. Ràng buộc: **mức rủi ro và thời gian còn lại phải đọc được khi liếc qua**, tên và tiền có thể cần nhìn kỹ hơn.

### 5.4 Nhóm rút thành một dòng

Các mục cùng một nhóm (ví dụ ba mốc hạn của SIM Viettel) **gom lại thành một dòng duy nhất**, hiện mốc gần nhất, kèm dấu hiệu cho biết bên trong còn mục khác. Bấm vào mở màn hình chi tiết nhóm.

Nếu không gom, một người có 5 SIM sẽ thấy 15 dòng gần giống nhau và màn hình mất hết ý nghĩa.

### 5.5 Khi danh sách rỗng

Hai trạng thái rỗng khác nhau, đừng dùng chung một thiết kế:

| Trạng thái | Nghĩa | Nên hiện |
|---|---|---|
| Chưa có mục nào | Người dùng vừa cài app | Hướng dẫn thêm mục đầu tiên, gợi ý các dịch vụ phổ biến |
| Có mục nhưng không có gì sắp tới | Mọi thứ đều ổn | Xác nhận yên tâm, kèm mốc kế tiếp là khi nào |

Trạng thái thứ hai là phần thưởng, nên thiết kế cho nó cảm giác dễ chịu.

### 5.6 Trạng thái cảnh báo bắt buộc

Ba trạng thái sau phải hiện ở màn hình này, không được giấu trong Cài đặt:

| Trạng thái | Vì sao bắt buộc |
|---|---|
| **Chưa cấp quyền thông báo** | Người dùng bấm "Không cho phép" một lần là app thành danh sách trang trí, mà nhìn vẫn như đang chạy bình thường. Banner thường trực, không tắt được, có nút mở thẳng Cài đặt |
| **SIM chưa xác thực danh tính** | Rủi ro mất số đang diễn ra, và nạp tiền không cứu được. Xem mục 7.3 |
| **Có mốc nhắc bị cắt do giới hạn hệ thống** | iOS chỉ giữ 64 thông báo chờ. Nếu phải cắt bớt, người dùng phải biết |

---

## 6. Thông báo: màn hình quan trọng nhất

Phần lớn tương tác với app này xảy ra trên màn hình khóa, không phải trong app. Thiết kế phần này trước, không phải sau.

### 6.1 Vì sao đây là chỗ ăn thua

Phân tích 1.744 đánh giá của 9 app cùng ngành: **thông báo không chạy hoặc chạy sai là than phiền số một**, chiếm 35% số đánh giá thấp của app dẫn đầu ngành, và lặp lại suốt sáu năm.

Và **không app nào cho xử lý ngay trên thông báo.** Đây là khoảng trống chưa ai lấp.

### 6.2 Nội dung một thông báo

Phải trả lời được ba câu mà không cần mở app: cái gì, còn bao lâu, làm gì bây giờ.

Ba nút hành động khi giữ tay lên thông báo:

| Nút | Việc |
|---|---|
| **Đã xong** | Ghi nhận đã xử lý, tự tính mốc kế tiếp |
| **Hoãn một ngày** | Dời 24 giờ |
| **Nút riêng của mục** | "Hủy Netflix" mở trang hủy, "Kiểm tra hạn" mở mã tra cứu nhà mạng |

Nút thứ ba đổi theo mục. Đây là thứ biến thông báo từ "biết rồi để đó" thành "bấm một cái là xong".

### 6.3 Mục Mức 1 không tự biến mất

Vuốt bỏ thông báo **không** tính là đã xử lý. Ngày mai nó quay lại, tới khi bấm "Đã xong".

Cần thể hiện điều này trong nội dung thông báo, để người dùng hiểu vì sao nó cứ hiện lại chứ không nghĩ app bị lỗi.

### 6.4 Số đếm trên biểu tượng app

Bằng số mục quá hạn cộng số mục tới hạn hôm nay. Người dùng các app khác đòi thứ này nhiều lần mà chưa ai làm.

---

## 7. Màn hình SIM: phần cần thiết kế cẩn thận nhất

Đây là chỗ app dễ gây hại nhất, và cũng là chỗ nó có giá trị nhất.

### 7.1 Điều tuyệt đối không được làm

**Không hiển thị một con số đếm ngược kiểu "SIM của bạn chết sau 47 ngày".**

Lý do: app chỉ biết cái người dùng gõ vào, nó không đọc được hạn thật từ nhà mạng. Và dữ liệu nền về mốc thu hồi số cực kỳ mâu thuẫn, các nguồn chênh nhau từ 10 tới 120 ngày, không có tài liệu chính thức nào của nhà mạng xác nhận.

Kiểu hỏng ở đây là kiểu tệ nhất: người dùng tin app, không làm gì, rồi mất số vĩnh viễn. Số đã bị thu hồi và cấp cho người khác thì không có đường lấy lại.

### 7.2 Thay bằng: hiện nguồn gốc của mỗi con số

Mọi ngày liên quan tới SIM đều phải kèm **nó ở đâu ra và từ bao giờ**.

Ý tưởng thiết kế: thay vì hiện một con số chắc nịch, hiện con số kèm mức độ cũ của nó. Thông tin xác nhận tuần trước và thông tin xác nhận tám tháng trước phải nhìn khác nhau.

Và **hành động chính trên màn hình này không phải "xem còn mấy ngày", mà là "đi kiểm tra lại với nhà mạng"**.

### 7.3 Ba đồng hồ, không phải một

Đây là phần khó nhất về mặt thiết kế thông tin. Một cái SIM có **ba cơ chế độc lập** đều dẫn tới mất số, và người dùng gần như chắc chắn chỉ biết cái thứ nhất:

| Đồng hồ | Nạp tiền cứu được không | Người dùng cần làm gì |
|---|---|---|
| **Hết hạn sử dụng** | Có | Nạp tiền, hoặc mua gói giữ số |
| **Chưa xác thực danh tính** | **Không** | Xác thực qua VNeID hoặc sinh trắc học |
| **Đổi máy** | **Không** | Xác thực khuôn mặt trong 30 ngày kể từ lúc đổi |

Thách thức thiết kế: **làm cho người dùng hiểu rằng nạp tiền chỉ giải quyết được một phần ba vấn đề**, mà không biến màn hình thành một bức tường cảnh báo khiến người ta bỏ qua hết.

Gợi ý hướng đi: coi mỗi đồng hồ là một mục trong danh sách kiểm tra của cái SIM đó, mỗi mục có trạng thái riêng (ổn, cần làm, không rõ). Trạng thái mặc định của xác thực danh tính là **không rõ**, không phải ổn. App không được đoán thay người dùng ở chỗ này.

Cảnh báo về đổi máy phải hiện đúng lúc người dùng đánh dấu một SIM là ít dùng, vì hành vi tự nhiên tiếp theo của họ là lấy SIM ra cắm vào máy khác để kiểm tra, và đó chính là thứ kích hoạt thu hồi.

### 7.4 Gói giữ số là hành động chính cho SIM ngủ đông

Với số gần như không dùng, lời khuyên đúng không phải nạp tiền lặt vặt mà là mua gói giữ số một lần cho cả năm.

Cần thiết kế: một hành động rõ ràng, cho từng nhà mạng, chép sẵn cú pháp tin nhắn để người dùng chỉ việc gửi.

Kèm ràng buộc: **giá của các gói này chưa xác minh được chắc chắn**, nguồn mâu thuẫn nhau. Giao diện phải hiện con số kèm dấu hiệu cần kiểm tra lại, không khẳng định như sự thật. Mỗi màn hình hướng dẫn ghi rõ lần cuối kiểm chứng là bao giờ, kèm chỗ cho người dùng sửa nếu thấy sai.

---

## 8. Màn hình Thêm mục

### 8.1 Đường chính là gõ tên

Ô đầu tiên là tên dịch vụ, có gợi ý khi gõ. Chọn một gợi ý là điền sẵn: chu kỳ, giá tham khảo, danh mục, mức rủi ro, trang hủy.

Danh sách dựng sẵn khoảng 80 dịch vụ, gồm cả quốc tế (Netflix, YouTube, Claude, OpenAI, iCloud, Spotify) lẫn Việt Nam (Viettel, VinaPhone, MobiFone, FPT Play, điện, nước).

Nếu gõ một cái tên không có trong danh sách, **lưu ngay lập tức** với biểu tượng và màu do người dùng tự chọn. Không có cơ chế gửi lên chờ duyệt. App dẫn đầu ngành làm kiểu chờ duyệt và người dùng gọi đó là "hố đen".

### 8.2 Ô nhập ngày nhận hai kiểu

Đăng ký trial thì người ta biết "hôm nay, 14 ngày" chứ không biết "29 tháng 8". Ô nhập phải nhận cả hai cách, không bắt người dùng tự tính.

### 8.3 Thêm SIM là luồng riêng

Chọn "Thêm SIM" không tạo một mục, mà tạo cả một nhóm với các mục con bên trong. Cần hỏi: nhà mạng nào, số điện thoại, và **số này có phải loại giữ để không mất không**.

Câu hỏi cuối quan trọng vì nó đổi toàn bộ cách app đối xử với cái SIM đó.

### 8.4 Đường phụ là quét ảnh

Nút quét ảnh có mặt nhưng không chiếm chỗ của đường chính.

Nguyên tắc thiết kế bắt buộc: **kết quả bóc từ ảnh không bao giờ được lưu thẳng.** Nó luôn đổ vào form để người dùng xác nhận.

Ba yêu cầu cho màn hình xác nhận:

1. **Hiện đoạn chữ gốc bên cạnh mỗi trường**, để người dùng đối chiếu với cái máy đọc được.
2. **Ngày tháng mập mờ hiện thành hai lựa chọn bấm được**, ví dụ "3 tháng 4" và "4 tháng 3", chứ không chọn sẵn một cái. `03/04` không tự giải quyết được, thông tin đó không có trong ảnh.
3. **Trường máy không chắc phải nhìn khác** trường máy chắc.

### 8.5 Màn hình che và xác nhận gửi

Ảnh được đọc chữ ngay trên máy, và **chỉ có chữ được gửi đi, không gửi ảnh**. Điều này định hình màn hình này.

Trước khi gửi, người dùng thấy một màn hình nói **đích danh cái gì sẽ rời khỏi máy**, không phải một dòng chấp thuận chung chung. Ảnh chụp SMS ngân hàng thường có số dư và bốn số cuối thẻ, ảnh hộ chiếu có số giấy tờ và ngày sinh.

**Cách che, và vì sao không dùng bôi mờ:**

Bôi mờ hoặc làm vỡ hạt chữ khôi phục lại được, nên nó không phải là che. Kết luận của người viết công cụ khôi phục nổi tiếng nhất: *"khi cần che chữ, dùng thanh đen phủ kín, đừng bao giờ dùng thứ gì khác"*.

Nghĩa là **công cụ che trong app chỉ có một kiểu: tô đặc**. Không cho chọn mờ, không cho chọn vỡ hạt, kể cả khi trông đẹp hơn. Đây là chỗ không nhường cho thẩm mỹ.

Vì đã đọc được chữ kèm tọa độ từng dòng, có cách vừa an toàn hơn vừa quen tay hơn:

> Người dùng chạm lên vùng chữ **trên ảnh** để che. App vẽ vệt che đúng vị trí đó. Nhưng thứ thật sự gửi đi là **đoạn chữ đã bị cắt bỏ**, không phải ảnh.

Nghĩa là thao tác cảm giác như bôi trên ảnh, còn mức an toàn là mức của việc xóa chữ. Người thiết kế cần làm rõ điều này trong giao diện: người dùng phải hiểu ảnh không đi đâu cả.

App tự gợi ý sẵn những đoạn nên che (số điện thoại, email, dãy số dài giống số thẻ), người dùng bỏ chọn được.

**Nhưng giao diện không được để người dùng tin rằng gợi ý là đủ.** Đo đạc trên gần 45.000 ảnh giao diện cho thấy ngay cả mô hình chuyên dụng vẫn bỏ sót khoảng một phần tư số vùng nhạy cảm. Nên gợi ý là để tiết kiệm thao tác, không phải để thay người dùng quyết. Cách viết chữ trên màn hình này phải phản ánh đúng điều đó.

Cần thêm một trạng thái: **khi máy phát hiện có vùng trông giống chữ mà đọc không ra.** Người dùng cần biết là còn chữ chưa được đọc, kèm gợi ý chụp lại rõ hơn.

**Một trạng thái nữa cần thiết kế: khi máy đọc chữ không rõ.**

Với ảnh chụp giấy tờ hay hóa đơn giấy chụp ngoài đời, việc đọc chữ trên máy có thể kém. Khi đó app hỏi người dùng có muốn gửi ảnh gốc không, vì gửi ảnh cho kết quả tốt hơn rõ rệt với loại ảnh này.

Đây là chỗ căng thẳng nhất về mặt thiết kế: **trường hợp gửi ảnh có lợi nhất lại chính là trường hợp riêng tư nhất.** Màn hình này phải nói rõ đánh đổi đó, không được dụ người dùng bấm đồng ý. Và mặc định luôn là không gửi.

---

## 9. Màn hình Tiền

### 9.1 Việc nó phải làm

Trả lời: **mỗi tháng đang trả bao nhiêu, và cho những gì.**

Đây là màn hình duy nhất danh mục chi tiêu được xuất hiện.

### 9.2 Ba tầng thông tin

```
≈ 1.240.000 ₫                      ← số lớn, tổng quy đổi, có dấu xấp xỉ
₫ 618.000  ·  $ 40,00              ← sự thật: tách theo từng loại tiền
tỷ giá 26.046 ₫/$ · cập nhật 14/08 ← nguồn và độ mới
```

Thứ tự nhấn mạnh có chủ đích: số quy đổi to nhất vì nó là thứ người ta muốn biết, nhưng **số tách theo loại tiền mới là sự thật**, và dòng tỷ giá phải luôn có mặt.

Ba quy tắc cứng:

- Số quy đổi **luôn** có dấu xấp xỉ và **luôn** kèm ngày của tỷ giá.
- VND làm tròn tới hàng nghìn.
- **Nếu tỷ giá cũ hơn 30 ngày, ẩn hẳn dòng quy đổi**, chỉ hiện số tách theo loại tiền. Một con số sai mà trông chắc chắn còn tệ hơn không có số.

### 9.3 Đã qua và sắp tới là hai thứ khác nhau

| | Đã qua | Sắp tới |
|---|---|---|
| Bản chất | Lịch sử, đã xảy ra | Dự báo |
| Có thay đổi không | **Không bao giờ** | Có |
| Hiển thị | Số chính xác | Có dấu xấp xỉ |

Phải nhìn ra được sự khác nhau này. Một app đi trước lưu tỷ giá kiểu ghi đè và hậu quả là mọi con số lịch sử đổi bốn lần một ngày, đó là cụm lỗi lớn nhất của họ.

### 9.4 Chi phí quy về tháng

Gói năm hiện kèm số tương đương mỗi tháng (299.000₫ một năm đọc thành khoảng 25.000₫ một tháng), để mục theo năm và mục theo tháng so sánh được với nhau khi liếc qua.

### 9.5 Mục không có tiền không được tính vào tổng

Hộ chiếu, đăng kiểm không phải khoản chi hàng tháng. Chúng nằm trong app nhưng phải bị loại khỏi mọi phép tính tổng chi.

---

## 10. Màn hình Chi tiết

Gồm: lịch sử các lần đã xử lý, tổng đã chi cho mục này, ghi chú cách hủy, lần đối chiếu gần nhất, nút hành động.

Đây cũng là nơi sửa được mức rủi ro và danh mục, hai thứ không có trong form nhập.

Với mục có lịch sử, cho phép **sửa số tiền thật từ sao kê**. Ngân hàng Việt Nam tính thêm phí xử lý ngoại tệ khoảng 2,27%, nên con số app tính ra luôn thấp hơn thực tế.

Ý tưởng đáng làm: **đính kèm ảnh chụp làm bằng chứng**. Với SIM, đính ảnh tin nhắn nhà mạng báo hạn sử dụng chính là thứ làm cho một ngày do người dùng tự nhập trở nên đáng tin.

---

## 11. Ràng buộc kỹ thuật ảnh hưởng tới thiết kế

| Ràng buộc | Ảnh hưởng |
|---|---|
| Compose Multiplatform, tối thiểu iOS 14 | Không dùng được thành phần chỉ có ở iOS mới |
| Chạy hoàn toàn ngoại tuyến, trừ lúc quét ảnh và cập nhật tỷ giá | Không có màn hình tải, không có trạng thái đồng bộ |
| Không có tài khoản | Không có màn hình đăng nhập, không có hồ sơ người dùng |
| iOS giữ tối đa 64 thông báo chờ | Cần trạng thái hiển thị khi phải cắt bớt |
| Widget màn hình khóa làm ở giai đoạn sau | Thiết kế trước phần nội dung widget để không phải sửa cấu trúc dữ liệu |

### 11.1 Giao diện sáng và tối

Bắt buộc có cả hai, **không được coi giao diện tối là tính năng trả phí**. Có đánh giá một sao gỡ app ngay vì lý do này, người viết nêu lý do đau nửa đầu.

Lưu ý riêng cho giao diện tối: hệ màu báo mức độ nghiêm trọng phải giữ được độ tương phản ở cả hai nền. Đỏ trên nền tối thường bị chìm.

---

## 12. Việc cần ở bản thiết kế

Xếp theo thứ tự ưu tiên. Nếu không làm hết được, làm từ trên xuống.

1. **Thông báo**: ba trạng thái (Mức 1, Mức 2, Mức 3) kèm các nút hành động.
2. **Màn hình Sắp tới**: đủ bốn nhóm thời gian, có nhóm SIM gom dòng, có ít nhất một trạng thái cảnh báo.
3. **Hệ màu mức rủi ro**: ba mức, cả nền sáng và nền tối, kèm cách phân biệt không dựa vào màu (cho người khó phân biệt màu).
4. **Màn hình chi tiết SIM**: ba đồng hồ, cách hiện nguồn gốc và độ cũ của thông tin.
5. **Form thêm mục**: có gợi ý tên, ô nhập ngày hai kiểu.
6. **Màn hình Tiền**: ba tầng thông tin, có trạng thái tỷ giá quá cũ.
7. **Màn hình xác nhận kết quả quét ảnh**: đoạn chữ gốc bên cạnh, ngày mập mờ thành hai lựa chọn.
8. Hai trạng thái rỗng.

---

## 13. Câu hỏi để ngỏ cho người thiết kế

- Ba mức rủi ro thể hiện bằng gì cho tốt? Màu là cách hiển nhiên nhưng có thể chưa đủ mạnh cho Mức 1.
- Nhóm SIM rút thành một dòng thì làm sao cho thấy bên trong có mấy mục và mục nào gấp nhất?
- Ba đồng hồ của SIM trình bày thế nào để không thành một bức tường cảnh báo bị bỏ qua?
- Thông tin cũ (ngày xác nhận từ tám tháng trước) hiện thế nào để người dùng thấy nó đáng nghi mà không hoảng?
- Tên app. "Đến Hạn" là tên tạm.
