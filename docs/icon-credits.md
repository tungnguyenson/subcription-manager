# Nguồn và giấy phép của icon dịch vụ

Mỗi mục trong danh sách có một ô vuông bên trái. Ô đó vẽ một trong ba thứ, xếp
theo mức độ nói được nhiều hay ít về mục đó:

1. **Dấu hiệu riêng của hãng**: Netflix, Spotify, Claude. 29 hình, tải về từ
   các bộ icon mở rồi biên dịch thành dữ liệu đường vẽ trong
   `lib/ui/widgets/service_marks.data.dart`.
2. **Hình hạng mục tô màu thương hiệu**: Viettel, VieON, iTel, Disney+. Đây là
   những hãng không phát hành bản vector ở bất cứ bộ icon mở nào; hình nói *đây
   là loại gì*, màu nói *của ai*.
3. **Hình hạng mục tô mực xám**: tiền điện, hộ chiếu, bảo hiểm. Không có thương
   hiệu nào để nói sai.

Hình ở mức 2 và 3 vẽ thẳng trong code tại `lib/ui/widgets/category_glyphs.dart`,
cùng lưới 20 đơn vị và nét 1,6px với icon thanh tab.

## Vì sao biên dịch chứ không đóng gói file SVG

App tự vẽ icon tab và cố tình không đóng gói bộ icon font nào. Thêm một thư
viện đọc SVG cùng 30 file asset để vẽ thêm 30 hình sẽ đúng là thứ phụ thuộc mà
phần còn lại của giao diện được dựng để tránh.

`tool/gen_service_marks.py` làm phẳng đường vẽ SVG ngay lúc build: giải toạ độ
tương đối, xấp xỉ cung tròn bằng đường bậc ba, nâng bậc đường bậc hai. Còn lại
đúng bốn lệnh (`M`, `L`, `C`, `Z`) nên bộ đọc lúc chạy trong
`lib/ui/widgets/service_mark.dart` chỉ dài bốn nhánh và không tải gì từ đĩa.

Chạy lại khi cần cập nhật:

```bash
python3 tool/gen_service_marks.py
flutter test test/golden/service_marks_golden_test.dart --update-goldens
```

## Nguồn

Toàn bộ hình lấy về đều thuộc giấy phép cho phép dùng và phát hành lại. Không
có bộ nào yêu cầu chia sẻ tương tự (copyleft), không bộ nào cấm dùng thương mại.

| Bộ | Giấy phép | Dùng cho |
|---|---|---|
| [theSVG](https://thesvg.org) | MIT | 22 hình: Netflix, YouTube, Spotify, HBO, Apple TV, Apple Music, PlayStation, Steam, Claude, ChatGPT, Gemini, GitHub Copilot, Cursor, Perplexity, Figma, Notion, JetBrains, 1Password, Vercel, iCloud, Google Drive, Dropbox, Backblaze |
| [CoreUI Brands](https://github.com/coreui/coreui-icons) | CC0 1.0 | 4 hình: Xbox, Nintendo Switch, Adobe Creative Cloud, Microsoft |
| [SVG Logos](https://github.com/gilbarbara/logos) của Gil Barbara | CC0 | 1 hình: Midjourney |
| [Material Design Icons](https://pictogrammers.com/library/mdi/) | Apache 2.0 | 1 hình: OneDrive |
| [Simple Icons](https://simpleicons.org) | CC0 1.0 | Không lấy hình, chỉ lấy mã màu thương hiệu |
| [Wikimedia Commons](https://commons.wikimedia.org) | PD-logo (dưới ngưỡng bản quyền) + nhãn hiệu của hãng | 9 hình cho các hãng chặn tải từ trang chủ |
| `tool/brand_icons/` | nhãn hiệu của hãng, tải thẳng từ hãng | Các hãng không phát hành vector ở bộ mở nào |

Giấy phép Apache 2.0 của Material Design Icons và CC BY của các bộ khác đều yêu
cầu ghi nguồn, chính là bảng trên. Nếu sau này thêm hình từ một bộ mới, thêm một
dòng vào đây trước khi thêm vào `tool/gen_service_marks.py`.

### Vì sao thiếu vài hãng lớn

Simple Icons đã gỡ Xbox, Nintendo, OpenAI, Adobe, Microsoft và Disney theo yêu
cầu của chính các hãng đó. Phần lớn tìm được ở bộ khác. Riêng Disney+ thì không
bộ nào có bản dùng được, nên nó rơi xuống mức 2: hình màn hình phát tô xanh
Disney.

## Về nhãn hiệu

Các dấu hiệu này vẫn là nhãn hiệu của chủ sở hữu. App dùng chúng chỉ để đánh dấu
*chính gói dịch vụ mà người dùng đang theo dõi*, không gắn lên chỗ nào hàm ý
hãng đó tài trợ, liên kết hay chứng thực cho app. Không hình nào bị vẽ lại, đổi
tỉ lệ lệch trục hay ghép vào hình khác.

Màu thương hiệu của các hãng không có vector được lấy từ chính tài sản công khai
của hãng: logo SVG trên trang chủ với iTel, ảnh og:image với Galaxy Play, favicon
độ phân giải cao với phần còn lại. Viettel ra đúng `#EE0033`, tức mã đỏ chính
thức của hãng, nên cách lấy màu này là đáng tin.

## Trạng thái hiện tại

**224 mục trong `assets/services.json` phủ hết, không mục nào rơi về ô chữ cái.** Chiều
ngược lại cũng sạch: không dấu hiệu nào nằm trong bộ mà không mục nào chạm tới. Một test
trong `test/golden/service_marks_golden_test.dart` giữ cả hai điều đó.

| Mức | Số luật | Là những gì |
|---|---|---|
| 1. Dấu hiệu riêng của hãng | 138 | 129 hình trong `brandMarks`, vài hình dùng cho nhiều tên (`copilot`, `game pass`) |
| 2. Hình hạng mục tô màu hãng | 64 | Hãng không phát hành vector: Disney+, VieON, 6 nhà mạng, iQIYI, TV360, Viu, WeTV, Waka... |
| 3. Hình hạng mục tô mực xám | 71 | Điện, nước, giấy tờ, bảo hiểm, và các mục chung không có thương hiệu |

Google One dùng dấu hiệu Google Drive, vì Google One chính là dung lượng Drive và Google
không phát hành dấu hiệu riêng cho nó.

### Hai luật hạ mức, đều đo được chứ không cảm tính

**Hình vẽ ra ngoài `viewBox` của chính nó.** DoorDash và Ubisoft+ khai `viewBox="0 0 24 24"`
nhưng path chạy tới 25,8. Chuẩn hoá theo viewBox thì hình tràn khỏi ô và bị cắt, trông như
một logo crop hỏng chứ không như một file nguồn lỗi. Bộ sinh giờ **dừng hẳn** khi gặp, kèm
tên mục và khoảng toạ độ thật.

**Wordmark quá dẹt thì không còn là dấu hiệu.** Co một wordmark tỉ lệ 7:1 về ô 24 đơn vị
thì nó chỉ cao 3 đơn vị — một vệt mực. Ngưỡng đo là **chiều cao dưới 5,5 đơn vị**:
`character-ai` (3,3), `oreilly` (4,1), `kaspersky` (4,6), `grindr` (4,9),
`kindle-unlimited` (5,0) đã hạ xuống mức 2. Zoom cao 5,6 và vẫn đọc được nên giữ ở mức 1.
Bộ sinh in cảnh báo cho mọi hình dưới 6 đơn vị, không chặn — đây là chỗ cần mắt người nhìn
ảnh golden, không phải chỗ cho một con số cứng.

## Khi cần sửa đổi về sau

### Nâng một mục từ mức 2 lên mức 1

Cần một bản vector đơn sắc, gộp được về một hình, ở một bộ có giấy phép cho
phép phát hành lại. Tìm được rồi thì:

1. Thêm một dòng vào `BRANDS` trong `tool/gen_service_marks.py`, dạng
   `"khoá": ("prefix:tên", "MÃMÀU", "slug-simple-icons-hoặc-None")`.
2. Đổi luật tương ứng trong `_rules` của `lib/ui/widgets/service_mark.dart` từ
   `GlyphSpec(...)` sang `BrandSpec('khoá')`.
3. Chạy lại bộ sinh, cập nhật bảng nguồn ở trên, chạy lại ảnh golden.

### Thêm một hình hạng mục mới

Thêm giá trị vào `enum CategoryGlyph`, thêm nhánh vẽ trong
`CategoryGlyphPainter` (lưới 20 đơn vị, nét 1,6px), thêm luật vào `_rules`,
chạy lại ảnh golden. Không cần chạy bộ sinh.

### Thứ tự trong `_rules` là thứ tự quyết định

`detect` lấy chuỗi con khớp đầu tiên, nên cụm dài phải nằm trên từ nằm trong nó.
`internet viettel` phải trên `viettel`, `visa card` phải trên `visa`, `onedrive`
phải trên `microsoft`. Mỗi cụm tiếng Việt có hai luật, một có dấu và một không,
vì gõ vội trên điện thoại thường mất dấu.

## Nguồn `file:` — logo tải về, nằm trong repo

Hãng nào không có vector ở bất cứ bộ mở nào thì tải logo SVG của chính hãng về
`tool/brand_icons/<khoá>.svg` và khai trong `BRANDS` dạng `("file:khoá", "MÃMÀU", None)`.
Bộ sinh đọc file thay vì gọi mạng.

Thư mục nằm trong `tool/` chứ không phải `assets/` vì nó là nguyên liệu lúc build; app
vẫn chỉ đọc `service_marks.data.dart`, không có file SVG nào lọt vào binary.

Lợi ích thứ hai, quan trọng hơn: **một dấu hiệu đã tải về thì không biến mất được nữa.**
Nhiều hãng lớn đã tự yêu cầu Simple Icons gỡ logo của họ sau khi ta bắt đầu dùng. Slack là
trường hợp đang treo: nó đã không còn trong `simple-icons.json` nhưng Iconify chưa đồng bộ
nên vẫn phục vụ được — đồng bộ xong là mất. Bộ sinh giờ báo lỗi rõ khi Iconify trả `404`
thay vì ghi ra một mark rỗng.

### Hai cái bẫy khi đi khảo sát nguồn

**jsdelivr trả HTTP 200 cho file không tồn tại**, kèm nội dung là một dòng chữ
báo không tìm thấy. Dò độ phủ bằng mã trạng thái sẽ ra kết quả sai hoàn toàn.
Cách đúng là đối chiếu với `data/simple-icons.json`. Iconify thì lành hơn:
`api.iconify.design/{prefix}:{tên}.svg` trả đúng chuỗi `404` khi thiếu.

**Bộ sinh dừng hẳn thay vì đoán.** Gặp SVG có `transform` hoặc không có `viewBox` thì nó
thoát kèm thông báo, vì một hình vẽ lệch chỗ trông y hệt một hình vẽ đúng cho tới khi có
người để ý.

Luật này từng bị viết hụt và đã sửa 2026-08-23. Bản cũ dò `"<g" in svg and "transform" in
svg`, tức sai cả hai chiều: `transform` đặt thẳng trên `<path>` (không có `<g>` nào) lọt
qua và vẽ lệch trong im lặng, còn file có một `<g>` bất kỳ cộng `gradientTransform` ở chỗ
khác thì bị chặn oan. Bản mới dò `transform=` trên mọi phần tử và loại trừ
`gradientTransform`/`patternTransform`. Đã tải lại cả 29 dấu hiệu đang dùng để xác nhận
luật chặt hơn không chặn nhầm mục nào.

**`fill-rule` có thể nằm trong `<style>` chứ không nằm trên `<path>`.** SVG xuất từ
Illustrator khai `fill-rule:evenodd` trong một class CSS rồi tham chiếu bằng `class="st0"`.
Bộ sinh cũ chỉ đọc thuộc tính inline nên bỏ sót, và **lỗ trong hình bị tô đặc** — sai chỉ
lộ ra khi nhìn ảnh render, không có lỗi nào được báo. Giờ nó đọc cả khối `<style>`.

### Vì sao file sinh ra tên `.data.dart`

`.gitignore` của dự án bỏ qua `*.g.dart`, đúng cho đầu ra của drift vì nó dựng
lại được bằng `build_runner`. File này thì không: dựng lại nó cần mạng và cần
với tới bốn CDN. Nó phải nằm trong git, nên nó mang tên khác.
