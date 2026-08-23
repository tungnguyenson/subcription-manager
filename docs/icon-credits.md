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
