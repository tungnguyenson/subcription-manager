# Kế hoạch dựng dataset dịch vụ

Mục tiêu: từ ~200 dịch vụ trong [service-list-review.md](service-list-review.md), dựng ra
một dataset có **tên + phân loại + các gói cước + icon**, đủ để form thêm mục điền sẵn
gần hết, và đủ để tính "chuyển sang gói năm tiết kiệm bao nhiêu".

Trạng thái: **đã chốt, đang chạy**. Bốn quyết định ở mục 6 đã có câu trả lời.

---

## 0. Vì sao phải chốt schema trước khi spawn agent

Nếu 10 agent cùng đi thu thập mà chưa có schema cố định, sẽ nhận về 10 kiểu dữ liệu khác
nhau và mất công merge hơn cả tự làm. Schema là việc phải xong trước, và là việc mình
làm, không giao agent.

Schema hiện tại chỉ chứa **một** giá:

```json
{ "defaultCycle": "MONTHLY", "typicalAmountMinor": 231000, "currency": "VND" }
```

Không đủ. Muốn tính tiết kiệm gói năm thì phải có giá tháng **và** giá năm **của cùng
một tier**. Netflix có 4 tier × 2 chu kỳ × 2 vùng giá.

### Schema đề xuất (v3)

```json
{
  "id": "netflix",
  "name": "Netflix",
  "aliases": ["netflix"],
  "sector": "STREAMING",
  "category": "SUBSCRIPTION",
  "defaultCycle": "MONTHLY",
  "cancelUrl": "https://www.netflix.com/cancelplan",
  "noteVi": null,
  "defaultPlan": "standard",
  "plans": [
    {
      "tier": "standard",
      "name": "Standard",
      "region": "VN",
      "currency": "VND",
      "cycle": "MONTHLY",
      "amountMinor": 220000,
      "seats": 2,
      "note": "1080p, 2 thiết bị",
      "source": "https://help.netflix.com/vi/node/24926",
      "checkedAt": "2026-08-23"
    }
  ]
}
```

Điểm quan trọng:

- **`tier` là khoá nhóm.** Gói tháng và gói năm của cùng một tier phải trùng `tier` thì
  mới trừ được cho nhau. Đây là lý do duy nhất `tier` tồn tại.
- **`region`** — `VN` hoặc `GLOBAL`. Một dịch vụ có thể có cả hai (Netflix), hoặc chỉ một
  (điện nước chỉ `VN`, Cursor chỉ `GLOBAL`).
- **`source` + `checkedAt` là bắt buộc với mọi giá.** Không có nguồn thì **không ghi giá**,
  chứ không đoán. Đây là đúng nguyên tắc `DateSource` mà app đang theo: thà thiếu còn hơn
  hiển thị một con số tự tin mà sai. Agent sẽ bị buộc theo luật này.
- **Tương thích ngược:** script merge tự sinh lại `typicalAmountMinor` + `currency` từ
  `defaultPlan` (ưu tiên plan `region: VN`, cycle `MONTHLY`), nên
  [add_item_screen.dart:620](../../lib/ui/screens/add_item_screen.dart#L620) và toàn bộ
  test hiện có không phải sửa ở bước này.
- **`sector` là trường mới, `category` giữ nguyên.** Đúng như đã bàn: `sector` là lĩnh vực
  (17 nhóm), `category` là ngữ nghĩa thanh toán (5 giá trị trong
  [model.dart:39](../../lib/domain/model.dart#L39)). Cả hai cùng tồn tại.

### Danh sách `sector`

17 nhóm của bạn: `AI` `STREAMING` `MUSIC` `GAMING` `PRODUCTIVITY` `SOCIAL` `NEWS`
`FOOD` `FITNESS` `FINANCE` `EDUCATION` `SECURITY` `ENTERTAINMENT` `TRAVEL` `DATING`
`STORAGE` `PHONE`

Cộng 4 nhóm cho phần VN mà 17 nhóm trên không phủ (điện, nước, chung cư, khoản vay,
giấy tờ, bảo hiểm): `UTILITIES` `HOUSING` `DOCUMENTS` `INSURANCE`

→ 21 sector. Không có `OTHER`: mục nào không xếp được thì phải xem lại có nên vào catalog
không.

---

## 1. Các pha

| Pha | Việc | Ai làm | Đầu ra |
|---|---|---|---|
| A | Chốt schema + viết validator + viết script merge | mình | `tool/validate_services.py`, `tool/merge_services.py` |
| B | Thu thập, chia theo sector | ~10 agent song song | `data/services/<sector>.json` |
| C | Đối chiếu giá, mục có giá trị cao | ~4 agent | báo cáo sai lệch |
| D | Merge + validate + test | mình | `assets/services.json` v3 |
| E | Icon: dò độ phủ, phân tier 1/2/3 | 2 agent + mình | cập nhật `BRANDS`, `_rules`, golden |
| F | Sửa code đọc `plans[]`, UI so sánh gói năm | mình | (bước sau, không thuộc kế hoạch này) |

Pha A phải xong trước B. Pha C phụ thuộc B. Pha E chạy song song được với C/D vì nó chỉ
cần **danh sách tên**, không cần giá.

---

## 2. Pha B — chia việc cho agent

Chia theo sector, mỗi agent 1–3 sector, khoảng 15–25 dịch vụ. Mỗi agent ghi đúng một file,
không đụng file của agent khác, nên chạy song song không tranh chấp.

| # | Agent | Sector | Ước lượng số mục |
|---|---|---|---|
| 1 | ai | AI | 19 |
| 2 | streaming | STREAMING | 18 |
| 3 | music-gaming | MUSIC, GAMING | 23 |
| 4 | productivity | PRODUCTIVITY | 23 |
| 5 | social-news | SOCIAL, NEWS | 19 |
| 6 | food-fitness | FOOD, FITNESS | 23 |
| 7 | finance-education | FINANCE, EDUCATION | 26 |
| 8 | security-storage | SECURITY, STORAGE | 27 |
| 9 | ent-travel-dating | ENTERTAINMENT, TRAVEL, DATING | 26 |
| 10 | phone-vn | PHONE, UTILITIES, HOUSING, DOCUMENTS, INSURANCE | 30 (đa số đã có sẵn) |

Brief cho mỗi agent, viết một lần rồi thay phần sector:

1. Đọc `docs/research/dataset-plan.md` (file này) để lấy schema. Không tự chế trường mới.
2. Với mỗi dịch vụ: mở **trang giá chính thức của hãng** bằng WebFetch. Trang giá bên thứ
   ba (báo, blog tổng hợp) chỉ dùng để tìm đường tới trang chính thức, không được dùng làm
   `source`.
3. Có bản giá VN riêng thì lấy cả `region: VN` lẫn `region: GLOBAL`. Không có thì chỉ lấy
   cái tồn tại.
4. **Không tra được giá → để `plans: []`.** Không suy ra, không quy đổi tỉ giá, không lấy
   giá năm ngoái. Ghi lý do vào `noteVi`.
5. `cancelUrl` trỏ tới trang huỷ thật, không phải trang chủ. Không tìm thấy trang huỷ thì
   để `null`.
6. Ghi ra `data/services/<tên-file>.json`, chạy `python3 tool/validate_services.py <file>`
   cho tới khi sạch, rồi mới báo xong.
7. Trả về: số mục, số mục có giá, số mục không tra được và vì sao.

Mỗi agent chỉ ghi file của nó, không sửa `assets/services.json`, không sửa code Dart.

---

## 3. Pha C — đối chiếu

Giá là chỗ dễ bịa nhất. Pha B đã buộc có `source`, pha C kiểm tra `source` đó có thật nói
đúng con số đó không.

Không đối chiếu hết 200 mục. Chỉ đối chiếu:

- Mọi mục có `region: VN` (giá VN hay đổi, và là giá người dùng thật sự nhìn thấy)
- Top ~40 dịch vụ phổ biến nhất
- Mọi mục có giá trông bất thường (validator tự gắn cờ: lệch >3× so với trung vị sector)

Agent đối chiếu **không được xem giá cũ trước khi tra**; tra độc lập rồi mới so. Lệch thì
báo, không tự sửa.

---

## 4. Pha E — icon

Đọc `docs/icon-credits.md` trước. Hệ thống 3 tier đã có, không đổi kiến trúc: SVG được
**biên dịch thành đường vẽ Dart** lúc build (`tool/gen_service_marks.py` →
`lib/ui/widgets/service_marks.data.dart`), app không nhúng `flutter_svg`, không đọc file
asset lúc chạy.

### Luật nguồn icon (bạn chốt 2026-08-23)

1. **Có trong bộ icon mở thì dùng bộ đó** — theSVG (MIT), CoreUI Brands (CC0), SVG Logos
   (CC0), MDI (Apache 2.0). Generator tải thẳng từ CDN như hiện nay, khai báo dạng
   `("thesvg:netflix", "E50914", "netflix")`.
2. **Không bộ nào có thì tải logo về, để trong một folder trong repo.** Đề xuất
   `tool/brand_icons/<khoá>.svg`, và thêm một dạng nguồn mới cho generator:
   `("file:vieon", "MÃMÀU", None)` → đọc file thay vì gọi mạng.

   Folder nằm trong `tool/` chứ không phải `assets/` vì nó là **nguyên liệu lúc build**,
   không phải asset lúc chạy — app vẫn chỉ đọc `service_marks.data.dart`. Để trong
   `assets/` sẽ khiến file bị đóng gói vào binary hai lần.

   Lợi ích phụ: hết phụ thuộc CDN, dựng lại được offline — đúng cái mà `icon-credits.md`
   đang phàn nàn ("dựng lại nó cần mạng và cần với tới bốn CDN").

3. **Chỉ tải được bản raster (PNG/favicon) thì không lên tier 1.** Generator chỉ nuốt SVG.
   Mục đó rơi về tier 2 như hiện nay: hình hạng mục tô màu thương hiệu. Đây đúng lý do bạn
   đã chọn dấu hiệu đơn sắc từ đầu — favicon của vài hãng VN chỉ có 16–32px.
4. Mỗi nguồn mới **một dòng trong bảng của `icon-credits.md` trước khi** vào generator.
   Logo tải thẳng từ hãng thì ghi rõ URL và ngày tải; nó là nhãn hiệu, dùng theo diện
   nominative fair use mà mục "Về nhãn hiệu" đã nêu, không phải giấy phép mở.

### Việc của pha E

- **Agent icon-1**: dò độ phủ ~160 tên mới trên theSVG / Iconify / Simple Icons.
  **Cạm bẫy đã ghi trong `icon-credits.md`: jsdelivr trả HTTP 200 cho file không tồn tại** —
  phải đối chiếu `data/simple-icons.json`, không dò bằng mã trạng thái.
- **Agent icon-2**: với mục không bộ nào có, tải logo SVG từ trang chủ hãng về
  `tool/brand_icons/`, kèm mã màu thương hiệu và URL nguồn. Chỉ có raster thì báo lại,
  không tự chuyển đổi.
- **Mình**: thêm dạng nguồn `file:` vào generator, gắn tier, thêm dòng `BRANDS`, thêm luật
  `_rules` (nhớ **cụm dài phải nằm trên từ nằm trong nó**), thêm `CategoryGlyph` mới nếu
  cần, chạy lại golden, cập nhật `icon-credits.md`.

Rủi ro thật: ~160 mục mới sẽ có nhiều mục rơi xuống tier 3 cùng một hình. 20 dịch vụ AI
cùng một glyph thì cột icon hết tác dụng phân biệt. Dự kiến cần thêm ~8 glyph hạng mục:
AI, dating, fitness, education, travel, news, food, VPN.

## 5. Rủi ro và cách chặn

| Rủi ro | Chặn bằng |
|---|---|
| Agent bịa giá | Bắt buộc `source` + `checkedAt`; không nguồn thì không giá; pha C tra độc lập |
| Giá cũ đi | `checkedAt` trên từng plan; UI phải hiển thị "giá tham khảo", không hiển thị như sự thật |
| 10 agent ra 10 kiểu | Schema chốt ở pha A; validator chạy trong chính agent trước khi báo xong |
| Trùng id giữa các file | Validator merge kiểm tra id toàn cục ở pha D |
| Dataset phình, app chậm | Đo lại kích thước `services.json` sau merge; hiện 71 mục, dự kiến ~250 |
| Mục không dùng ở VN chiếm chỗ | `region` cho phép lọc; search vẫn ưu tiên prefix nên ít ảnh hưởng |
| Icon tier 3 trùng nhau hàng loạt | Thêm glyph hạng mục mới ở pha E |

---

## 6. Bốn quyết định — đã chốt 2026-08-23

1. **Độ sâu của plan**: chỉ **tier phổ biến nhất**, nhưng lấy đủ cả chu kỳ tháng và năm.
   Mỗi dịch vụ ra 2–4 dòng plan. Đây là mức tối thiểu để tính được tiết kiệm gói năm mà
   dataset không phình.
2. **Vùng giá**: `VN` + `GLOBAL` (USD). Có bảng giá VN thì lấy VN; không thì lấy giá niêm
   yết USD. Không lấy EU.
3. **Phạm vi**: chạy hết ~230 mục, chia 10 batch song song.
4. **Mục chung** ("Thẻ tập gym", "Học phí", "Gói cước data"): **có đưa vào, `plans: []`**.
   Chúng vào catalog để user chọn nhanh và có sẵn category + icon, còn giá thì tự nhập.
   Không bịa khoảng giá.
