import 'package:flutter/material.dart';

/// The item icons, and how one is guessed from a name.
///
/// Material Symbols Rounded, per the hand-off. Flutter ships the rounded
/// variants of the Material set in the `MaterialIcons` font it already bundles,
/// so this costs nothing to add — unlike a logo pack, which would need a
/// licence for every brand in the catalog. What the user gets is a shape that
/// says *what kind of thing this is*, which is what a 40px tile can carry
/// anyway.
///
/// Every icon is addressed by a short stable [String] key because the choice is
/// persisted. Storing the codepoint instead would tie the database to a font
/// version, and a font update would silently redraw everyone's list.
abstract final class SubdockIcons {
  /// Shown when nothing is detected and nothing is chosen — the name's first
  /// letter is drawn instead, so this is only the gallery's fallback entry.
  static const String fallback = 'calendar';

  static const Map<String, IconData> all = {
    // watching, listening, playing
    'play': Icons.play_circle_rounded,
    'movie': Icons.movie_rounded,
    'music': Icons.music_note_rounded,
    'tv': Icons.tv_rounded,
    'game': Icons.sports_esports_rounded,
    // working
    'ai': Icons.auto_awesome_rounded,
    'code': Icons.code_rounded,
    'cloud': Icons.cloud_rounded,
    'design': Icons.brush_rounded,
    // connected
    'sim': Icons.sim_card_rounded,
    'phone': Icons.smartphone_rounded,
    'wifi': Icons.wifi_rounded,
    // the flat
    'power': Icons.bolt_rounded,
    'water': Icons.water_drop_rounded,
    'home': Icons.home_rounded,
    'rent': Icons.vpn_key_rounded,
    // money
    'card': Icons.credit_card_rounded,
    'bank': Icons.account_balance_rounded,
    'receipt': Icons.receipt_long_rounded,
    // cover
    'shield': Icons.shield_rounded,
    'health': Icons.health_and_safety_rounded,
    'car': Icons.directions_car_rounded,
    'bike': Icons.two_wheeler_rounded,
    // papers
    'passport': Icons.flight_rounded,
    'id': Icons.badge_rounded,
    'document': Icons.description_rounded,
    'school': Icons.school_rounded,
    // the rest of life
    'gym': Icons.fitness_center_rounded,
    'coffee': Icons.local_cafe_rounded,
    'pet': Icons.pets_rounded,
    'shopping': Icons.shopping_bag_rounded,
    fallback: Icons.calendar_month_rounded,
  };

  static IconData? resolve(String? key) => key == null ? null : all[key];

  /// Matched in order, so a more specific phrase is listed above the word it
  /// contains — `visa card` before `visa`.
  ///
  /// Matched against the name the user typed, not against the catalog: the
  /// catalog covers 71 global services and the user's list will not be. A
  /// substring rule catches "Netflix Premium" and "Tiền điện tháng 9" alike.
  static const List<(String, String)> _keywords = [
    ('netflix', 'movie'),
    ('spotify', 'music'),
    ('youtube', 'play'),
    ('disney', 'movie'),
    ('hbo', 'movie'),
    ('apple music', 'music'),
    ('apple tv', 'tv'),
    ('vieon', 'movie'),
    ('fpt play', 'play'),
    ('steam', 'game'),
    ('playstation', 'game'),
    ('xbox', 'game'),
    ('nintendo', 'game'),
    ('claude', 'ai'),
    ('chatgpt', 'ai'),
    ('openai', 'ai'),
    ('gemini', 'ai'),
    ('copilot', 'code'),
    ('cursor', 'code'),
    ('github', 'code'),
    ('figma', 'design'),
    ('adobe', 'design'),
    ('canva', 'design'),
    ('icloud', 'cloud'),
    ('dropbox', 'cloud'),
    ('google one', 'cloud'),
    ('drive', 'cloud'),
    ('sim', 'sim'),
    ('viettel', 'sim'),
    ('vinaphone', 'sim'),
    ('mobifone', 'sim'),
    ('điện thoại', 'phone'),
    ('internet', 'wifi'),
    ('wifi', 'wifi'),
    ('cáp quang', 'wifi'),
    ('điện', 'power'),
    ('electric', 'power'),
    ('nước', 'water'),
    ('water', 'water'),
    ('gas', 'home'),
    ('thuê nhà', 'rent'),
    ('rent', 'rent'),
    ('bảo hiểm', 'shield'),
    ('insurance', 'shield'),
    ('sức khỏe', 'health'),
    ('health', 'health'),
    ('ô tô', 'car'),
    ('xe máy', 'bike'),
    ('hộ chiếu', 'passport'),
    ('passport', 'passport'),
    ('visa card', 'card'),
    ('visa', 'passport'),
    ('căn cước', 'id'),
    ('bằng lái', 'id'),
    ('licence', 'id'),
    ('license', 'id'),
    ('học phí', 'school'),
    ('tuition', 'school'),
    ('gym', 'gym'),
    ('fitness', 'gym'),
    ('cà phê', 'coffee'),
    ('thẻ', 'card'),
    ('card', 'card'),
    ('vay', 'bank'),
    ('loan', 'bank'),
    ('hóa đơn', 'receipt'),
    ('bill', 'receipt'),
  ];

  /// The icon this name suggests, or null when nothing does.
  ///
  /// Null rather than a default: a wrong icon on every row is worse than a
  /// letter on some of them, because a wrong icon is read before the name is.
  static String? detect(String name) {
    final haystack = name.toLowerCase();
    for (final (keyword, icon) in _keywords) {
      if (haystack.contains(keyword)) return icon;
    }
    return null;
  }
}
