import 'parts/currency_names_vi.dart';
import 'strings.dart';

class ViStrings implements Strings {
  const ViStrings();

  // ---- common ----

  @override
  String get cancel => 'Huỷ';
  @override
  String get save => 'Lưu';
  @override
  String get done => 'Xong';
  @override
  String get back => 'Quay lại';
  @override
  String get continueOn => 'Tiếp tục';
  @override
  String get getStarted => 'Bắt đầu';

  @override
  String millions(String digits, String symbol, {required bool minorUnits}) =>
      minorUnits ? '$symbol${digits}M' : '$digits triệu $symbol';

  // ---- currency ----

  @override
  String currencyName(String code) =>
      CurrencyNamesVi.names[code.toUpperCase()] ?? code.toUpperCase();

  // ---- onboarding ----

  @override
  String get onboardTitle => 'Không bỏ lỡ ngày đến hạn nào nữa.';

  @override
  String get onboardListTitle => 'Mọi thứ có ngày hạn, trong một danh sách';
  @override
  String get onboardNotifyTitle => 'Báo trước ngày hạn, không phải sau';
  @override
  String get onboardSpendTitle => 'Xem cộng lại là bao nhiêu';

  @override
  String get onboardNextTwelveMonths => '12 tháng tới';

  @override
  String get sampleMobileSim => 'SIM điện thoại';
  @override
  String get sampleElectricity => 'Tiền điện';
  @override
  String get sampleCarInsurance => 'Bảo hiểm ô tô';
  @override
  String get sampleDrivingLicence => 'Giấy phép lái xe';
  @override
  String get sampleHomeInternet => 'Internet nhà';
  @override
  String get sampleWaterBill => 'Tiền nước';

  @override
  String expiresOn(String date) => 'hết hạn $date';
  @override
  String dueOn(String date) => 'đến hạn $date';
  @override
  String renewsOn(String date) => 'gia hạn $date';
  @override
  String trialEndsOn(String date) => 'hết dùng thử $date';

  @override
  String notifSimTitle(int days) => 'SIM điện thoại hết hạn sau $days ngày';
  @override
  String get notifSimBody => 'Nạp tiền để giữ số';
  @override
  String get notifNetflixTitle => 'Netflix gia hạn vào ngày mai';
  @override
  String notifNetflixBody(String amount) => '$amount · chỉ nhắc một lần';

  @override
  String get notifNow => 'vừa xong';
  @override
  String notifAge(int days) => '$days ngày';

  @override
  String get onboardCurrencyTitle => 'Bạn trả tiền bằng loại tiền nào?';
  @override
  String get onboardCurrencyBody =>
      'Các khoản tổng và từng mục đều hiện theo loại tiền này. Bạn vẫn nhập '
      'được giá bằng loại tiền khác.';
  @override
  String get onboardOtherCurrency => 'Loại tiền khác';
  @override
  String get onboardSearchCurrency => 'Tìm loại tiền';
  @override
  String get onboardLanguageLabel => 'Ngôn ngữ';
  @override
  String get onboardNoRateNote =>
      'Subdock chỉ mang theo một tỉ giá, giữa đồng và đô la. Chọn loại tiền '
      'khác thì từng loại vẫn cộng riêng được, nhưng không có một con số tổng '
      'gộp chung.';
}
