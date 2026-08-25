import 'package:flutter/material.dart';

import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/source_mark.dart';

/// One source, plus what is pointing at it.
class SourceRow {
  final PaymentSource source;

  /// `Netflix Premium`, `3 items`, or `Not used yet`. Naming the single user is
  /// what makes Remove safe to tap: the user can see exactly what loses its
  /// source, and it is the one question they would otherwise have to guess at.
  final String usage;

  /// How many items point here. Zero means Remove costs nothing.
  final int itemCount;

  const SourceRow({
    required this.source,
    required this.usage,
    required this.itemCount,
  });
}

/// The cards, wallets and accounts the user pays from.
///
/// **Nothing here is connected to a bank, and there is no field for a card
/// number.** The whole feature is one sentence long: a reminder that says
/// "Netflix · 260,000 ₫ from VCB 4412" tells the user which card is about to be
/// charged, and a nickname does that completely. The copy on this screen says
/// so twice, at the top and again beside the field, because a screen headed
/// "Payment sources" in an app about money is one a careful person is right to
/// be suspicious of.
class SourcesScreen extends StatefulWidget {
  final List<SourceRow> rows;

  final void Function(String name, SourceGlyph glyph)? onAdd;
  final void Function(String id)? onRemove;
  final VoidCallback? onBack;

  const SourcesScreen({
    super.key,
    required this.rows,
    this.onAdd,
    this.onRemove,
    this.onBack,
  });

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final TextEditingController _name = TextEditingController();
  SourceGlyph _glyph = SourceGlyph.card;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canAdd => _name.text.trim().isNotEmpty;

  void _pickPreset(String label, SourceGlyph glyph) {
    setState(() {
      _glyph = glyph;
      // The preset fills an empty field and leaves a typed one alone. Someone
      // who has typed "VCB 4412" and then taps the card preset wants the mark,
      // not their name overwritten.
      if (_name.text.trim().isEmpty) _name.text = label;
    });
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.onAdd?.call(name, _glyph);
    setState(() {
      _name.clear();
      _glyph = SourceGlyph.card;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: widget.onBack),
        const Text('Payment sources', style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        const Text(
          'A name you recognise, so a reminder can tell you which card or '
          'account is about to be charged. Nothing is connected to your bank.',
          style: SubdockText.summary,
        ),
        if (widget.rows.isNotEmpty) ...[
          const SectionLabel('Your sources'),
          GroupedCard(
            children: [
              for (final row in widget.rows)
                _SourceListRow(
                  row: row,
                  onRemove: () => widget.onRemove?.call(row.source.id),
                ),
            ],
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'No sources yet. Add the card or account you pay most bills '
              'from.',
              style: SubdockText.summary,
            ),
          ),
        const SectionLabel('Add one'),
        GroupedCard(
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
                    icon: Icon(SourceMark.iconFor(glyph)),
                    onTap: () => _pickPreset(label, glyph),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _NameField(
              controller: _name,
              onChanged: () => setState(() {}),
              onSubmit: _add,
            ),
            const SizedBox(height: 10),
            PrimaryButton('Add source', onPressed: _canAdd ? _add : null),
            const SizedBox(height: 10),
            const Text(
              'A nickname is enough. Never enter a full card number.',
              style: SubdockText.caption,
            ),
          ],
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  const _NameField({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.hairline,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onSubmit(),
        textInputAction: TextInputAction.done,
        style: SubdockText.fieldValue,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          hintText: 'e.g. VCB 4412',
          hintStyle: TextStyle(
            fontFamily: SubdockText.family,
            fontSize: 16,
            color: SubdockColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _SourceListRow extends StatelessWidget {
  final SourceRow row;
  final VoidCallback onRemove;

  const _SourceListRow({required this.row, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.rowH,
        vertical: 13,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SubdockColors.hairline,
              borderRadius: BorderRadius.circular(SubdockRadius.chip),
            ),
            child: SourceMark(glyph: row.source.glyph),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.itemName.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  row.usage,
                  style: SubdockText.caption.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'Remove',
                style: TextStyle(
                  fontFamily: SubdockText.family,
                  fontSize: 14.5,
                  height: 1,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
