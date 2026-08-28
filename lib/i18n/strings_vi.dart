import 'parts/currency_names_vi.dart';
import 'parts/category_names_vi.dart';
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
  String get spendingTitle => 'Chi tiêu';
  @override
  String get savingsTitle => 'Tiết kiệm';
  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String millions(String digits, String symbol, {required bool minorUnits}) =>
      minorUnits ? '$symbol${digits}M' : '$digits triệu $symbol';

  // ---- categories ----

  @override
  String? categoryLabel(String id) => CategoryNamesVi.names[id];

  // ---- currency ----

  @override
  String currencyName(String code) =>
      CurrencyNamesVi.names[code.toUpperCase()] ?? code.toUpperCase();

  // ---- dates ----

  static const List<String> _weekdays = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];

  @override
  String weekday(int weekday) => _weekdays[weekday - 1];

  /// `Tháng 8`, not `Tháng Tám`. Vietnamese numbers its months, and the
  /// numbered form is what a date on a bill is written with.
  /// `T2` through `T7`, and `CN` for Sunday -- what a wall calendar prints.
  @override
  String weekdayShort(int weekday) => weekday == 7 ? 'CN' : 'T${weekday + 1}';

  @override
  String monthName(int month) => 'Tháng $month';
  @override
  String monthShort(int month) => 'th$month';

  @override
  String lockScreenDate(String weekday, int day, String month) =>
      '$weekday, $day $month';
  @override
  String listedDate(int day, String monthShort, int year) =>
      '$day/$monthShort/$year';

  @override
  String get today => 'Hôm nay';
  @override
  String get tomorrow => 'Ngày mai';
  @override
  String get yesterday => 'Hôm qua';

  @override
  String inDays(int days) => 'Còn $days ngày';
  @override
  String daysAgo(int days) => '$days ngày trước';
  @override
  String daysShort(int days) => '$days ngày';
  @override
  String get late => 'Trễ';
  @override
  String daysEarlier(int days) => 'sớm hơn $days ngày';

  @override
  List<String> get dateShortcuts => ['Hôm nay', 'Ngày mai', '+7', '+14', '+30'];

  // ---- onboarding ----

  @override
  String get onboardTitle => 'Không bỏ lỡ hạn thanh toán.';

  @override
  String get onboardListTitle => 'Theo dõi mọi thứ có ngày hết hạn';
  @override
  String get onboardNotifyTitle => 'Biết trước khi tiền bị trừ';
  @override
  String get onboardSpendTitle => 'Xem thống kê chi phí hàng tháng';

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
  String get onboardCurrencyTitle => 'Ngôn ngữ và loại tiền';
  @override
  String get onboardLanguageLabel => 'Ngôn ngữ';
  @override
  String get onboardCurrencyLabel => 'Đơn vị tiền';
  @override
  String get onboardAddCurrency => 'Thêm đơn vị tiền';
  @override
  String get onboardOtherCurrency => 'Đơn vị khác';
  @override
  String get onboardSearchCurrency => 'Tìm loại tiền';
  @override
  String get onboardSampleMonthly => 'hàng tháng';
  @override
  String get onboardDefaultLabel => 'Đơn vị tiền mặc định';
  @override
  String get onboardDefaultNote =>
      'Dùng khi thêm mục mới và khi tính tổng. Mỗi mục vẫn giữ đơn vị tiền đã '
      'nhập cho nó.';
  @override
  String get onboardRemoveCurrency => 'Bỏ';
  @override
  String get onboardNoRateNote =>
      'Subdock chỉ mang theo một tỉ giá, giữa đồng và đô la. Chọn đơn vị tiền '
      'khác thì từng loại vẫn cộng riêng được, nhưng không có một con số tổng '
      'gộp chung.';

  // ---- upcoming ----

  @override
  String get upcomingTitle => 'Sắp tới';

  @override
  String get bucketOverdue => 'Quá hạn';
  @override
  String get bucketNext7 => '7 ngày tới';
  @override
  String get bucketNext30 => '30 ngày tới';
  @override
  String get bucketLater => 'Xa hơn';

  @override
  String get allServices => 'Tất cả dịch vụ';
  @override
  String get layoutList => 'Danh sách';
  @override
  String get layoutCalendar => 'Lịch';

  @override
  String get freeTrials => 'Dùng thử';
  @override
  String overdueAgo(int days) => '$days ngày';

  @override
  String get freeTrialBadge => 'DÙNG THỬ';
  @override
  String get freeNow => 'Đang miễn phí';

  @override
  String instalment(int index, int total) => 'kỳ $index trên $total';

  /// Two letters, not three. See [weekdayShort].
  @override
  List<String> get weekdayInitials => [
    for (var day = 1; day <= 7; day++) weekdayShort(day),
  ];

  @override
  String monthLabel(String monthShort, int year) => '$monthShort/$year';
  @override
  String calendarDayLabel(
    String weekdayShort,
    int day,
    String monthShort,
    int year,
  ) => '$weekdayShort, $day/$monthShort/$year';

  @override
  String get nothingOnThisDay => 'Không có gì trong ngày này.';

  @override
  String get filterTitle => 'Lọc';
  @override
  String get filterClearAll => 'Bỏ hết';
  @override
  String get filterClear => 'Bỏ';
  @override
  String get filterType => 'Nhóm';
  @override
  String get filterBillingCycle => 'Chu kỳ';
  @override
  String get filterPaysFrom => 'Trả bằng';
  @override
  String get filterOnlyShow => 'Chỉ hiện';
  @override
  String get filterNoPrice => 'Chưa có giá';
  @override
  String get filterRemindersOff => 'Đã tắt nhắc';
  @override
  String get filterNoSource => 'Chưa ghi nguồn';

  @override
  String filterShow(int count) => 'Hiện $count mục';
  @override
  String filterCount(int shown, int total) => '$shown trên $total mục';
  @override
  String filterTypes(int count) => '$count nhóm';
  @override
  String filterCycles(int count) => '$count chu kỳ';
  @override
  String filterSources(int count) => '$count nguồn';

  @override
  String get bullet => ' · ';

  @override
  String get nothingTracked => 'Chưa theo dõi gì';
  @override
  String get nothingTrackedBody => 'Thêm cái ngày bạn hay quên nhất.';
  @override
  String get addAnItem => 'Thêm một mục';
  @override
  String get nothingMatchesFilters => 'Không mục nào khớp bộ lọc';
  @override
  String get clearFilters => 'Bỏ bộ lọc';

  // ---- item detail ----

  @override
  String expiredAgo(int days) => 'Hết hạn $days ngày trước';
  @override
  String overdueBy(int days) => 'Quá hạn $days ngày';
  @override
  String get expiresToday => 'Hết hạn hôm nay';
  @override
  String get dueToday => 'Đến hạn hôm nay';
  @override
  String get expiresTomorrow => 'Hết hạn ngày mai';
  @override
  String get dueTomorrow => 'Đến hạn ngày mai';
  @override
  String expiresInDays(int days) => 'Còn $days ngày nữa hết hạn';
  @override
  String dueInDays(int days) => 'Còn $days ngày nữa đến hạn';

  @override
  String get edit => 'Sửa';
  @override
  String get rowCategory => 'Nhóm';
  @override
  String get rowRepeats => 'Lặp lại';
  @override
  String get rowLastPayment => 'Lần trả gần nhất';
  @override
  String get rowRemindMe => 'Nhắc tôi';
  @override
  String get rowCost => 'Giá';
  @override
  String get rowTotalLeft => 'Còn phải trả';
  @override
  String get rowPaysFrom => 'Trả bằng';
  @override
  String get rowDateFrom => 'Ngày lấy từ';
  @override
  String get rowNote => 'Ghi chú';
  @override
  String get rowYearlyPlan => 'Gói năm';
  @override
  String get whatHappensNext => 'Sắp tới có gì';
  @override
  String get addACost => 'Thêm giá';

  @override
  String get rowHistory => 'Lịch sử';
  @override
  String get never => 'Chưa bao giờ';

  @override
  String repeatTimes(String cycle, int total) => '$cycle · $total lần';

  @override
  String get cycleOnce => 'Một lần';
  @override
  String get cycleWeekly => 'Hàng tuần';
  @override
  String get cycleMonthly => 'Hàng tháng';
  @override
  String get cycleQuarterly => 'Hàng quý';
  @override
  String get cycleTwiceAYear => 'Nửa năm một lần';
  @override
  String get cycleYearly => 'Hàng năm';
  @override
  String cycleEvery(String interval) => 'Mỗi $interval';

  @override
  String intervalDays(int count) => '$count ngày';
  @override
  String intervalWeeks(int count) => '$count tuần';
  @override
  String intervalMonths(int count) => '$count tháng';
  @override
  String intervalYears(int count) => '$count năm';

  @override
  String intervalShortDays(int count) => '$count ngày';
  @override
  String intervalShortWeeks(int count) => '$count tuần';
  @override
  String intervalShortMonths(int count) => '$count tháng';
  @override
  String intervalShortYears(int count) => '$count năm';

  @override
  String get perWeek => '/ tuần';
  @override
  String get perMonth => '/ tháng';
  @override
  String get perQuarter => '/ quý';
  @override
  String get perHalfYear => '/ 6 tháng';
  @override
  String get perYear => '/ năm';
  @override
  String perInterval(String shortInterval) => '/ $shortInterval';
  @override
  String get aYear => ' một năm';

  @override
  String get instalmentPayment => 'Kỳ trả';
  @override
  String instalmentPosition(int index, int total) => '$index trên $total';
  @override
  String instalmentPaid(int count) => 'đã trả $count';
  @override
  String get instalmentThisOneDue => 'kỳ này đến hạn';
  @override
  String instalmentLeft(int count) => 'còn $count';
  @override
  String get instalmentLastOne => 'kỳ cuối';

  @override
  String get dateSourceConfirmed => 'đã hỏi nhà cung cấp';
  @override
  String get dateSourceRemembered => 'nhớ áng chừng';
  @override
  String get dateSourceComputed => 'app tính từ chu kỳ';
  @override
  String get dateSourceExtracted => 'đọc từ ảnh, chưa kiểm lại';

  @override
  String get leadOnTheDay => 'Đúng ngày';
  @override
  String leadDaysBefore(int days) => 'Trước $days ngày';

  @override
  String get actions => 'Việc có thể làm';
  @override
  String get editReminders => 'Sửa nhắc hạn';
  @override
  String get remindAgainInThreeDays => 'Nhắc lại sau 3 ngày';
  @override
  String get deleteThisItem => 'Xoá mục này';
  @override
  String get markAsPaid => 'Ghi nhận đã trả';
  @override
  String markPaymentAsPaid(int index) => 'Ghi nhận đã trả kỳ $index';
  @override
  String get stopAfterThisPayment => 'Dừng sau kỳ này';
  @override
  String get cancelThisSubscription => 'Huỷ gói này';
  @override
  String get paid => 'Đã trả';

  @override
  String deleteConsequence(int reminderCount) {
    final reminders = reminderCount == 0
        ? 'Không có nhắc hạn nào đang chờ.'
        : 'Bỏ $reminderCount nhắc hạn đang chờ.';
    return '$reminders Các lần trả đã ghi cũng đi theo, và màn Chi tiêu '
        'thôi tính mục này.';
  }

  @override
  String deleteAskTitle(String name) => 'Xoá $name?';
  @override
  String get deleteAskLost => 'Mất theo';
  @override
  String get deleteAskRemindersStopped => 'Nhắc hạn dừng lại';
  @override
  String get deleteAskKeep => 'Giữ lại';
  @override
  String get deleteAskConfirm => 'Xoá';
  @override
  String get recordedPaymentsNone => 'Chưa ghi lần nào';
  @override
  String recordedPayments(int count) => '$count lần trả đã ghi';
  @override
  String get pendingRemindersNone => 'Không có cái nào đang chờ';
  @override
  String pendingReminders(int count) => '$count nhắc hạn đang chờ';

  // ---- the timeline ----

  @override
  String get timelineActBy => 'Phải xong trước ngày này';
  @override
  String get timelineExpires => 'Hết hạn';
  @override
  String get timelineFirstPayment => 'Lần trả đầu tiên';
  @override
  String get timelinePaymentDue => 'Đến hạn trả';
  @override
  String get timelineAlreadyPassed => 'đã qua';
  @override
  String timelineCharged(String amount) => 'bị trừ $amount';
  @override
  String timelineFreeForDays(int days) => 'Còn miễn phí $days ngày nữa';
  @override
  String get timelineNothingChargedYet => 'chưa bị trừ đồng nào';
  @override
  String get timelineSnoozed => 'Bạn đã hẹn nhắc lại';
  @override
  String get timelineVerify => 'Kiểm lại ngày còn đúng không';
  @override
  String get timelineNag => 'Vẫn chưa ghi nhận đã trả';
  @override
  String timelineNagEvery(int stepDays) =>
      'Rồi ${stepDays == 1 ? 'mỗi ngày' : 'mỗi $stepDays ngày'} cho tới khi '
      'bạn ghi nhận đã trả';
  @override
  String timelineReminderAt(String time) => 'Nhắc lúc $time';
  @override
  String get timelineReminder => 'Nhắc hạn';
  @override
  String timelineNext(String label) => '$label · gần nhất';
  @override
  String get timelineSilentPaused =>
      'Mục này đã tắt nhắc, nên không có gì được đặt lịch.';
  @override
  String get timelineSilentClosed =>
      'Mục này đã đóng, nên không còn gì được đặt lịch.';
  @override
  String get timelineSilentLadderDone =>
      'Không còn nhắc hạn nào. Mọi nấc của thang nhắc cho mục này đều đã qua.';
  @override
  String timelineDropped(int count, int budget) =>
      '$count nhắc hạn nữa của mục này không lọt vào $budget suất app đặt '
      'được, và sẽ được nhặt lại khi các mốc gần trôi qua.';

  // ---- spending ----

  @override
  String get spanMonth => 'Tháng';
  @override
  String get spanYear => 'Năm';
  @override
  String get thisMonth => 'Tháng này';
  @override
  String get nextTwelveMonths => '12 tháng tới';
  @override
  String get costByMonth => 'CHI THEO THÁNG';
  @override
  String get inAFreeTrial => 'ĐANG DÙNG THỬ';
  @override
  String startsCharging(String date) => 'Bắt đầu trừ tiền $date';
  @override
  String get byCategory => 'Theo nhóm';
  @override
  String get byItem => 'Theo mục';
  @override
  String get paymentHistory => 'Lịch sử trả tiền';
  @override
  String get open => 'Mở ›';
  @override
  String get whereItGoes => 'Tiền đi đâu';
  @override
  String get whereItGoesCaption => 'Vẫn con số đó, chia theo loại.';
  @override
  String get bandSubscriptions => 'Gói thuê bao';
  @override
  String get bandBills => 'Hoá đơn và tiện ích';
  @override
  String get bandAnnual => 'Trả một lần mỗi năm';
  @override
  String timesInMonth(String name, int times) => '$name ×$times';
  @override
  String approximately(String amount) => '≈ $amount';
  @override
  String alternateTotal(String amount, String rate) => '≈ $amount ($rate)';
  @override
  String unconverted(int currencies) =>
      'Không có tỉ giá dùng được — $currencies loại tiền nằm ngoài tổng';
  @override
  String get chartNothingDue => 'không có gì đến hạn';
  @override
  String chartAmount(String digits, String currency) => '$digits $currency';
  @override
  String get chartNotDueYet => 'chưa tới hạn';

  // ---- savings ----

  @override
  String get tabMoveToYearly => 'Sang gói năm';
  @override
  String get tabCancelAService => 'Huỷ dịch vụ';

  @override
  String get savingsCancelLead =>
      'Xếp theo mức dễ bỏ. Mỗi con số là khoản bạn thôi trả trong một năm.';
  @override
  String get savingsNothingToMove => 'Chưa có gì đáng chuyển lúc này.';
  @override
  String savingsYearlyLead(int cheaper, int monthlyCount) =>
      '$cheaper trên $monthlyCount gói hàng tháng rẻ hơn nếu trả theo năm.';

  @override
  String get savingsNothingToMoveShort => 'Chưa có gì đáng chuyển';
  @override
  String savingsTotalSub(int plans) =>
      'một năm, nếu chuyển $plans gói sang trả theo năm';

  @override
  String get paidUpFront => 'Trả trước một lần, không phải hàng tháng';

  @override
  String skippedSuggestions(int count) => 'Đã bỏ qua $count gợi ý — hiện lại';

  @override
  String get cancelDisclaimer =>
      'Subdock không huỷ hộ bạn được. Nó đưa bạn tới đúng trang, và thôi theo '
      'dõi khi bạn nói là đã xong.';

  @override
  String reminderSetFor(String date) => 'Đã hẹn nhắc ngày $date';
  @override
  String remindMeOn(String date) => 'Nhắc tôi ngày $date';
  @override
  String get skip => 'Bỏ qua';

  @override
  String noYearlyPriceYet(int count) => '$count gói chưa có giá năm';
  @override
  String get addPrice => 'Thêm giá';

  @override
  String get openedOpenAgain => 'Đã mở · mở lại';
  @override
  String get cancelledRemove => 'Đã huỷ — bỏ khỏi Subdock';

  @override
  String get tierEntertainment => 'Giải trí';
  @override
  String get tierEntertainmentHint => 'Dễ bỏ nhất';
  @override
  String get tierWork => 'Công việc và công cụ';
  @override
  String get tierWorkHint => 'Chỉ giữ cái đang dùng';
  @override
  String get tierHard => 'Khó bỏ';
  @override
  String get tierHardHint => 'Lưu trữ, kết nối, tiện ích';

  @override
  String yearlyCompare(String monthly, String yearly, int percent) =>
      '$monthly × 12 → $yearly · rẻ hơn $percent%';
  @override
  String yearlyNoteStale(String checkedDate) =>
      'Giá niêm yết từ $checkedDate — kiểm lại trước đã.';
  @override
  String yearlyNoteMismatch(String listed, String entered) =>
      'Giá niêm yết là $listed, không phải $entered bạn đã nhập.';
  @override
  String yearlyNoteFresh(String checkedDate) =>
      'Trả một lần mỗi năm, không phải hàng tháng. Giá niêm yết tra ngày '
      '$checkedDate.';

  @override
  String leftOut(String parts) => 'Không tính: $parts';
  @override
  String leftOutAlreadyYearly(int count) => '$count đã trả theo năm';
  @override
  String leftOutInTrial(int count) => '$count đang dùng thử';
  @override
  String leftOutUnpriced(int count) => '$count gói chưa có giá năm';

  @override
  String perYearAmount(String amount) => '$amount/năm';

  @override
  String get viaAppStore => 'App Store';
  @override
  String get whereAppStore => 'Cài đặt › Tài khoản Apple › Thuê bao';
  @override
  String get actionAppStore => 'Mở danh sách thuê bao';
  @override
  String get viaGooglePlay => 'Google Play';
  @override
  String get whereGooglePlay => 'Play Store › Thanh toán và gói thuê bao';
  @override
  String get actionGooglePlay => 'Mở danh sách thuê bao';
  @override
  String get viaWeb => 'Web';
  @override
  String get actionCancelPage => 'Mở trang huỷ';
  @override
  String get viaAccountPage => 'Trang tài khoản';
  @override
  String get actionAccountPage => 'Mở trang tài khoản';
  @override
  String get viaNotInCatalogue => 'Không có trong danh mục';
  @override
  String get whereNotInCatalogue => 'Subdock không biết trang huỷ của mục này';

  @override
  String get savingLeadAbout => 'Tiết kiệm khoảng';
  @override
  String get savingLeadExact => 'Tiết kiệm';
  @override
  String savingLine(String lead, String amount) => '$lead $amount một năm';
  @override
  String twelveTimes(String monthly, String twelve) =>
      '$monthly × 12 = $twelve';
  @override
  String annualNoteStale(String checkedDate) =>
      'Giá niêm yết từ $checkedDate — kiểm lại giá hiện tại';
  @override
  String annualNoteFresh(String checkedDate) =>
      'Giá niêm yết, tra ngày $checkedDate';
  @override
  String annualNoteMismatch(String listed, String entered) =>
      'Tính theo giá niêm yết $listed, không phải $entered bạn đã nhập';

  @override
  String openAccount(String name) => 'Mở tài khoản $name';
  @override
  String get manageInAppStore => 'Quản lý trong App Store';
  @override
  String get manageInGooglePlay => 'Quản lý trong Google Play';
  @override
  String get boughtThroughAppStore => 'Bạn mua qua App Store?';

  // ---- settings ----

  @override
  String get rowCurrency => 'Loại tiền';
  @override
  String get rowLanguage => 'Ngôn ngữ';
  @override
  String get rowWidget => 'Widget';
  @override
  String get widgetNotYet => 'Chưa có';
  @override
  String get rowAppearance => 'Giao diện';
  @override
  String get themeSystem => 'Theo máy';
  @override
  String get themeLight => 'Sáng';
  @override
  String get themeDark => 'Tối';
  @override
  String get sectionBackup => 'Sao lưu';
  @override
  String get sectionApp => 'Ứng dụng';
  @override
  String get rowAbout => 'Giới thiệu';
  @override
  String get rowICloud => 'iCloud';
  @override
  String get rowFile => 'Nhập/Xuất';
  @override
  String get rowReminders => 'Nhắc hạn';
  @override
  String get rowPaymentSources => 'Nguồn tiền';
  @override
  String get exportABackup => 'Xuất một bản sao lưu';
  @override
  String droppedRemindersTitle(int count) =>
      'Có $count nhắc hạn không đặt được';
  @override
  String droppedRemindersBody(int budget, String names) =>
      'App chỉ đặt được nhiều nhất $budget nhắc hạn một lúc. '
      'Không đặt được: $names.';

  // ---- about ----

  @override
  String get aboutTitle => 'Giới thiệu';
  @override
  String get aboutLead =>
      'Subdock theo dõi mọi thứ có ngày hết hạn và nhắc bạn trước khi nó mất '
      'hiệu lực.';
  @override
  String get aboutThisBuild => 'Bản này';
  @override
  String get aboutVersion => 'Phiên bản';
  @override
  String get aboutBuild => 'Số build';
  @override
  String get aboutPrices =>
      'Giá trong danh mục dịch vụ đóng gói sẵn là giá nhà cung cấp niêm yết '
      'vào ngày được tra, và app nói rõ ngày đó. Chúng ở đây để điền nhanh một '
      'ô, không phải để nói bạn đang trả bao nhiêu.';

  @override
  String get chooseABackup => 'Chọn một bản sao lưu Subdock';

  // ---- payment sources ----

  @override
  String get sourcesTitle => 'Nguồn tiền';
  @override
  String get sourcesLead =>
      'Một cái tên bạn nhận ra, để nhắc hạn nói được thẻ hay tài khoản nào sắp '
      'bị trừ. App không nối với ngân hàng nào cả.';
  @override
  String get sourcesNewItems => 'Mục mới';
  @override
  String get sourcesStartsOn => 'Mặc định dùng';
  @override
  String get sourcesYours => 'Nguồn của bạn';
  @override
  String get sourcesEmpty =>
      'Chưa có nguồn nào. Thêm thẻ hay tài khoản bạn hay trả tiền nhất.';
  @override
  String get sourcesAddOne => 'Thêm một cái';
  @override
  String get sourcesAddTitle => 'Thêm nguồn';
  @override
  String get sourcesAddLead =>
      'Một cái tên gọi là đủ. Đừng bao giờ nhập số thẻ đầy đủ.';
  @override
  String get sourcesNameHint => 'ví dụ VCB 4412';
  @override
  String sourcesDefaultUsage(String usage) => 'Mặc định · $usage';
  @override
  String get sourcesRemove => 'Bỏ';
  @override
  String get sourcesNotUsedYet => 'Chưa dùng lần nào';
  @override
  String sourcesItemCount(int count) => '$count mục';

  @override
  String get sourcePresetCard => 'Thẻ';
  @override
  String get sourcePresetBank => 'Chuyển khoản';
  @override
  String get sourcePresetWallet => 'Ví điện tử';
  @override
  String get sourcePresetContactless => 'Apple / Google Pay';
  @override
  String get sourcePresetCash => 'Tiền mặt';

  // ---- all services ----

  @override
  String get servicesLead =>
      'Tắt một mục thì nó thôi hiện trên Sắp tới và thôi gửi nhắc hạn. Không '
      'có gì bị xoá.';
  @override
  String get servicesEmpty => 'Chưa theo dõi gì.';
  @override
  String get servicesAdd => 'Thêm một dịch vụ';
  @override
  String servicesRemindersFor(String name) => 'Nhắc hạn của $name';
  @override
  String get servicesOff => 'Đã tắt · không nhắc';
  @override
  String servicesTrialEnds(String date) => 'Hết dùng thử $date';
  @override
  String servicesNext(String date) => 'Kỳ tới $date';

  // ---- history ----

  @override
  String get historyTitle => 'Lịch sử';
  @override
  String get historyAll => 'Tất cả';
  @override
  String get historyPaid => 'Đúng hạn';
  @override
  String get historyMissed => 'Trễ';
  @override
  String historyMonthWithYear(String month, int year) => '$month/$year';
  @override
  String historyClosedClean(int count) =>
      'Đã xong $count. Đây là bằng chứng cho những gì đã không xảy ra.';
  @override
  String historyClosedWithMissed(int count, int missed) =>
      'Đã xong $count · $missed cái xong sau khi ngày hạn đã qua.';
  @override
  String historyClosedOnTime(int count) =>
      'Đã xong $count, đúng hạn hoặc sớm hơn.';
  @override
  String historyClosedLate(int count) =>
      'Đã xong $count, sau khi ngày hạn đã qua.';
  @override
  String get historyEmptyAll =>
      'Chưa có gì đóng lại. Những việc bạn xử lý kịp sẽ được ghi ở đây.';
  @override
  String get historyEmptyPaid => 'Chưa có gì đóng lại đúng hạn.';
  @override
  String get historyEmptyMissed => 'Chưa có gì để lỡ quá ngày hạn.';
  @override
  String get historyVerbMissed => 'trễ';
  @override
  String get historyVerbHandled => 'đã xử lý';
  @override
  String get historyVerbPaid => 'đã trả';
  @override
  String get historyVerbRenewed => 'đã gia hạn';

  // ---- reminders ----

  @override
  String budgetHolds(int held, int budget) =>
      'Đang giữ $held trên $budget suất nhắc hạn app đặt được.';
  @override
  String budgetDroppedElsewhere(int count) =>
      'Có $count nhắc hạn của các mục khác phải bỏ đi.';

  @override
  String get remindersDefaultSchedule => 'Thang nhắc mặc định';
  @override
  String get remindersSchedule => 'Thang nhắc';
  @override
  String get remindersTimeOfDay => 'Giờ trong ngày';
  @override
  String get remindersSendAt => 'Gửi lúc';
  @override
  String get remindersChannels => 'Kênh';
  @override
  String get remindersPush => 'Thông báo đẩy';
  @override
  String get remindersSendTest => 'Gửi thử một nhắc hạn';
  @override
  String get remindersTurnOffForItem => 'Tắt mọi nhắc hạn của mục này';
  @override
  String get remindersNotificationsOff =>
      'Thông báo đang tắt, nên không có gì được gửi đi.';
  @override
  String get remindersInexact =>
      'Máy này không cho app đặt báo thức đúng phút, nên nhắc hạn sẽ tới lúc '
      'hệ thống thức dậy chứ không phải đúng giờ ở trên. Cho phép mục "Báo '
      'thức và lời nhắc" trong cài đặt hệ thống để sửa.';

  // ---- the form ----

  @override
  String get newItem => 'Mục mới';
  @override
  String get pickerStep => 'Bước 1 trên 2 · chọn dịch vụ';
  @override
  String get searchServices => 'Tìm dịch vụ';
  @override
  String get pickerNoMatch =>
      'Không có gì khớp. Thêm nó theo đúng tên bạn vừa gõ.';
  @override
  String get pickerNotInList => 'Không có trong danh sách?';
  @override
  String get enterManually => 'Tự nhập';
  @override
  String get scan => 'Quét';

  @override
  String editingName(String name) => 'Đang sửa $name';
  @override
  String get editItem => 'Sửa mục';
  @override
  String get untitledItem => 'Mục chưa đặt tên';

  @override
  String get fieldName => 'Tên';
  @override
  String get fieldNameHint => 'ví dụ Spotify';
  @override
  String get fieldCategory => 'Nhóm';
  @override
  String get fieldPickCategory => 'Chọn một nhóm';
  @override
  String get fieldPlan => 'Gói';
  @override
  String get fieldRepeats => 'Lặp lại';
  @override
  String get fieldBillingCycle => 'Chu kỳ tính tiền';
  @override
  String get fieldFreeTrial => 'Dùng thử';
  @override
  String get fieldInFreeTrialNow => 'Đang trong kỳ dùng thử';
  @override
  String get fieldRemindMe => 'Nhắc tôi';
  @override
  String get fieldCost => 'Giá';
  @override
  String get fieldCostOptional => 'Giá (không bắt buộc)';
  @override
  String get fieldNextPaymentDate => 'Ngày trả tiền kế tiếp';
  @override
  String get fieldLastPaymentOn => 'Kỳ cuối vào ngày';
  @override
  String get fieldChooseADate => 'Chọn một ngày';
  @override
  String get fieldTapToOpenCalendar => 'Chạm để mở lịch';
  @override
  String get fieldOpenSubscriptionPage => 'Mở trang thuê bao';
  @override
  String get fieldNote => 'Ghi chú';
  @override
  String get fieldNoteHint => 'Điều gì bạn muốn nhớ';

  @override
  String get saveChanges => 'Lưu thay đổi';
  @override
  String get saveItem => 'Lưu mục';

  @override
  String useCustomName(String typed) => 'Dùng "$typed" làm tên riêng';

  @override
  String get repeatsForever => 'Lặp mãi';
  @override
  String get stopsAfter => 'Dừng sau';
  @override
  String get afterANumberOfPayments => 'Sau một số kỳ trả';
  @override
  String get onADate => 'Vào một ngày';
  @override
  String paymentsCount(int count) => '$count kỳ';
  @override
  String get paymentsUnit => 'kỳ trả';

  @override
  String get cycleOther => 'Khác';
  @override
  String get cycleEveryEllipsis => 'Mỗi…';
  @override
  String get cycleOneOff => 'Một lần';
  @override
  String get unitDays => 'Ngày';
  @override
  String get unitWeeks => 'Tuần';
  @override
  String get unitMonths => 'Tháng';
  @override
  String get unitYears => 'Năm';
  @override
  String get every => 'Mỗi';
  @override
  String currentlyCycle(String cycle) =>
      'Đang là $cycle — chạm cái khác để đổi.';

  @override
  String get planOtherAmount => 'Số tiền khác';
  @override
  String get planTypeItYourself => 'Tự gõ vào';

  @override
  String get paysFrom => 'TRẢ BẰNG';
  @override
  String get optionalSuffix => ' · không bắt buộc';
  @override
  String get sourceNotSet => 'Chưa đặt';
  @override
  String get sourceNew => 'Thêm';
  @override
  String get sourceClearName => 'Xoá tên';
  @override
  String get sourceHelp => 'Một cái tên bạn nhận ra. Đừng bao giờ là số thẻ.';

  @override
  String get summaryAmountNotSet => 'một số tiền bạn chưa nhập';
  @override
  String get summaryNoDate =>
      'Nhập ngày trả tiền kế tiếp thì khoản đó sẽ hiện ở đây.';
  @override
  String summaryTrial(String date, String money) =>
      'Miễn phí tới $date — rồi bị trừ $money.';
  @override
  String summaryCharge(String money, String date) =>
      'Bạn sẽ bị trừ $money vào $date.';
  @override
  String summaryReminderOnTheDay(String date) => 'Nhắc đúng ngày, $date.';
  @override
  String summaryReminderBefore(String lead, String date) =>
      'Nhắc $lead, vào $date.';

  @override
  String get searchIcons => 'Tìm icon';
  @override
  String get galleryCategories => 'Nhóm';
  @override
  String get galleryServices => 'Dịch vụ';
  @override
  String galleryNoIcon(String query) => 'Không có icon nào tên "$query"';
  @override
  String get galleryClearSearch => 'Xoá ô tìm để chọn một hình chung.';
  @override
  String get customEllipsis => 'Tự chọn…';

  @override
  String get addedToSubdock => 'Đã thêm vào Subdock';
  @override
  String get turnOnReminders => 'Bật nhắc hạn';
  @override
  String get notNow => 'Để sau';
  @override
  String get onlyDueDateReminders => 'Chỉ nhắc ngày đến hạn. Không gì khác.';

  @override
  String get restoreAskTitle => 'Khôi phục bản sao lưu này?';
  @override
  String get restoreAskReplaceTitle => 'Thay toàn bộ bằng bản sao lưu này?';
  @override
  String get restoreAskFrom => 'Từ tệp';
  @override
  String restoreAskSummary(String incoming, String takenOn) =>
      '$incoming · $takenOn';
  @override
  String get restoreAskLost => 'Bị xoá khỏi máy này';
  @override
  String get restoreAskKeep => 'Giữ cái đang có';
  @override
  String get restoreAskConfirm => 'Khôi phục';
  @override
  String get restoreAskReplace => 'Thay toàn bộ';

  @override
  String get backupNow => 'Hiện tại';
  @override
  String get backupActions => 'Việc có thể làm';
  @override
  String get backupNever => 'Chưa bao giờ';
  @override
  String get backupCloudTitle => 'iCloud';
  @override
  String get backupCloudIntro =>
      'Subdock giữ một bản chép danh sách của bạn trong iCloud của chính bạn, '
      'và ghi lại mỗi khi có gì đổi. Không có tài khoản nào và không có máy '
      'chủ Subdock nào dính vào.';
  @override
  String get backupLastSaved => 'Lưu gần nhất';

  @override
  String backupCopyAt(String date, String time) => '$date lúc $time';
  @override
  String get backupLastExport => 'Lần xuất gần nhất';
  @override
  String get backupRestoreFromCloud => 'Khôi phục từ iCloud';
  @override
  String get backupCloudRestoreNote =>
      'Khôi phục là thay toàn bộ những gì đang có trong app bằng những gì nằm '
      'trong iCloud. Nó không trộn.';
  @override
  String get backupFileTitle => 'Nhập/Xuất';
  @override
  String get backupExportCsv => 'Xuất ra CSV';
  @override
  String csvExported(int count) => 'Đã xuất \$count dịch vụ.';
  @override
  String get backupFileIntro =>
      'Bản sao lưu JSON chứa tất cả: mọi mục, mọi nhóm, mọi nguồn tiền và mọi '
      'lần trả đã ghi. Tệp CSV chứa chính cái danh sách, mỗi dòng một dịch '
      'vụ, để mở bằng bảng tính.';
  @override
  String get backupRestoreFromFile => 'Khôi phục từ một tệp';
  @override
  String get backupFileRestoreNote =>
      'Khôi phục là thay toàn bộ những gì đang có trong app bằng những gì nằm '
      'trong tệp. Nó không trộn, và nó chỉ đọc bản sao lưu JSON. Tệp CSV chỉ '
      'đi ra, không quay về.';
  @override
  String get backupNothingSaved => 'Chưa có gì được sao lưu';
  @override
  String backupNothingSavedBody(int confirmed) =>
      'Danh sách của bạn chỉ nằm trên máy này, và $confirmed ngày trong đó đã '
      'được hỏi lại nhà cung cấp. Gỡ app là mất chúng.';
  @override
  String get backupStale => 'Có ngày mới chưa được sao lưu';
  @override
  String backupStaleBody(int confirmed) =>
      '$confirmed ngày bạn đã hỏi lại nhà cung cấp không nằm trong bản sao '
      'nào. Bản gần nhất được tạo trước khi bạn thêm chúng.';
  @override
  String get backupStateSignedOut => 'Hãy đăng nhập iCloud';
  @override
  String get backupStateReconnect => 'Hãy kết nối lại tài khoản';
  @override
  String get backupFirstCopy => 'Đang lưu bản đầu tiên';
  @override
  String get backupStateDisconnected => 'Chưa kết nối';
  @override
  String get backupStateFailed => 'Không lưu được';
  @override
  String get backupDriveTitle => 'Google Drive';
  @override
  String get backupDriveIntro =>
      'Subdock giữ một bản sao danh sách trong Google Drive của chính bạn, ở '
      'một thư mục ẩn chỉ app này mở được. Bạn sửa gì thì nó ghi lại bản mới, '
      'và bạn lấy về được trên máy khác.';
  @override
  String get backupDriveAccount => 'Tài khoản';
  @override
  String get backupDriveConnect => 'Kết nối tài khoản Google';
  @override
  String get backupDriveConnectNote =>
      'Subdock không có tài khoản và không có máy chủ. Bản sao đi vào tài '
      'khoản Google bạn chọn, ở một thư mục ẩn với Drive và với mọi app khác. '
      'App không đọc gì khác trong Drive của bạn.';
  @override
  String get backupDriveDisconnect => 'Ngắt tài khoản này';
  @override
  String get backupRestoreFromDrive => 'Khôi phục từ Drive';
  @override
  String get backupDriveRestoreNote =>
      'Khôi phục là thay hết những gì đang có trong app bằng nội dung bản sao. '
      'Ngắt tài khoản thì bản sao vẫn nằm nguyên trong Drive.';
  @override
  String get backupNoteWholeDevice =>
      'Subdock không có tài khoản và không có máy chủ. Danh sách của bạn nằm '
      'trong bản sao lưu của chính chiếc iPhone này, nhưng iOS chỉ khôi phục '
      'nó bằng cách khôi phục cả máy.';
  @override
  String get backupNotePerApp =>
      'Subdock không có tài khoản và không có máy chủ. Nó chỉ giữ những bản sao '
      'trong mục này. Bản sao lưu Google của chính máy này cũng có thể mang '
      'danh sách sang máy mới, theo lịch riêng của nó, và Subdock không can '
      'thiệp vào bản đó.';
  @override
  String get backupNoteUnknown =>
      'Subdock không có tài khoản và không có máy chủ. Những gì bạn thấy trong '
      'app là bản duy nhất, và gỡ app là mất nó.';

  // ---- notifications ----

  @override
  String get channelDeadlines => 'Hạn chót';
  @override
  String get channelDeadlinesBody => 'Những thứ qua ngày là mất.';
  @override
  String get channelReminders => 'Nhắc hạn';
  @override
  String get channelRemindersBody => 'Gia hạn và những ngày đáng liếc qua.';

  @override
  String get actionMarkAsPaid => 'Đã trả';
  @override
  String get actionRemindTomorrow => 'Mai nhắc lại';
  @override
  String get actionOpen => 'Mở';
  @override
  String get actionGotIt => 'Đã biết';

  @override
  String get testReminderTitle => 'Nhắc hạn thử';
  @override
  String get testReminderBody =>
      'Thông báo tới được. Không có gì trong danh sách đến hạn cả.';

  @override
  String get notifDueToday => 'Đến hạn hôm nay';
  @override
  String get notifDueTomorrow => 'Đến hạn ngày mai';
  @override
  String notifDueInDays(int days) => 'Còn $days ngày nữa đến hạn';
  @override
  String get notifOverdue => 'Đã quá hạn';
  @override
  String get notifVerify => 'Kiểm lại ngày này còn đúng không';
  @override
  String get notifSnoozed => 'Bạn đã hẹn nhắc lại';
  @override
  String get notifYearlyCostsLess => 'Gói năm rẻ hơn';

  // ---- the app's own voice ----

  @override
  String get notificationsOffTitle => 'Thông báo đang tắt';
  @override
  String get notificationsOffBody => 'Sẽ không có gì nhắc bạn.';
  @override
  String get turnOn => 'Bật';

  @override
  String cutAYear(String amount) => 'Cắt được $amount một năm';
  @override
  String plansCostLessYearly(int count) =>
      '$count gói rẻ hơn nếu trả theo năm · huỷ hẳn còn tiết kiệm hơn';

  @override
  String get none => 'Chưa có';

  @override
  String savedNamed(String name) => 'Đã lưu "$name".';
  @override
  String savedUnderLater(String name) =>
      'Đã lưu "$name" — nó nằm ở nhóm Xa hơn.';
  @override
  String savedUnderNext30(String name) =>
      'Đã lưu "$name" — nó nằm ở nhóm 30 ngày tới.';
  @override
  String get askTrialEnds => 'Nhắc bạn trước khi hết dùng thử nhé?';
  @override
  String askBeforeCharges(String name) =>
      'Nhắc bạn trước khi $name trừ tiền nhé?';

  @override
  String askLineOnTheDay(String fireOn, String money, String from) =>
      'Thông báo vào $fireOn, đúng ngày nó xảy ra$money$from.';
  @override
  String askLineBefore(
    String fireOn,
    String lead,
    String actBy,
    String money,
    String from,
  ) => 'Thông báo vào $fireOn — $lead ($actBy)$money$from.';
  @override
  String askMoneyThen(String amount) => ' · rồi $amount';
  @override
  String askMoney(String amount) => ' · $amount';
  @override
  String askFrom(String source) => ' từ $source';
  @override
  String reminderSetOn(String date) => 'Đã hẹn nhắc vào $date.';

  @override
  String get sawRenewalDate => 'Bạn có thấy ngày gia hạn không?';
  @override
  String get enterDate => 'Nhập ngày';
  @override
  String savedConfirmedDate(String date) =>
      'Đã lưu $date, ghi là đã hỏi nhà cung cấp.';
  @override
  String get yearlyMentionedInReminder =>
      'Nhắc hạn gia hạn sẽ nói kèm giá gói năm.';
  @override
  String remindingAgainOn(String date) => 'Sẽ nhắc lại vào $date.';

  @override
  String backedUp(String summary) => 'Đã sao lưu $summary.';
  @override
  String couldNotExport(String error) => 'Không xuất được: $error';
  @override
  String restored(String summary) => 'Đã khôi phục $summary.';
  @override
  String couldNotRestore(String error) => 'Không khôi phục được: $error';
  @override
  String couldNotOpenFile(String error) => 'Không mở được tệp đó: $error';
  @override
  String get noCopyInICloud => 'Chưa có bản nào trong iCloud.';
  @override
  String get signInToICloud => 'Đăng nhập iCloud để lấy bản cất ở đó.';
  @override
  String couldNotReadICloud(String detail) => 'Không đọc được iCloud: $detail.';
  @override
  String get noCopyInDrive => 'Trên Drive chưa có bản sao nào.';
  @override
  String get connectDriveFirst => 'Hãy kết nối tài khoản Google trước.';
  @override
  String couldNotReadDrive(String detail) => 'Không đọc được Drive: $detail.';
  @override
  String couldNotConnectDrive(String detail) =>
      'Không kết nối được tài khoản: $detail.';
  @override
  String get unknownError => 'lỗi không rõ';
  @override
  String takenOn(String date) => 'lấy ngày $date';

  @override
  String get couldNotOpenPage => 'Không mở được trang đó.';
  @override
  String couldNotScheduleTest(String error) => 'Không hẹn thử được: $error';
  @override
  String testSetInexact(String at, String zone) =>
      'Đã hẹn thử lúc $at $zone, xê dịch vài phút — máy này không bắn đúng '
      'phút được.';
  @override
  String testSet(String at, String zone) => 'Đã hẹn thử lúc $at $zone.';

  // ---- reading a bill ----

  @override
  String get scanTitle => 'Quét hoá đơn';
  @override
  String get scanLead => 'Đọc được — kiểm lại trước khi lưu';
  @override
  String get scanCaption =>
      'Đọc từ ảnh hoặc từ đoạn chữ bạn dán vào. Chưa có gì ở đây được xác nhận '
      'cho tới khi bạn lưu.';
  @override
  String get scanRetake => 'Chụp lại';
  @override
  String get scanCouldNotRead => 'không đọc được';
  @override
  String get scanNothingToQuote => 'không có gì để trích';
  @override
  String get scanDue => 'Hạn';
  @override
  String get scanAmount => 'Số tiền';
  @override
  String scanUnitUnclear(String minor) => '$minor · chưa rõ đơn vị';
  @override
  String get scanDayBeforeMonth => 'ngày trước tháng';
  @override
  String get scanMonthBeforeDay => 'tháng trước ngày';

  @override
  String warnUnsupportedValue(String field) =>
      'Mục $field trả về mà không chỉ vào chỗ nào trong ảnh. Kiểm lại đi.';
  @override
  String warnAmbiguousDate(String raw) =>
      'Ngày $raw đọc được theo hai kiểu. Chọn kiểu đúng.';
  @override
  String get warnMissingDate => 'Không tìm thấy ngày đến hạn. Tự gõ vào.';
  @override
  String get warnUnknownCurrency => 'Chưa rõ loại tiền. Chọn đồng hay đô la.';
  @override
  String get warnLowConfidence =>
      'Mô hình không chắc về lần đọc này. Kiểm từng dòng trước khi lưu.';

  @override
  String get fieldServiceNameLower => 'tên dịch vụ';
  @override
  String get fieldDueLower => 'ngày đến hạn';
  @override
  String get fieldAmountLower => 'số tiền';

  @override
  String get errRateLimited => 'Đang bận. Thử lại sau vài giây.';
  @override
  String get errCreditExhausted =>
      'Tài khoản OpenAI hết tiền rồi. Nạp thêm rồi thử lại.';
  @override
  String get errSpendLimit => 'Bạn đã chạm mức chi tiêu tự đặt trên OpenAI.';
  @override
  String get errInvalidKey =>
      'Khoá API sai hoặc đã bị thu hồi. Kiểm lại trong Cài đặt.';
  @override
  String get errRegionUnsupported => 'OpenAI chưa hỗ trợ khu vực của bạn.';
  @override
  String get errUpstream => 'OpenAI đang trục trặc. Thử lại sau.';
  @override
  String get errNoNetwork => 'Không có kết nối mạng.';
  @override
  String get errUnreadable => 'Không đọc được nội dung này.';
  @override
  String get errTruncated => 'Dài quá, không đọc hết được.';
  @override
  String get errBadShape => 'Câu trả lời về sai định dạng.';
  @override
  String get errNoApiKey =>
      'Chưa có khoá API. Thêm một cái trong Cài đặt để dùng được.';

  // ---- backup files ----

  @override
  String get backupNotOurs => 'Tệp đó không phải bản sao lưu của Subdock.';
  @override
  String get backupTooNew =>
      'Bản sao lưu đó do một phiên bản Subdock mới hơn ghi ra.';
  @override
  String backupFileContains(String what) => 'Trong tệp có $what.';
  @override
  String get backupWhatCategoryNoId => 'một nhóm không có id';
  @override
  String get backupWhatCategory => 'một nhóm';
  @override
  String get backupWhatSourceNoId => 'một nguồn tiền không có id';
  @override
  String get backupWhatItemNoId => 'một mục không có id';
  @override
  String get backupWhatPaymentNoId => 'một lần trả đã ghi không có id';
  @override
  String get backupWhatPaymentNoItem =>
      'một lần trả đã ghi không gắn với mục nào';
  @override
  String backupItemHasNoDate(String name) => 'Một mục không có ngày: $name.';
  @override
  String get backupPaymentHasNoDate =>
      'Một lần trả đã ghi không có ngày nào trên đó.';
  @override
  String backupSummaryItems(int count) => '$count mục';
  @override
  String backupSummaryPayments(int count) => '$count lần trả';
  @override
  String backupSummarySources(int count) => '$count nguồn tiền';
  @override
  String get listJoin => ', ';

  @override
  String get fallbackShelf => 'Khác';
  @override
  String get csvColName => 'Tên';
  @override
  String get csvColCategory => 'Nhóm';
  @override
  String get csvColNextDate => 'Ngày kế tiếp';
  @override
  String get csvColRepeats => 'Lặp lại';
  @override
  String get csvColAmount => 'Số tiền';
  @override
  String get csvColCurrency => 'Loại tiền';
  @override
  String get csvColPaidWith => 'Trả bằng';
  @override
  String get csvColTrial => 'Dùng thử';
  @override
  String get csvColStatus => 'Trạng thái';
  @override
  String get csvColNote => 'Ghi chú';
  @override
  String get csvYes => 'Có';
  @override
  String get csvNo => 'Không';
  @override
  String get csvStateActive => 'Đang theo dõi';
  @override
  String get csvStateCancelled => 'Đã huỷ (còn hạn dùng)';
  @override
  String get csvStateArchived => 'Đã cất đi';
}
