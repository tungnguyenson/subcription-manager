import 'model.dart';
import 'reminders.dart';

/// The shelves the app ships with.
///
/// Seeded into `categoryRow` on a fresh install and on the upgrade that
/// introduced the table, then owned by the user: every field here is editable
/// afterwards, and nothing in the app looks a shelf up by the ids below. They
/// are the catalogue's own codes so a catalogue entry lands on its shelf
/// without a translation table, not because any code branches on them.
///
/// The order is most-likely-first rather than alphabetical, for the same reason
/// the service picker's rail was: someone opening it is far more often adding
/// Netflix than a travel subscription.
///
/// Reminder defaults come from what the old five-value classification did,
/// mapped onto the shelves the catalogue actually puts those items on. The
/// shelves that were entirely `BILL` or entirely `DOCUMENT` in the shipped data
/// keep that behaviour exactly; the mixed ones take the majority and are one
/// tap from the other answer.
const List<Category> defaultCategories = [
  Category(id: 'STREAMING', label: 'Streaming', builtIn: true, sortOrder: 0),
  Category(id: 'MUSIC', label: 'Music', builtIn: true, sortOrder: 1),
  Category(id: 'AI', label: 'AI and tools', builtIn: true, sortOrder: 2),
  Category(id: 'STORAGE', label: 'Cloud storage', builtIn: true, sortOrder: 3),
  Category(
    id: 'PRODUCTIVITY',
    label: 'Productivity',
    builtIn: true,
    sortOrder: 4,
  ),

  /// Prepaid SIMs live here, and this shelf is why the app exists: letting one
  /// lapse costs a phone number, and a number carried for ten years is not
  /// something a refund returns. It ships nagging daily and reading as
  /// *expires* rather than *due* -- a prepaid top-up is already paid for, what
  /// runs out is the right to keep the number.
  ///
  /// Nothing in the code knows that. The user can rename this shelf, move it to
  /// the bottom and set it to never nag, and the app will obey, because a shelf
  /// the app treats as special is a shelf the user cannot fix when the app
  /// guessed wrong about them.
  Category(
    id: 'PHONE',
    label: 'Mobile and SIM',
    wording: CategoryWording.expires,
    nag: NagPolicy.daily,
    builtIn: true,
    sortOrder: 5,
  ),

  Category(
    id: 'UTILITIES',
    label: 'Bills and utilities',
    nag: NagPolicy.daily,
    builtIn: true,
    sortOrder: 6,
  ),
  Category(
    id: 'HOUSING',
    label: 'Home',
    nag: NagPolicy.daily,
    builtIn: true,
    sortOrder: 7,
  ),
  Category(id: 'GAMING', label: 'Gaming', builtIn: true, sortOrder: 8),
  Category(
    id: 'ENTERTAINMENT',
    label: 'Entertainment',
    builtIn: true,
    sortOrder: 9,
  ),
  Category(id: 'EDUCATION', label: 'Education', builtIn: true, sortOrder: 10),
  Category(id: 'FITNESS', label: 'Fitness', builtIn: true, sortOrder: 11),
  Category(id: 'NEWS', label: 'News', builtIn: true, sortOrder: 12),
  Category(id: 'SECURITY', label: 'Security', builtIn: true, sortOrder: 13),

  /// Mixed in the shipped catalogue: eight subscriptions against four loan and
  /// card bills. It nags daily because the four are the ones with a late fee,
  /// and a subscription that nags a day too long costs nothing but a swipe.
  Category(
    id: 'FINANCE',
    label: 'Finance',
    nag: NagPolicy.daily,
    builtIn: true,
    sortOrder: 14,
  ),

  Category(
    id: 'INSURANCE',
    label: 'Insurance',
    wording: CategoryWording.expires,
    nag: NagPolicy.daily,
    builtIn: true,
    sortOrder: 15,
  ),

  /// A passport or a licence is renewed by appointment, not by tapping Pay.
  /// Three days' notice on one is notice of a problem rather than of a task, so
  /// this is the one shipped shelf that does not take the form's default lead.
  ///
  /// It also asks to be re-checked, because the real date lives at an office
  /// the app cannot read, and it is kept out of spend totals: the fee is real
  /// money and still not a recurring cost.
  Category(
    id: 'DOCUMENTS',
    label: 'Documents',
    wording: CategoryWording.expires,
    nag: NagPolicy.weekly,
    leadDays: [30, 7],
    verifyEveryDays: Reminders.defaultVerifyEveryDays,
    countsTowardSpend: false,
    builtIn: true,
    sortOrder: 16,
  ),

  Category(id: 'DATING', label: 'Dating', builtIn: true, sortOrder: 17),
  Category(id: 'SOCIAL', label: 'Social', builtIn: true, sortOrder: 18),
  Category(id: 'FOOD', label: 'Food', builtIn: true, sortOrder: 19),
  Category(id: 'TRAVEL', label: 'Travel', builtIn: true, sortOrder: 20),

  /// Last, and the only shelf that is not a subject.
  ///
  /// It exists because an item has to land somewhere: the catalogue refuses
  /// entries that fit no shelf, but a hand-typed item answers to nobody. Never
  /// guessed into -- an item is here because the user put it here, or because a
  /// migration could not tell where else it belonged.
  Category(id: 'OTHER', label: 'Other', builtIn: true, sortOrder: 21),
];

/// The shelf a hand-typed item falls back to.
const String fallbackCategoryId = 'OTHER';
