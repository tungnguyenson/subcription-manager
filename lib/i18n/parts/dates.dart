/// Dates and durations in words.
///
/// Every one of these is a method rather than a format string handed to the
/// caller, because the two languages do not put the pieces in the same order
/// and do not agree on where a plural goes. English says `9 days ago` and
/// `In 12 days`; Vietnamese says `9 ngày trước` and `Còn 12 ngày`, with no
/// plural at all. A caller that built `'$n ' + unit` could not express that.
abstract class DateStrings {
  /// 1 is Monday, 7 is Sunday.
  String weekday(int weekday);

  /// The short form used in a heading: `Thu`, `T5`.
  ///
  /// Its own method rather than the first three letters of [weekday], because
  /// three letters is an English fact. Vietnamese numbers its weekdays, and
  /// `Thứ hai`, `Thứ ba` and `Thứ tư` all begin `Thứ`.
  String weekdayShort(int weekday);

  /// 1 is January.
  String monthName(int month);

  /// The three-letter form used inside a sentence about where a price came
  /// from: `23 Aug 2026`.
  String monthShort(int month);

  /// `Saturday 16 August`, the way a lock screen writes it.
  String lockScreenDate(String weekday, int day, String month);

  /// `23 Aug 2026`.
  String listedDate(int day, String monthShort, int year);

  String get today;
  String get tomorrow;
  String get yesterday;

  /// `In 12 days`, under the date field.
  String inDays(int days);

  /// `9 days ago`.
  String daysAgo(int days);

  /// The countdown column on a list row, in the fewest characters that say it:
  /// `6d`. Today, tomorrow and overdue are spelled out by the caller.
  String daysShort(int days);

  /// The overdue pill: `Late`.
  String get late;

  /// `· 3 days earlier`, after the act-by date.
  String daysEarlier(int days);

  /// The five chips beside the date field. `+7` and friends are digits in
  /// both languages, so only the first two are words.
  List<String> get dateShortcuts;
}
