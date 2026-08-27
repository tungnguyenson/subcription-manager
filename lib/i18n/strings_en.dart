import 'parts/currency_names_en.dart';
import 'parts/category_names_en.dart';
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

  // ---- categories ----

  @override
  String? categoryLabel(String id) => CategoryNamesEn.names[id];

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

  // ---- settings ----

  @override
  String get rowCurrency => 'Currency';
  @override
  String get rowLanguage => 'Language';
  @override
  String get rowWidget => 'Widget';
  @override
  String get widgetNotYet => 'Not yet';
  @override
  String get rowAppearance => 'Appearance';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeSystemBody =>
      'Following the phone. This changes when the system setting does, '
      'including on a schedule.';
  @override
  String get themeLightBody => 'Always light, whatever the phone is set to.';
  @override
  String get themeDarkBody => 'Always dark, whatever the phone is set to.';
  @override
  String get sectionBackup => 'Backup';
  @override
  String get sectionApp => 'App';
  @override
  String get rowAbout => 'About';
  @override
  String get rowICloud => 'iCloud';
  @override
  String get rowFile => 'File';
  @override
  String get rowReminders => 'Reminders';
  @override
  String get rowPaymentSources => 'Payment sources';
  @override
  String get exportABackup => 'Export a backup';
  @override
  String droppedRemindersTitle(int count) =>
      '$count reminders could not be scheduled';
  @override
  String droppedRemindersBody(int budget, String names) =>
      'This app schedules at most $budget reminders at a time. '
      'Left out: $names.';

  // ---- about ----

  @override
  String get aboutTitle => 'About';
  @override
  String get aboutLead =>
      'Subdock tracks anything with an expiry date and reminds you before it '
      'lapses.';
  @override
  String get aboutThisBuild => 'This build';
  @override
  String get aboutVersion => 'Version';
  @override
  String get aboutBuild => 'Build';
  @override
  String get aboutWhatItDoes => 'What it does with your list';
  @override
  String get aboutAccount => 'Account';
  @override
  String get aboutServer => 'Server';
  @override
  String get aboutNone => 'None';
  @override
  String get aboutYourList => 'Your list';
  @override
  String get aboutOnThisPhone => 'On this phone';
  @override
  String get aboutPrices =>
      'Prices in the built-in service list are what each provider had '
      'published on the day they were checked, and the app says which day. '
      'They are there to fill a field in, not to tell you what you are paying.';

  // ---- payment sources ----

  @override
  String get sourcesTitle => 'Payment sources';
  @override
  String get sourcesLead =>
      'A name you recognise, so a reminder can tell you which card or account '
      'is about to be charged. Nothing is connected to your bank.';
  @override
  String get sourcesNewItems => 'New items';
  @override
  String get sourcesStartsOn => 'Starts on';
  @override
  String get sourcesYours => 'Your sources';
  @override
  String get sourcesEmpty =>
      'No sources yet. Add the card or account you pay most bills from.';
  @override
  String get sourcesAddOne => 'Add one';
  @override
  String get sourcesAddTitle => 'Add source';
  @override
  String get sourcesAddLead =>
      'A nickname is enough. Never enter a full card number.';
  @override
  String get sourcesNameHint => 'e.g. VCB 4412';
  @override
  String sourcesDefaultUsage(String usage) => 'Default · $usage';
  @override
  String get sourcesRemove => 'Remove';
  @override
  String get sourcesNotUsedYet => 'Not used yet';
  @override
  String sourcesItemCount(int count) =>
      '$count ${count == 1 ? 'item' : 'items'}';

  // ---- all services ----

  @override
  String get servicesLead =>
      'Turn one off and it stops showing up on Upcoming and stops sending '
      'reminders. Nothing is deleted.';
  @override
  String get servicesEmpty => 'Nothing tracked yet.';
  @override
  String get servicesAdd => 'Add a service';
  @override
  String servicesRemindersFor(String name) => '$name reminders';
  @override
  String get servicesOff => 'Off · no reminders';
  @override
  String servicesTrialEnds(String date) => 'Trial ends $date';
  @override
  String servicesNext(String date) => 'Next $date';

  // ---- history ----

  @override
  String get historyTitle => 'History';
  @override
  String get historyAll => 'All';
  @override
  String get historyPaid => 'Paid';
  @override
  String get historyMissed => 'Missed';
  @override
  String historyMonthWithYear(String month, int year) => '$month $year';
  @override
  String historyClosedClean(int count) =>
      '$count closed. This is the record of what did not happen.';
  @override
  String historyClosedWithMissed(int count, int missed) =>
      '$count closed · $missed after the date had passed.';
  @override
  String historyClosedOnTime(int count) => '$count closed on time or before.';
  @override
  String historyClosedLate(int count) =>
      '$count closed after the date had passed.';
  @override
  String get historyEmptyAll =>
      'Nothing closed yet. What you deal with in time is recorded here.';
  @override
  String get historyEmptyPaid => 'Nothing closed on time yet.';
  @override
  String get historyEmptyMissed => 'Nothing has gone past its date unhandled.';
  @override
  String get historyVerbMissed => 'missed';
  @override
  String get historyVerbHandled => 'handled';
  @override
  String get historyVerbPaid => 'paid';
  @override
  String get historyVerbRenewed => 'renewed';

  // ---- reminders ----

  @override
  String get remindersDefaultSchedule => 'Default schedule';
  @override
  String get remindersSchedule => 'Schedule';
  @override
  String get remindersTimeOfDay => 'Time of day';
  @override
  String get remindersSendAt => 'Send at';
  @override
  String get remindersChannels => 'Channels';
  @override
  String get remindersPush => 'Push';
  @override
  String get remindersSendTest => 'Send a test reminder';
  @override
  String get remindersTurnOffForItem => 'Turn off every reminder for this item';
  @override
  String get remindersNotificationsOff =>
      'Notifications are off, so nothing is delivered.';
  @override
  String get remindersInexact =>
      'This device is not allowing alarms at an exact time, so reminders '
      'arrive when the system next wakes rather than at the minute above. '
      'Allow "Alarms & reminders" in system settings to fix it.';

  // ---- the form ----

  @override
  String get newItem => 'New item';
  @override
  String get pickerStep => 'Step 1 of 2 · pick a service';
  @override
  String get searchServices => 'Search services';
  @override
  String get pickerNoMatch =>
      'Nothing matches that. Add it under the name you typed.';
  @override
  String get pickerNotInList => 'Not in the list?';
  @override
  String get enterManually => 'Enter manually';
  @override
  String get scan => 'Scan';

  @override
  String editingName(String name) => 'Editing $name';
  @override
  String get editItem => 'Edit item';
  @override
  String get untitledItem => 'Untitled item';

  @override
  String get fieldName => 'Name';
  @override
  String get fieldNameHint => 'e.g. Spotify';
  @override
  String get fieldCategory => 'Category';
  @override
  String get fieldPickCategory => 'Pick a category';
  @override
  String get fieldPlan => 'Plan';
  @override
  String get fieldRepeats => 'Repeats';
  @override
  String get fieldBillingCycle => 'Billing cycle';
  @override
  String get fieldFreeTrial => 'Free trial';
  @override
  String get fieldInFreeTrialNow => 'In a free trial now';
  @override
  String get fieldRemindMe => 'Remind me';
  @override
  String get fieldCost => 'Cost';
  @override
  String get fieldCostOptional => 'Cost (optional)';
  @override
  String get fieldNextPaymentDate => 'Next payment date';
  @override
  String get fieldLastPaymentOn => 'Last payment on';
  @override
  String get fieldChooseADate => 'Choose a date';
  @override
  String get fieldTapToOpenCalendar => 'Tap to open the calendar';
  @override
  String get fieldOpenSubscriptionPage => 'Open subscription page';

  @override
  String get saveChanges => 'Save changes';
  @override
  String get saveItem => 'Save item';

  @override
  String useCustomName(String typed) => 'Use "$typed" as a custom name';

  @override
  String get repeatsForever => 'Repeats forever';
  @override
  String get stopsAfter => 'Stops after';
  @override
  String get afterANumberOfPayments => 'After a number of payments';
  @override
  String get onADate => 'On a date';
  @override
  String paymentsCount(int count) =>
      '$count ${count == 1 ? 'payment' : 'payments'}';
  @override
  String get paymentsUnit => 'payments';

  @override
  String get cycleOther => 'Other';
  @override
  String get cycleEveryEllipsis => 'Every…';
  @override
  String get cycleOneOff => 'One-off';
  @override
  String get unitDays => 'Days';
  @override
  String get unitWeeks => 'Weeks';
  @override
  String get unitMonths => 'Months';
  @override
  String get unitYears => 'Years';
  @override
  String get every => 'Every';
  @override
  String currentlyCycle(String cycle) =>
      'Currently $cycle — tap another to change it.';

  @override
  String get planOtherAmount => 'Other amount';
  @override
  String get planTypeItYourself => 'Type it yourself';

  @override
  String get paysFrom => 'PAYS FROM';
  @override
  String get optionalSuffix => ' · optional';
  @override
  String get sourceNotSet => 'Not set';
  @override
  String get sourceNew => 'New';
  @override
  String get sourceClearName => 'Clear name';
  @override
  String get sourceHelp => 'A name you recognise. Never a card number.';

  @override
  String get summaryAmountNotSet => 'an amount you have not set yet';
  @override
  String get summaryNoDate =>
      'Set the next payment date and this is where the charge shows up.';
  @override
  String summaryTrial(String date, String money) =>
      'Free until $date — then $money is charged.';
  @override
  String summaryCharge(String money, String date) =>
      'You will be charged $money on $date.';
  @override
  String summaryReminderOnTheDay(String date) => 'Reminder on the day, $date.';
  @override
  String summaryReminderBefore(String lead, String date) =>
      'Reminder $lead, on $date.';

  @override
  String get searchIcons => 'Search icons';
  @override
  String get galleryCategories => 'Categories';
  @override
  String get galleryServices => 'Services';
  @override
  String galleryNoIcon(String query) => 'No icon called "$query"';
  @override
  String get galleryClearSearch => 'Clear the search to pick a shape instead.';
  @override
  String get customEllipsis => 'Custom…';

  @override
  String get addedToSubdock => 'Added to Subdock';
  @override
  String get turnOnReminders => 'Turn on reminders';
  @override
  String get notNow => 'Not now';
  @override
  String get onlyDueDateReminders => 'Only due-date reminders. Nothing else.';

  @override
  String get restoreAskTitle => 'Restore this backup?';
  @override
  String get restoreAskReplaceTitle => 'Replace everything with this backup?';
  @override
  String get restoreAskFrom => 'From the file';
  @override
  String restoreAskSummary(String incoming, String takenOn) =>
      '$incoming · $takenOn';
  @override
  String get restoreAskLost => 'Deleted from this phone';
  @override
  String get restoreAskKeep => 'Keep what I have';
  @override
  String get restoreAskConfirm => 'Restore';
  @override
  String get restoreAskReplace => 'Replace everything';

  @override
  String get backupNow => 'Now';
  @override
  String get backupActions => 'Actions';
  @override
  String get backupNever => 'Never';
  @override
  String get backupCloudTitle => 'iCloud';
  @override
  String get backupCloudIntro =>
      'Subdock keeps a copy of your list in your own iCloud, and writes it '
      'again whenever something changes. There is no account and no Subdock '
      'server involved.';
  @override
  String get backupStatus => 'Status';
  @override
  String get backupLastCopy => 'Last copy';
  @override
  String get backupLastExport => 'Last export';
  @override
  String get backupRestoreFromCloud => 'Restore from iCloud';
  @override
  String get backupCloudRestoreNote =>
      'Restoring replaces everything in the app with what is in iCloud. It '
      'does not merge.';
  @override
  String get backupFileTitle => 'File';
  @override
  String get backupFileIntro =>
      'One JSON file holding every item, shelf, payment source and recorded '
      'payment. Yours to keep wherever you like, and to read.';
  @override
  String get backupRestoreFromFile => 'Restore from a file';
  @override
  String get backupFileRestoreNote =>
      'Restoring replaces everything in the app with what is in the file. It '
      'does not merge.';
  @override
  String get backupNothingSaved => 'Nothing has been backed up';
  @override
  String backupNothingSavedBody(int confirmed) =>
      'Your list is only on this phone, and '
      '${confirmed == 1 ? 'one of its dates was' : '$confirmed of its dates '
                'were'} confirmed with a provider. Removing the app removes them.';
  @override
  String get backupStateSaved => 'Saved';
  @override
  String get backupStateSignedOut => 'Sign in to iCloud';
  @override
  String get backupStateFailed => 'Could not save';
  @override
  String get backupStateWaiting => 'Waiting for a change';
  @override
  String get backupNoteWholeDevice =>
      'Subdock has no account and no server. Your list is in this '
      "iPhone's own backup, but iOS restores that only by restoring the "
      'whole phone.';
  @override
  String get backupNotePerApp =>
      'Subdock has no account and no server. Your list is in this '
      "phone's Google backup and moves to a new phone by itself, but "
      'Subdock cannot check whether that backup has ever run.';
  @override
  String get backupNoteUnknown =>
      'Subdock has no account and no server. What you see in the app is the '
      'only copy, and removing the app removes it.';

  // ---- notifications ----

  @override
  String get channelDeadlines => 'Deadlines';
  @override
  String get channelDeadlinesBody => 'Things you lose if the date passes.';
  @override
  String get channelReminders => 'Reminders';
  @override
  String get channelRemindersBody => 'Renewals and dates worth a glance.';

  @override
  String get actionMarkAsPaid => 'Mark as paid';
  @override
  String get actionRemindTomorrow => 'Remind tomorrow';
  @override
  String get actionOpen => 'Open';
  @override
  String get actionGotIt => 'Got it';

  @override
  String get testReminderTitle => 'Test reminder';
  @override
  String get testReminderBody => 'Delivery works. Nothing on your list is due.';

  @override
  String get notifDueToday => 'Due today';
  @override
  String get notifDueTomorrow => 'Due tomorrow';
  @override
  String notifDueInDays(int days) => 'Due in $days days';
  @override
  String get notifOverdue => 'Overdue';
  @override
  String get notifVerify => 'Check this date is still right';
  @override
  String get notifSnoozed => 'You asked to be reminded';
  @override
  String get notifYearlyCostsLess => 'Yearly costs less';

  // ---- the app's own voice ----

  @override
  String get notificationsOffTitle => 'Notifications are off';
  @override
  String get notificationsOffBody => 'Nothing will remind you.';
  @override
  String get turnOn => 'On';

  @override
  String cutAYear(String amount) => 'Cut $amount a year';
  @override
  String plansCostLessYearly(int count) =>
      '$count ${count == 1 ? 'plan' : 'plans'} cost less yearly · cancelling '
      'saves more';

  @override
  String get none => 'None';

  @override
  String savedNamed(String name) => 'Saved "$name".';
  @override
  String savedUnderLater(String name) => 'Saved "$name" — it is under Later.';
  @override
  String savedUnderNext30(String name) =>
      'Saved "$name" — it is under Next 30 days.';
  @override
  String get askTrialEnds => 'Remind you before the trial ends?';
  @override
  String askBeforeCharges(String name) => 'Remind you before $name charges?';

  @override
  String askLineOnTheDay(String fireOn, String money, String from) =>
      'Notification on $fireOn, the day it happens$money$from.';
  @override
  String askLineBefore(
    String fireOn,
    String lead,
    String actBy,
    String money,
    String from,
  ) => 'Notification on $fireOn — $lead ($actBy)$money$from.';
  @override
  String askMoneyThen(String amount) => ' · then $amount';
  @override
  String askMoney(String amount) => ' · $amount';
  @override
  String askFrom(String source) => ' from $source';
  @override
  String reminderSetOn(String date) => 'Reminder set for $date.';

  @override
  String get sawRenewalDate => 'Did you see the renewal date?';
  @override
  String get enterDate => 'Enter date';
  @override
  String savedConfirmedDate(String date) => 'Saved $date as confirmed.';
  @override
  String get yearlyMentionedInReminder =>
      'The renewal reminder will mention the yearly price.';
  @override
  String remindingAgainOn(String date) => 'Reminding you again on $date.';

  @override
  String backedUp(String summary) => 'Backed up $summary.';
  @override
  String couldNotExport(String error) => 'Could not export: $error';
  @override
  String restored(String summary) => 'Restored $summary.';
  @override
  String couldNotRestore(String error) => 'Could not restore: $error';
  @override
  String couldNotOpenFile(String error) => 'Could not open that file: $error';
  @override
  String get noCopyInICloud => 'There is no copy in iCloud yet.';
  @override
  String get signInToICloud =>
      'Sign in to iCloud to reach the copy kept there.';
  @override
  String couldNotReadICloud(String detail) => 'Could not read iCloud: $detail.';
  @override
  String get unknownError => 'unknown error';
  @override
  String takenOn(String date) => 'taken $date';

  @override
  String get couldNotOpenPage => 'Could not open that page.';
  @override
  String couldNotScheduleTest(String error) =>
      'Could not schedule a test: $error';
  @override
  String testSetInexact(String at, String zone) =>
      'Test set for $at $zone, give or take a few minutes — this device will '
      'not fire on the minute.';
  @override
  String testSet(String at, String zone) => 'Test set for $at $zone.';

  // ---- reading a bill ----

  @override
  String get scanTitle => 'Scan a bill';
  @override
  String get scanLead => 'Detected — check before saving';
  @override
  String get scanCaption =>
      'Read from the image or the text you pasted. Nothing here is confirmed '
      'until you save it.';
  @override
  String get scanRetake => 'Retake';
  @override
  String get scanCouldNotRead => 'could not read';
  @override
  String get scanNothingToQuote => 'nothing to quote';
  @override
  String get scanDue => 'Due';
  @override
  String get scanAmount => 'Amount';
  @override
  String scanUnitUnclear(String minor) => '$minor · unit unclear';
  @override
  String get scanDayBeforeMonth => 'day before month';
  @override
  String get scanMonthBeforeDay => 'month before day';

  @override
  String warnUnsupportedValue(String field) =>
      'The $field was returned without pointing at anything in the image. '
      'Check it.';
  @override
  String warnAmbiguousDate(String raw) =>
      'The date $raw can be read two ways. Pick the right one.';
  @override
  String get warnMissingDate => 'No due date found. Type it in.';
  @override
  String get warnUnknownCurrency => 'Currency unclear. Choose dong or dollars.';
  @override
  String get warnLowConfidence =>
      'The model was not sure about this read. Check every line before saving.';

  @override
  String get fieldServiceNameLower => 'service name';
  @override
  String get fieldDueLower => 'due date';
  @override
  String get fieldAmountLower => 'amount';

  @override
  String get errRateLimited => 'Busy right now. Try again in a few seconds.';
  @override
  String get errCreditExhausted =>
      'The OpenAI account is out of credit. Top it up and try again.';
  @override
  String get errSpendLimit => 'You have hit the spend limit you set on OpenAI.';
  @override
  String get errInvalidKey =>
      'The API key is wrong or has been revoked. Check it in Settings.';
  @override
  String get errRegionUnsupported => 'OpenAI does not support your region yet.';
  @override
  String get errUpstream => 'OpenAI is having trouble. Try again later.';
  @override
  String get errNoNetwork => 'No network connection.';
  @override
  String get errUnreadable => 'This content could not be read.';
  @override
  String get errTruncated => 'Too long to read all the way through.';
  @override
  String get errBadShape => 'The reply came back in the wrong shape.';
  @override
  String get errNoApiKey => 'No API key yet. Add one in Settings to use this.';

  // ---- backup files ----

  @override
  String get backupNotOurs => 'That file is not a Subdock backup.';
  @override
  String get backupTooNew =>
      'That backup was written by a newer version of Subdock.';
  @override
  String backupFileContains(String what) => 'The file contains $what.';
  @override
  String get backupWhatCategoryNoId => 'a category with no id';
  @override
  String get backupWhatCategory => 'a category';
  @override
  String get backupWhatSourceNoId => 'a payment source with no id';
  @override
  String get backupWhatItemNoId => 'an item with no id';
  @override
  String get backupWhatPaymentNoId => 'a recorded payment with no id';
  @override
  String get backupWhatPaymentNoItem => 'a recorded payment with no item';
  @override
  String backupItemHasNoDate(String name) => 'An item has no date: $name.';
  @override
  String get backupPaymentHasNoDate => 'A recorded payment has no date on it.';
  @override
  String backupSummaryItems(int count) =>
      '$count ${count == 1 ? 'item' : 'items'}';
  @override
  String backupSummaryPayments(int count) =>
      '$count ${count == 1 ? 'payment' : 'payments'}';
  @override
  String backupSummarySources(int count) =>
      '$count payment ${count == 1 ? 'source' : 'sources'}';
  @override
  String get listJoin => ', ';

  @override
  String get fallbackShelf => 'Other';
}
