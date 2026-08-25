import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/money_format.dart';

/// One quick way to set a date without opening a picker.
class DateShortcut {
  final String label;
  final LocalDate Function(LocalDate today) resolve;

  const DateShortcut(this.label, this.resolve);
}

/// Dates in words.
///
/// Hand-written rather than `intl`, because the app must not follow the device
/// locale: a date the user typed as 17/08 has to read back as 17/08 even on a
/// phone set to en-US, and `intl` would render it 08/17.
abstract final class DateCopy {
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

  static String weekday(LocalDate date) => _weekdays[date.weekday - 1];

  static String month(int month) => _months[month - 1];

  /// `Saturday, 29/08/2026`. Shown under a date shortcut so the user can see
  /// what the shortcut actually resolved to before committing.
  static String longDate(LocalDate date) =>
      '${weekday(date)}, ${MoneyFormat.date(date)}';

  /// `Saturday 16 August`, the way a lock screen writes it.
  static String lockScreenDate(LocalDate date) =>
      '${weekday(date)} ${date.day} ${month(date.month)}';

  /// `23 Aug 2026`. The form a *sourced* date takes: the day a catalog price
  /// was read off the vendor's page.
  ///
  /// Spelled out rather than 23/08/2026 because it sits inside a sentence
  /// about where a number came from, and a slashed date beside a slashed due
  /// date reads as a second due date. The year is always shown: a price with
  /// no year on it cannot be judged stale, and judging that is the only reason
  /// this date is on screen.
  static String listedDate(LocalDate date) =>
      '${date.day} ${month(date.month).substring(0, 3)} ${date.year}';

  /// The shortcuts beside the date field, in the order the design shows them.
  ///
  /// Shortcuts only: the calendar is its own row above them, so this rail
  /// never has to carry the general case. That is what lets it stay a short
  /// list of the dates people actually type — a rail whose last chip is the
  /// picker puts the most-used control at the end of a sideways scroll.
  /// `Today · Tomorrow · +7 · +14 · +30`, which is how the build file labels
  /// them. The offsets are written the way a person writing a note to
  /// themselves writes them, and five short chips fit the row without
  /// scrolling — `In 7 days` and `In 1 month` did not, and a shortcut rail
  /// that scrolls is a rail whose last shortcuts nobody sees.
  ///
  /// The resolved date is spelled out in full on the picker row above, so the
  /// terseness here costs the reader nothing.
  static const List<DateShortcut> shortcuts = [
    DateShortcut('Today', _today),
    DateShortcut('Tomorrow', _tomorrow),
    DateShortcut('+7', _plus7),
    DateShortcut('+14', _plus14),
    DateShortcut('+30', _plus30),
  ];

  static LocalDate _today(LocalDate today) => today;
  static LocalDate _tomorrow(LocalDate today) => today.plusDays(1);
  static LocalDate _plus7(LocalDate today) => today.plusDays(7);
  static LocalDate _plus14(LocalDate today) => today.plusDays(14);
  static LocalDate _plus30(LocalDate today) => today.plusDays(30);

  /// The act-by line: what date the user must have acted by, and how much
  /// earlier that is than the expiry.
  ///
  /// Returns null when the two coincide, rather than printing a no-op. "Act by
  /// 17/08. Expires 17/08." reads as two facts and teaches the reader to skim.
  static String? actByLine(LocalDate expiresOn, int offsetDays) {
    if (offsetDays <= 0) return null;
    final actBy = expiresOn.minusDays(offsetDays);
    final unit = offsetDays == 1 ? '1 day' : '$offsetDays days';
    return '${MoneyFormat.shortDate(actBy)} · $unit earlier';
  }
}
