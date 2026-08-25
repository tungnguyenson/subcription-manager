import 'package:flutter/material.dart';

import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/source_mark.dart';

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
            text: 'PAYS FROM',
            style: SubdockText.sectionLabel,
            children: [
              TextSpan(
                text: ' · optional',
                style: SubdockText.sectionLabel.copyWith(
                  fontWeight: SubdockWeight.regular,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'A name you recognise. Never a card number.',
          style: SubdockText.caption,
        ),
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
              'Not set',
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
                spacing: 6,
                runSpacing: 6,
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
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: TextField(
                  controller: _name,
                  focusNode: _nameFocus,
                  // The card opened because the user asked to name something,
                  // so it opens with the keyboard up rather than asking for a
                  // second tap on the only field in it.
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _create(),
                  textInputAction: TextInputAction.done,
                  style: SubdockText.fieldValue,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                    hintText: 'e.g. VCB 4412',
                    hintStyle: TextStyle(
                      fontFamily: SubdockText.family,
                      fontSize: 15.5,
                      color: SubdockColors.inkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      'Add source',
                      onPressed: _name.text.trim().isEmpty ? null : _create,
                    ),
                  ),
                  const SizedBox(width: 9),
                  QuietButton(
                    'Cancel',
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
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: SubdockColors.accent),
                SizedBox(width: 6),
                Text(
                  'New',
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
