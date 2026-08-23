import 'local_date.dart';
import 'model.dart';

/// Reminder defaults per category.
///
/// The user can override any of these per item, but the defaults have to be
/// right out of the box: an app that reminds at the wrong time trains the user
/// to swipe reminders away, and then the real one gets swiped away too.
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

  static List<int> defaultLeadDays(Category category) => switch (category) {
    // A passport or a licence is renewed by appointment, not by tapping Pay.
    // Three days' notice on one of these is notice of a problem, not of a
    // task, so this is the one category that does not take the form default.
    Category.document => const [30, 7],
    _ => const [defaultLead],
  };

  static NagPolicy defaultNagPolicy(Category category) => switch (category) {
    Category.bill || Category.insurance => NagPolicy.daily,
    Category.document => NagPolicy.weekly,
    // A subscription renewing is news, not a task. One notice is enough.
    Category.subscription || Category.other => NagPolicy.none,
  };

  static int? defaultVerifyEveryDaysFor(Category category) =>
      switch (category) {
        // Only things whose real date lives somewhere the app cannot read.
        Category.document => defaultVerifyEveryDays,
        _ => null,
      };

  /// Whether a notification should use iOS's Time Sensitive interruption
  /// level, which gets past Focus and Do Not Disturb.
  ///
  /// Keyed off the category rather than off a severity field the user can see.
  /// A subscription renewing is news; everything else on this list is a
  /// deadline with a consequence, and a deadline that arrives silently during
  /// Focus is a deadline the app failed to deliver.
  ///
  /// Deliberately not Critical Alert: that sounds through silent mode and needs
  /// a per-app entitlement granted by Apple.
  static bool isTimeSensitive(Category category) =>
      category != Category.subscription;
}
