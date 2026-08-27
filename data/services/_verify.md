# Trạng thái dataset dịch vụ

## Xong 2026-08-24 — pha B, C, D, E hoàn tất

**223 mục | 166 có giá | 82 đủ cặp tháng+năm | 32 có manageUrl | 257 dòng giá.**
`flutter analyze` sạch. Số test tại thời điểm đó là 351, hiện là 410.

Mọi giá đều kèm `source` là trang của chính hãng và `checkedAt`. Mục không tra được để
`plans: []` — không mục nào mang số đoán.

### Việc đã làm thêm 2026-08-24

- **`purchaseChannel` trên item** — enum trong `model.dart`, cột `purchaseChannel`
  trong `itemRow` (schema v4, `addColumn` với default `'UNKNOWN'`), đi qua mappers,
  repository và backup. `lib/domain/manage_link.dart` quyết định mở link nào, có 12
  test riêng. **Chưa có UI.**
- **Mã USSD đã gỡ khỏi `data/manage-urls.json`.** Lý do kép: nguồn chỉ đạt mức B/C, và
  iOS chặn quay số USSD từ app. Giữ App Store ID của cả 7 nhà mạng, đều mức A.
- **Đặc tả thiết kế** cho khối so sánh gói năm và nút mở trang thuê bao:
  `docs/design-spec-annual-saving.md`.

### Việc còn lại

1. **17 `manageUrl` không kết luận được** (ChatGPT, X, Adobe, Disney+, Notion...): các
   trang này là SPA/OAuth trả cùng kết quả cho mọi đường dẫn, nên URL thật và URL bịa
   không phân biệt được kể cả bằng trình duyệt thật. Cần đăng nhập thật mới xác minh.
2. **13 mục chưa có giá và đáng tra lại**: deliveroo-plus, hellofresh, linkedin-learning,
   google-play-pass, sim-wintel, github, geforce-now, amazon-prime-video, viu, airalo,
   money-lover, bkav-pro, evernote.

### Đã đưa vào app 2026-08-24

Hai bề mặt trong `docs/design-spec-annual-saving.md` đã dựng xong và có test.

- **Khối so sánh gói năm** trên màn chi tiết một mục. `AnnualSavingPresenter` dựng chữ,
  `_AnnualSavingCard` vẽ. Đủ năm trạng thái trong đặc tả, cộng ba luật: giá quá 12 tháng
  thì đổi giọng sang "Save about" kèm câu nhắc tra lại; giá người dùng nhập lệch quá 10%
  so với giá niêm yết thì nói rõ phép tính dựa trên giá nào; ưu tiên vùng VN, rơi về
  GLOBAL khi vùng VN không có gì để so.
- **Nút mở trang thuê bao**, bốn trạng thái theo `purchaseChannel`. Cú chạm đầu tiên ghi
  luôn kênh mua, nên dòng "Bought through the App Store?" chỉ xuất hiện một lần.
- **Hỏi ngày gia hạn khi quay lại app**. `launchUrl` trả về ngay lúc iOS nhận đường dẫn
  chứ không phải lúc người dùng quay lại, nên phải bắt bằng `didChangeAppLifecycleState`.
  Ngày nhập ở đây được ghi là `userConfirmed`, không phải ước lượng.
- **`ServiceCatalog.matchByName`**: khớp đúng tên hoặc đúng alias, không khớp tiền tố.
  Search có thể dễ dãi vì người dùng đọc kết quả trước khi chạm, còn hàm này chạy sau
  lưng họ, nên "Netflix (acc của mẹ)" phải không khớp.
- **`url_launcher`** vào `pubspec.yaml`. Build iOS simulator chạy được, 410 test pass.

Một lỗi dữ liệu lộ ra lúc viết test: **`simplize` niêm yết gói năm đúng bằng 12 lần gói
tháng**, nên `savingMinor` bằng 0 chứ không dương như comment cũ khẳng định. Đã sửa
comment và bỏ hẳn khối so sánh khi khoản tiết kiệm bằng 0.

### Mục đã bỏ khỏi catalog

`k-plus` (ngừng dịch vụ ở VN 1/1/2026), `shopeefood-xtra` (không còn gói), `steam` (là ví,
không phải thuê bao), `deepseek` (chỉ bán API), `windsurf` (sáp nhập vào Devin),
`microsoft-copilot` (trùng `microsoft-365`), `hulu` (gộp hẳn vào Disney+).

`amazon-prime-video` và `viu` **giữ lại**: không phục vụ VN nhưng vẫn là dịch vụ thật ở
ngoài, và catalog hỗ trợ cả global lẫn local.

### Mục đã đổi tên

`hbo-go` → Max, `be-hoi-vien` → beOne, `fitbit-premium` → Google Health Premium.
Cả ba giữ nguyên `id`, và luật nhận diện icon giữ **cả tên cũ lẫn tên mới** vì người dùng
vẫn quen gõ tên cũ.

### Đã xác minh xong — ba mục nghi sai đều ĐÚNG

| id | kết luận |
|---|---|
| apple-tv | 179.000đ/tháng đúng, xác minh trên `tv.apple.com/vn`. Trùng giá Apple Arcade VN là trùng hợp thật. |
| zing-mp3 | 49.000đ/tháng và 499.000đ/năm đúng, trên tên miền mới `zingmp3.vn`. Trùng NhacCuaTui là trùng hợp thật. |
| waka | Bảng giá chính thức đúng là 3 tháng 207.000đ / 6 tháng 414.000đ / 12 tháng 828.000đ — không giảm giá theo chu kỳ. |

Gom trong lúc duyệt báo cáo của agent thu thập. Chưa xác minh, chưa sửa trừ chỗ ghi rõ.

## A. Nguồn yếu — có URL nhưng agent không thật sự mở được trang

Lấy từ trích dẫn trong kết quả tìm kiếm, không fetch trực tiếp được:

| id | giá đã ghi | vấn đề |
|---|---|---|
| audible | $14.95/th | amazon.com trả 503 suốt phiên |
| kindle-unlimited | $11.99/th | như trên |
| webtoon | $9.99/th | webtoon.zendesk.com trả 403 |

## B. Số trùng nhau đáng ngờ

| id | giá | vì sao nghi |
|---|---|---|
| apple-tv | 179.000đ/th (VN) | **Trùng đúng giá Apple Arcade VN**. Arcade global $6.99 mà TV+ global $12.99 → TV+ không thể cùng giá VND với Arcade. Nhiều khả năng lấy nhầm từ trang liệt kê nhiều dịch vụ Apple. |
| zing-mp3 | 49.000đ/th, 499.000đ/năm | Trùng khít giá NhacCuaTui. Nguồn `mp3.zing.vn/vip` là tên miền cũ (đã đổi `zingmp3.vn`). |
| waka | quý 207.000đ, năm 828.000đ | Năm = đúng 4× quý, không giảm đồng nào. Có thể là suy ra. |

## C. Nguồn là trang tin / tư vấn của hãng, không phải trang niêm yết giá

`sim-itel` (bài tin tức), `internet-vnpt` (bài tư vấn), `vnsky` (bài tin tức),
`bhyt` (trang UBND huyện dẫn nghị định), `xbox-gamepass` (news.xbox.com).

Riêng `bhyt`: cần kiểm tra Nghị định 161/2026/NĐ-CP và mức lương cơ sở 2.530.000đ có
đúng không — con số 1.366.200đ/năm phụ thuộc hoàn toàn vào hai dữ kiện đó.

## D. Đã sửa tại chỗ

- `qobuz`: đã **xoá gói năm** ($129,96). Agent tự khai là suy ra từ mức 10,83 USD/tháng
  khi cam kết trả năm — trang hãng không hiện tổng tiền cả năm. Vi phạm luật "không suy
  luận".

## E. Mục nên bỏ khỏi catalog

| id | lý do |
|---|---|
| k-plus | K+ **ngừng cung cấp dịch vụ tại VN từ 01/01/2026** (thông báo trên kplus.vn) |
| shopeefood-xtra | không còn gói hội viên trả phí cho người mua ở VN |
| steam | là cửa hàng/ví, không phải thuê bao |
| deepseek | chỉ bán API theo token, không có thuê bao cá nhân |
| windsurf | windsurf.com redirect 308 vĩnh viễn sang devin.ai, đã sáp nhập |
| microsoft-copilot | không bán rời, chỉ có trong Microsoft 365 Premium → trùng mục `microsoft-365` |

## F. Mục cần đổi tên / phân loại

| id | sửa gì |
|---|---|
| hbo-go | đã đổi `name` → "Max" (HBO Go ngừng ở VN 15/6/2026, Max ra mắt 16/6/2026). Giữ `id`. |
| be-hoi-vien | gói cũ thay bằng **beOne** (19.000đ/th, ra mắt 24/6/2026) → đổi `name` |
| fitbit-premium | đang gộp vào **Google Health Premium** |
| hulu | hulu.com/plans redirect 302 sang disneyplus.com → kiểm tra còn là dịch vụ riêng không |
| cleanmymac | `category: SECURITY` sai, là phần mềm dọn máy → cân nhắc chuyển |
| grab-unlimited, uber-one | `category: FOOD` nhưng thực chất là gói bundle cả đi lại lẫn giao đồ ăn |

## G. Cần trình duyệt thật (chrome-devtools MCP) thay cho WebFetch

Trang chặn bot hoặc nạp giá bằng JS. WebFetch không lấy được, không phải lỗi agent.

**Streaming (16 mục — batch nghèo nhất)**: youtube-premium, disney-plus, crunchyroll,
paramount-plus, peacock, fpt-play, vieon, tv360, mytv, amazon-prime-video, viu, iqiyi,
wetv, hulu, twitch-turbo

**Khác**: leonardo-ai, lovable, poe, dashpass, deliveroo-plus, hellofresh, fitbit-premium,
whoop, calm, headspace, peloton, zwift, skillshare, brilliant, babbel, oreilly,
linkedin-learning, soundcloud-go, tidal, amazon-music, google-play-pass, geforce-now,
roblox-premium, minecraft-realms, wow-sub, expressvpn, surfshark, dashlane, lastpass,
proton-drive, box, synology-c2, kaspersky, terabox, bkav-pro, sim-viettel,
internet-viettel, sim-wintel, money-lover, fiin, vietstock, storytel

## H. Giới hạn công cụ đã gặp

**WebSearch hết quota 200/200 trong phiên** — hai agent (streaming, music-gaming) báo hết
giữa chừng và phải chạy nốt bằng WebFetch trực tiếp. Đây là lý do chính khiến batch
streaming chỉ có 4/20 mục có giá.
