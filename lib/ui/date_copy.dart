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

  /// The shortcuts on the add form, in the order the design shows them.
  static const List<DateShortcut> shortcuts = [
    DateShortcut('Today', _today),
    DateShortcut('Tomorrow', _tomorrow),
    DateShortcut('In 7 days', _plus7),
    DateShortcut('In 1 month', _plusMonth),
  ];

  static LocalDate _today(LocalDate today) => today;
  static LocalDate _tomorrow(LocalDate today) => today.plusDays(1);
  static LocalDate _plus7(LocalDate today) => today.plusDays(7);
  static LocalDate _plusMonth(LocalDate today) => today.plusMonths(1);

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
