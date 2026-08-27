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
  String get spendingTitle => 'Chi tiêu';
  @override
  String get savingsTitle => 'Tiết kiệm';
  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String millions(String digits, String symbol, {required bool minorUnits}) =>
      minorUnits ? '$symbol${digits}M' : '$digits triệu $symbol';

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
  String get freeTrials => 'Đang dùng thử';
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
}
