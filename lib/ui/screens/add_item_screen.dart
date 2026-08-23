import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/reminders.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/icons.dart';
import 'package:subdock/ui/item_draft.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/icon_gallery.dart';
import 'package:subdock/ui/widgets/primitives.dart';

// The form's output type lives beside the presenter, not here, because the
// merge back onto an existing item is domain reasoning rather than layout.
// Re-exported so every caller of this screen has it in scope already.
export 'package:subdock/ui/item_draft.dart';

/// The item form. Adds an item when [initial] is null, edits one when it is
/// not; the screen itself never writes to storage either way.
class AddItemScreen extends StatefulWidget {
  final ServiceCatalog catalog;
  final LocalDate today;

  /// The item being edited, already reduced to what this form asks for. Null
  /// for a new item.
  final DraftItem? initial;

  final VoidCallback? onCancel;
  final void Function(DraftItem draft)? onSave;
  final VoidCallback? onScan;

  /// Opens the calendar, seeded with the date the form is holding.
  final Future<LocalDate?> Function(LocalDate? from)? onPickDate;

  const AddItemScreen({
    super.key,
    required this.catalog,
    required this.today,
    this.initial,
    this.onCancel,
    this.onSave,
    this.onScan,
    this.onPickDate,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _nameFocus = FocusNode();

  CatalogEntry? _matched;
  LocalDate? _expiresOn;
  Category _category = Category.subscription;
  String? _iconName;
  Cycle? _cycle = Cycle.monthly;
  int? _repeatCount;
  String _currency = 'VND';
  int _lead = Reminders.defaultLead;

  /// True once the user has picked a suggestion or explicitly declined one.
  /// Until then the suggestion list stays open, because tapping a known service
  /// fills the category, the cycle and the cancel link in one go, which is the
  /// single biggest reduction in entry friction this app has.
  bool _nameSettled = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _seed(widget.initial);

    _name.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
  }

  void _seed(DraftItem? initial) {
    if (initial == null) return;

    _name.text = initial.name;
    _expiresOn = initial.expiresOn;
    _category = initial.category;
    _iconName = initial.iconName;
    _cycle = initial.cycle;
    _repeatCount = initial.repeatCount;
    _lead = initial.leadDays.isEmpty
        ? Reminders.defaultLead
        : initial.leadDays.first;

    final minor = initial.amountMinor;
    if (minor != null) {
      _amount.text = minor.toString();
      _currency = initial.currency ?? _currency;
    }

    // The name is already what the user meant. Offering to replace it with a
    // catalog row the moment the screen opens is an offer to undo their edit.
    _nameSettled = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  List<CatalogEntry> get _suggestions =>
      _nameSettled ? const [] : widget.catalog.search(_name.text);

  bool get _canSave => _name.text.trim().isNotEmpty && _expiresOn != null;

  /// The repeats the form offers, in the hand-off's order.
  ///
  /// Three, not the five the domain can store. A form that lists every cycle
  /// it supports takes longer to fill in than the item is worth. An item that
  /// already carries one of the other two keeps it as a fourth option, because
  /// opening the editor must never quietly rewrite a value it did not ask
  /// about.
  List<Cycle?> get _repeatOptions {
    const offered = <Cycle?>[Cycle.monthly, Cycle.yearly, null];
    final cycle = _cycle;
    if (cycle == null || offered.contains(cycle)) return offered;
    return [Cycle.monthly, Cycle.yearly, cycle, null];
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _suggestions.isNotEmpty && _nameFocus.hasFocus;

    return Column(
      children: [
        Expanded(
          // No horizontal padding here: the chip rails have to reach the edge
          // of the screen, so every other block asks for the gutter itself.
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
            children: [
              _gutter(_header()),
              const SizedBox(height: 18),
              _gutter(Field(label: 'Name', child: _nameField())),
              if (showSuggestions) ...[
                const SizedBox(height: 12),
                _gutter(_suggestionList()),
              ],
              const SizedBox(height: SubdockSpacing.formBlock),
              Field(label: 'Category', bleed: true, child: _categoryRail()),
              const SizedBox(height: SubdockSpacing.formBlock),
              Field(label: 'Date', bleed: true, child: _dateField()),
              const SizedBox(height: SubdockSpacing.formBlock),
              _gutter(Field(label: 'Repeat', child: _repeatRow())),
              if (_cycle != null) ...[
                const SizedBox(height: SubdockSpacing.formBlock),
                _gutter(
                  Field(
                    label: 'How many times',
                    child: PickerField(
                      value: _repeatCountLabel,
                      onTap: _pickRepeatCount,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: SubdockSpacing.formBlock),
              _gutter(
                Field(
                  label: _amount.text.isEmpty ? 'Cost (optional)' : 'Cost',
                  child: _costField(),
                ),
              ),
              // Editing does not show the reminder ladder. An item can hold
              // several leads and this rail holds one, so offering it here
              // would silently flatten "14, 7, 3, 1, 0 days before" down to
              // whichever chip happened to be lit. The item's own screen has a
              // reminders editor that can say all of them.
              if (!_isEdit) ...[
                const SizedBox(height: SubdockSpacing.formBlock),
                Field(label: 'Remind me', bleed: true, child: _leadRail()),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SubdockSpacing.screenH,
            12,
            SubdockSpacing.screenH,
            12,
          ),
          child: PrimaryButton(
            _isEdit ? 'Save changes' : 'Save',
            onPressed: _canSave ? _save : null,
          ),
        ),
      ],
    );
  }

  Widget _gutter(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SubdockSpacing.screenH),
    child: child,
  );

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEdit ? 'Edit item' : 'New item',
            style: SubdockText.editorTitle,
          ),
        ),
        if (widget.onScan != null) ...[
          InkWell(
            onTap: widget.onScan,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Scan', style: SubdockText.quietAction),
            ),
          ),
          const SizedBox(width: 16),
        ],
        InkWell(
          onTap: widget.onCancel ?? () => Navigator.of(context).maybePop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Cancel', style: SubdockText.quietAction),
          ),
        ),
      ],
    );
  }

  Widget _nameField() {
    return FieldBox(
      focused: _nameFocus.hasFocus,
      child: Row(
        children: [
          // The tile is the way into the gallery. Tapping the mark beside a
          // name to change it is the gesture every list app in this shape
          // already teaches, so it carries no label.
          ServiceTile(
            _name.text,
            iconName: _iconName,
            size: 34,
            radius: SubdockRadius.tile,
            fontSize: 14,
            onTap: _pickIcon,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _nameFocus,
              // An empty form is asking for a name and nothing else, so it
              // opens with the keyboard up. A form that is already full is
              // asking which field to change, and answering that from behind
              // a keyboard means dismissing it first.
              autofocus: !_isEdit,
              style: SubdockText.fieldValue,
              cursorColor: SubdockColors.accent,
              onChanged: (_) => _nameSettled = false,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'e.g. Spotify',
                hintStyle: SubdockText.fieldValue.copyWith(
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionList() {
    return GroupedCard(
      children: [
        for (final entry in _suggestions)
          _SuggestionRow(
            name: entry.name,
            detail: _catalogDetail(entry),
            onTap: () => _pick(entry),
          ),
        _SuggestionRow(
          name: 'Use "${_name.text.trim()}" as a custom name',
          muted: true,
          onTap: _keepTyped,
        ),
      ],
    );
  }

  Widget _categoryRail() {
    return ChipRail(
      children: [
        for (final category in Category.values)
          ChoiceChipPill(
            ItemPresenter.categoryLabel(category),
            selected: _category == category,
            onTap: () => setState(() => _category = category),
          ),
      ],
    );
  }

  Widget _dateField() {
    final expiresOn = _expiresOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipRail(
          children: [
            for (final shortcut in DateCopy.shortcuts)
              ChoiceChipPill(
                shortcut.label,
                selected:
                    expiresOn != null &&
                    expiresOn == shortcut.resolve(widget.today),
                onTap: () =>
                    setState(() => _expiresOn = shortcut.resolve(widget.today)),
              ),
            ChoiceChipPill('Pick a date…', onTap: _pickDate),
          ],
        ),
        if (expiresOn != null)
          // The chip says "In 1 month"; this says which day that landed on. A
          // relative shortcut the user cannot verify is a date they will have
          // to re-check against their provider anyway.
          Padding(
            padding: const EdgeInsets.fromLTRB(SubdockSpacing.screenH, 5, 0, 0),
            child: Text(
              MoneyFormat.date(expiresOn),
              style: SubdockText.monoInline,
            ),
          ),
      ],
    );
  }

  Widget _repeatRow() {
    final options = _repeatOptions;

    return SegmentedRow(
      labels: [for (final cycle in options) _repeatLabel(cycle)],
      selected: options.indexOf(_cycle),
      onSelect: (i) => setState(() {
        _cycle = options[i];
        // "Once" and "how many times" cannot both be true.
        if (_cycle == null) _repeatCount = null;
      }),
    );
  }

  /// The segment labels. Shorter than [ItemPresenter.cycleLabel] because four
  /// of these have to share the width of a phone: "Twice a year" does not fit
  /// beside three siblings, "6 months" does.
  static String _repeatLabel(Cycle? cycle) => switch (cycle) {
    null => 'Once',
    Cycle.weekly => 'Weekly',
    Cycle.monthly => 'Monthly',
    Cycle.quarterly => '3 months',
    Cycle.semiannual => '6 months',
    Cycle.yearly => 'Yearly',
  };

  Widget _costField() {
    return FieldBox(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: SubdockText.monoValue,
              cursorColor: SubdockColors.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle: SubdockText.fieldValue.copyWith(
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ChoiceChipPill(
            '₫',
            selected: _currency == 'VND',
            onTap: () => setState(() => _currency = 'VND'),
          ),
          const SizedBox(width: 5),
          ChoiceChipPill(
            r'$',
            selected: _currency == 'USD',
            onTap: () => setState(() => _currency = 'USD'),
          ),
        ],
      ),
    );
  }

  Widget _leadRail() {
    return ChipRail(
      children: [
        for (final lead in Reminders.offered)
          ChoiceChipPill(
            ItemPresenter.leadLabel(lead),
            selected: _lead == lead,
            onTap: () => setState(() => _lead = lead),
          ),
        ChoiceChipPill(
          Reminders.offered.contains(_lead)
              ? 'Custom…'
              : ItemPresenter.leadLabel(_lead),
          selected: !Reminders.offered.contains(_lead),
          onTap: _pickLead,
        ),
      ],
    );
  }

  String get _repeatCountLabel {
    final count = _repeatCount;
    if (count == null) return 'Forever';
    final cycle = _cycle;
    if (cycle == null) return '$count times';

    // A count the user set through "Until a date" is still stored as a count,
    // so the field says both: the number is what the app will act on, and the
    // date is what the user was actually thinking about.
    final last = Recurrence.occurrenceAfter(
      _expiresOn ?? widget.today,
      cycle,
      count - 1,
    );
    return '$count times · to ${MoneyFormat.shortDate(last)}';
  }

  String _catalogDetail(CatalogEntry entry) {
    final parts = <String>[ItemPresenter.cycleLabel(entry.defaultCycle)];
    final minor = entry.typicalAmountMinor;
    final currency = entry.currency;
    if (minor != null && currency != null) {
      parts.add(MoneyFormat.full(Money(minor, currency)));
    }
    return parts.join(' · ');
  }

  void _pick(CatalogEntry entry) {
    setState(() {
      _matched = entry;
      _name.text = entry.name;
      _nameSettled = true;
      _category = entry.category;
      _cycle = entry.defaultCycle;
      if (_cycle == null) _repeatCount = null;
      final minor = entry.typicalAmountMinor;
      if (minor != null) {
        _amount.text = minor.toString();
        _currency = entry.currency ?? _currency;
      }
    });
    _nameFocus.unfocus();
  }

  void _keepTyped() {
    setState(() {
      _matched = null;
      _nameSettled = true;
    });
    _nameFocus.unfocus();
  }

  Future<void> _pickDate() async {
    final picked = await widget.onPickDate?.call(_expiresOn);
    if (picked != null && mounted) setState(() => _expiresOn = picked);
  }

  Future<void> _pickIcon() async {
    _nameFocus.unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SubdockColors.canvas,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SubdockRadius.placard),
        ),
      ),
      builder: (sheet) => IconGallery(
        selected: _iconName ?? SubdockIcons.detect(_name.text),
        onPick: (key) => Navigator.of(sheet).pop(key),
      ),
    );
    if (picked != null && mounted) setState(() => _iconName = picked);
  }

  Future<void> _pickRepeatCount() async {
    const untilADate = -1;

    final picked = await _choose<int>(
      title: 'How many times',
      options: const [
        (0, 'Forever'),
        (3, '3 times'),
        (6, '6 times'),
        (12, '12 times'),
        (untilADate, 'Until a date…'),
      ],
      selected: _repeatCount ?? 0,
    );
    if (picked == null || !mounted) return;

    if (picked != untilADate) {
      setState(() => _repeatCount = picked == 0 ? null : picked);
      return;
    }

    // "Until a date" is stored as a count, not as a second end-date field.
    // Two ways of saying when a series stops is two things that can disagree,
    // and the count is the one the reminder planner already understands.
    final end = await widget.onPickDate?.call(_expiresOn);
    final cycle = _cycle;
    if (end == null || cycle == null || !mounted) return;
    setState(() {
      _repeatCount =
          Recurrence.cyclesElapsed(
            _expiresOn ?? widget.today,
            cycle,
            end,
          ).clamp(0, 600) +
          1;
    });
  }

  Future<void> _pickLead() async {
    final picked = await _choose<int>(
      title: 'Remind me',
      options: [
        for (final lead in const [0, 1, 2, 3, 5, 7, 14, 30, 60])
          (lead, ItemPresenter.leadLabel(lead)),
      ],
      selected: _lead,
    );
    if (picked != null && mounted) setState(() => _lead = picked);
  }

  /// One sheet for every list-of-options field on this form.
  ///
  /// A sheet rather than a Material dropdown: the dropdown paints its own menu
  /// surface with its own radius and elevation, and there is no way to make
  /// that surface agree with the rest of this design.
  Future<T?> _choose<T>({
    required String title,
    required List<(T, String)> options,
    T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: SubdockColors.canvas,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SubdockRadius.placard),
        ),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            SubdockSpacing.screenH,
            0,
            SubdockSpacing.screenH,
            20,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title.toUpperCase(), style: SubdockText.sectionLabel),
            ),
            GroupedCard(
              children: [
                for (final (value, label) in options)
                  DetailRow(
                    // The tick is set in mono because that is the family that
                    // carries the glyph; Be Vietnam Pro has no U+2713 and
                    // would fall back to whatever the platform supplies.
                    label: label,
                    value: value == selected ? '✓' : null,
                    monoValue: true,
                    valueColor: SubdockColors.accent,
                    onTap: () => Navigator.of(sheet).pop(value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final amount = int.tryParse(_amount.text.trim());
    final initial = widget.initial;

    widget.onSave?.call(
      DraftItem(
        name: _name.text.trim(),
        expiresOn: _expiresOn!,
        category: _category,
        iconName: _iconName,
        cycle: _cycle,
        repeatCount: _cycle == null ? null : _repeatCount,
        amountMinor: amount,
        currency: amount == null ? null : _currency,
        // The ladder the item arrived with, untouched: the edit form does not
        // show it, so it has nothing to say about it.
        leadDays: initial?.leadDays ?? [_lead],
        matched: _matched,
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final String name;
  final String? detail;
  final bool muted;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.name,
    this.detail,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            ServiceTile(
              name,
              size: 30,
              radius: SubdockRadius.tile,
              fontSize: 12,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted ? SubdockText.rowLabel : SubdockText.fieldValue,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 10),
              Text(detail!, style: SubdockText.rowLabel.copyWith(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
