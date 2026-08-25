import 'local_date.dart';

/// Reminder settings that hold for every item, whatever shelf it is on.
///
/// The per-shelf defaults used to live here too, as switches over a five-value
/// enum. They are columns on the shelf now, because the app no longer knows any
/// shelf by name -- see [Category]. What is left is what the whole app shares:
/// the time of day, the lead times the form offers, and the re-check cadence a
/// shelf can opt into.
abstract final class Reminders {
  static const LocalTime defaultRemindAt = LocalTime(8, 30);

  /// Re-check cadence for items whose date can silently drift. See spec 7.5.
  static const int defaultVerifyEveryDays = 60;

  /// The lead times the add form offers, in the hand-off's order.
  ///
  /// Anything outside this list is reachable through Custom, so the list is
  /// short on purpose: five one-tap choices that cover almost every item beat
  /// a wheel the user has to think in.
  static const List<int> offered = [0, 1, 3, 7];

  /// The one the form starts on.
  static const int defaultLead = 3;
}
