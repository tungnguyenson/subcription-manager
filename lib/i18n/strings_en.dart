import 'parts/currency_names_en.dart';
import 'strings.dart';

class EnStrings implements Strings {
  const EnStrings();

  // ---- common ----

  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get done => 'Done';
  @override
  String get back => 'Back';
  @override
  String get continueOn => 'Continue';
  @override
  String get getStarted => 'Get started';

  @override
  String get spendingTitle => 'Spending';
  @override
  String get savingsTitle => 'Savings';
  @override
  String get settingsTitle => 'Settings';

  @override
  String millions(String digits, String symbol, {required bool minorUnits}) =>
      minorUnits ? '$symbol${digits}M' : '${digits}M $symbol';

  // ---- currency ----

  @override
  String currencyName(String code) =>
      CurrencyNamesEn.names[code.toUpperCase()] ?? code.toUpperCase();

  // ---- dates ----

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  String weekday(int weekday) => _weekdays[weekday - 1];
  @override
  String weekdayShort(int weekday) => _weekdays[weekday - 1].substring(0, 3);

  @override
  String monthName(int month) => _months[month - 1];
  @override
  String monthShort(int month) => _months[month - 1].substring(0, 3);

  @override
  String lockScreenDate(String weekday, int day, String month) =>
      '$weekday $day $month';
  @override
  String listedDate(int day, String monthShort, int year) =>
      '$day $monthShort $year';

  @override
  String get today => 'Today';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String get yesterday => 'Yesterday';

  @override
  String inDays(int days) => 'In $days ${days == 1 ? 'day' : 'days'}';
  @override
  String daysAgo(int days) => '$days ${days == 1 ? 'day' : 'days'} ago';
  @override
  String daysShort(int days) => '${days}d';
  @override
  String get late => 'Late';
  @override
  String daysEarlier(int days) => '$days ${days == 1 ? 'day' : 'days'} earlier';

  @override
  List<String> get dateShortcuts => ['Today', 'Tomorrow', '+7', '+14', '+30'];

  // ---- onboarding ----

  @override
  String get onboardTitle => 'Never miss a due date again.';

  @override
  String get onboardListTitle => 'Everything with a date, in one list';
  @override
  String get onboardNotifyTitle => 'Told before the date, not after';
  @override
  String get onboardSpendTitle => 'See what it adds up to';

  @override
  String get onboardNextTwelveMonths => 'Next 12 months';

  @override
  String get sampleMobileSim => 'Mobile SIM';
  @override
  String get sampleElectricity => 'Electricity';
  @override
  String get sampleCarInsurance => 'Car insurance';
  @override
  String get sampleDrivingLicence => 'Driving licence';
  @override
  String get sampleHomeInternet => 'Home internet';
  @override
  String get sampleWaterBill => 'Water bill';

  @override
  String expiresOn(String date) => 'expires $date';
  @override
  String dueOn(String date) => 'due $date';
  @override
  String renewsOn(String date) => 'renews $date';
  @override
  String trialEndsOn(String date) => 'trial ends $date';

  @override
  String notifSimTitle(int days) =>
      'Mobile SIM expires in $days ${days == 1 ? 'day' : 'days'}';
  @override
  String get notifSimBody => 'Top up to keep the number';
  @override
  String get notifNetflixTitle => 'Netflix renews tomorrow';
  @override
  String notifNetflixBody(String amount) => '$amount · one nudge only';

  @override
  String get notifNow => 'now';
  @override
  String notifAge(int days) => '${days}d';

  @override
  String get onboardCurrencyTitle => 'Which currency do you pay in?';
  @override
  String get onboardCurrencyBody =>
      'Totals and each item are shown in this currency. You can still enter '
      'a price in another one.';
  @override
  String get onboardOtherCurrency => 'Another currency';
  @override
  String get onboardSearchCurrency => 'Search currencies';
  @override
  String get onboardLanguageLabel => 'Language';
  @override
  String get onboardNoRateNote =>
      'Subdock carries one exchange rate, between the dong and the dollar. In '
      'another currency each one still adds up on its own, but there is no '
      'single combined total.';

  // ---- upcoming ----

  @override
  String get upcomingTitle => 'Upcoming';

  @override
  String get bucketOverdue => 'Overdue';
  @override
  String get bucketNext7 => 'Next 7 days';
  @override
  String get bucketNext30 => 'Next 30 days';
  @override
  String get bucketLater => 'Later';

  @override
  String get allServices => 'All services';
  @override
  String get layoutList => 'List';
  @override
  String get layoutCalendar => 'Calendar';

  @override
  String get freeTrials => 'Free trials';
  @override
  String get freeTrialBadge => 'FREE TRIAL';
  @override
  String get freeNow => 'Free now';

  @override
  String instalment(int index, int total) => 'payment $index of $total';

  @override
  List<String> get weekdayInitials => [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  String monthLabel(String monthShort, int year) => '$monthShort $year';
  @override
  String calendarDayLabel(
    String weekdayShort,
    int day,
    String monthShort,
    int year,
  ) => '$weekdayShort $day $monthShort $year';

  @override
  String get nothingOnThisDay => 'Nothing on this day.';

  @override
  String get filterTitle => 'Filter';
  @override
  String get filterClearAll => 'Clear all';
  @override
  String get filterClear => 'Clear';
  @override
  String get filterType => 'Type';
  @override
  String get filterBillingCycle => 'Billing cycle';
  @override
  String get filterPaysFrom => 'Pays from';
  @override
  String get filterOnlyShow => 'Only show';
  @override
  String get filterNoPrice => 'No price';
  @override
  String get filterRemindersOff => 'Reminders off';
  @override
  String get filterNoSource => 'No source';

  @override
  String filterShow(int count) =>
      'Show $count ${count == 1 ? 'item' : 'items'}';
  @override
  String filterCount(int shown, int total) =>
      '$shown of $total ${total == 1 ? 'item' : 'items'}';
  @override
  String filterTypes(int count) => '$count types';
  @override
  String filterCycles(int count) => '$count cycles';
  @override
  String filterSources(int count) => '$count sources';

  @override
  String get bullet => ' · ';

  @override
  String get nothingTracked => 'Nothing tracked yet';
  @override
  String get nothingTrackedBody => 'Add the first date you keep forgetting.';
  @override
  String get addAnItem => 'Add an item';
  @override
  String get nothingMatchesFilters => 'Nothing matches these filters';
  @override
  String get clearFilters => 'Clear filters';

  // ---- item detail ----

  @override
  String expiredAgo(int days) =>
      'Expired ${days == 1 ? '1 day' : '$days days'} ago';
  @override
  String overdueBy(int days) =>
      'Overdue by ${days == 1 ? '1 day' : '$days days'}';
  @override
  String get expiresToday => 'Expires today';
  @override
  String get dueToday => 'Due today';
  @override
  String get expiresTomorrow => 'Expires tomorrow';
  @override
  String get dueTomorrow => 'Due tomorrow';
  @override
  String expiresInDays(int days) =>
      'Expires in ${days == 1 ? '1 day' : '$days days'}';
  @override
  String dueInDays(int days) => 'Due in ${days == 1 ? '1 day' : '$days days'}';

  @override
  String get edit => 'Edit';
  @override
  String get rowCategory => 'Category';
  @override
  String get rowRepeats => 'Repeats';
  @override
  String get rowLastPayment => 'Last payment';
  @override
  String get rowRemindMe => 'Remind me';
  @override
  String get rowCost => 'Cost';
  @override
  String get rowTotalLeft => 'Total left';
  @override
  String get rowPaysFrom => 'Pays from';
  @override
  String get rowDateFrom => 'Date from';
  @override
  String get rowNote => 'Note';
  @override
  String get rowYearlyPlan => 'Yearly plan';
  @override
  String get whatHappensNext => 'What happens next';
  @override
  String get addACost => 'Add a cost';

  @override
  String get rowHistory => 'History';
  @override
  String get never => 'Never';

  @override
  String repeatTimes(String cycle, int total) => '$cycle · $total times';

  @override
  String get cycleOnce => 'Once';
  @override
  String get cycleWeekly => 'Weekly';
  @override
  String get cycleMonthly => 'Monthly';
  @override
  String get cycleQuarterly => 'Quarterly';
  @override
  String get cycleTwiceAYear => 'Twice a year';
  @override
  String get cycleYearly => 'Yearly';
  @override
  String cycleEvery(String interval) => 'Every $interval';

  @override
  String intervalDays(int count) => count == 1 ? 'day' : '$count days';
  @override
  String intervalWeeks(int count) => count == 1 ? 'week' : '$count weeks';
  @override
  String intervalMonths(int count) => count == 1 ? 'month' : '$count months';
  @override
  String intervalYears(int count) => count == 1 ? 'year' : '$count years';

  @override
  String intervalShortDays(int count) => '$count d';
  @override
  String intervalShortWeeks(int count) => '$count wk';
  @override
  String intervalShortMonths(int count) => '$count mo';
  @override
  String intervalShortYears(int count) => '$count yr';

  @override
  String get perWeek => '/ wk';
  @override
  String get perMonth => '/ mo';
  @override
  String get perQuarter => '/ qtr';
  @override
  String get perHalfYear => '/ 6 mo';
  @override
  String get perYear => '/ yr';
  @override
  String perInterval(String shortInterval) => '/ $shortInterval';
  @override
  String get aYear => ' a year';

  @override
  String get instalmentPayment => 'Payment';
  @override
  String instalmentPosition(int index, int total) => '$index of $total';
  @override
  String instalmentPaid(int count) => '$count paid';
  @override
  String get instalmentThisOneDue => 'this one due';
  @override
  String instalmentLeft(int count) => '$count left';
  @override
  String get instalmentLastOne => 'last one';

  @override
  String get dateSourceConfirmed => 'confirmed with the provider';
  @override
  String get dateSourceRemembered => 'from memory';
  @override
  String get dateSourceComputed => 'worked out from the cycle';
  @override
  String get dateSourceExtracted => 'read from an image, not checked';

  @override
  String get leadOnTheDay => 'On the day';
  @override
  String leadDaysBefore(int days) =>
      '$days ${days == 1 ? 'day' : 'days'} before';

  @override
  String get actions => 'Actions';
  @override
  String get editReminders => 'Edit reminders';
  @override
  String get remindAgainInThreeDays => 'Remind me again in 3 days';
  @override
  String get deleteThisItem => 'Delete this item';
  @override
  String get markAsPaid => 'Mark as paid';
  @override
  String markPaymentAsPaid(int index) => 'Mark payment $index as paid';
  @override
  String get stopAfterThisPayment => 'Stop after this payment';
  @override
  String get cancelThisSubscription => 'Cancel this subscription';
  @override
  String get paid => 'Paid';

  @override
  String deleteConsequence(int reminderCount) {
    final reminders = reminderCount == 0
        ? 'No reminders are pending.'
        : 'Removes $reminderCount pending '
              '${reminderCount == 1 ? 'reminder' : 'reminders'}.';
    return '$reminders Its recorded payments go too, and Spending stops '
        'counting it.';
  }

  @override
  String deleteAskTitle(String name) => 'Delete $name?';
  @override
  String get deleteAskLost => 'Deleted with it';
  @override
  String get deleteAskRemindersStopped => 'Reminders stopped';
  @override
  String get deleteAskKeep => 'Keep it';
  @override
  String get deleteAskConfirm => 'Delete';
  @override
  String get recordedPaymentsNone => 'Nothing recorded yet';
  @override
  String recordedPayments(int count) =>
      '$count recorded ${count == 1 ? 'payment' : 'payments'}';
  @override
  String get pendingRemindersNone => 'None pending';
  @override
  String pendingReminders(int count) =>
      '$count pending ${count == 1 ? 'reminder' : 'reminders'}';

  // ---- the timeline ----

  @override
  String get timelineActBy => 'Act by this day';
  @override
  String get timelineExpires => 'Expires';
  @override
  String get timelineFirstPayment => 'First payment';
  @override
  String get timelinePaymentDue => 'Payment due';
  @override
  String get timelineAlreadyPassed => 'already passed';
  @override
  String timelineCharged(String amount) => '$amount charged';
  @override
  String timelineFreeForDays(int days) =>
      'Free for $days more ${days == 1 ? 'day' : 'days'}';
  @override
  String get timelineNothingChargedYet => 'nothing charged yet';
  @override
  String get timelineSnoozed => 'You asked to be reminded';
  @override
  String get timelineVerify => 'Check the date is still right';
  @override
  String get timelineNag => 'Still not marked as paid';
  @override
  String timelineNagEvery(int stepDays) =>
      'Then ${stepDays == 1 ? 'every day' : 'every $stepDays days'} until you '
      'mark it as paid';
  @override
  String timelineReminderAt(String time) => 'Reminder at $time';
  @override
  String get timelineReminder => 'Reminder';
  @override
  String timelineNext(String label) => '$label · next';
  @override
  String get timelineSilentPaused =>
      'Reminders are off for this item, so nothing is scheduled.';
  @override
  String get timelineSilentClosed =>
      'This item is closed, so nothing more is scheduled.';
  @override
  String get timelineSilentLadderDone =>
      'No reminders are scheduled. Every step of the ladder for this item has '
      'already passed.';
  @override
  String timelineDropped(int count, int budget) =>
      '$count further ${count == 1 ? 'reminder' : 'reminders'} for this item '
      'did not fit the $budget slots the app schedules, and will be picked up '
      'as the nearer ones pass.';

  // ---- spending ----

  @override
  String get spanMonth => 'Month';
  @override
  String get spanYear => 'Year';
  @override
  String get thisMonth => 'This month';
  @override
  String get nextTwelveMonths => 'Next 12 months';
  @override
  String get costByMonth => 'COST BY MONTH';
  @override
  String get inAFreeTrial => 'IN A FREE TRIAL';
  @override
  String startsCharging(String date) => 'Starts charging $date';
  @override
  String get byCategory => 'By category';
  @override
  String get byItem => 'By item';
  @override
  String get paymentHistory => 'Payment history';
  @override
  String get open => 'Open ›';
  @override
  String get whereItGoes => 'Where it goes';
  @override
  String get whereItGoesCaption => 'The same total again, split by kind.';
  @override
  String get bandSubscriptions => 'Subscriptions';
  @override
  String get bandBills => 'Bills and utilities';
  @override
  String get bandAnnual => 'Charged once a year';
  @override
  String timesInMonth(String name, int times) => '$name ×$times';
  @override
  String approximately(String amount) => '≈ $amount';
  @override
  String alternateTotal(String amount, String rate) => '≈ $amount ($rate)';
  @override
  String unconverted(int currencies) =>
      'No usable rate — $currencies '
      '${currencies == 1 ? 'currency' : 'currencies'} left unconverted';
  @override
  String get chartNothingDue => 'nothing due';
  @override
  String chartAmount(String digits, String currency) => '$digits $currency';
  @override
  String get chartNotDueYet => 'not due yet';

  // ---- savings ----

  @override
  String get tabMoveToYearly => 'Move to yearly';
  @override
  String get tabCancelAService => 'Cancel a service';

  @override
  String get savingsCancelLead =>
      'Grouped by how easy it is to drop. Each total is what you stop paying '
      'in a year.';
  @override
  String get savingsNothingToMove => 'Nothing to move right now.';
  @override
  String savingsYearlyLead(int cheaper, int monthlyCount) =>
      '$cheaper of $monthlyCount monthly plans cost less yearly.';

  @override
  String get savingsNothingToMoveShort => 'Nothing to move right now';
  @override
  String savingsTotalSub(int plans) =>
      'a year, moving $plans ${plans == 1 ? 'plan' : 'plans'} to yearly';

  @override
  String get paidUpFront => 'Paid up front, not monthly';

  @override
  String skippedSuggestions(int count) =>
      '$count ${count == 1 ? 'suggestion' : 'suggestions'} skipped — show '
      'again';

  @override
  String get cancelDisclaimer =>
      'Subdock cannot cancel for you. It takes you to the right page and '
      'stops tracking once you say it is done.';

  @override
  String reminderSetFor(String date) => 'Reminder set for $date';
  @override
  String remindMeOn(String date) => 'Remind me on $date';
  @override
  String get skip => 'Skip';

  @override
  String noYearlyPriceYet(int count) =>
      '$count ${count == 1 ? 'plan has' : 'plans have'} no yearly price yet';
  @override
  String get addPrice => 'Add price';

  @override
  String get openedOpenAgain => 'Opened · open again';
  @override
  String get cancelledRemove => 'Cancelled — remove from Subdock';

  @override
  String get tierEntertainment => 'Entertainment';
  @override
  String get tierEntertainmentHint => 'Easiest to drop';
  @override
  String get tierWork => 'Work and tools';
  @override
  String get tierWorkHint => 'Keep only what you are using';
  @override
  String get tierHard => 'Hard to drop';
  @override
  String get tierHardHint => 'Storage, connectivity, utilities';

  @override
  String yearlyCompare(String monthly, String yearly, int percent) =>
      '$monthly × 12 → $yearly · $percent% less';
  @override
  String yearlyNoteStale(String checkedDate) =>
      'Listed price from $checkedDate — check it first.';
  @override
  String yearlyNoteMismatch(String listed, String entered) =>
      'Listed price is $listed, not the $entered you entered.';
  @override
  String yearlyNoteFresh(String checkedDate) =>
      'Charged once a year, not monthly. Listed price checked $checkedDate.';

  @override
  String leftOut(String parts) => 'Left out: $parts';
  @override
  String leftOutAlreadyYearly(int count) => '$count already yearly';
  @override
  String leftOutInTrial(int count) => '$count in a trial';
  @override
  String leftOutUnpriced(int count) =>
      '$count ${count == 1 ? 'plan' : 'plans'} with no yearly price';

  @override
  String perYearAmount(String amount) => '$amount/yr';

  @override
  String get viaAppStore => 'App Store';
  @override
  String get whereAppStore => 'Settings › Apple Account › Subscriptions';
  @override
  String get actionAppStore => 'Open Subscriptions';
  @override
  String get viaGooglePlay => 'Google Play';
  @override
  String get whereGooglePlay => 'Play Store › Payments and subscriptions';
  @override
  String get actionGooglePlay => 'Open subscriptions';
  @override
  String get viaWeb => 'Web';
  @override
  String get actionCancelPage => 'Open the cancel page';
  @override
  String get viaAccountPage => 'Account page';
  @override
  String get actionAccountPage => 'Open the account page';
  @override
  String get viaNotInCatalogue => 'Not in the catalogue';
  @override
  String get whereNotInCatalogue => 'Subdock has no cancel page for this one';

  @override
  String get savingLeadAbout => 'Save about';
  @override
  String get savingLeadExact => 'Save';
  @override
  String savingLine(String lead, String amount) => '$lead $amount a year';
  @override
  String twelveTimes(String monthly, String twelve) =>
      '$monthly × 12 = $twelve';
  @override
  String annualNoteStale(String checkedDate) =>
      'Listed price from $checkedDate — check the current price';
  @override
  String annualNoteFresh(String checkedDate) =>
      'Listed price, checked $checkedDate';
  @override
  String annualNoteMismatch(String listed, String entered) =>
      'Based on the listed price of $listed, not the $entered you entered';

  @override
  String openAccount(String name) => 'Open $name account';
  @override
  String get manageInAppStore => 'Manage in the App Store';
  @override
  String get manageInGooglePlay => 'Manage in Google Play';
  @override
  String get boughtThroughAppStore => 'Bought through the App Store?';
}
