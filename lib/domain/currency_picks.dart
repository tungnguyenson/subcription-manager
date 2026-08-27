import 'package:meta/meta.dart';

/// Which currencies the user says they are billed in, and which one the
/// combined totals speak.
///
/// Two facts rather than one, because they answer different questions and the
/// app was previously only asking the second. `base` is what every total is
/// restated in; `codes` is the set the user actually pays in, which is what
/// the amount field offers and what the Money screen has to expect to meet.
/// Before this, the form guessed the second from the first — it offered the
/// base plus whichever half of the one bundled rate was missing — so someone
/// billed in dong and won had a chip for dollars they never use and no chip
/// for the currency half their list arrives in.
///
/// No amount is rewritten when either changes. Every `Money` keeps the
/// currency it was entered under, for ever; see trap 41.
@immutable
class CurrencyPicks {
  /// Two, and the cap is a judgement rather than a limit of the code.
  ///
  /// The list is a set of things the user has to rule out every time they type
  /// an amount, and a person billed in three currencies is rare enough that
  /// serving them costs everyone else a wider chip row on the form they use
  /// daily. The third currency still works — it is typed, stored and totalled
  /// exactly; it simply is not one tap away.
  static const int max = 2;

  /// In the order they were declared, never re-sorted. The first is the one
  /// the app guessed from the phone's region, and moving it after the fact
  /// would shuffle rows under the finger that just added the second.
  final List<String> codes;

  /// Always a member of [codes].
  final String base;

  const CurrencyPicks._(this.codes, this.base);

  /// Normalises rather than validates: upper-cases, drops duplicates and
  /// blanks, cuts to [max], and pulls [base] into the list if it is missing.
  ///
  /// Lenient on purpose, and for the reason `mappers.dart` is: this is read
  /// back from a settings row that an older build wrote and a newer one may
  /// have written differently. A restore that threw here would leave a user
  /// with no currency at all rather than with a slightly odd one.
  factory CurrencyPicks(Iterable<String> codes, {String? base}) {
    final cleaned = <String>[];
    for (final raw in codes) {
      final code = raw.trim().toUpperCase();
      if (code.isEmpty || cleaned.contains(code)) continue;
      cleaned.add(code);
      if (cleaned.length == max) break;
    }

    final wanted = base?.trim().toUpperCase();
    if (wanted != null && wanted.isNotEmpty && !cleaned.contains(wanted)) {
      if (cleaned.length == max) {
        cleaned.removeLast();
      }
      cleaned.insert(0, wanted);
    }

    if (cleaned.isEmpty) {
      throw ArgumentError.value(codes, 'codes', 'at least one currency');
    }

    return CurrencyPicks._(
      List.unmodifiable(cleaned),
      wanted != null && wanted.isNotEmpty ? wanted : cleaned.first,
    );
  }

  factory CurrencyPicks.one(String code) => CurrencyPicks([code], base: code);

  bool get isFull => codes.length >= max;

  bool contains(String code) => codes.contains(code.trim().toUpperCase());

  /// Appends, leaving [base] where it is. Adding a currency says "I am billed
  /// in this too", not "state my totals in this".
  CurrencyPicks add(String code) {
    if (isFull || contains(code)) return this;
    return CurrencyPicks([...codes, code], base: base);
  }

  /// Removing the base hands the job to whatever is left, because a list with
  /// no base is not a state any screen can render.
  CurrencyPicks remove(String code) {
    final gone = code.trim().toUpperCase();
    if (!contains(gone) || codes.length == 1) return this;
    final rest = [
      for (final kept in codes)
        if (kept != gone) kept,
    ];
    return CurrencyPicks(rest, base: gone == base ? rest.first : base);
  }

  /// Swaps one slot without disturbing the other, and without moving the row
  /// under the finger that opened the sheet.
  CurrencyPicks replace(String old, String next) {
    final gone = old.trim().toUpperCase();
    final code = next.trim().toUpperCase();
    if (!contains(gone) || code.isEmpty) return this;
    if (contains(code)) return code == gone ? this : remove(gone);
    return CurrencyPicks([
      for (final kept in codes) kept == gone ? code : kept,
    ], base: base == gone ? code : base);
  }

  /// Restates the totals in [code], declaring it on the way in if it was not
  /// declared already.
  ///
  /// When the list is full the *base* slot is the one that gives way, not the
  /// other. Someone changing which currency their totals speak is editing that
  /// answer; the second currency is a separate answer they gave on purpose,
  /// and dropping it to make room would undo a choice they did not revisit.
  CurrencyPicks withBase(String code) {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty || wanted == base) return this;
    if (contains(wanted)) return CurrencyPicks._(codes, wanted);
    if (!isFull) return CurrencyPicks([...codes, wanted], base: wanted);
    return CurrencyPicks([
      for (final kept in codes) kept == base ? wanted : kept,
    ], base: wanted);
  }

  @override
  bool operator ==(Object other) =>
      other is CurrencyPicks &&
      other.base == base &&
      _sameOrder(other.codes, codes);

  /// Order-sensitive: the list is drawn in it, so two picks that differ only
  /// in order are two different screens.
  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(base, Object.hashAll(codes));

  @override
  String toString() => 'CurrencyPicks(${codes.join('+')}, base $base)';
}
