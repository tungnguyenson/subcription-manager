# Đặc tả thiết kế: so sánh gói năm & nút mở trang thuê bao

Tài liệu này dành cho người thiết kế màn hình. Nó mô tả **hai bề mặt mới**, cả hai
đều nằm trên màn chi tiết một mục:

1. **So sánh gói tháng với gói năm**: cho người dùng biết chuyển sang gói năm
   tiết kiệm bao nhiêu.
2. **Nút mở trang thuê bao**: đưa người dùng tới đúng trang hiển thị gói của họ.

Bối cảnh chung, giọng chữ, font và bảng màu: đọc `Subdock Handoff.dc.html` (bản
chốt hiện hành). Chữ trên giao diện là **tiếng Anh**; tài liệu này viết tiếng Việt
nhưng mọi chuỗi hiển thị đều ghi sẵn bằng tiếng Anh, dùng đúng như đã ghi.

---

## 0. Điều quan trọng nhất phải hiểu trước khi vẽ

App **không đọc được hồ sơ bên nhà cung cấp**. Nó chỉ biết những gì người dùng gõ
vào, cộng với một bảng giá tham khảo đóng gói sẵn trong app.

Nghĩa là mọi con số trên hai bề mặt này thuộc **một trong hai loại khác hẳn nhau**,
và giao diện phải phân biệt được chúng:

| Loại | Nguồn | Độ tin |
|---|---|---|
| **Số của người dùng** | Họ tự nhập khi thêm mục | Đúng với họ |
| **Số trong danh mục** | Bảng giá niêm yết của hãng, kèm ngày kiểm | Chỉ là giá niêm yết |

Số trong danh mục **không phải giá người dùng đang trả**. Họ có thể đang dùng gói
khuyến mãi, gói cũ giá thấp hơn, gói gia đình chia nhiều người, hoặc mua qua đại lý.

> **Nguyên tắc bao trùm:** một con số hiển thị tự tin hơn mức nó xứng đáng là lỗi
> nghiêm trọng hơn là không hiển thị gì. App đã có sẵn cả một enum (`DateSource`)
> chỉ để phục vụ nguyên tắc này. Hai bề mặt dưới đây phải theo cùng luật.

---

## 1. So sánh gói năm

### 1.1 Việc nó phải làm

Trả lời đúng một câu hỏi, trong một lần liếc:

> *"Trả theo năm thì rẻ hơn bao nhiêu?"*

Không phải "quản lý chi tiêu", không phải biểu đồ, không phải bảng so sánh nhiều
tier. Một câu trả lời, một con số, một hành động.

### 1.2 Dữ liệu có sẵn

Hàm `CatalogEntry.annualSaving()` trả về, hoặc `null`:

```
monthly    một dòng giá: số tiền, tiền tệ, tên gói, nguồn, ngày kiểm
yearly     dòng tương ứng của cùng một gói, chu kỳ năm
saving     = monthly × 12 − yearly, luôn dương
currency   VND hoặc USD
```

Hiện có **82/223 mục** trả về giá trị khác `null`. Nghĩa là **khoảng hai phần ba số
mục sẽ không có bề mặt này**. Trạng thái vắng mặt là trạng thái thường gặp nhất,
hãy thiết kế nó trước, đừng thiết kế nó sau cùng.

Vài mục có giá ở hai vùng (`VN` và `GLOBAL`). Ưu tiên vùng `VN` khi có, vì đó là số
tiền thật sự bị trừ.

### 1.3 Năm trạng thái, tất cả đều phải vẽ

| # | Khi nào | Hiện gì |
|---|---|---|
| 1 | Có đủ giá tháng và giá năm, người dùng đang trả theo tháng | **Bề mặt đầy đủ.** Đây là ca chính. |
| 2 | Có đủ hai giá, người dùng **đã** trả theo năm | Không hiện gợi ý. Có thể hiện một dòng xác nhận nhẹ, hoặc không hiện gì. Tuyệt đối không rủ họ làm thứ họ đã làm. |
| 3 | Chỉ có giá tháng, hãng không bán gói năm | Không hiện gì. Không viết "no annual plan available", vì đó là một dòng chữ trả lời câu hỏi không ai hỏi. |
| 4 | Mục không có giá trong danh mục (hoá đơn điện, giấy tờ, mục chung) | Không hiện gì. |
| 5 | Số người dùng nhập **lệch nhiều** so với giá niêm yết | Vẫn hiện, nhưng phải nói rõ phép tính dựa trên giá niêm yết. Xem 1.6. |

### 1.4 Nội dung ca chính

Ba mẩu thông tin, theo thứ tự quan trọng giảm dần:

1. **Số tiền tiết kiệm mỗi năm**: thứ duy nhất người dùng nhớ được
2. **Hai giá đặt cạnh nhau** để con số trên có nghĩa
3. **Nguồn và ngày kiểm**: thứ khiến con số đáng tin, và là thứ cho phép người dùng
   tự phát hiện khi nó đã cũ

Chuỗi hiển thị (tiếng Anh, dùng nguyên văn):

```
Save 456,000₫ a year
Monthly 129,000₫ × 12 = 1,548,000₫
Yearly  1,092,000₫
Listed price, checked 23 Aug 2026
```

Ghi chú cách viết:

- **`Save`, không phải `You could save`.** Ngắn hơn và không hàm ý hứa hẹn.
- **`a year`, không phải `per year` hay `/yr`.** Giọng của app là câu nói, không phải bảng tính.
- **`Listed price`** là mấu chốt của cả khối. Nó nói con số này của hãng, không phải của bạn.
- Ngày viết theo định dạng đã có trong app (xem `date_copy.dart`), không viết ISO.

### 1.5 Cách trình bày số

- Tất cả **số tiền dùng IBM Plex Mono**, giống mọi con số khác trong app.
- **VND: không có phần thập phân**, ngăn cách hàng nghìn, ký hiệu `₫` đứng sau.
- **USD: hai chữ số thập phân**, ký hiệu `$` đứng trước.
- **Không quy đổi tỉ giá trong khối này.** Nếu gói niêm yết bằng USD thì hiện USD.
  App có phần FX riêng cho việc quy đổi; trộn hai thứ ở đây sẽ tạo ra một con số
  không khớp với bất kỳ hoá đơn nào người dùng nhìn thấy.
- Phép tính `× 12` phải **hiện ra**, đừng giấu. Người dùng cần thấy được nó để tin,
  và để tự kiểm khi giá của họ khác giá niêm yết.

### 1.6 Khi giá người dùng khác giá niêm yết

Ca thường gặp: người dùng nhập 99.000₫ (giá khuyến mãi họ đang được hưởng) trong
khi danh mục ghi 129.000₫.

**Không im lặng dùng số của người dùng để tính**, vì gói năm trong danh mục là giá
niêm yết, trừ hai số khác nguồn nhau ra một con số vô nghĩa.

**Cũng không im lặng dùng số của danh mục**, vì người dùng sẽ thấy một phép tính
không khớp với số họ vừa nhập ngay phía trên.

Cách đúng: hiện phép tính bằng **giá niêm yết**, và nói rõ:

```
Based on the listed price of 129,000₫, not the 99,000₫ you entered
```

Đặt ngưỡng: chỉ hiện câu này khi lệch **quá 10%**. Lệch vài nghìn thì câu giải thích
gây nhiễu nhiều hơn giúp.

### 1.7 Khi giá đã cũ

Mỗi dòng giá có `checkedAt`. Giá sẽ cũ dần và app không có cách tự cập nhật.

- Dưới 6 tháng: hiện ngày bình thường.
- **Quá 12 tháng: đổi giọng của cả khối** từ khẳng định sang gợi ý, và làm dòng
  nguồn nổi hơn:

```
Save about 456,000₫ a year
Listed price from 23 Aug 2026 — check the current price
```

Thêm chữ `about`, và câu nhắc phải là **một phần của khối**, không phải một cảnh báo
màu vàng riêng. Đây không phải lỗi, chỉ là dữ liệu đang già đi.

### 1.8 Hành động

Khối này kết thúc bằng **đúng một** hành động: mở trang thuê bao của dịch vụ, tức
cùng nút ở mục 2 dưới đây. App **không** đổi gói giúp người dùng và không được tỏ ra
như vậy.

Không có nút "switch to yearly". App không có quyền đó, và một nút hứa điều nó không
làm được là cách nhanh nhất để mất niềm tin.

### 1.9 Những thứ tuyệt đối không làm

- **Không cộng dồn "tổng tiết kiệm được nếu chuyển hết sang gói năm"** trên màn tổng
  quan. Nó gộp nhiều giá niêm yết chưa chắc đúng thành một con số to, và con số to
  sai thì sai to.
- **Không xếp hạng, không huy hiệu, không "bạn đang lãng phí X".** App này ngăn người
  dùng mất thứ không lấy lại được, nó không phải huấn luyện viên tài chính.
- **Không animation đếm số.** Con số này là dữ liệu tham khảo, không phải thành tích.
- **Không dùng màu cảnh báo** (đỏ/cam) cho khối này. Tiết kiệm được tiền không phải
  một mối nguy, và app đã dành màu cảnh báo cho việc sắp mất thứ gì đó.

---

## 2. Nút mở trang thuê bao

### 2.1 Vấn đề nó giải

Người dùng muốn biết chính xác ngày gia hạn thì phải tự đi tra. Việc đó tốn thời
gian vì mỗi dịch vụ giấu trang billing ở một chỗ khác nhau. App có sẵn đường dẫn cho
**32 dịch vụ**, nên nó có thể rút việc đó xuống một cú chạm.

### 2.2 Cái bẫy: cùng dịch vụ, ba trang khác nhau

Ai mua Claude qua web thì `claude.ai/settings/billing` đúng. Ai **mua qua App Store**
thì mở trang đó ra sẽ thấy **một tài khoản trống rỗng**, vì thuê bao của họ nằm bên
Apple. Gửi họ tới đó là một chuyến đi công cốc, và tệ hơn là nó khiến người dùng
tưởng mình chưa từng đăng ký.

Catalog **không giải được** chuyện này: biết Claude bán qua cả ba kênh không nói gì
về việc *người này* mua ở đâu. Chỉ họ biết.

### 2.3 Cách hỏi: không hỏi

Không có bước "bạn mua qua đâu?" khi thêm mục. Đó là một câu hỏi về hạ tầng thanh
toán chen giữa người dùng và việc họ đang làm.

Thay vào đó: **cú chạm đầu tiên chính là câu trả lời.**

Trạng thái ban đầu (`purchaseChannel = UNKNOWN`) hiện nút chính trỏ tới trang của
hãng, kèm một lối thoát nhỏ bên dưới:

```
[ Open Netflix account ]
Bought through the App Store?
```

Chạm dòng thứ hai → mở trang thuê bao của Apple **và ghi nhớ**. Từ lần sau mục này
chỉ còn một nút, trỏ thẳng App Store, và dòng gợi ý biến mất hẳn.

Người đã trả lời rồi thì không bị hỏi lại. Đây là điều kiện bắt buộc, không phải
tuỳ chọn, vì một dòng "bạn mua ở đâu?" nằm mãi trên mọi mục là nhiễu vĩnh viễn.

### 2.4 Bốn trạng thái

| `purchaseChannel` | Nút chính | Dòng phụ |
|---|---|---|
| `UNKNOWN`, danh mục có link hãng | `Open <service> account` | `Bought through the App Store?` |
| `UNKNOWN`, danh mục **không** có link | `Manage in the App Store` | không có |
| `WEB` | `Open <service> account` | không có |
| `APP_STORE` | `Manage in the App Store` | không có |

Mục không có link hãng **và** không phải thuê bao (tiền điện, hộ chiếu, khoản vay)
thì **không hiện nút nào**. Một nút dẫn tới trang chắc chắn không có thứ họ cần còn
tệ hơn không có nút.

### 2.5 Sau khi quay lại từ trang đó

Đây là lúc app đáng giá nhất và rất dễ bỏ lỡ. Người dùng vừa nhìn thấy ngày gia hạn
thật bằng chính mắt mình. Khi họ quay lại app, hỏi luôn:

```
Did you see the renewal date?
[ Enter date ]
```

Nếu họ nhập, ngày đó được ghi là **đã xác nhận** chứ không phải ước lượng, và đó chính là
thứ toàn bộ app xoay quanh. Hỏi một lần, không hỏi lại nếu họ bỏ qua.

### 2.6 Chuyện SIM: không có nút USSD

Với SIM trả trước, cách kiểm tra hạn dùng quen thuộc là bấm mã USSD kiểu `*101#`.
**Không thiết kế nút này.** iOS chặn hoàn toàn việc quay số USSD từ trong app: URL
chứa `*` hoặc `#` thì Phone app không quay, và điều tệ nhất là hệ thống vẫn báo
"mở được" nên nút sẽ **im lặng không làm gì**.

Thay thế: mở app của nhà mạng. App có sẵn App Store ID chính thức của cả 7 nhà mạng
VN (Viettel, VinaPhone, MobiFone, Vietnamobile, iTel, Wintel, VNSKY).

```
[ Open My Viettel ]
```

Chi tiết kỹ thuật và nguồn: `docs/research/manage-links.md`.

---

## 3. Cả hai khối nằm ở đâu

Trên màn chi tiết một mục, dưới phần ngày và tiền, theo thứ tự:

1. Khối so sánh gói năm (khi có)
2. Nút mở trang thuê bao (khi có)

Không đưa lên màn danh sách. Danh sách trả lời câu hỏi *"sắp tới có gì?"*, hai khối
này trả lời *"mục này thì sao?"*. Đó là hai câu hỏi khác nhau, và mục 2.2 của
`design-spec.md` đã đặt luật: mỗi cách phân loại chỉ xuất hiện ở một màn hình.

---

## 4. Bảng tra nhanh khi vẽ

| Câu hỏi | Trả lời |
|---|---|
| Bao nhiêu mục có so sánh gói năm? | 82 trên 223 |
| Bao nhiêu mục có link trang thuê bao? | 32 |
| Có được quy đổi USD sang VND ở đây không? | Không |
| Có được cộng dồn tiết kiệm nhiều mục không? | Không |
| Có nút "đổi sang gói năm" không? | Không, app không đổi hộ được |
| Có nút bấm mã USSD không? | Không, iOS chặn |
| Hỏi kênh thanh toán lúc nào? | Không hỏi; cú chạm đầu tiên là câu trả lời |
| Số tiền dùng font gì? | IBM Plex Mono |
