# Thư mục research: đọc cái nào trước

Năm tài liệu trong thư mục này đều sinh ra từ **một đợt việc duy nhất**: dựng danh mục
dịch vụ cho app, từ 71 mục lên 223 mục, làm trong hai ngày 23 và 24 tháng 8 năm 2026.

Chúng không phải năm nghiên cứu độc lập. Chúng là năm giai đoạn của cùng một việc, viết
ra ở năm thời điểm khác nhau, nên có cái đã cũ so với cái khác.

## Muốn xem từng dịch vụ thu được gì

**[`catalog-coverage.md`](catalog-coverage.md)**. Bảng từng dịch vụ một, chia theo nhóm:
thu được mấy dòng giá, vùng nào, có đủ cặp tháng và năm không, icon ở mức nào, có link
trang thuê bao và link huỷ không, và nếu không có giá thì vì sao.

Bảng này **sinh tự động** bằng `python3 tool/coverage_table.py`, đọc thẳng từ
`assets/services.json` và từ luật icon trong code. Cập nhật danh mục xong thì chạy lại,
đừng sửa tay.

## Nếu chỉ đọc một cái

**[`catalog-report.md`](catalog-report.md)** (341 dòng). Bản tổng kết, viết cuối cùng
nên phản ánh đúng hiện trạng. Có đầu bài, kết quả bằng số, cách làm, cái gì không thu
được và vì sao, rủi ro còn lại, cách cập nhật về sau.

Bốn tài liệu còn lại là chi tiết đằng sau nó.

## Thứ tự sinh ra

```
service-list-review.md   →  dataset-plan.md  →  collector-brief.md  →  catalog-report.md
   "nên có dịch vụ nào"       "lưu ra sao"        "agent làm thế nào"     "kết quả ra sao"

manage-links.md          nhánh riêng, xuất hiện giữa đợt
```

## Từng cái là gì

| Tài liệu | Là gì | Còn đúng không |
|---|---|---|
| [`catalog-report.md`](catalog-report.md) | Tổng kết cả đợt. Đầu bài, số liệu, cách làm, rủi ro, cách cập nhật | **Đúng hiện trạng** |
| [`manage-links.md`](manage-links.md) | Nghiên cứu link trang thuê bao, kênh thanh toán, và USSD nhà mạng | **Đúng**, nhưng phần USSD đã bị loại khỏi dữ liệu, xem bên dưới |
| [`service-list-review.md`](service-list-review.md) | Danh sách dịch vụ đề xuất ban đầu, để duyệt trước khi thu thập | Đã hoàn thành vai trò. Một số mục trong đó sau này bị bỏ |
| [`dataset-plan.md`](dataset-plan.md) | Kế hoạch: schema, chia việc cho 10 agent, cách chặn rủi ro | Schema còn đúng. Phần kế hoạch chạy thì đã xong |
| [`collector-brief.md`](collector-brief.md) | Luật giao cho agent thu thập: luật giá, luật nguồn, định dạng | **Còn dùng được** nếu chạy thêm một đợt thu thập nữa |

## Ba chỗ dễ hiểu nhầm

**`service-list-review.md` là bản đề xuất, không phải bản chốt.** Nó liệt kê khoảng 200
dịch vụ để duyệt. Sau khi thu thập, 7 mục bị bỏ hẳn (K+ ngừng dịch vụ ở Việt Nam, Hulu
gộp vào Disney+, Steam không phải thuê bao, và bốn mục nữa) và 3 mục đổi tên. Danh sách
đúng nằm trong `assets/services.json`, không nằm ở đây.

**`manage-links.md` có nguyên một phần về mã USSD nhà mạng, và phần đó đã bị loại khỏi
dữ liệu.** Hai lý do cộng lại: nguồn chỉ đạt mức tin cậy B hoặc C, và iOS chặn hoàn toàn
việc quay số USSD từ trong app. Giữ tài liệu vì phần kết luận kỹ thuật vẫn có giá trị,
đặc biệt chi tiết `%23` làm `canOpenURL:` trả về `true` trong khi trình quay số không hề
mở, tức nút sẽ im lặng không làm gì. Cái còn dùng được từ phần đó là App Store ID chính
thức của 7 nhà mạng.

**`dataset-plan.md` mục 6 ghi "bốn quyết định cần chốt" và cả bốn đã được chốt.** Câu
trả lời nằm ngay trong đó, và cũng được nhắc lại ở `catalog-report.md` mục 1.4.

## Tài liệu liên quan ngoài thư mục này

| Đường dẫn | Nội dung |
|---|---|
| [`../../data/services/_verify.md`](../../data/services/_verify.md) | Trạng thái hiện tại và việc còn lại. Đọc cái này để biết làm tiếp gì |
| [`../icon-credits.md`](../icon-credits.md) | Nguồn và giấy phép icon, ba mức hình, hai luật hạ mức |
| [`../design-spec-annual-saving.md`](../design-spec-annual-saving.md) | Đặc tả giao diện cho phần so sánh gói năm và nút mở trang thuê bao |
| [`../product-spec.md`](../product-spec.md) | Đặc tả chức năng của app. Có trước đợt này |

## Dữ liệu nằm ở đâu

| Đường dẫn | Nội dung |
|---|---|
| `assets/services.json` | Danh mục đã gộp, app đọc file này |
| `data/services/*.json` | 10 file nguồn theo nhóm. Sửa ở đây rồi chạy merge |
| `data/manage-urls.json` | Link trang thuê bao và App Store ID nhà mạng |
| `data/icons/coverage-*.json` | Kết quả khảo sát icon cho từng dịch vụ |
| `tool/brand_icons/*.svg` | Logo tải về cho hãng không có trong bộ icon mở |
