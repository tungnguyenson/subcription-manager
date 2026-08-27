/// The Upcoming screen: its buckets, its calendar, its filter sheet, and the
/// two lines a row is built from.
abstract class UpcomingStrings {
  String get upcomingTitle;

  // ---- the dated groups ----

  String get bucketOverdue;
  String get bucketNext7;
  String get bucketNext30;
  String get bucketLater;

  // ---- the control row ----

  String get allServices;
  String get layoutList;
  String get layoutCalendar;

  /// The chip that gathers every item still inside its free period.
  String get freeTrials;

  /// The badge on a row, in capitals.
  String get freeTrialBadge;

  /// A trial with no price at all. The only case where this line answers for
  /// the state rather than the amount, because there is no amount to give.
  String get freeNow;

  /// `payment 3 of 12`, after the amount on a row.
  String instalment(int index, int total);

  // ---- the calendar ----

  /// The seven column heads, Monday first, in capitals.
  List<String> get weekdayInitials;

  /// `Aug 2026`, over the grid.
  String monthLabel(String monthShort, int year);

  /// `Sat 29 Aug 2026`, over the list under the grid.
  String calendarDayLabel(
    String weekdayShort,
    int day,
    String monthShort,
    int year,
  );

  String get nothingOnThisDay;

  // ---- the filter sheet ----

  String get filterTitle;
  String get filterClearAll;
  String get filterClear;
  String get filterType;
  String get filterBillingCycle;
  String get filterPaysFrom;
  String get filterOnlyShow;
  String get filterNoPrice;
  String get filterRemindersOff;
  String get filterNoSource;

  /// The button that closes the sheet: `Show 8 items`.
  String filterShow(int count);

  /// `8 of 23 items`, the head of the summary line.
  String filterCount(int shown, int total);

  /// `3 types`, when more than two chips of one kind are on.
  String filterTypes(int count);
  String filterCycles(int count);
  String filterSources(int count);

  /// The separator between the parts of the summary line.
  String get bullet;

  // ---- the empty states ----

  String get nothingTracked;
  String get nothingTrackedBody;
  String get addAnItem;
  String get nothingMatchesFilters;
  String get clearFilters;
}
