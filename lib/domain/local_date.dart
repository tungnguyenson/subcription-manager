import 'package:meta/meta.dart';

/// A calendar date: no time, no zone.
///
/// Dart's [DateTime] cannot stand in for this. Two of its behaviours are wrong
/// for a date-only domain:
///
///  1. It carries a time and a zone. Two dates that ought to compare equal
///     differ across a daylight-saving boundary, and `difference().inDays`
///     quietly returns 0 or 2 for what is plainly one day.
///  2. Its constructor **rolls over** out-of-range components instead of
///     clamping. `DateTime(2026, 2, 31)` is 3 March. So the obvious way to add
///     a month to 31 January lands on 3 March, a date no subscription renews on.
///
/// [plusMonths] clamps to the last valid day instead, which is what billing
/// systems actually do. See product-spec.md section 5.2.
@immutable
class LocalDate implements Comparable<LocalDate> {
  final int year;
  final int month;
  final int day;

  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12, 'month out of range'),
      assert(day >= 1 && day <= 31, 'day out of range');

  /// Parses `YYYY-MM-DD`. Throws [FormatException] on anything else, including
  /// a well-formed but impossible date like `2026-02-31`.
  factory LocalDate.parse(String iso) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (match == null) {
      throw FormatException('not an ISO date (YYYY-MM-DD)', iso);
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
      throw FormatException('no such date on the calendar', iso);
    }
    return LocalDate(year, month, day);
  }

  static LocalDate? tryParse(String iso) {
    try {
      return LocalDate.parse(iso);
    } on FormatException {
      return null;
    }
  }

  /// Takes the date part in whatever zone [dateTime] is expressed in.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  /// Today in the device's local zone, which is the only zone a reminder app
  /// cares about: a bill is due on the user's calendar day, not on UTC's.
  factory LocalDate.today([DateTime? clock]) =>
      LocalDate.fromDateTime(clock ?? DateTime.now());

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// Midnight UTC. UTC has no daylight saving, so day arithmetic done through
  /// this is exact; doing the same in local time is not.
  DateTime get _utc => DateTime.utc(year, month, day);

  int get epochDay =>
      _utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// ISO-8601 weekday, Monday = 1.
  int get weekday => _utc.weekday;

  LocalDate plusDays(int days) =>
      LocalDate.fromDateTime(_utc.add(Duration(days: days)));

  LocalDate minusDays(int days) => plusDays(-days);

  /// Adds whole months, clamping the day to the end of the target month.
  ///
  /// 31 Jan + 1 month is 28 Feb, not 3 March. Note that clamping loses
  /// information: never accumulate month-by-month, always compute the Nth
  /// occurrence from the original anchor. [Recurrence] is built around that.
  LocalDate plusMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    // Floor division, not truncating `~/`, so dates before year 1 still work.
    final targetYear = (total / 12).floor();
    final targetMonth = total - targetYear * 12 + 1;
    final lastDay = daysInMonth(targetYear, targetMonth);
    return LocalDate(targetYear, targetMonth, day < lastDay ? day : lastDay);
  }

  LocalDate plusYears(int years) => plusMonths(years * 12);

  /// Midnight local time on this date.
  ///
  /// Only for handing a date to a widget that insists on [DateTime], such as
  /// Flutter's date picker. Never use the result for arithmetic: that is what
  /// this class exists to avoid.
  DateTime toDateTimeMidnight() => DateTime(year, month, day);

  /// Whole days from this date until [other]. Negative when [other] is earlier.
  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  bool operator <(LocalDate other) => compareTo(other) < 0;
  bool operator <=(LocalDate other) => compareTo(other) <= 0;
  bool operator >(LocalDate other) => compareTo(other) > 0;
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  /// Whether this date falls in the inclusive range [from]..[to].
  bool isBetween(LocalDate from, LocalDate to) => this >= from && this <= to;

  static LocalDate max(LocalDate a, LocalDate b) => a >= b ? a : b;
  static LocalDate min(LocalDate a, LocalDate b) => a <= b ? a : b;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// ISO-8601. This is also the storage format, so it must stay stable.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// A wall-clock time of day, to the minute. Used for "remind me at 08:30",
/// which is a time on the user's clock and not an instant.
@immutable
class LocalTime implements Comparable<LocalTime> {
  final int hour;
  final int minute;

  const LocalTime(this.hour, this.minute)
    : assert(hour >= 0 && hour <= 23, 'hour out of range'),
      assert(minute >= 0 && minute <= 59, 'minute out of range');

  /// Parses `HH:MM`, and tolerates a trailing `:SS` that storage may carry.
  factory LocalTime.parse(String text) {
    final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (match == null) {
      throw FormatException('not a time (HH:MM)', text);
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw FormatException('no such time on the clock', text);
    }
    return LocalTime(hour, minute);
  }

  static LocalTime? tryParse(String text) {
    try {
      return LocalTime.parse(text);
    } on FormatException {
      return null;
    }
  }

  int get minuteOfDay => hour * 60 + minute;

  @override
  int compareTo(LocalTime other) => minuteOfDay.compareTo(other.minuteOfDay);

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// A date and a wall-clock time together, which is what a scheduled
/// notification needs. Kept apart from [DateTime] until the last moment so the
/// zone conversion happens once, in the scheduler.
@immutable
class LocalDateTime {
  final LocalDate date;
  final LocalTime time;

  const LocalDateTime(this.date, this.time);

  /// Resolves to an instant in the device's current zone.
  DateTime toLocalDateTime() =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  @override
  bool operator ==(Object other) =>
      other is LocalDateTime && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);

  @override
  String toString() => '$date $time';
}
