import 'package:flutter/material.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// Step one of adding an item: which service is this?
///
/// A browser, not just a search box. Search only helps someone who already
/// knows what they are looking for and can spell it; the shelves are for the
/// other case, which is the one that actually happens — a person sitting down
/// to enter *everything* they pay for and trying to remember what that is. A
/// rail of shelves is a prompt list.
///
/// Picking a row here is worth more than the typing it saves. It carries the
/// category, the default cycle, the published prices, the cancel page and the
/// account page in one tap, and every one of those has a source and a date
/// behind it. Typing the same name by hand gets none of them.
class ServicePicker extends StatefulWidget {
  final ServiceCatalog catalog;

  /// The user's own shelves. They set the rail's order and its labels, so the
  /// shelf someone renamed reads the same here as everywhere else, and one
  /// with nothing in the catalogue is left off the rail rather than opening
  /// empty.
  final CategoryBook categories;

  final void Function(CatalogEntry entry)? onPick;

  /// Skips the catalogue entirely. Not a fallback for a failed search — a real
  /// answer, and it has to stay one tap away: the catalogue has 223 entries and
  /// the world has more, and a picker with no exit traps anyone paying for
  /// something local.
  final VoidCallback? onManual;

  final VoidCallback? onCancel;

  const ServicePicker({
    super.key,
    required this.catalog,
    required this.categories,
    this.onPick,
    this.onManual,
    this.onCancel,
  });

  @override
  State<ServicePicker> createState() => _ServicePickerState();
}

class _ServicePickerState extends State<ServicePicker> {
  final TextEditingController _query = TextEditingController();
  late String _shelf;

  @override
  void initState() {
    super.initState();
    final shelves = widget.categories.all
        .map((c) => c.id)
        .where(widget.catalog.categoryIds().contains)
        .toList(growable: false);
    _shelf = shelves.isEmpty ? '' : shelves.first;
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _searching => _query.text.trim().isNotEmpty;

  /// A search hit list, or the current shelf.
  ///
  /// The search limit is raised well above the inline suggester's eight: this
  /// is a whole screen rather than a dropdown over a field, so cutting the list
  /// short here hides matches for no reason.
  List<CatalogEntry> get _rows => _searching
      ? widget.catalog.search(_query.text, limit: 40)
      : widget.catalog.byCategory(_shelf);

  @override
  Widget build(BuildContext context) {
    final shelves = widget.categories.all
        .map((c) => c.id)
        .where(widget.catalog.categoryIds().contains)
        .toList(growable: false);
    final rows = _rows;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SubdockSpacing.screenH,
            6,
            SubdockSpacing.screenH,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New item', style: SubdockText.editorTitle),
                        SizedBox(height: 6),
                        Text(
                          // Short enough to hold one line at 390pt in mono,
                          // which the longer wording did not.
                          'Step 1 of 2 · pick a service',
                          style: SubdockText.monoInline,
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: widget.onCancel,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(12, 5, 0, 8),
                      child: Text('Cancel', style: SubdockText.quietAction),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SearchField(controller: _query),
            ],
          ),
        ),
        // The shelf rail disappears while searching. A shelf label lit up
        // beside results from every other shelf says the results are from that
        // shelf, and they are not.
        if (!_searching) ...[
          const SizedBox(height: 14),
          ChipRail(
            children: [
              for (final shelf in shelves)
                ChoiceChipPill(
                  widget.categories[shelf].label,
                  selected: shelf == _shelf,
                  onTap: () => setState(() => _shelf = shelf),
                ),
            ],
          ),
        ],
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SubdockSpacing.screenH,
              18,
              SubdockSpacing.screenH,
              18,
            ),
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: SubdockSpacing.rowGap),
                _CatalogRow(
                  entry: rows[i],
                  shelfLabel: widget.categories[rows[i].categoryId].label,
                  onTap: () => widget.onPick?.call(rows[i]),
                ),
              ],
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Nothing matches that. Add it yourself below.',
                    style: SubdockText.summary,
                  ),
                ),
              const SizedBox(height: 22),
              const Divider(
                height: 1,
                thickness: 1,
                color: SubdockColors.hairline,
              ),
              const SizedBox(height: 16),
              const Text('Not in the list?', style: SubdockText.summary),
              const SizedBox(height: 10),
              SecondaryButton(
                'Enter manually',
                accent: true,
                onPressed: widget.onManual,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FieldBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: SubdockColors.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: SubdockText.fieldValue,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                hintText: 'Search services',
                hintStyle: TextStyle(
                  fontFamily: SubdockText.family,
                  fontSize: 16,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  final CatalogEntry entry;
  final String shelfLabel;
  final VoidCallback onTap;

  const _CatalogRow({
    required this.entry,
    required this.shelfLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SubdockSurface.card(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ServiceTile(entry.name, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SubdockText.itemName,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // The shelf, and the cycle. Deliberately not a price:
                        // this row is one of forty and a figure on each turns
                        // the shelf into a price list, which invites comparing
                        // two plans the user does not have.
                        '$shelfLabel · '
                        '${ItemPresenter.cycleLabel(entry.defaultCycle)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SubdockText.itemSubtitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '›',
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 15,
                    height: 1,
                    color: SubdockColors.inkMuted,
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
