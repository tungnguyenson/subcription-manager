import 'package:flutter/material.dart';

import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/i18n.dart';

/// The mark beside a payment source's name.
///
/// A bundled Material icon rather than a hand-drawn mark, which is the opposite
/// of the rule for service marks — and for a reason. A service mark stands for a
/// specific brand and has to be recognisable as *that* brand, which only a drawn
/// logo achieves. These five stand for kinds of money, and a card, a bank
/// building, a wallet, a contactless wave and a banknote are already universal.
/// Drawing our own would be five new files that look slightly wrong.
class SourceMark extends StatelessWidget {
  final SourceGlyph glyph;
  final double size;
  final Color? colour;

  const SourceMark({
    super.key,
    required this.glyph,
    this.size = 19,
    this.colour,
  });

  static IconData iconFor(SourceGlyph glyph) => switch (glyph) {
    SourceGlyph.card => Icons.credit_card_rounded,
    SourceGlyph.bank => Icons.account_balance_rounded,
    SourceGlyph.wallet => Icons.account_balance_wallet_rounded,
    SourceGlyph.contactless => Icons.contactless_rounded,
    SourceGlyph.cash => Icons.payments_rounded,
  };

  @override
  Widget build(BuildContext context) =>
      Icon(iconFor(glyph), size: size, color: colour ?? SubdockColors.accent);
}

/// The starting points offered when adding a source.
///
/// Presets, not a fixed list: each one fills the name field with a word the
/// user can then edit. Vietnam has a dozen wallets and forty banks, so a closed
/// list would be wrong within a month — and the name is the part that matters,
/// because the whole feature is "a name you recognise".
abstract final class SourcePresets {
  static List<(String, SourceGlyph)> get all => [
    (S.t.sourcePresetCard, SourceGlyph.card),
    (S.t.sourcePresetBank, SourceGlyph.bank),
    // One 'Wallet' rather than a row of named ones. Naming two of the dozen
    // wallets in use here reads as a list of the wallets the app supports, and
    // the user whose wallet is not on it concludes theirs is missing. The name
    // is a free-text field anyway, so the preset only has to say what kind of
    // money it is; the user types which one.
    (S.t.sourcePresetWallet, SourceGlyph.wallet),
    (S.t.sourcePresetContactless, SourceGlyph.contactless),
    (S.t.sourcePresetCash, SourceGlyph.cash),
  ];
}
