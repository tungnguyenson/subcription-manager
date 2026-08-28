import 'dart:async';

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
import 'package:subdock/i18n.dart';

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

  /// Opens the provider's own account page in a browser.
  ///
  /// A plain open, unlike the button on the detail screen: that one also
  /// records where the subscription was bought and offers to write down the
  /// renewal date on the way back. Neither belongs on a form that has not
  /// saved an item yet, and a prompt landing on top of half-typed fields would
  /// be worse than not asking.
  final void Function(String url)? onOpenLink;

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
    this.onOpenLink,
    this.defaultSourceId,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();

  CatalogEntry? _matched;
  LocalDate? _expiresOn;

  /// The shelf, once somebody has said which one.
  ///
  /// Null until then, and the field reads `Pick a category` rather than
  /// showing a shelf nobody chose. The old rail lit its fallback chip on the
  /// first frame, which is the form answering its own question and then asking
  /// the user to confirm it.
  Category? _chosen;

  String? _iconName;
  Cycle? _cycle = Cycle.monthly;
  int? _repeatCount;

  /// A new amount starts in the currency the app counts in. Not a constant:
  /// someone who told onboarding they pay in dollars should not have to change
  /// the chip on every item they add.
  String _currency = Fx.base;
  int _lead = Reminders.defaultLead;

  /// Which of the two steps a *new* item is on. An edit never sees step one:
  /// the item already has a name, and offering to replace it with a catalogue
  /// row would be offering to undo the thing the user came here to change.
  bool _picking = true;

  /// The [PlanOption.id] whose price is in the cost field, or null once the
  /// user has typed their own amount. Only ever set alongside [_matched].
  String? _planTier;

  bool _inTrial = false;
  String? _sourceId;

  /// Whether the row of less common cycles is open under the tray.
  ///
  /// Opened by the third segment and left open once a cycle from it is
  /// chosen, because the segment then reads `Quarterly` and a reader who
  /// wanted `Weekly` would otherwise have to work out that the way to change
  /// their answer is to tap the answer.
  bool _cycleOther = false;

  /// True once the user has picked a suggestion or explicitly declined one.
  /// Until then the suggestion list stays open, because tapping a known service
  /// fills the category, the cycle and the cancel link in one go, which is the
  /// single biggest reduction in entry friction this app has.
  bool _nameSettled = false;

  bool get _isEdit => widget.initial != null;

  /// The shelf the item will be saved on: the chosen one, or the fallback.
  ///
  /// Nothing downstream takes a null category -- an item is always on a shelf
  /// -- so the null lives only as far as this getter and the placeholder that
  /// reads it back.
  Category get _category => _chosen ?? widget.categories.fallback;

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
    _noteFocus.addListener(() => setState(() {}));
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
    _chosen = initial.category;
    _iconName = initial.iconName;
    _cycle = initial.cycle;
    _repeatCount = initial.repeatCount;
    _count.text = initial.repeatCount == null ? '' : '${initial.repeatCount}';
    final cycle = initial.cycle;
    // An item that is neither monthly nor yearly opens with the row showing,
    // for the same reason it stays showing after a pick: the third segment is
    // the only thing naming the cycle, and a reader has to be able to see
    // what else was on offer.
    _cycleOther =
        cycle != null && cycle != Cycle.monthly && cycle != Cycle.yearly;
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
    _inTrial = initial.inTrial;
    _note.text = initial.note ?? '';

    // The name is already what the user meant. Offering to replace it with a
    // catalog row the moment the screen opens is an offer to undo their edit.
    _nameSettled = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    _count.dispose();
    _every.dispose();
    _nameFocus.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    _countFocus.dispose();
    _everyFocus.dispose();
    super.dispose();
  }

  List<CatalogEntry> get _suggestions =>
      _nameSettled ? const [] : widget.catalog.search(_name.text);

  /// The item's due date, trial or not.
  ///
  /// One field asks for it, because a trial's free period ending *is* the
  /// charge landing. Two fields would let the reminder fire against one date
  /// and the row display the other.
  LocalDate? get _dueDate => _expiresOn;

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
    return typed.isEmpty ? S.t.untitledItem : typed;
  }

  bool get _canSave => _dueDate != null && !_saved;

  /// The note as it will be stored, or null when the box says nothing.
  ///
  /// A box holding spaces is a box the user cleared, so it comes back as null
  /// rather than as whitespace -- otherwise the detail screen would print a
  /// blank line where it prints nothing today.
  String? get _savedNote {
    final typed = _note.text.trim();
    return typed.isEmpty ? null : typed;
  }

  /// Latched by the first tap on Save, never unlatched.
  ///
  /// [_save] hands the draft to a caller that writes to SQLite before it pops
  /// this route, so the form and its enabled button stay on screen for the
  /// length of that write. A second tap inside that window writes a second row
  /// with a second id -- two identical items, and the caller pops twice, which
  /// takes the notification sheet the first save had just opened down with it.
  /// Nothing unlatches it because there is no path back to this form: every
  /// caller either pops it or replaces it.
  bool _saved = false;

  /// True while the cycle is an interval the app has no name for.
  bool get _isCustomCycle => _cycle != null && !_cycle!.isPreset;

  /// The cost field as money, or null while it is empty or unparseable.
  Money? get _parsedAmount {
    final minor = MoneyFormat.parseMajor(_amount.text, _currency);
    return minor == null ? null : Money(minor, _currency);
  }

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    // Step one, for a new item only.
    if (_picking) {
      return ServicePicker(
        catalog: widget.catalog,
        categories: widget.categories,
        onPick: _pickFromCatalog,
        onManual: (typed) => setState(() {
          _picking = false;
          // What they typed into the search box is the name they want. The
          // catalogue not carrying it says nothing about the name, so the form
          // opens with it already written rather than asking for it twice.
          if (typed.isNotEmpty) {
            _name.text = typed;
            // Setting `text` leaves the caret at offset -1, which reads as no
            // caret at all in a field that autofocuses. Park it after the last
            // letter, where someone about to fix a typo would put it.
            _name.selection = TextSelection.collapsed(offset: typed.length);
          }
          // Not a suggestion to second-guess: they came out of a full-screen
          // browser of the same catalogue the suggester reads from.
          _nameSettled = true;
        }),
        onCancel: widget.onCancel,
      );
    }

    final showSuggestions = _suggestions.isNotEmpty && _nameFocus.hasFocus;
    final plans = _planOptions;

    // A tap on the empty space beside a field is how a keyboard gets closed
    // everywhere else, and on iOS and Android a TextField does nothing with
    // it by default. This form cannot afford that: the cost box and the two
    // count boxes open a number pad, which has no Done key, so a keyboard
    // raised there stays up over the Save button until the form is left.
    // Children with taps of their own still win the gesture arena, so this
    // only picks up the taps nothing else wanted.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            // No horizontal padding here: the chip rails have to reach the edge
            // of the screen, so every other block asks for the gutter itself.
            child: ListView(
              // The other half of the same promise: a drag over the list puts
              // the keyboard away before it has covered whatever is being
              // scrolled to.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
              children: [
                _gutter(_header()),
                const SizedBox(height: 18),
                _gutter(Field(label: S.t.fieldName, child: _nameField())),
                if (showSuggestions) ...[
                  const SizedBox(height: 12),
                  _gutter(_suggestionList()),
                ],
                // A block of its own, with its own gap above it. It used to be
                // pulled up tight under the name field on the grounds that what
                // a thing is called and what kind of thing it is are one answer
                // given twice -- but a form whose gaps vary from block to block
                // reads as groupings that were never meant, so this one takes
                // the same 22 as every other.
                const SizedBox(height: SubdockSpacing.formBlock),
                _gutter(
                  Field(
                    // One row, never a rail. Twenty-two shelves scrolling
                    // sideways is a browsing control on a form whose other
                    // eleven blocks all answer in place, and the one thing it
                    // did better -- showing what the choices are -- is what the
                    // sheet behind this row does with the whole screen.
                    label: S.t.fieldCategory,
                    child: PickerField(
                      value: _chosen?.displayLabel ?? S.t.fieldPickCategory,
                      placeholder: _chosen == null,
                      onTap: _pickCategory,
                    ),
                  ),
                ),
                // The provider's own page, where the two answers this form is
                // waiting for actually live. Someone adding a service they have
                // never looked up does not know the renewal date or the amount,
                // and this is the one place in the app that can send them to
                // where both are written down.
                if (_manageUrl case final url?) ...[
                  const SizedBox(height: 14),
                  _gutter(_manageLink(url)),
                ],
                // The plans of the chosen service. Above the cost field, and
                // above the cycle: picking a tile fills both of them, so a user
                // who recognises their plan never reads the two blocks below.
                if (plans.isNotEmpty) ...[
                  const SizedBox(height: SubdockSpacing.formBlock),
                  _gutter(
                    Field(
                      label: S.t.fieldPlan,
                      child: PlanGrid(
                        options: plans,
                        selected: _planTier,
                        onSelect: _pickPlan,
                        // The way past the grid, as the last tile in it. The
                        // provenance line that used to sit under here -- "listed
                        // prices, checked 30 Jul 2026" -- is gone with it: the
                        // tiles are a shortcut to a number the user can
                        // overwrite in the field below, and a caveat about
                        // staleness under every one of them charged the reader
                        // for a doubt they can settle by looking at their own
                        // statement.
                        onOther: _costOpen
                            ? null
                            : () => setState(() => _costOpen = true),
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
                    label: _isEdit ? S.t.fieldRepeats : S.t.fieldBillingCycle,
                    child: _cycleField(),
                  ),
                ),
                // The cycles nobody bills on often enough to earn a segment.
                // A sub-block of the tray above rather than a block of its own:
                // it is the second half of one answer.
                if (_cycleOther) ...[
                  const SizedBox(height: 9),
                  _gutter(_otherCycles()),
                ],
                // The interval nothing on the list covers, typed out.
                if (_isCustomCycle) ...[
                  const SizedBox(height: 9),
                  _gutter(_everyRow()),
                ],
                // Asked once, trial or not. For a trial this date is the day
                // the free period ends, which is the same day the first charge
                // lands -- see the trial card's own note.
                const SizedBox(height: SubdockSpacing.formBlock),
                Field(
                  // No heading, on either form. The card says `Next payment
                  // date` while it is still a prompt and shows the date itself
                  // once it has one, so an uppercase `NEXT PAYMENT` above it is
                  // the screen saying the same thing twice in two type sizes.
                  label: null,
                  bleed: true,
                  child: _dateField(),
                ),
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
                    label: _isEdit ? S.t.fieldFreeTrial : null,
                    child: TrialField(
                      value: _inTrial,
                      onChanged: (on) => setState(() => _inTrial = on),
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
                  Field(
                    label: S.t.fieldRemindMe,
                    bleed: true,
                    child: _leadRail(),
                  ),
                ],
                // Last, and on both forms. Everything above it is a fact the
                // app acts on -- a date it reminds against, an amount it totals,
                // a shelf it files under -- and this is the one box that asks
                // for what only the user knows. Asking it before the form has
                // finished asking its own questions would read as a required
                // field.
                const SizedBox(height: SubdockSpacing.formBlock),
                _gutter(Field(label: S.t.fieldNote, child: _noteField())),
                const SizedBox(height: SubdockSpacing.formBlock),
                _gutter(
                  SummaryBlock(
                    due: _dueDate,
                    amount: _parsedAmount,
                    trial: _inTrial,
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
              _isEdit ? S.t.saveChanges : S.t.saveItem,
              onPressed: _canSave ? _save : null,
            ),
          ),
        ],
      ),
    );
  }

  /// The chosen service's tiers, at every cycle the vendor sells them on.
  ///
  /// Empty for a manually entered item, and empty for a service the catalogue
  /// has no priced plans for — which is two thirds of it. An empty grid is not
  /// a failure state, it is the normal one, so the block simply does not appear.
  ///
  /// Not filtered by [_cycle] any more. The grid used to show only the tiles
  /// matching whatever the tray happened to be set to, which hid a vendor's
  /// yearly prices behind a control the user had not touched — and the yearly
  /// figure is the one most worth seeing before committing. Every tile now
  /// carries its own `/m` or `/y`, and tapping one sets the tray.
  List<PlanOption> get _planOptions {
    final entry = _matched;
    if (entry == null) return const [];
    return PlanGrid.optionsFor(entry);
  }

  /// The last amount the app wrote into the cost field, as opposed to typed.
  ///
  /// Null once the user has touched it. See the listener in [initState].
  String? _written;

  void _pickPlan(PlanOption plan) {
    setState(() {
      _planTier = plan.id;
      _currency = plan.price.currency;
      // The tile says `/m` or `/y`, so the tray under it has to agree.
      // Filling the amount and leaving the cycle alone is how a yearly price
      // would end up saved as a monthly charge -- twelve times the money, with
      // nothing on screen contradicting it.
      _cycle = plan.cycle;
      _cycleOther = false;
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
      // already lit and its price already in the cost field. The shortest
      // cycle of that tier, because the grid is sorted that way and a vendor
      // who prices one plan monthly and yearly bills it monthly by default.
      final plans = PlanGrid.optionsFor(entry);
      final pick = plans.where((p) => p.tier == entry.defaultPlan).firstOrNull;
      _planTier = pick?.id;
      if (pick != null) {
        _currency = pick.price.currency;
        // The tier decides the cycle, not the entry's default: a service whose
        // default plan is a yearly one is billed yearly.
        _cycle = pick.cycle;
        _fillAmount(pick.price.minor);
      }
    });
  }

  Widget _gutter(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SubdockSpacing.screenH),
    child: child,
  );

  /// The two ways out on one line, and the item's own name under them.
  ///
  /// `Back` and `Cancel` are both escapes and they belong in the same band at
  /// the top of the screen, pushed to opposite ends: one goes back a step, the
  /// other abandons the whole thing, and stacking them made the second look
  /// like a heading action on the first.
  ///
  /// The title is the name being typed, live. It contradicts what this comment
  /// used to say -- that a heading rewriting itself stops answering "which
  /// item is this" -- and the design is right: on the add form the heading has
  /// no other job, and watching it become `Netflix` as you type is the clearest
  /// signal in the app that the name took. An edit keeps `Edit item` and names
  /// the item on the mono line under it, because there the heading does have
  /// another job: saying that this screen changes something that already
  /// exists.
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Back to step one, and only when there is a step one to go back
            // to. An edit has no picker behind it, and a back link that
            // dropped the user into a service browser would look like the
            // app had lost the item they were editing.
            if (!_isEdit)
              InkWell(
                onTap: () => setState(() => _picking = true),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '\u2039 ${S.t.back}',
                    style: SubdockText.quietAction,
                  ),
                ),
              ),
            const Spacer(),
            if (widget.onScan != null) ...[
              InkWell(
                onTap: widget.onScan,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(S.t.scan, style: SubdockText.quietAction),
                ),
              ),
              const SizedBox(width: 16),
            ],
            InkWell(
              onTap: widget.onCancel ?? () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(S.t.cancel, style: SubdockText.quietAction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _isEdit ? S.t.editItem : _title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: SubdockText.editorTitle,
        ),
        // Only the editor carries a mono line under the title, and it
        // names the item, because `Edit item` alone does not say which
        // of forty was opened.
        if (_isEdit) ...[
          const SizedBox(height: 6),
          Text(S.t.editingName(_editingName), style: SubdockText.monoInline),
        ],
      ],
    );
  }

  /// What the add form calls itself: the name being typed, the service that
  /// was picked, or nothing yet.
  String get _title {
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    return _matched?.name ?? S.t.newItem;
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
            labels: [S.t.afterANumberOfPayments, S.t.onADate],
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
              label: S.t.fieldLastPaymentOn,
              child: PickerField(
                value: _endsOn == null
                    ? S.t.fieldChooseADate
                    : DateCopy.longDate(_endsOn!),
                placeholder: _endsOn == null,
                hint: _endsOn == null ? S.t.fieldTapToOpenCalendar : null,
                onTap: _pickRepeatUntil,
              ),
            )
          else ...[
            Row(
              children: [
                // Both words give way before the field between them does: the
                // number is the part being read, and at a large text size a
                // rigid row would push it off the card instead.
                Flexible(
                  child: Text(
                    S.t.stopsAfter,
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
                Flexible(
                  child: Text(
                    S.t.paymentsUnit,
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
                    label: S.t.paymentsCount(n),
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
      label: _amount.text.isEmpty ? S.t.fieldCostOptional : S.t.fieldCost,
      child: CostField(
        controller: _amount,
        focusNode: _amountFocus,
        currency: _currency,
        onCurrency: _setCurrency,
        convertedLine: _convertedLine,
      ),
    ),
  );

  /// The free-text box at the foot of the form.
  ///
  /// Two lines to start and up to six, rather than one line that scrolls: a
  /// note is written in sentences, and a one-line box hides everything but the
  /// last few words of what the user just typed. Past six it scrolls inside
  /// itself, so a long note cannot push the Save button off a small screen.
  ///
  /// No clear button, unlike the name field. That one opens pre-filled from a
  /// catalogue row and clearing it is the common move; this one only ever
  /// holds what the user wrote themselves.
  Widget _noteField() {
    return FieldBox(
      focused: _noteFocus.hasFocus,
      child: TextField(
        controller: _note,
        focusNode: _noteFocus,
        minLines: 2,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        style: SubdockText.fieldValue,
        cursorColor: SubdockColors.accent,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: S.t.fieldNoteHint,
          hintStyle: SubdockText.fieldValue.copyWith(
            color: SubdockColors.inkMuted,
          ),
        ),
      ),
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
              // The keyboard comes up only when this field is the question.
              //
              // An empty name is one: there is nothing else to do on the form
              // until it is answered. A name that arrived filled in is not,
              // whether it came from a catalogue row, from the search box on
              // step one, or from the item being edited. The keyboard covers
              // half the screen, and what is under it -- the date, the cost,
              // the cycle -- is what the user actually came to fill in, while
              // the name it opened over is already right.
              autofocus: _name.text.isEmpty,
              // A name, so the keyboard opens shifted. `sentences` rather than
              // `words`: a Vietnamese name is a sentence, and `Bao Hiem Xe May`
              // is not how anyone writes one.
              textCapitalization: TextCapitalization.sentences,
              style: SubdockText.fieldValue,
              cursorColor: SubdockColors.accent,
              onChanged: (_) => _nameSettled = false,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: S.t.fieldNameHint,
                hintStyle: SubdockText.fieldValue.copyWith(
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
          ),
          // Same clear button the search boxes carry, for the same reason: the
          // field opens pre-filled -- from a catalogue row, from the search box
          // on step one, or from the item being edited -- and someone who wants
          // a different name would otherwise hold backspace down.
          //
          // It reopens the suggestions the way typing does. Clearing by hand is
          // not the user settling on a name, it is them starting over, and a
          // settled flag left standing would keep the catalogue quiet through
          // whatever they type next.
          if (_name.text.isNotEmpty)
            InkResponse(
              onTap: () {
                _name.clear();
                _nameSettled = false;
                _nameFocus.requestFocus();
              },
              radius: 20,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: SubdockColors.inkMuted,
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
          name: S.t.useCustomName(_name.text.trim()),
          muted: true,
          onTap: _keepTyped,
        ),
      ],
    );
  }

  /// The catalogue row this form is about, for the things that only read from
  /// it.
  ///
  /// Falls back to the name on an edit, which never goes through the picker
  /// and so never sets [_matched]. Kept separate from [_matched] on purpose:
  /// that one is written into the draft and decides what gets *saved*, and a
  /// name that happens to match must not start putting a vendor's cancel URL
  /// on an item the user typed by hand. This one only decides what is drawn.
  CatalogEntry? get _entry =>
      _matched ?? (_isEdit ? widget.catalog.matchByName(_name.text) : null);

  /// The provider's own billing page, when the catalogue has one.
  ///
  /// Only 25 of 223 catalogue rows carry a cancel URL and not many more carry
  /// this one, so the row is absent far more often than it is present. That is
  /// the honest state rather than a gap: a link to a page the app guessed at
  /// is worse than no link, which is the same reason the Cancel tab says
  /// outright when it does not know.
  String? get _manageUrl {
    final url = _entry?.manageUrl;
    return url == null || url.isEmpty ? null : url;
  }

  Future<void> _pickCategory() async {
    // A sheet behind the keyboard opens half covered.
    FocusScope.of(context).unfocus();
    final picked = await chooseOption<String>(
      context,
      title: S.t.fieldCategory,
      options: [
        for (final category in widget.categories.all)
          (category.id, category.displayLabel),
      ],
      selected: _category.id,
    );
    if (picked != null && mounted) {
      setState(() => _chosen = widget.categories[picked]);
    }
  }

  /// A quiet link rather than a button.
  ///
  /// The only filled button on this screen is Save, and a second one here
  /// would compete with it for the tap that ends the task. This is a way out
  /// to go and check something, which is what the `Enter it` link under the
  /// plan grid is too.
  Widget _manageLink(String url) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: widget.onOpenLink == null
            ? null
            : () {
                // The browser opens over whatever has focus, and a keyboard
                // left up is a keyboard still there on the way back.
                FocusScope.of(context).unfocus();
                widget.onOpenLink!(url);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 15,
                color: SubdockColors.accent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  // Not `Open Netflix account`, the way the detail screen
                  // words it. There the item exists and the sentence is about
                  // that item; here it is a way out to go and read a number
                  // off a page, and the vendor's name is already the heading
                  // of this screen.
                  S.t.fieldOpenSubscriptionPage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.quietAction,
                ),
              ),
            ],
          ),
        ),
      ),
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
            // `Next payment date`, not `Choose a date`: the label above this
            // card is gone, so the prompt is now the only thing naming what
            // the date is for.
            value: expiresOn == null
                ? S.t.fieldNextPaymentDate
                : DateCopy.longDate(expiresOn),
            placeholder: expiresOn == null,
            // Two lines either way, so the card never changes height under
            // the thumb. Empty, the second line says what tapping does; full,
            // it says how far off the date is -- which is the half of the
            // answer a calendar date does not give at a glance, and the half
            // that catches a month picked wrong.
            hint: expiresOn == null
                ? S.t.fieldTapToOpenCalendar
                : DateCopy.relative(widget.today, expiresOn),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 10),
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
                    Expanded(
                      child: Text(
                        S.t.repeatsForever,
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
    final units = [
      (CycleField.day, S.t.unitDays),
      (CycleField.week, S.t.unitWeeks),
      (CycleField.month, S.t.unitMonths),
      (CycleField.year, S.t.unitYears),
    ];

    return Container(
      decoration: SubdockSurface.card(),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  S.t.every,
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

  /// The two cycles nearly every subscription uses, and a way to the rest.
  ///
  /// Monthly and yearly cover almost everything a person pays for, and both of
  /// them used to cost a sheet: open it, read seven options, tap one, watch it
  /// close. A tray answers the common case in one tap and keeps the rest
  /// behind the third segment.
  ///
  /// The third segment says what was chosen rather than `Other` whenever
  /// something was. A tray reading `Other` on a quarterly plan hides the
  /// answer on the one control whose whole job is to show it, and the reader
  /// would have to reopen the list to find out what their own item does.
  Widget _cycleField() {
    final cycle = _cycle;
    final monthly = cycle == Cycle.monthly;
    final yearly = cycle == Cycle.yearly;

    return SegmentedRow(
      labels: [
        S.t.cycleMonthly,
        S.t.cycleYearly,
        monthly || yearly ? S.t.cycleOther : _cycleLabel(cycle),
      ],
      // Weighted, because `Every 2 months` beside `Yearly` in equal thirds
      // truncates the one segment carrying information the other two do not.
      weighted: true,
      selected: monthly
          ? 0
          : yearly
          ? 1
          : 2,
      onSelect: (index) {
        if (index == 2) {
          // A row on the form rather than a modal. The sheet it replaced put
          // seven options over the whole screen, hid the tray that had just
          // been tapped, and cost a second tap to dismiss -- for a question
          // whose answers are four short words.
          setState(() => _cycleOther = true);
          return;
        }
        setState(() {
          _cycle = index == 0 ? Cycle.monthly : Cycle.yearly;
          _cycleOther = false;
        });
      },
    );
  }

  /// The cycles behind the third segment, and the line that says the row is
  /// still live once one of them is showing on it.
  ///
  /// `Custom…` does not open a modal either. It sets an interval and reveals
  /// the `Every n …` row underneath, which is where the number is then edited
  /// in place — a real contract renews on a schedule somebody else chose, and
  /// "my plan runs 5 months" must not turn into "make it a one-off and re-date
  /// it by hand five times a year".
  Widget _otherCycles() {
    final cycle = _cycle;
    final custom = _isCustomCycle;
    final named =
        cycle != null && cycle != Cycle.monthly && cycle != Cycle.yearly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in Cycle.values)
              if (preset != Cycle.monthly && preset != Cycle.yearly)
                ChoiceChipPill(
                  ItemPresenter.cycleLabel(preset),
                  selected: cycle == preset,
                  onTap: () => setState(() => _cycle = preset),
                ),
            ChoiceChipPill(
              S.t.cycleOneOff,
              selected: cycle == null,
              onTap: () => setState(() {
                _cycle = null;
                // Nothing to end when there is only one payment, and the
                // block that asks about it is about to disappear.
                _repeatCount = null;
              }),
            ),
            ChoiceChipPill(
              S.t.cycleEveryEllipsis,
              selected: custom,
              // Two months, not one: one month is already a segment above, so
              // a user who came this far means something else. An interval
              // already custom is left alone -- tapping the chip that is
              // already lit must not reset the number underneath it.
              onTap: () => custom ? null : _setCustomCycle(2, CycleField.month),
            ),
          ],
        ),
        if (named) ...[
          const SizedBox(height: 8),
          Text(
            S.t.currentlyCycle(_cycleLabel(cycle).toLowerCase()),
            style: SubdockText.caption.copyWith(fontSize: 13.5),
          ),
        ],
      ],
    );
  }

  /// [ItemPresenter.cycleLabel] with one word changed: `One-off` rather than
  /// `Once`, because this field is a list of billing cycles and `Once` beside
  /// `Monthly` reads like a frequency where `One-off` reads like a kind of
  /// payment. Everything else, custom intervals included, is the presenter's
  /// wording — the field is full width, so `Every 2 months` fits.
  static String _cycleLabel(Cycle? cycle) =>
      cycle == null ? S.t.cycleOneOff : ItemPresenter.cycleLabel(cycle);

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
    // Only the one pair the app carries a rate for. An amount typed in a third
    // currency simply gets no second line, which is the honest outcome: this
    // app never invents a rate to fill a gap.
    final converted = switch (_currency.toUpperCase()) {
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
              ? S.t.customEllipsis
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
      _chosen = widget.categories[entry.categoryId];
      _cycle = entry.defaultCycle;
      // A catalogue row prices its plans on its own cycle, and the grid now
      // shows every cycle at once, so the tray closes: the answer is on the
      // segment, or one tap away on a tile.
      _cycleOther = false;
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
      // Nearly full height, and the gallery fills whatever it is given. A
      // half-height sheet showed four rows of a hundred and fifty marks, so
      // the search box below was reached by scrolling past the answer.
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * IconGallery.maxHeightFraction,
      ),
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
      title: S.t.fieldRemindMe,
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
    if (_saved) return;
    setState(() => _saved = true);

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
        inTrial: _inTrial,
        paymentSourceId: _sourceId,
        note: _savedNote,
      ),
    );
  }
}
