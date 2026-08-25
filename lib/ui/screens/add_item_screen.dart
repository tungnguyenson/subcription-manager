import 'package:flutter/material.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/category_book.dart';
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
import 'package:subdock/ui/screens/add/cost_field.dart';
import 'package:subdock/ui/screens/add/option_sheets.dart';
import 'package:subdock/ui/screens/add/plan_grid.dart';
import 'package:subdock/ui/screens/add/service_picker.dart';
import 'package:subdock/ui/screens/add/source_field.dart';
import 'package:subdock/ui/screens/add/summary_block.dart';
import 'package:subdock/ui/screens/add/trial_field.dart';
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

  /// The shelves the user keeps, for the category rail and for the reminder
  /// defaults a new item takes.
  final CategoryBook categories;

  final LocalDate today;

  /// The item being edited, already reduced to what this form asks for. Null
  /// for a new item.
  final DraftItem? initial;

  final VoidCallback? onCancel;
  final void Function(DraftItem draft)? onSave;
  final VoidCallback? onScan;

  /// Opens the calendar, seeded with the date the form is holding.
  final Future<LocalDate?> Function(LocalDate? from)? onPickDate;

  /// The sources the user has named, for the "pays from" chips.
  final List<PaymentSource> sources;

  /// Creates a source from inside the form and hands back its id.
  final Future<String?> Function(String name, SourceGlyph glyph)?
  onCreateSource;

  /// Which source to preselect on a new item.
  ///
  /// The last one used, supplied by the caller. Most people pay for nearly
  /// everything from one card, so defaulting to it turns the commonest answer
  /// into no taps at all — and it is still a chip they can change, not a
  /// hidden assumption.
  final String? defaultSourceId;

  const AddItemScreen({
    super.key,
    required this.catalog,
    required this.categories,
    required this.today,
    this.initial,
    this.onCancel,
    this.onSave,
    this.onScan,
    this.onPickDate,
    this.sources = const [],
    this.onCreateSource,
    this.defaultSourceId,
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
  late Category _category = widget.categories.fallback;
  String? _iconName;
  Cycle? _cycle = Cycle.monthly;
  int? _repeatCount;
  String _currency = 'VND';
  int _lead = Reminders.defaultLead;

  /// Which of the two steps a *new* item is on. An edit never sees step one:
  /// the item already has a name, and offering to replace it with a catalogue
  /// row would be offering to undo the thing the user came here to change.
  bool _picking = true;

  /// The catalogue tier whose price is in the cost field, or null once the user
  /// has typed their own amount. Only ever set alongside [_matched].
  String? _planTier;

  TrialDraft _trial = TrialDraft.off;
  String? _sourceId;

  /// True once the user has picked a suggestion or explicitly declined one.
  /// Until then the suggestion list stays open, because tapping a known service
  /// fills the category, the cycle and the cancel link in one go, which is the
  /// single biggest reduction in entry friction this app has.
  bool _nameSettled = false;

  bool get _isEdit => widget.initial != null;

  /// Whether the cost field is on screen while a plan grid is also on screen.
  ///
  /// Only ever set, never cleared: a user who has opened it has typed, or is
  /// about to, and folding the field away under them would take the number
  /// with it. Picking a plan tile afterwards overwrites the amount, which is
  /// the same thing the field itself would do.
  bool _costOpen = false;

  /// Which of the card's two modes is showing. Display only: both modes end up
  /// in [_repeatCount].
  bool _endsOnDate = false;

  /// The date the user picked in `On a date` mode, kept so the field can read
  /// it back. The count is what is saved.
  LocalDate? _endsOn;

  final TextEditingController _count = TextEditingController();
  final FocusNode _countFocus = FocusNode();

  /// The interval behind `Custom…`, as typed and as chosen.
  ///
  /// Held here rather than read back off [_cycle] on every frame, because a
  /// half-typed number is not a cycle: the field can hold `''` for a keystroke
  /// while [_cycle] keeps the last whole interval, and reading the unit off a
  /// cycle would flip the lit chip from `weeks` to `days` the moment 2 weeks
  /// became 14 days internally.
  final TextEditingController _every = TextEditingController();
  final FocusNode _everyFocus = FocusNode();
  CycleField _everyUnit = CycleField.month;

  /// The item's name as it was when the form opened.
  ///
  /// Read off `initial` rather than off the live text field: the line is there
  /// to say which item is on screen, and a heading that rewrites itself as the
  /// user types stops answering that halfway through the first keystroke.
  String get _editingName => widget.initial?.name ?? '';

  @override
  void initState() {
    super.initState();
    _seed(widget.initial);

    _name.addListener(() => setState(() {}));
    // Typing an amount unlatches the plan tile. The grid says "this is the
    // listed price of that tier", and leaving a tile lit beside a number the
    // user overwrote would make it say something false.
    //
    // Only *typing*, though. `_pickPlan` writes the tier's price into this
    // same field, and a bare listener cannot tell the two apart — it fires
    // synchronously on the assignment and clears the tier the tap just set,
    // so no tile would ever stay lit. [_written] is what the app put there.
    _amount.addListener(() {
      if (_amount.text == _written) return;
      setState(() => _planTier = null);
    });
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
    if (initial == null) {
      _sourceId = widget.defaultSourceId;
      return;
    }

    _picking = false;

    _name.text = initial.name;
    _expiresOn = initial.expiresOn;
    _category = initial.category;
    _iconName = initial.iconName;
    _cycle = initial.cycle;
    _repeatCount = initial.repeatCount;
    _count.text = initial.repeatCount == null ? '' : '${initial.repeatCount}';
    final cycle = initial.cycle;
    if (cycle != null && !cycle.isPreset) {
      final (count, field) = cycle.inLargestField;
      _every.text = '$count';
      _everyUnit = field;
    }
    _lead = initial.leadDays.isEmpty
        ? Reminders.defaultLead
        : initial.leadDays.first;

    final minor = initial.amountMinor;
    if (minor != null) {
      _currency = initial.currency ?? _currency;
      _amount.text = MoneyFormat.majorInput(minor, _currency);
    }

    _sourceId = initial.paymentSourceId;
    final trialStart = initial.trialStart;
    if (trialStart != null) {
      _trial = TrialDraft(start: trialStart, firstCharge: initial.expiresOn);
    }

    // The name is already what the user meant. Offering to replace it with a
    // catalog row the moment the screen opens is an offer to undo their edit.
    _nameSettled = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _count.dispose();
    _every.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _countFocus.dispose();
    _everyFocus.dispose();
    super.dispose();
  }

  List<CatalogEntry> get _suggestions =>
      _nameSettled ? const [] : widget.catalog.search(_name.text);

  /// The item's due date: a trial's first charge, or the date field.
  ///
  /// One value, resolved in one place. A trial's free period ending *is* the
  /// charge landing, so letting the two fields hold different dates would let
  /// the reminder fire against one and the row display the other.
  LocalDate? get _dueDate => _trial.on ? _trial.firstCharge : _expiresOn;

  /// The name as it will be stored: what was typed, or a stand-in.
  ///
  /// An empty name does not block the save. The spec is explicit that it
  /// becomes `Untitled item`, and it is right: someone who set a date and an
  /// amount and then tapped Save has told the app the two things it needs, and
  /// refusing them over a label they can fix in one tap loses the date.
  ///
  /// The date is the one thing that still gates the button. `expiresOn` is
  /// non-null all the way down to the table, so there is nowhere to put an
  /// item without one — see the note on [_save].
  String get _savedName {
    final typed = _name.text.trim();
    return typed.isEmpty ? 'Untitled item' : typed;
  }

  bool get _canSave => _dueDate != null;

  /// True while the cycle is an interval the app has no name for.
  bool get _isCustomCycle => _cycle != null && !_cycle!.isPreset;

  /// The cost field as money, or null while it is empty or unparseable.
  Money? get _parsedAmount {
    final minor = MoneyFormat.parseMajor(_amount.text, _currency);
    return minor == null ? null : Money(minor, _currency);
  }

  @override
  Widget build(BuildContext context) {
    // Step one, for a new item only.
    if (_picking) {
      return ServicePicker(
        catalog: widget.catalog,
        categories: widget.categories,
        onPick: _pickFromCatalog,
        onManual: () => setState(() {
          _picking = false;
          _nameSettled = true;
        }),
        onCancel: widget.onCancel,
      );
    }

    final showSuggestions = _suggestions.isNotEmpty && _nameFocus.hasFocus;
    final plans = _planOptions;

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
              // Part of the name block, not a block of its own: the chips are
              // eight pixels under the field rather than twenty-six, because
              // what a thing is called and what kind of thing it is are one
              // answer given twice.
              const SizedBox(height: 9),
              Field(
                label: _isEdit ? 'Category' : null,
                bleed: true,
                child: _categoryRail(),
              ),
              // The plans of the chosen service. Above the cost field, and
              // above the cycle: picking a tile fills both of them, so a user
              // who recognises their plan never reads the two blocks below.
              if (plans.isNotEmpty) ...[
                const SizedBox(height: SubdockSpacing.formBlock),
                _gutter(
                  Field(
                    label: 'Plan',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PlanGrid(
                          options: plans,
                          selected: _planTier,
                          onSelect: _pickPlan,
                        ),
                        const SizedBox(height: 8),
                        // Kept, though the build file has no line here. A
                        // price with no page and no date behind it is a
                        // rumour, and this grid is the one place in the app
                        // that shows figures the user did not type.
                        Text(
                          _planProvenance(plans),
                          style: SubdockText.caption,
                        ),
                        // The way past the grid, and the reason the cost
                        // field below is folded away: a user who recognises
                        // their plan on a tile never needs a number pad, and
                        // a field standing open under the tiles asks them to
                        // check whether the tile they just tapped was right.
                        if (!_costOpen) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Flexible, because the sentence and the link
                              // have to share one line at any text scale.
                              const Flexible(
                                child: Text(
                                  'Paying a different amount?',
                                  style: SubdockText.summary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => setState(() => _costOpen = true),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'Enter it',
                                    style: SubdockText.quietAction,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (plans.isEmpty || _costOpen) ...[
                const SizedBox(height: SubdockSpacing.formBlock),
                _costBlock(),
              ],
              const SizedBox(height: SubdockSpacing.formBlock),
              _gutter(
                Field(
                  // `Repeats` when editing an item that already does,
                  // `Billing cycle` when setting one up. The hand-off words
                  // them differently and both readings are right: one is a
                  // fact about the item, the other is a choice being made.
                  label: _isEdit ? 'Repeats' : 'Billing cycle',
                  child: PickerField(
                    value: _cycleLabel(_cycle),
                    onTap: _pickCycle,
                  ),
                ),
              ),
              // The interval nothing on the list covers, typed out. A sub-block
              // of the dropdown above rather than a block of its own: it is the
              // second half of one answer.
              if (_isCustomCycle) ...[
                const SizedBox(height: 9),
                _gutter(_everyRow()),
              ],
              // The date field only appears when there is no trial. With one on,
              // the first charge date *is* the due date, and a second date
              // field beside it is a second answer to the same question.
              if (!_trial.on) ...[
                const SizedBox(height: SubdockSpacing.formBlock),
                Field(
                  // No heading on a new item. The field itself reads `Choose a
                  // date`, so a `NEXT PAYMENT` label over it is the screen
                  // asking the same question twice. An edit gets one, because
                  // there the field holds a date rather than a prompt.
                  label: _isEdit ? 'Next date' : null,
                  bleed: true,
                  child: _dateField(),
                ),
              ],
              // Hidden for a one-off. There is no series to end, and a
              // `Repeats forever` toggle over a payment that happens once is
              // a question with no true answer.
              if (_cycle != null) ...[
                const SizedBox(height: SubdockSpacing.formBlock),
                _gutter(_repeatsBlock()),
              ],
              const SizedBox(height: SubdockSpacing.formBlock),
              _gutter(
                Field(
                  label: _isEdit ? 'Free trial' : null,
                  child: TrialField(
                    value: _trial,
                    today: widget.today,
                    leadDays: _lead,
                    onChanged: (next) => setState(() => _trial = next),
                    onPickDate: widget.onPickDate,
                  ),
                ),
              ),
              const SizedBox(height: SubdockSpacing.formBlock),
              _gutter(
                SourceField(
                  sources: widget.sources,
                  selected: _sourceId,
                  onSelect: (id) => setState(() => _sourceId = id),
                  onCreate: widget.onCreateSource,
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
              const SizedBox(height: SubdockSpacing.formBlock),
              _gutter(
                SummaryBlock(
                  due: _dueDate,
                  amount: _parsedAmount,
                  trial: _trial.on,
                  leadDays: _lead,
                ),
              ),
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
            _isEdit ? 'Save changes' : 'Save item',
            onPressed: _canSave ? _save : null,
          ),
        ),
      ],
    );
  }

  /// The chosen service's tiers at the cycle currently selected.
  ///
  /// Empty for a manually entered item, and empty for a service the catalogue
  /// has no priced plans for — which is two thirds of it. An empty grid is not
  /// a failure state, it is the normal one, so the block simply does not appear.
  List<PlanOption> get _planOptions {
    final entry = _matched;
    final cycle = _cycle;
    if (entry == null || cycle == null) return const [];
    return PlanGrid.optionsFor(entry, cycle);
  }

  /// Where the prices in the grid came from, and when.
  ///
  /// Never omitted. A grid of amounts with no provenance reads as the app
  /// knowing what the user pays, and it does not — these are the vendor's list
  /// prices, and a promotion, a legacy tier or a family plan split four ways all
  /// make them wrong for this particular person.
  String _planProvenance(List<PlanOption> plans) {
    final checked = plans
        .map((p) => p.checkedAt)
        .reduce(
          // The oldest of them: the block is only as fresh as its weakest row, and
          // quoting the newest would overstate how current it is.
          (a, b) => a.compareTo(b) <= 0 ? a : b,
        );
    final date = LocalDate.tryParse(checked);
    return date == null
        ? 'Listed prices from the vendor. Yours may differ.'
        : 'Listed prices, checked ${DateCopy.listedDate(date)}. '
              'Yours may differ.';
  }

  /// The last amount the app wrote into the cost field, as opposed to typed.
  ///
  /// Null once the user has touched it. See the listener in [initState].
  String? _written;

  void _pickPlan(PlanOption plan) {
    setState(() {
      _planTier = plan.tier;
      _currency = plan.price.currency;
      _fillAmount(plan.price.minor);
    });
  }

  /// Puts a catalogue price in the cost field without unlatching the tile.
  void _fillAmount(int minor) {
    _written = MoneyFormat.majorInput(minor, _currency);
    _amount.text = _written!;
  }

  /// Step one handing over to step two.
  void _pickFromCatalog(CatalogEntry entry) {
    _pick(entry);
    setState(() {
      _picking = false;
      // Preselect the vendor's own default tier, so the commonest plan is
      // already lit and its price already in the cost field.
      _planTier = entry.defaultPlan;
      final cycle = _cycle;
      if (cycle == null) return;
      final plans = PlanGrid.optionsFor(entry, cycle);
      final pick = plans.where((p) => p.tier == entry.defaultPlan).firstOrNull;
      if (pick != null) {
        _currency = pick.price.currency;
        _fillAmount(pick.price.minor);
      }
    });
  }

  Widget _gutter(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SubdockSpacing.screenH),
    child: child,
  );

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back to step one, and only when there is a step one to go back
              // to. An edit has no picker behind it, and a back link that
              // dropped the user into a service browser would look like the
              // app had lost the item they were editing.
              if (!_isEdit)
                InkWell(
                  onTap: () => setState(() => _picking = true),
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('‹ Back', style: SubdockText.quietAction),
                  ),
                ),
              Text(
                _isEdit ? 'Edit item' : (_matched?.name ?? 'New item'),
                style: SubdockText.editorTitle,
              ),
              // Only the editor carries a mono line under the title, and it
              // names the item, because `Edit item` alone does not say which
              // of forty was opened. The add form's title is already the
              // service's own name, so a `Step 2 of 2` under it counts steps
              // at the reader instead of telling them anything.
              if (_isEdit) ...[
                const SizedBox(height: 6),
                Text('Editing $_editingName', style: SubdockText.monoInline),
              ],
            ],
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

  /// When the series stops, in the two ways a person says it.
  ///
  /// Only on screen once `Forever` is unticked, which is what makes the whole
  /// block affordable: the common answer is "it just runs", and that answer is
  /// a checkbox rather than a card.
  ///
  /// Two modes rather than a mixed list of chips, because "after six payments"
  /// and "until March" are different questions and a chip rail that offers
  /// both makes the reader work out which one they are answering. The date
  /// mode still stores a count -- two ways of saying when a series stops are
  /// two things that can disagree, and the count is the one the reminder
  /// planner already understands.
  Widget _endsBlock() {
    const quick = [3, 6, 12];
    final count = _repeatCount ?? _defaultRepeatCount;

    return Container(
      decoration: SubdockSurface.card(),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedRow(
            weighted: true,
            labels: const ['After a number of payments', 'On a date'],
            selected: _endsOnDate ? 1 : 0,
            onSelect: (i) {
              if (i == 1) {
                _pickRepeatUntil();
                return;
              }
              setState(() => _endsOnDate = false);
            },
          ),
          const SizedBox(height: 13),
          if (_endsOnDate)
            Field(
              label: 'Last payment on',
              child: PickerField(
                value: _endsOn == null
                    ? 'Choose a date'
                    : DateCopy.longDate(_endsOn!),
                placeholder: _endsOn == null,
                hint: _endsOn == null ? 'Tap to open the calendar' : null,
                onTap: _pickRepeatUntil,
              ),
            )
          else ...[
            Row(
              children: [
                // Both words give way before the field between them does: the
                // number is the part being read, and at a large text size a
                // rigid row would push it off the card instead.
                const Flexible(
                  child: Text(
                    'Stops after',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SubdockText.rowLabel,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 76,
                  child: _numberBox(
                    controller: _count,
                    focusNode: _countFocus,
                    onChanged: (n) {
                      if (n < 1) return;
                      setState(() => _repeatCount = n.clamp(1, 600));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'payments',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SubdockText.rowLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            // The three counts people actually pick, as flat chips: this is a
            // shortcut to the field above, not a second control that can
            // disagree with it.
            // Wrapped, not a Row: three chips fit one line at this width and
            // stop fitting the moment the reader turns the text size up.
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final n in quick)
                  FlatChip(
                    label: '$n payments',
                    selected: count == n,
                    onTap: () => _setRepeatCount(n),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _setRepeatCount(int n) {
    setState(() {
      _repeatCount = n;
      _endsOnDate = false;
      _endsOn = null;
    });
    _count.text = '$n';
  }

  Widget _costBlock() => _gutter(
    Field(
      label: _amount.text.isEmpty ? 'Cost (optional)' : 'Cost',
      child: CostField(
        controller: _amount,
        focusNode: _amountFocus,
        currency: _currency,
        onCurrency: _setCurrency,
        convertedLine: _convertedLine,
      ),
    ),
  );

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
          SuggestionRow(
            name: entry.name,
            detail: _catalogDetail(entry),
            onTap: () => _pick(entry),
          ),
        SuggestionRow(
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
        for (final category in widget.categories.all)
          ChoiceChipPill(
            category.label,
            selected: _category.id == category.id,
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
                ? 'Choose a date'
                : DateCopy.longDate(expiresOn),
            placeholder: expiresOn == null,
            // Only while the field is still a prompt. Once it holds a date the
            // second line would be explaining a control the user has used.
            hint: expiresOn == null ? 'Tap to open the calendar' : null,
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

  /// `Repeats forever`, and the card behind it.
  ///
  /// A toggle rather than a checkbox on the cycle row: this is a statement
  /// about the item ("it just runs"), the same shape of question as `In a free
  /// trial now` two blocks down, and the two read as one kind of control only
  /// if they are drawn as one. It is also the answer most of the time — a
  /// subscription runs until it is stopped — so it is on by default and the
  /// count card does not exist until the user says otherwise.
  ///
  /// Turning it off sets twelve payments, which is the spec's own default: a
  /// count control that opens on nothing makes the user answer a question they
  /// have not been asked yet.
  Widget _repeatsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          children: [
            InkWell(
              onTap: _toggleForever,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Repeats forever',
                        style: SubdockText.rowLink,
                      ),
                    ),
                    AppToggle(
                      value: _repeatCount == null,
                      onChanged: (_) => _toggleForever(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_repeatCount != null) ...[const SizedBox(height: 9), _endsBlock()],
      ],
    );
  }

  /// `Every [n] months`, for the interval the preset list has no name for.
  ///
  /// Inline rather than in a sheet. A sheet was one tap further away and, worse,
  /// hid the answer: the dropdown above reads `Every 2 months` afterwards, and
  /// a user who wants to make it three has to reopen a modal to find out what
  /// the current number even is.
  ///
  /// Four units, where the spec names three. Days stay because a prepaid SIM's
  /// validity is sold in days — `30 days`, `180 days` — and that is the one
  /// item in this app whose lapse cannot be undone.
  Widget _everyRow() {
    const units = [
      (CycleField.day, 'Days'),
      (CycleField.week, 'Weeks'),
      (CycleField.month, 'Months'),
      (CycleField.year, 'Years'),
    ];

    return Container(
      decoration: SubdockSurface.card(),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'Every',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.rowLabel,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 76,
                child: _numberBox(
                  controller: _every,
                  focusNode: _everyFocus,
                  onChanged: (n) => _setCustomCycle(n, _everyUnit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (field, label) in units)
                FlatChip(
                  label: label,
                  selected: _everyUnit == field,
                  onTap: () => _setCustomCycle(
                    int.tryParse(_every.text.trim()) ?? 1,
                    field,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rebuilds the custom cycle from the number and the unit.
  ///
  /// Out-of-range numbers are dropped rather than clamped: the user is still
  /// typing, and rewriting `4` to `480` under the cursor because they were on
  /// their way to `45` is worse than waiting.
  void _setCustomCycle(int count, CycleField field) {
    if (count < 1 || count > Cycle.maxStep) return;
    setState(() {
      _everyUnit = field;
      _cycle = Cycle.every(count, field);
    });
    if (_every.text.trim() != '$count') _every.text = '$count';
  }

  /// The small centred number field the two count rows share.
  Widget _numberBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required void Function(int value) onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: SubdockText.rowValue,
      cursorColor: SubdockColors.accent,
      onChanged: (text) {
        final n = int.tryParse(text.trim());
        if (n == null) return;
        onChanged(n);
      },
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: SubdockColors.hairline,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SubdockRadius.chip),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Twelve, from the spec. A year of a monthly plan.
  static const int _defaultRepeatCount = 12;

  void _toggleForever() {
    if (_repeatCount != null) {
      setState(() {
        _repeatCount = null;
        _endsOnDate = false;
        _endsOn = null;
      });
      return;
    }
    _setRepeatCount(_defaultRepeatCount);
  }

  /// The name of a cycle as the dropdown shows it.
  ///
  /// [ItemPresenter.cycleLabel] with one word changed: `One-off` rather than
  /// `Once`, because this field is a list of billing cycles and `Once` beside
  /// `Monthly` reads like a frequency where `One-off` reads like a kind of
  /// payment. Everything else, custom intervals included, is the presenter's
  /// wording — the field is full width, so `Every 2 months` fits.
  static String _cycleLabel(Cycle? cycle) =>
      cycle == null ? 'One-off' : ItemPresenter.cycleLabel(cycle);

  /// The list behind the dropdown: every preset, the one-off, and the way out
  /// to an interval the app does not have a name for.
  ///
  /// `Custom…` does not open a second modal. It sets an interval and reveals
  /// the `Every n …` row underneath, which is where the number is then edited
  /// in place — a real contract renews on a schedule somebody else chose, and
  /// "my plan runs 5 months" must not turn into "make it a one-off and re-date
  /// it by hand five times a year".
  Future<void> _pickCycle() async {
    const once = 'ONCE';
    const custom = 'CUSTOM';

    final cycle = _cycle;
    final isCustom = _isCustomCycle;

    final picked = await chooseOption<String>(
      context,
      title: 'Billing cycle',
      options: [
        for (final preset in Cycle.values)
          (preset.wireName, ItemPresenter.cycleLabel(preset)),
        (once, 'One-off'),
        (
          custom,
          isCustom
              ? 'Every ${ItemPresenter.cycleEvery(cycle!)}…'
              : 'Every N days, weeks, months…',
        ),
      ],
      selected: isCustom ? custom : (cycle?.wireName ?? once),
    );
    if (picked == null || !mounted) return;

    if (picked == custom) {
      // Two months, not one: one month is already on the list above, so a user
      // who came this far means something else. An interval already custom is
      // left alone — reopening the list to check what it says must not reset it.
      if (!isCustom) _setCustomCycle(2, CycleField.month);
      return;
    }

    setState(() {
      _cycle = picked == once ? null : CycleWire.fromWire(picked);
      if (_cycle == null) _repeatCount = null;
    });
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
      _category = widget.categories[entry.categoryId];
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

  /// The calendar behind `On a date`.
  ///
  /// The date is turned into a count straight away and the count is what gets
  /// saved; the date is kept only so the field can read it back. Two ways of
  /// saying when a series stops are two things that can disagree, and the count
  /// is the one the reminder planner already understands.
  ///
  /// A date before the next payment is pulled forward to it. The spec requires
  /// `>= next payment`, and the honest reading of "last payment on a day before
  /// the first" is one payment, not none — a series with zero payments is an
  /// item that does nothing, which is not what anyone meant by picking a date.
  Future<void> _pickRepeatUntil() async {
    final picked = await widget.onPickDate?.call(_endsOn ?? _expiresOn);
    final cycle = _cycle;
    if (picked == null || cycle == null || !mounted) return;

    final first = _expiresOn ?? widget.today;
    final end = picked < first ? first : picked;

    setState(() {
      _endsOnDate = true;
      _endsOn = end;
      _repeatCount =
          Recurrence.cyclesElapsed(first, cycle, end).clamp(0, 600) + 1;
    });
    _count.text = '$_repeatCount';
  }

  Future<void> _pickLead() async {
    final picked = await chooseOption<int>(
      context,
      title: 'Remind me',
      options: [
        for (final lead in const [0, 1, 2, 3, 5, 7, 14, 30, 60])
          (lead, ItemPresenter.leadLabel(lead)),
      ],
      selected: _lead,
    );
    if (picked != null && mounted) setState(() => _lead = picked);
  }

  /// Hands the form's answers back to the caller.
  ///
  /// The spec also asks for a save with no date at all — the item joins the
  /// list and simply gets no reminder. That is not done here, and it is not a
  /// layout change: `DraftItem.expiresOn`, `itemRow.expiresOn` and every
  /// reminder query below them are non-null, so a dateless item needs a
  /// migration and a nullable column, not a different button state.
  void _save() {
    final amount = MoneyFormat.parseMajor(_amount.text, _currency);
    final initial = widget.initial;

    widget.onSave?.call(
      DraftItem(
        name: _savedName,
        expiresOn: _dueDate!,
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
        trialStart: _trial.on ? _trial.start : null,
        paymentSourceId: _sourceId,
      ),
    );
  }
}
