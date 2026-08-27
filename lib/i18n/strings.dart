import 'parts/common.dart';
import 'parts/currency.dart';
import 'parts/dates.dart';
import 'parts/item.dart';
import 'parts/money.dart';
import 'parts/onboarding.dart';
import 'parts/savings.dart';
import 'parts/timeline.dart';
import 'parts/upcoming.dart';

export 'parts/common.dart';
export 'parts/currency.dart';
export 'parts/dates.dart';
export 'parts/item.dart';
export 'parts/money.dart';
export 'parts/onboarding.dart';
export 'parts/savings.dart';
export 'parts/timeline.dart';
export 'parts/upcoming.dart';

/// Every word the interface says, in one language.
///
/// Split into part classes by area rather than kept as one 600-member class,
/// for the same reason the rest of the app is split: the file you have to open
/// to change the Money screen's wording should be about the Money screen.
///
/// Getters and methods rather than a `Map<String, String>`. A key typo in a
/// map is a runtime blank; a key typo here does not compile. Anything with a
/// number or a name in it is a method, so the translation owns the whole
/// sentence — Vietnamese does not put the plural where English does, and a
/// translation handed `'$n days'` cannot fix that.
abstract class Strings
    implements
        CommonStrings,
        CurrencyStrings,
        DateStrings,
        ItemStrings,
        MoneyStrings,
        OnboardingStrings,
        SavingsStrings,
        TimelineStrings,
        UpcomingStrings {}
