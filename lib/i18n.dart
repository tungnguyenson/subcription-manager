import 'i18n/locale.dart';
import 'i18n/strings.dart';
import 'i18n/strings_en.dart';
import 'i18n/strings_vi.dart';

export 'i18n/locale.dart';
export 'i18n/strings.dart';

/// The language every string reads from.
///
/// A mutable global, and the same trade [SubdockPalette] makes: several
/// hundred call sites want a word, and a good many of them are inside
/// presenters and static helpers that hold no `BuildContext` to look one up
/// with. See the header of `lib/ui/theme.dart` for the argument in full.
///
/// The consequence is identical too: assigning this repaints nothing on its
/// own. `SubdockTheme` publishes both the palette and the locale through one
/// inherited scope, so the single rule — a route root calls
/// `SubdockTheme.watch(context)` first thing — already covers language.
AppLocale _activeLocale = AppLocale.en;
Strings _activeStrings = const EnStrings();

/// The words. Written `S.t.getStarted` at every call site.
abstract final class S {
  static Strings get t => _activeStrings;

  static AppLocale get locale => _activeLocale;

  /// Publishes a language. Called by `SubdockTheme`, not by screens.
  static void publish(AppLocale locale) {
    _activeLocale = locale;
    _activeStrings = stringsFor(locale);
  }

  static Strings stringsFor(AppLocale locale) => switch (locale) {
    AppLocale.en => const EnStrings(),
    AppLocale.vi => const ViStrings(),
  };
}
