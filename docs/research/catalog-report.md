# Tổng kết đợt dựng danh mục dịch vụ

Ngày 23 và 24 tháng 8 năm 2026. Danh mục đi từ **71 mục** lên **223 mục**, và từ chỗ
mỗi mục chỉ có một con số giá không nguồn thành chỗ mỗi giá đều có trang niêm yết của
chính hãng kèm ngày kiểm.

Tài liệu này ghi lại: đầu bài là gì, thu được gì, làm bằng cách nào, cái gì không thu
được và vì sao, chỗ nào còn rủi ro, và cách cập nhật lại về sau.

Các tài liệu liên quan:

- `dataset-plan.md`: kế hoạch và schema
- `collector-brief.md`: luật giao cho agent thu thập
- `service-list-review.md`: danh sách dịch vụ ban đầu để review
- `manage-links.md`: nghiên cứu link trang thuê bao, kênh thanh toán, USSD
- `../icon-credits.md`: nguồn và giấy phép icon
- `catalog-coverage.md`: bảng từng dịch vụ thu được gì, sinh tự động
- `../../data/services/_verify.md`: trạng thái hiện tại và việc còn lại

---

## 1. Yêu cầu: cần thu thập những gì

### 1.1 Vì sao làm

Hai việc app cần mà danh mục cũ không làm được:

1. **Giảm công gõ khi thêm mục.** Người dùng gõ tên dịch vụ thì form phải tự điền phần
   còn lại: phân loại, chu kỳ, giá tham khảo, icon.
2. **So được gói tháng với gói năm.** Muốn nói "chuyển sang gói năm tiết kiệm bao nhiêu"
   thì phải có giá của cả hai chu kỳ, và phải là hai chu kỳ **của cùng một gói**.

Danh mục cũ có 71 mục, mỗi mục đúng một con số giá, không nguồn, không ngày kiểm. Không
đủ cho việc thứ hai, và quá mỏng cho việc thứ nhất.

### 1.2 Mỗi dịch vụ cần những gì

| Cần gì | Ghi chú |
|---|---|
| Tên và các cách gõ tắt | Có cả bản không dấu, vì người dùng gõ vội trên điện thoại |
| Lĩnh vực (`sector`) | AI, Streaming, Music, Gaming... |
| Cách thanh toán (`category`) | Subscription, Bill, Insurance, Document |
| Các gói cước | Giá, tiền tệ, chu kỳ, vùng, kèm nguồn và ngày kiểm |
| Icon | Dấu hiệu riêng của hãng nếu có |
| Link huỷ | Trang huỷ thật, không phải trang chủ |
| Link trang thuê bao | Nơi người dùng xem gói của chính họ (thêm giữa đợt, xem 1.5) |

`sector` và `category` là **hai cách phân loại khác nhau và cùng tồn tại**: một cái nói
dịch vụ thuộc lĩnh vực gì (để duyệt và chọn), cái kia nói nó được thanh toán ra sao (để
tính tiền và đặt nhắc hạn). Gộp hai cái làm một sẽ phá phần nhắc hạn.

### 1.3 Phạm vi

17 nhóm lĩnh vực do chủ dự án đưa ra: AI, Streaming, Music, Gaming, Productivity,
Social, News, Food, Fitness, Finance, Education, Security, Entertainment, Travel,
Dating, Storage, Phone.

Cộng 4 nhóm cho phần Việt Nam mà 17 nhóm trên không phủ: Utilities, Housing, Documents,
Insurance. Đây chính là phần "đến hạn" đặc trưng của app (tiền điện, hộ chiếu, đăng
kiểm, bảo hiểm), nên không được bỏ.

Tổng 21 nhóm, khoảng 230 mục. Hỗ trợ cả dịch vụ toàn cầu lẫn dịch vụ chỉ có ở Việt Nam.

### 1.4 Bốn quyết định chốt trước khi chạy

| Câu hỏi | Chốt |
|---|---|
| Mỗi dịch vụ lấy bao nhiêu gói? | Một gói phổ biến nhất, nhưng lấy đủ **cả chu kỳ tháng và năm** |
| Vùng giá nào? | `VN` và `GLOBAL` (USD). Không lấy EU |
| Chạy bao nhiêu mục? | Hết, khoảng 230, chia 10 nhóm chạy song song |
| Mục chung không có thương hiệu? | Đưa vào danh mục nhưng **để trống giá**, không bịa khoảng giá |

Quyết định thứ nhất là quyết định quan trọng nhất. Lấy hết mọi gói của Netflix sẽ ra 8
dòng cho một dịch vụ và phần lớn sẽ cũ đi vô ích; lấy đúng một gói một chu kỳ thì mất
luôn khả năng so sánh, tức mất đúng lý do làm đợt này.

### 1.5 Hai luật bổ sung trong lúc chạy

**Icon:** hãng nào có trong bộ icon mở thì dùng bộ đó; không có thì tải logo SVG của
chính hãng về `tool/brand_icons/` và biên dịch từ file. Điều này cũng khiến một dấu hiệu
đã lấy về thì không biến mất được nữa, kể cả khi hãng yêu cầu bộ icon gỡ logo của họ.

**Link trang thuê bao:** thêm giữa đợt, từ một nhận xét của chủ dự án là tìm thông tin
gói hiện tại của một dịch vụ rất mất thời gian. Đây trúng vào giới hạn lớn nhất của app:
nó không đọc được hồ sơ bên nhà cung cấp, chỉ biết những gì người dùng gõ vào. Một link
thẳng tới trang billing là đường ngắn nhất để người dùng tự xác nhận ngày gia hạn.

---

## 2. Kết quả bằng số

| | |
|---|---|
| Mục trong danh mục | **223** |
| Mục có giá | **166** (74%) |
| Mục có đủ cặp tháng và năm | **82** |
| Tổng số dòng giá | **257** |
| Mục có link trang thuê bao | 32 |
| Mục có link huỷ | 25 |

Phân bố dòng giá:

| Chia theo | Phân bố |
|---|---|
| Vùng | 194 GLOBAL, 63 VN |
| Tiền tệ | 194 USD, 63 VND |
| Chu kỳ | 142 tháng, 112 năm, 2 quý, 1 nửa năm |
| Loại nguồn | 210 trang của hãng, 47 trang App Store của hãng |

**82 mục có đủ cặp tháng và năm** là con số đáng chú ý nhất, vì đó là điều kiện để app
tính được "chuyển sang gói năm tiết kiệm bao nhiêu". Nói cách khác, tính năng đó chạy
được trên khoảng một phần ba danh mục, và giao diện phải coi trạng thái vắng mặt là
trạng thái thường gặp.

Độ phủ icon, tính theo từng mục:

| Mức | Số mục | |
|---|---|---|
| Dấu hiệu riêng của hãng | 127 | 57% |
| Hình hạng mục tô màu thương hiệu | 60 | 27% |
| Hình hạng mục tô mực xám | 36 | 16% |
| Rơi về ô chữ cái | **0** | |

---

## 3. Cách làm

### 3.1 Chốt schema trước, thu thập sau

Việc đầu tiên không phải là đi tra giá mà là cố định schema và viết validator. Mười
agent chạy song song mà chưa có schema sẽ trả về mười kiểu dữ liệu, và công merge sẽ
lớn hơn công tự làm.

Ba công cụ dựng trước khi agent chạy:

- `tool/validate_services.py`: kiểm từng file batch
- `tool/seed_batches.py`: chia 230 mục thành 10 file, gán sẵn id duy nhất toàn cục
- `tool/merge_services.py`: gộp về `assets/services.json`, kiểm trùng id và trùng alias

Gán id từ trước là chi tiết quan trọng: nó khiến hai agent không thể tạo ra cùng một
mục, và merge cuối cùng không thể va nhau.

### 3.2 Luật cứng nhất: không nguồn thì không giá

Mỗi dòng giá bắt buộc có `source` là trang niêm yết của chính hãng, và `checkedAt` là
ngày thật sự mở trang đó. Không tra được thì để `plans: []` kèm lý do, tuyệt đối không
suy luận, không quy đổi tỉ giá, không lấy giá năm ngoái.

Luật này theo đúng tinh thần enum `DateSource` đã có trong app: một con số hiển thị tự
tin hơn mức nó xứng đáng là lỗi nghiêm trọng hơn là không hiển thị gì.

Một ngoại lệ được chốt giữa đường: **trang App Store của chính hãng tính là nguồn chính
thức**. Nhiều hãng chặn bot ở web nhưng vẫn niêm yết đầy đủ mục In-App Purchases, và
với người dùng Việt Nam thì đó mới là giá thật sự bị trừ. 47 trong 257 dòng giá đến từ
đây.

### 3.3 Ba vòng thu thập

| Vòng | Công cụ | Kết quả |
|---|---|---|
| B: 10 agent song song, mỗi agent một file | WebFetch, WebSearch | 118 mục có giá |
| C: 3 agent tuần tự | Trình duyệt thật qua chrome-devtools | thêm 48 mục |
| Trộn link trang thuê bao | HTTP có đối chứng | 32 mục |

Vòng C phải chạy **tuần tự** vì chrome-devtools chỉ có một trình duyệt, hai agent cùng
lái sẽ giành tab của nhau.

Phát hiện của vòng C: phần lớn thất bại ở vòng B **không phải vì trang không có giá mà
vì Cloudflare chặn công cụ tải trang**. Trình duyệt thật gỡ được hầu hết. Đây là lý do
đáng để chạy vòng hai chứ không phải kết luận sớm là "hãng không công bố giá".

### 3.4 Phương pháp đối chứng khi tìm link trang thuê bao

Với các trang dạng SPA, một URL thật và một URL bịa hoàn toàn đều trả về HTTP 200 y hệt
nhau. Nên mỗi URL đều được gọi kèm **một đường dẫn rác trên cùng host làm đối chứng**,
và chỉ tính là bằng chứng khi hai kết quả khác nhau.

Nhờ bước này mà phát hiện `github.com/settings/billing` trả về **404**, trong khi đường
dẫn đúng là `/settings/billing/summary`. Đây đúng là loại URL mà một quy trình cẩu thả
sẽ ghi vào vì nó nghe hợp lý.

---

## 4. Validator đã chặn được gì

Đây là phần đáng giá của việc viết validator trước.

| Luật | Bắt được gì |
|---|---|
| Gói năm phải đắt hơn gói tháng | Điền nhầm ô, sẽ khiến app khoe "tiết kiệm 92%" |
| Gói năm không quá 12 lần gói tháng | Ghi nhầm mức "quy ra tháng khi trả năm" |
| VND trong khoảng hợp lý | Giá bị nhân hoặc chia 100 |
| `region: VN` phải đi với `VND` | Trộn vùng giá với tiền tệ |
| `source` phải là `https://` | Nguồn không kiểm chứng được |
| `checkedAt` không ở tương lai | Ngày bịa |
| `defaultPlan` phải trỏ tới tier có thật | Mặc định trỏ vào khoảng không |

Merge còn chặn thêm **trùng alias**, thứ mắt thường không thấy được. Ba va chạm bị bắt:
`"copilot"` bị cả GitHub Copilot lẫn Microsoft Copilot nhận, `"linkedin"` bị cả Learning
lẫn Premium nhận, `"k+"` bị mục chung "truyền hình cáp" nhận. Vì search trả về kết quả
khớp đầu tiên, mỗi va chạm là một mục biến mất khỏi kết quả tìm.

### Ba dòng giá bị loại vì vi phạm luật

- **Qobuz gói năm**: agent tự khai là suy ra từ mức 10,83 USD mỗi tháng khi cam kết trả
  năm, trang hãng không hiện tổng tiền cả năm. Đã xoá.
- **Evernote giá VND**: trang hiện số có phần thập phân lẻ, dấu hiệu trang tự quy đổi
  tỉ giá chứ không phải giá VND niêm yết. Đã bỏ.
- **DoorDash và Ubisoft+** ở phần icon: hình vẽ ra ngoài `viewBox` mà chính chúng khai
  báo, nên bị hạ xuống mức 2.

### Ba số nghi sai đã tra lại độc lập, cả ba đều đúng

| Mục | Nghi ngờ | Kết luận |
|---|---|---|
| Apple TV+ | 179.000đ trùng khít giá Apple Arcade VN | Đúng, trùng hợp thật |
| Zing MP3 | 49k và 499k trùng khít NhacCuaTui | Đúng, và tên miền đã đổi sang `zingmp3.vn` |
| Waka | Gói năm đúng bằng 4 lần gói quý | Đúng, hãng không giảm giá theo chu kỳ |

---

## 5. 57 mục không có giá, và vì sao

Con số này nghe lớn nhưng phần lớn là **đúng như thiết kế**, không phải thiếu sót.

### 5.1 Không có giá chuẩn theo bản chất: 32 mục

Hoá đơn điện, nước, gas, phí chung cư, phí rác, phí gửi xe, khoản vay, trả góp, sao kê
thẻ, phí quản lý tài khoản, SMS banking, học phí. Cộng với toàn bộ giấy tờ (hộ chiếu,
CCCD, GPLX, đăng kiểm, visa, thẻ tạm trú, giấy phép kinh doanh, chứng chỉ) và bảo hiểm.
Cộng với các mục chung không có thương hiệu: tên miền, VPS, gói cước data, gói cước trả
sau, truyền hình cáp, thẻ tập gym, vé tháng xe buýt.

Những mục này số tiền thay đổi theo từng người và từng kỳ. Để trống là câu trả lời đúng.

### 5.2 Hãng không công bố bảng giá: 12 mục

Tinder, Bumble, Hinge, Grindr, Badoo, happn, OkCupid, Coffee Meets Bagel: **toàn bộ tám
app hẹn hò** định giá động theo tuổi, vùng và thiết bị, không hãng nào có trang giá công
khai. Cộng với Patreon và Substack (giá do từng người sáng tạo đặt), Mullvad (chỉ niêm
yết 5 EUR, không có bảng USD hay VND), Storytel (không có Việt Nam trong danh sách quốc
gia).

### 5.3 Thu thập thất bại thật: 13 mục

| Mục | Lý do |
|---|---|
| deliveroo-plus, hellofresh | Cloudflare chặn cả trình duyệt thật |
| linkedin-learning, google-play-pass | Chỉ hiện giá sau khi đăng nhập |
| sim-wintel | Đổi sang mô hình tự thiết kế gói, không còn bảng giá cố định |
| github | Đã bỏ gói Pro cá nhân, chỉ còn Free, Team, Enterprise |
| geforce-now | Do đối tác vận hành theo vùng, không có bảng giá thống nhất |
| amazon-prime-video, viu | Xác nhận bằng bằng chứng runtime là không phục vụ Việt Nam |
| airalo | Bán gói eSIM theo dung lượng từng nước, không phải thuê bao định kỳ |
| money-lover, bkav-pro | Mục IAP chồng chéo, hoặc có giá nhưng không ghi rõ thời hạn |
| evernote | Giá VND là số tự quy đổi, đã bỏ |

Đây mới là danh sách đáng quay lại. 44 mục còn lại thì không.

---

## 6. Mục đã bỏ và đã đổi tên

### Bỏ khỏi danh mục: 7 mục

| Mục | Lý do |
|---|---|
| k-plus | Ngừng cung cấp dịch vụ tại Việt Nam từ 1 tháng 1 năm 2026 |
| hulu | Đã gộp hẳn vào Disney+, trang đăng ký redirect thẳng sang đó |
| shopeefood-xtra | Không còn gói hội viên trả phí cho người mua |
| steam | Là cửa hàng và ví, không phải thuê bao |
| deepseek | Chỉ bán API theo token, không có gói thuê bao cá nhân |
| windsurf | Đã sáp nhập vào Devin, tên miền redirect vĩnh viễn |
| microsoft-copilot | Không bán rời, chỉ có trong Microsoft 365, trùng mục đã có |

Amazon Prime Video và Viu **giữ lại** dù không phục vụ Việt Nam, vì chúng vẫn là dịch
vụ thật ở ngoài và danh mục hỗ trợ cả toàn cầu lẫn trong nước.

### Đổi tên: 3 mục

| id | Tên cũ | Tên mới |
|---|---|---|
| hbo-go | HBO Go | Max |
| be-hoi-vien | be Hội viên | beOne |
| fitbit-premium | Fitbit Premium | Google Health Premium |

Cả ba giữ nguyên `id`, và luật nhận diện icon giữ **cả tên cũ lẫn tên mới**, vì người
dùng vẫn quen gõ tên cũ. Bài học kèm theo: đổi `name` làm golden test đỏ ngay lập tức,
vì luật icon khớp theo tên chứ không theo id.

---

## 7. Rủi ro còn lại

**Giá sẽ cũ đi và app không có cách tự cập nhật.** Toàn bộ 257 dòng giá mang ngày kiểm
23 hoặc 24 tháng 8 năm 2026. Giao diện phải hiển thị ngày này, và đổi giọng khi giá quá
12 tháng tuổi (xem `design-spec-annual-saving.md` mục 1.7).

**Giá niêm yết không phải giá người dùng đang trả.** Họ có thể đang dùng gói khuyến mãi,
gói cũ, hoặc gói gia đình chia nhiều người. Mọi bề mặt dùng số này phải nói rõ đó là giá
niêm yết.

**Một số nguồn là trang tin hoặc trang tư vấn của hãng**, không phải trang niêm yết:
`sim-itel`, `internet-vnpt`, `vnsky`, `xbox-gamepass`. Vẫn là tên miền của hãng nhưng
yếu hơn một trang giá.

**Mức đóng BHYT hộ gia đình phụ thuộc hai dữ kiện pháp lý** (nghị định và mức lương cơ
sở). Con số 1.366.200đ mỗi năm chỉ đúng khi cả hai còn hiệu lực. Đây là dòng giá dễ hết
hạn nhất trong danh mục.

**Giá lấy từ App Store là giá của gian hàng Mỹ hoặc Việt Nam tuỳ mục.** Đã ghi trong
`source`, nhưng khi cập nhật cần giữ đúng gian hàng cũ để so sánh có nghĩa.

---

## 8. Cách cập nhật về sau

```bash
# sửa file batch trong data/services/, rồi:
python3 tool/validate_services.py data/services/*.json
python3 tool/merge_services.py            # chạy thử, không ghi
python3 tool/merge_services.py --write    # ghi vào assets/services.json
flutter test test/unit/catalog/
```

Thêm dịch vụ mới thì cần cả icon:

```bash
# thêm dòng vào BRANDS trong tool/gen_service_marks.py, hoặc thêm luật
# GlyphSpec vào _rules trong lib/ui/widgets/service_mark.dart
python3 tool/gen_service_marks.py
flutter test test/golden/service_marks_golden_test.dart --update-goldens
```

Ba điều dễ quên:

1. **Luật icon khớp theo tên, không theo id.** Đổi `name` là phải thêm luật.
2. **Cụm dài phải nằm trên từ nằm trong nó** trong `_rules`, vì `detect` lấy kết quả
   khớp đầu tiên.
3. **Thêm cột vào bảng `itemRow` phải sửa hai chỗ**: bước migration của chính nó, và
   danh sách `newColumns` của bước dựng lại bảng ở v3. Thiếu chỗ thứ hai thì file cũ
   không nâng cấp được.
