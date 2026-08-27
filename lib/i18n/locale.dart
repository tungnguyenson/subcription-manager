/// Which language the interface is written in.
///
/// Two values, both real answers. There is no `system` here the way there is
/// in `ThemeChoice`: the phone's language says what the person reads, but this
/// app ships two hand-written translations rather than a generated table, and
/// a phone set to Korean would land on whichever of the two the fallback
/// picked without ever asking. Onboarding asks once, in a screen the user is
/// already reading, which is cheaper than being wrong silently.
enum AppLocale {
  en('en', 'English'),
  vi('vi', 'Tiếng Việt');

  /// What is written to the settings row, and the ISO 639-1 code.
  ///
  /// Spelled out rather than stored as an index, for the reason [ThemeChoice]
  /// spells its own out: an index reorders itself the day someone adds a third
  /// language and silently rewrites everyone's app into another tongue.
  final String code;

  /// The language's name *in that language*. A picker that wrote "Vietnamese"
  /// in English would be asking the one person who cannot read the question.
  final String label;

  const AppLocale(this.code, this.label);

  static AppLocale? tryParse(String raw) {
    for (final locale in values) {
      if (locale.code == raw) return locale;
    }
    return null;
  }

  /// The best match for a device language tag, or null when neither fits.
  ///
  /// Used only to seed the picker on the onboarding screen, never to decide
  /// silently: the user still sees which one is selected and can move it.
  static AppLocale? forDevice(String languageCode) =>
      tryParse(languageCode.toLowerCase());
}
