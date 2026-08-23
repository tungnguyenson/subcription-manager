import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/reminders.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/widgets/service_mark.dart';
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
  final _amountFocus = FocusNode();

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
    // Grouping commas are settled when the field is left, not while it is
    // being typed into: re-formatting under the cursor moves the caret away
    // from the digit the user is working on.
    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) _normalizeAmount();
      setState(() {});
    });
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
      _currency = initial.currency ?? _currency;
      _amount.text = MoneyFormat.majorInput(minor, _currency);
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
    _amountFocus.dispose();
    super.dispose();
  }

  List<CatalogEntry> get _suggestions =>
      _nameSettled ? const [] : widget.catalog.search(_name.text);

  bool get _canSave => _name.text.trim().isNotEmpty && _expiresOn != null;

  /// The three repeats almost every item uses.
  ///
  /// Three, not the whole space of intervals. A form that lists every cycle it
  /// supports takes longer to fill in than the item is worth. Everything else
  /// — the other presets, and any interval the user types — lives behind the
  /// fourth segment, which shows the chosen value once there is one.
  static const List<Cycle?> _quickRepeats = [Cycle.monthly, Cycle.yearly, null];

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
              // Date before category: it is the one field every item has to
              // answer, and the one the user came here to type.
              const SizedBox(height: SubdockSpacing.formBlock),
              Field(label: 'Date', bleed: true, child: _dateField()),
              const SizedBox(height: SubdockSpacing.formBlock),
              Field(label: 'Category', bleed: true, child: _categoryRail()),
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

  /// The calendar on a row of its own, the shortcuts under it.
  ///
  /// The picker used to be the last chip on the rail, which put the control
  /// most items need at the end of a sideways scroll past four they do not.
  /// The row also carries the resolved date, because a shortcut the user
  /// cannot read back is a date they will re-check against their provider
  /// anyway.
  Widget _dateField() {
    final expiresOn = _expiresOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gutter(
          PickerField(
            value: expiresOn == null
                ? 'Pick a date'
                : DateCopy.longDate(expiresOn),
            placeholder: expiresOn == null,
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 9),
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
          ],
        ),
      ],
    );
  }

  Widget _repeatRow() {
    final cycle = _cycle;
    final isCustom = cycle != null && !_quickRepeats.contains(cycle);

    return SegmentedRow(
      labels: [
        for (final option in _quickRepeats) _repeatLabel(option),
        // The fourth segment is a value and a door at once: it says what was
        // chosen when the choice is not one of the three, and opens the full
        // list either way.
        isCustom ? _repeatLabel(cycle) : 'Other…',
      ],
      selected: isCustom ? _quickRepeats.length : _quickRepeats.indexOf(cycle),
      onSelect: (i) {
        if (i == _quickRepeats.length) {
          _pickCycle();
          return;
        }
        setState(() {
          _cycle = _quickRepeats[i];
          // "Once" and "how many times" cannot both be true.
          if (_cycle == null) _repeatCount = null;
        });
      },
    );
  }

  /// The segment labels. Shorter than [ItemPresenter.cycleLabel] because four
  /// of these have to share the width of a phone: "Twice a year" does not fit
  /// beside three siblings, "6 months" does, and a typed interval shrinks all
  /// the way to "5 mo".
  static String _repeatLabel(Cycle? cycle) {
    if (cycle == null) return 'Once';
    return switch ((cycle.unit, cycle.step)) {
      (CycleUnit.day, 7) => 'Weekly',
      (CycleUnit.month, 1) => 'Monthly',
      (CycleUnit.month, 3) => '3 months',
      (CycleUnit.month, 6) => '6 months',
      (CycleUnit.month, 12) => 'Yearly',
      _ => ItemPresenter.cycleEveryShort(cycle),
    };
  }

  /// The full list behind the fourth segment: every preset, one-off, and the
  /// way out to an interval the app does not have a name for.
  Future<void> _pickCycle() async {
    const once = 'ONCE';
    const custom = 'CUSTOM';

    final cycle = _cycle;
    final isCustom = cycle != null && !cycle.isPreset;

    final picked = await _choose<String>(
      title: 'Repeat',
      options: [
        for (final preset in Cycle.values)
          (preset.wireName, ItemPresenter.cycleLabel(preset)),
        (once, 'Once'),
        (
          custom,
          isCustom
              ? 'Every ${ItemPresenter.cycleEvery(cycle)}…'
              : 'Every N days, weeks, months…',
        ),
      ],
      selected: isCustom ? custom : (cycle?.wireName ?? once),
    );
    if (picked == null || !mounted) return;

    if (picked == custom) {
      await _pickCustomCycle();
      return;
    }

    setState(() {
      _cycle = picked == once ? null : CycleWire.fromWire(picked);
      if (_cycle == null) _repeatCount = null;
    });
  }

  /// The interval nothing on the list covers: every 5 months, every 45 days.
  ///
  /// A real contract renews on a schedule somebody else chose, and the answer
  /// to "my plan runs 5 months" cannot be "then make it a one-off and re-date
  /// it by hand five times a year".
  Future<void> _pickCustomCycle() async {
    final picked = await showModalBottomSheet<Cycle>(
      context: context,
      backgroundColor: SubdockColors.canvas,
      showDragHandle: true,
      // The sheet holds a keyboard-bound field, so it has to be free to give
      // up height to the keyboard rather than sit under it.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SubdockRadius.placard),
        ),
      ),
      builder: (sheet) => _CustomCycleSheet(initial: _cycle),
    );
    if (picked != null && mounted) setState(() => _cycle = picked);
  }

  Widget _costField() {
    // VND has no minor unit, so its field has no decimal point to offer and
    // no decimal key to put on the keyboard.
    final exponent = Currencies.exponentOf(_currency);
    final converted = _convertedLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldBox(
          focused: _amountFocus.hasFocus,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: exponent > 0,
                  ),
                  // The amount is typed the way it is written — 20.50, not
                  // 2050 — so the separators it is written with have to be
                  // typeable. Everything else is filtered out here rather than
                  // rejected on save.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      exponent > 0 ? RegExp(r'[0-9.,]') : RegExp(r'[0-9,]'),
                    ),
                  ],
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
                onField: true,
                onTap: () => _setCurrency('VND'),
              ),
              const SizedBox(width: 5),
              ChoiceChipPill(
                r'$',
                selected: _currency == 'USD',
                onField: true,
                onTap: () => _setCurrency('USD'),
              ),
            ],
          ),
        ),
        if (converted != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(converted, style: SubdockText.monoInline),
          ),
      ],
    );
  }

  /// The same figure in the other currency.
  ///
  /// Two currency chips on one field means the amount can be typed under the
  /// wrong one, and 20 read as dong is a different mistake from 260,000 read
  /// as dollars — neither is visible in the digits themselves. Shown with the
  /// rate that produced it, on the same terms as every other converted figure
  /// in this app: an approximation that does not say where it came from is
  /// worse than none.
  String? get _convertedLine {
    final minor = MoneyFormat.parseMajor(_amount.text, _currency);
    if (minor == null || minor == 0) return null;

    final rate = Fx.bundledUsdVnd;
    final money = Money(minor, _currency);
    final converted = switch (_currency) {
      'USD' => rate.convert(money),
      'VND' => rate.invert(money),
      _ => null,
    };
    if (converted == null) return null;

    return '≈ ${MoneyFormat.full(converted)} · ${MoneyFormat.rate(rate)}';
  }

  /// Re-renders the typed amount at the currency's own precision.
  ///
  /// The number the user typed is kept as a number; only its precision moves.
  /// Converting it instead would answer a question they did not ask — tapping
  /// ₫ says "this price is in dong", not "restate this price in dong".
  void _setCurrency(String code) {
    if (code == _currency) return;
    setState(() {
      _currency = code;
      final minor = MoneyFormat.parseMajor(_amount.text, code);
      if (minor != null) _amount.text = MoneyFormat.majorInput(minor, code);
    });
  }

  void _normalizeAmount() {
    final minor = MoneyFormat.parseMajor(_amount.text, _currency);
    final text = minor == null ? '' : MoneyFormat.majorInput(minor, _currency);
    if (text != _amount.text) _amount.text = text;
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
        _currency = entry.currency ?? _currency;
        _amount.text = MoneyFormat.majorInput(minor, _currency);
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
    // A calendar behind the keyboard is a calendar with two rows of dates on
    // it, so the keyboard goes first.
    FocusScope.of(context).unfocus();
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
        selected: _iconName ?? SubdockMarks.detectKey(_name.text),
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
    final amount = MoneyFormat.parseMajor(_amount.text, _currency);
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

/// The sheet behind "Every N days, weeks, months…".
///
/// Its own widget, and its own state, because the number is only a cycle once
/// it is a whole number in range: the form outside must never hold a half-typed
/// interval, and the sheet must be able to say why the button is off.
class _CustomCycleSheet extends StatefulWidget {
  /// The interval the form is holding, so the sheet opens on it rather than on
  /// a default the user then has to undo.
  final Cycle? initial;

  const _CustomCycleSheet({this.initial});

  @override
  State<_CustomCycleSheet> createState() => _CustomCycleSheetState();
}

class _CustomCycleSheetState extends State<_CustomCycleSheet> {
  static const List<CycleField> _fields = [
    CycleField.day,
    CycleField.week,
    CycleField.month,
    CycleField.year,
  ];

  final _count = TextEditingController();
  late CycleField _field;

  @override
  void initState() {
    super.initState();
    // Two months rather than one: one month is already a segment on the form,
    // so a user who got this far means something else.
    final (count, field) =
        widget.initial?.inLargestField ?? (2, CycleField.month);
    _count.text = count.toString();
    _field = field;
    _count.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  /// The cycle the sheet currently describes, or null while it describes
  /// nothing valid.
  Cycle? get _cycle {
    final count = int.tryParse(_count.text.trim());
    if (count == null || count < 1) return null;
    try {
      return Cycle.every(count, _field);
    } on ArgumentError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycle = _cycle;

    return Padding(
      // The sheet gives up height to the keyboard rather than letting it cover
      // the field it belongs to.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SubdockSpacing.screenH,
            0,
            SubdockSpacing.screenH,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('REPEAT EVERY', style: SubdockText.sectionLabel),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: FieldBox(
                      child: TextField(
                        controller: _count,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        textAlign: TextAlign.center,
                        style: SubdockText.monoValue,
                        cursorColor: SubdockColors.accent,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SegmentedRow(
                      labels: [for (final field in _fields) _fieldLabel(field)],
                      selected: _fields.indexOf(_field),
                      onSelect: (i) => setState(() => _field = _fields[i]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                cycle == null
                    ? 'A whole number of at most ${Cycle.maxStep} days or months.'
                    : 'Repeats every ${ItemPresenter.cycleEvery(cycle)}.',
                style: SubdockText.footnote,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                'Done',
                onPressed: cycle == null
                    ? null
                    : () => Navigator.of(context).pop(cycle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fieldLabel(CycleField field) => switch (field) {
    CycleField.day => 'Days',
    CycleField.week => 'Weeks',
    CycleField.month => 'Months',
    CycleField.year => 'Years',
  };
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
