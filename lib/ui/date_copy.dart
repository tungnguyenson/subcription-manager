import 'package:subdock/domain/local_date.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/money_format.dart';

/// One quick way to set a date without opening a picker.
class DateShortcut {
  final String label;
  final LocalDate Function(LocalDate today) resolve;

  const DateShortcut(this.label, this.resolve);
}

/// Dates in words.
///
/// Hand-written rather than `intl`, and the reason is worth keeping straight
/// now that the app has two languages of its own. The *shape* of a date must
/// not follow the device locale: one the user typed as 17/08 has to read back
/// as 17/08 even on a phone set to en-US, and `intl` would render it 08/17.
/// The *words* around it — the weekday, the month, `In 12 days` — follow the
/// language the user picked, which is a different question with a different
/// answer, and [S] is where those live.
abstract final class DateCopy {
  static String weekday(LocalDate date) => S.t.weekday(date.weekday);

  static String month(int month) => S.t.monthName(month);

  /// `Saturday, 29/08/2026`. Shown under a date shortcut so the user can see
  /// what the shortcut actually resolved to before committing.
  static String longDate(LocalDate date) =>
      '${weekday(date)}, ${MoneyFormat.date(date)}';

  /// How far off a date is, in words: `Today`, `In 12 days`, `9 days ago`.
  ///
  /// The second line of the date field, under the date itself. The two say the
  /// same thing in the two ways a person checks it — a calendar date is what
  /// they compare against their provider, and "in 12 days" is what tells them
  /// at a glance whether they picked the wrong month.
  static String relative(LocalDate today, LocalDate date) {
    final days = today.daysUntil(date);
    if (days == 0) return S.t.today;
    if (days == 1) return S.t.tomorrow;
    if (days == -1) return S.t.yesterday;
    return days > 0 ? S.t.inDays(days) : S.t.daysAgo(-days);
  }

  /// `Saturday 16 August`, the way a lock screen writes it.
  static String lockScreenDate(LocalDate date) =>
      S.t.lockScreenDate(weekday(date), date.day, month(date.month));

  /// `23 Aug 2026`. The form a *sourced* date takes: the day a catalog price
  /// was read off the vendor's page.
  ///
  /// Spelled out rather than 23/08/2026 because it sits inside a sentence
  /// about where a number came from, and a slashed date beside a slashed due
  /// date reads as a second due date. The year is always shown: a price with
  /// no year on it cannot be judged stale, and judging that is the only reason
  /// this date is on screen.
  static String listedDate(LocalDate date) =>
      S.t.listedDate(date.day, S.t.monthShort(date.month), date.year);

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
  /// Built per call rather than held as a `const` list, because the first two
  /// labels are words and the words move with the language. The offsets do
  /// not: `+7` is digits in both.
  static List<DateShortcut> get shortcuts {
    final labels = S.t.dateShortcuts;
    return [
      DateShortcut(labels[0], _today),
      DateShortcut(labels[1], _tomorrow),
      DateShortcut(labels[2], _plus7),
      DateShortcut(labels[3], _plus14),
      DateShortcut(labels[4], _plus30),
    ];
  }

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
    return '${MoneyFormat.shortDate(actBy)} · ${S.t.daysEarlier(offsetDays)}';
  }
}
