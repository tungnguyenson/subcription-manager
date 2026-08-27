import 'package:flutter/material.dart';

import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/source_mark.dart';
import 'package:subdock/i18n.dart';

/// The "pays from" control: pick a source, or add one without leaving the form.
///
/// Adding inline matters more than it looks. The first item a user enters is
/// also the first time they have any reason to name a card, and sending them to
/// a settings screen to do it means they will pick "Not set" instead — and then
/// every reminder they ever get is missing the one detail that makes it
/// actionable. So the whole add-a-source flow is four taps inside this block.
///
/// **There is no field for a card number here or anywhere else.** The label
/// under the heading says so, on the form rather than only on the settings
/// screen, because this is where someone would otherwise type one.
class SourceField extends StatefulWidget {
  final List<PaymentSource> sources;

  /// The chosen source's id, or null for "not set".
  final String? selected;

  final ValueChanged<String?> onSelect;

  /// Creates a source and hands back its id, so this field can select it.
  final Future<String?> Function(String name, SourceGlyph glyph)? onCreate;

  const SourceField({
    super.key,
    required this.sources,
    required this.selected,
    required this.onSelect,
    this.onCreate,
  });

  @override
  State<SourceField> createState() => _SourceFieldState();
}

/// The one rule this field exists to state, in the two places a user could
/// still be about to break it.
///
/// A getter, not a `const`: it is a sentence, and a sentence moves with the
/// language.
String get _noCardNumbers => S.t.sourceHelp;

class _SourceFieldState extends State<SourceField> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  bool _adding = false;
  SourceGlyph _glyph = SourceGlyph.card;

  /// Anchors the card so it can be scrolled back into view. See [_reveal].
  final GlobalKey _cardKey = GlobalKey();

  /// The sources created from inside this form.
  ///
  /// Held here, and merged into [widget.sources] on every build, because the
  /// form is a *pushed route*: it was built once with the list the app happened
  /// to hold at the time, and nothing rebuilds it when the database gains a
  /// row. Without this the chip the user just created never appears — the write
  /// goes through, the card closes, and `Add source` looks like a dead button.
  final List<PaymentSource> _created = [];

  /// Every source the chips should offer, saved ones first.
  ///
  /// Deduplicated by id, so a source that *does* reach [widget.sources] later
  /// (the edit form reopened, say) is not drawn twice.
  List<PaymentSource> get _offered => [
    ...widget.sources,
    for (final source in _created)
      if (!widget.sources.any((s) => s.id == source.id)) source,
  ];

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) _reveal();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The keyboard opening shrinks the viewport under this card, and that
    // arrives as a MediaQuery change rather than as anything this widget did.
    // Without a second pass here the reveal above runs against the tall
    // viewport and the `Add source` button ends up behind the keyboard.
    if (_adding) _reveal();
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Scrolls the card so its bottom edge sits at the bottom of the list.
  ///
  /// `Add source` is the last thing in the card and it is the whole point of
  /// the card; the form's own `Save item` button is pinned under the list, so
  /// a card that merely *exists* below the fold has its only button behind a
  /// different button. Aligned to 1.0 rather than centred so the button is the
  /// part guaranteed to be on screen.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _cardKey.currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _open() {
    setState(() => _adding = true);
    _reveal();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final glyph = _glyph;
    final id = await widget.onCreate?.call(name, glyph);
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (id != null) {
        _created.add(PaymentSource(id: id, name: name, glyph: glyph));
      }
      _name.clear();
      _glyph = SourceGlyph.card;
    });
    if (id != null) widget.onSelect(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: S.t.paysFrom,
            style: SubdockText.sectionLabel,
            children: [
              TextSpan(
                text: S.t.optionalSuffix,
                style: SubdockText.sectionLabel.copyWith(
                  fontWeight: SubdockWeight.regular,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        // Only while there is nothing to pick from. Once the user has named
        // a card, the chips below are the answer and this line is a caption
        // on a control they have already used -- and it is repeated inside
        // the panel anyway, which is the one place someone could still be
        // about to type a card number.
        if (_offered.isEmpty) ...[
          const SizedBox(height: 5),
          Text(_noCardNumbers, style: SubdockText.caption),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final source in _offered)
              ChoiceChipPill(
                source.name,
                selected: widget.selected == source.id,
                icon: Icon(SourceMark.iconFor(source.glyph)),
                onTap: () => widget.onSelect(source.id),
              ),
            ChoiceChipPill(
              S.t.sourceNotSet,
              selected: widget.selected == null,
              icon: const Icon(Icons.block_rounded),
              onTap: () => widget.onSelect(null),
            ),
            if (widget.onCreate != null) _NewChip(onTap: _open),
          ],
        ),
        if (_adding) ...[
          const SizedBox(height: 9),
          GroupedCard(
            key: _cardKey,
            padding: const EdgeInsets.all(14),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, glyph) in SourcePresets.all)
                    ChoiceChipPill(
                      label,
                      selected: _glyph == glyph && _name.text.trim() == label,
                      // The same mark the saved chips above carry. A preset is
                      // a starting point for one of those, and a row of bare
                      // words does not look like it produces one.
                      icon: Icon(SourceMark.iconFor(glyph)),
                      onField: true,
                      onTap: () => setState(() {
                        _glyph = glyph;
                        if (_name.text.trim().isEmpty) _name.text = label;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: SubdockColors.hairline,
                  borderRadius: BorderRadius.circular(SubdockRadius.chip),
                ),
                padding: const EdgeInsets.only(left: 11),
                child: Row(
                  children: [
                    // The mark for the kind of money picked above, in front of
                    // the name being typed. The preset chips scroll out of
                    // thumb's reach once the keyboard is up, so without this
                    // the only record of which one is armed is a chip the user
                    // may not be able to see — and the glyph is what the saved
                    // chip will carry from then on.
                    SourceMark(glyph: _glyph, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _name,
                        focusNode: _nameFocus,
                        // The card opened because the user asked to name
                        // something, so it opens with the keyboard up rather
                        // than asking for a second tap on the only field in it.
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _create(),
                        textInputAction: TextInputAction.done,
                        style: SubdockText.fieldValue,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                          hintText: S.t.sourcesNameHint,
                          hintStyle: TextStyle(
                            fontFamily: SubdockText.family,
                            fontSize: 15.5,
                            color: SubdockColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                    // Clearing by hand costs one backspace per character of a
                    // name a preset just filled in for them, which is the most
                    // likely thing to want gone.
                    if (_name.text.isNotEmpty)
                      _ClearButton(
                        onTap: () => setState(() {
                          _name.clear();
                          _nameFocus.requestFocus();
                        }),
                      )
                    else
                      const SizedBox(width: 11),
                  ],
                ),
              ),
              // Here, where someone is looking at an empty box wondering what
              // to put in it. The label above the chips says it too when there
              // are no sources yet; this is the same sentence at the moment it
              // is actually load-bearing.
              const SizedBox(height: 8),
              Text(_noCardNumbers, style: SubdockText.caption),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      S.t.sourcesAddTitle,
                      onPressed: _name.text.trim().isEmpty ? null : _create,
                    ),
                  ),
                  const SizedBox(width: 9),
                  QuietButton(
                    S.t.cancel,
                    onPressed: () => setState(() {
                      _adding = false;
                      _name.clear();
                    }),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The "x" at the end of the name field.
///
/// Drawn rather than handed to [InputDecoration.suffixIcon] because that pulls
/// in Material's 48px icon-button metrics and pushes the field taller than the
/// chips above it.
class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.t.sourceClearName,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Icon(
            Icons.cancel_rounded,
            size: 17,
            color: SubdockColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _NewChip extends StatelessWidget {
  final VoidCallback onTap;

  const _NewChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SubdockSurface.card(radius: SubdockRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: SubdockColors.accent),
                SizedBox(width: 6),
                Text(
                  S.t.sourceNew,
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 14,
                    height: 1,
                    color: SubdockColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
