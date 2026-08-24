# Brief cho agent thu thập dữ liệu dịch vụ

Bạn nhận **đúng một file** trong `data/services/`. Chỉ sửa file đó. Không sửa file của
batch khác, không sửa `assets/services.json`, không sửa code Dart, không chạy `flutter`.

## Việc

File đã có sẵn stub cho mọi dịch vụ thuộc batch của bạn. Với **từng** mục:

1. Điền `aliases` — những chuỗi thường **viết thường, không dấu** mà người dùng có thể gõ
   trên điện thoại. Ví dụ Netflix → `["netflix"]`; ELSA Speak → `["elsa", "elsa speak"]`;
   Thẻ tập gym → `["gym", "the tap gym", "phong tap"]`. App tự bỏ dấu khi tìm, nhưng cứ
   thêm cả bản không dấu cho chắc.
2. Xác nhận `category` (ngữ nghĩa thanh toán, khác `sector`):
   - `SUBSCRIPTION` — tự gia hạn tới khi huỷ. Gần như mọi mục trong danh sách.
   - `BILL` — khoản phải trả theo kỳ, số tiền thay đổi (học phí, điện, khoản vay).
   - `INSURANCE`, `DOCUMENT` — chỉ dùng cho bảo hiểm và giấy tờ.
   - `OTHER` — **cấm dùng**. Validator sẽ chặn.
3. Điền `plans` theo luật giá bên dưới.
4. Điền `defaultPlan` = `tier` của gói phổ biến nhất (chỉ khi `plans` không rỗng).
5. `cancelUrl`: link tới **trang huỷ thật**, không phải trang chủ. Không tìm thấy thì để
   `null`. Bắt buộc `https://`.
6. `manageUrl`: link tới **trang xem gói của chính người dùng** — nơi hiện gói đang dùng,
   giá đang trả và ngày gia hạn kế tiếp. Ví dụ Claude: `https://claude.ai/new#settings/billing`.
   App không đọc được hồ sơ bên nhà cung cấp, nên link này là đường ngắn nhất để người dùng
   tự đi xác nhận ngày hết hạn. **Chỉ ghi URL có bằng chứng tồn tại**: trang trợ giúp của
   hãng ghi rõ đường dẫn đó, hoặc mở ra trả 200/302 sang trang đăng nhập. Trả 404 thì không
   phải. **Không tự chế đường dẫn nghe hợp lý** kiểu đoán `/account/subscription`.
7. `noteVi`: một câu tiếng Việt, chỉ viết khi có thứ thật sự đáng nói — không bán ở VN,
   không tra được giá và vì sao, gói có ràng buộc lạ. Không viết câu quảng cáo.
8. Xoá `_todo` và `_hint` khi làm xong mục đó. Xoá `_legacyPrice` sau khi đã xác minh lại
   (dù kết quả là ghi plan mới hay bỏ hẳn giá cũ).

## Luật giá — phần dễ sai nhất

Mỗi mục lấy **một tier duy nhất**: tier phổ biến nhất với người dùng cá nhân. Không lấy
gói doanh nghiệp, không lấy hết mọi tier.

Với tier đó, lấy **cả chu kỳ tháng và chu kỳ năm** nếu hãng có bán cả hai. Đây là lý do
tồn tại của cả dataset này: app cần so gói tháng với gói năm để nói cho người dùng biết
chuyển sang gói năm tiết kiệm bao nhiêu.

Vùng giá:

- `region: "VN"`, `currency: "VND"` — khi hãng có bảng giá riêng cho Việt Nam.
- `region: "GLOBAL"`, `currency: "USD"` — giá niêm yết USD.
- Có cả hai thì ghi cả hai. Chỉ có một thì ghi một.
- **Không tự quy đổi tỉ giá.** Giá VND phải là giá hãng niêm yết bằng VND.

Đơn vị `amountMinor`:

- VND: ghi **nguyên đồng**. 231.000đ → `231000`. VND không có đơn vị phụ.
- USD: ghi **cent**. $19.99 → `1999`.

**Nguồn là bắt buộc.** `source` phải là trang giá của chính hãng (`https://`). Báo, blog
tổng hợp, bài "top 10 gói rẻ nhất" chỉ dùng để tìm đường tới trang chính thức — không
được ghi vào `source`. `checkedAt` là ngày bạn thật sự mở trang đó.

**Trang App Store / Google Play của chính hãng được tính là nguồn chính thức** (bổ sung
2026-08-23). Nhiều hãng chặn bot ở web nhưng vẫn niêm yết đầy đủ mục "In-App Purchases"
trên store, và với người dùng VN thì đó mới đúng là giá thật sự bị trừ tiền. Điều kiện:
phải là trang app của chính hãng (`apps.apple.com/...`, `play.google.com/...`), không
phải bài viết nói về app đó.

**Không tra được thì để `plans: []`** và ghi lý do vào `noteVi`. Không suy luận, không lấy
giá năm ngoái, không lấy giá vùng khác thay thế. App này có cả một enum `DateSource` chỉ
để tránh hiển thị một con số tự tin hơn mức nó xứng đáng — dữ liệu giá theo đúng nguyên
tắc đó.

Mục được đánh dấu `MỤC CHUNG` trong `_hint` ("Thẻ tập gym", "Học phí", "SMS Banking")
**luôn để `plans: []`**. Chúng không có giá chuẩn.

### Ví dụ một mục hoàn chỉnh

```json
{
  "id": "netflix",
  "name": "Netflix",
  "aliases": ["netflix"],
  "sector": "STREAMING",
  "category": "SUBSCRIPTION",
  "defaultCycle": "MONTHLY",
  "cancelUrl": "https://www.netflix.com/cancelplan",
  "manageUrl": "https://www.netflix.com/account",
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

## Trước khi báo xong

```bash
python3 tool/validate_services.py data/services/<batch>.json
```

Phải sạch lỗi. Cảnh báo (`warn`) thì đọc và tự quyết, không bắt buộc phải hết.

Validator sẽ chặn các lỗi hay gặp: giá VND bị nhân/chia 100, gói năm rẻ hơn gói tháng
(dấu hiệu điền nhầm ô), gói năm đắt hơn 12 lần gói tháng, `source` không phải https,
`checkedAt` ở tương lai, `region: VN` mà lại ghi USD.

## Báo cáo trả về

Ngắn gọn, dạng văn xuôi, gồm đúng bốn ý:

1. Số mục đã xử lý / tổng số.
2. Số mục có giá, số mục có cả gói năm.
3. Danh sách mục **không** tra được giá, kèm lý do một dòng mỗi mục.
4. Bất cứ thứ gì bạn thấy sai trong stub: dịch vụ đã ngừng hoạt động, đổi tên, không còn
   bán ở VN, hoặc phân loại `sector` đặt sai.

Không tóm tắt lại brief này trong báo cáo.
