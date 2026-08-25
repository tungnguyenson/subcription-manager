import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The three dates a free trial is made of, and how they constrain each other.
///
/// A trial has a start, a length and a first-charge date, and **any two of them
/// fix the third**. That is the whole difficulty of this control: a user who
/// knows "I started it last Tuesday and it is a 14-day trial" should not have to
/// work out the charge date in their head, and a user who knows "it charges on
/// the 23rd and it was a month" should not have to work out the start.
///
/// So a length can be *locked*. With a lock on, moving either date moves the
/// other; with it off, setting both dates computes the length and displays it.
/// Locked is not the default — a length the app assumed would quietly overwrite
/// a charge date the user had read off a receipt, which is the one date here
/// that might be true.
///
/// Held apart from the form so this arithmetic can be read in one place. Spread
/// through three `onChanged` handlers it becomes impossible to see whether the
/// lock is respected on every path.
@immutable
class TrialDraft {
  /// The day the free period began. Null means "not a trial".
  final LocalDate? start;

  /// The day the first charge lands, which is also the item's `expiresOn`.
  final LocalDate? firstCharge;

  /// A length the user pinned, in days. Null means the length simply follows
  /// from the two dates.
  final int? lockedDays;

  const TrialDraft({this.start, this.firstCharge, this.lockedDays});

  static const TrialDraft off = TrialDraft();

  bool get on => start != null || firstCharge != null;

  /// The length implied by the two dates, or null while only one is set.
  int? get spanDays => (start != null && firstCharge != null)
      ? start!.daysUntil(firstCharge!)
      : null;

  TrialDraft withStart(LocalDate date) => TrialDraft(
    start: date,
    firstCharge: lockedDays == null ? firstCharge : date.plusDays(lockedDays!),
    lockedDays: lockedDays,
  );

  TrialDraft withFirstCharge(LocalDate date) => TrialDraft(
    start: lockedDays == null ? start : date.minusDays(lockedDays!),
    firstCharge: date,
    lockedDays: lockedDays,
  );

  /// Pins a length, and moves whichever date it can to honour it.
  ///
  /// The start wins when both are set: it is the date the user is surest of
  /// (they remember signing up), and the charge date is the one they are
  /// guessing at — which is exactly why they reached for a preset length.
  TrialDraft withLength(int days) {
    if (start != null) {
      return TrialDraft(
        start: start,
        firstCharge: start!.plusDays(days),
        lockedDays: days,
      );
    }
    if (firstCharge != null) {
      return TrialDraft(
        start: firstCharge!.minusDays(days),
        firstCharge: firstCharge,
        lockedDays: days,
      );
    }
    return TrialDraft(lockedDays: days);
  }

  TrialDraft get unlocked => TrialDraft(start: start, firstCharge: firstCharge);

  /// The line under the control: what the app will actually do.
  ///
  /// Always a full sentence naming the charge date and the reminder, because
  /// the promise of the whole feature is "you will be warned while cancelling
  /// is still free" and that promise is only believable if the dates are shown.
  String summary(int leadDays) {
    final span = spanDays;
    if (start != null && firstCharge != null && span != null) {
      final remindOn = firstCharge!.minusDays(leadDays);
      return 'Free for $span ${span == 1 ? "day" : "days"} · charges '
          '${MoneyFormat.shortDate(firstCharge!)} · reminder '
          '${ItemPresenter.leadLabel(leadDays).toLowerCase()}, on '
          '${MoneyFormat.shortDate(remindOn)}';
    }
    if (start != null) {
      return 'Pick a length, or set the first charge date.';
    }
    if (firstCharge != null) {
      return 'Pick a length and the start date is worked out.';
    }
    return 'Set the day the trial started.';
  }
}

/// The trial control: a switch, and the dates behind it.
class TrialField extends StatelessWidget {
  final TrialDraft value;
  final LocalDate today;

  /// The lead the form is holding, so the summary can name the real reminder
  /// date rather than a generic one.
  final int leadDays;

  final ValueChanged<TrialDraft> onChanged;

  /// Opens the calendar, seeded with whatever the field already holds.
  final Future<LocalDate?> Function(LocalDate? from)? onPickDate;

  const TrialField({
    super.key,
    required this.value,
    required this.today,
    required this.leadDays,
    required this.onChanged,
    this.onPickDate,
  });

  /// The lengths nearly every trial uses. Anything else is expressed by setting
  /// both dates, which computes the length and shows it as a fourth chip.
  static const List<int> offeredLengths = [7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final span = value.spanDays;
    final extra =
        value.lockedDays == null &&
        span != null &&
        !offeredLengths.contains(span);

    return GroupedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      children: [
        InkWell(
          onTap: () => onChanged(value.on ? TrialDraft.off : _turnOn()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'In a free trial now',
                    style: SubdockText.rowLink,
                  ),
                ),
                AppToggle(
                  value: value.on,
                  onChanged: (on) => onChanged(on ? _turnOn() : TrialDraft.off),
                ),
              ],
            ),
          ),
        ),
        if (value.on) ...[
          const Divider(height: 1, thickness: 1, color: SubdockColors.hairline),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DateLine(
                  label: 'Trial started',
                  date: value.start,
                  // "Today" is offered on the start only. A trial that started
                  // today is the common case — the user has just signed up —
                  // and a trial that *charges* today is not something a
                  // shortcut should make easy to enter by accident.
                  shortcut: 'Today',
                  shortcutOn: value.start == today,
                  onShortcut: () => onChanged(value.withStart(today)),
                  onPick: () =>
                      _pick(value.start, (d) => onChanged(value.withStart(d))),
                ),
                const SizedBox(height: 9),
                Text(_lengthHint(), style: SubdockText.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final days in offeredLengths)
                      _LengthChip(
                        label: '$days days',
                        selected: value.lockedDays == days,
                        // Tapping the lit chip unlocks rather than re-applying:
                        // the lock is the surprising state, so the way out of
                        // it has to be the same tap that got in.
                        onTap: value.on
                            ? () => onChanged(
                                value.lockedDays == days
                                    ? value.unlocked
                                    : value.withLength(days),
                              )
                            : null,
                      ),
                    if (extra)
                      _LengthChip(
                        label: '$span days',
                        selected: true,
                        onTap: () => onChanged(value.withLength(span)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: SubdockColors.hairline,
                ),
                const SizedBox(height: 12),
                _DateLine(
                  label: 'First charge',
                  date: value.firstCharge,
                  accent: true,
                  onPick: () => _pick(
                    value.firstCharge,
                    (d) => onChanged(value.withFirstCharge(d)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(value.summary(leadDays), style: SubdockText.footnote),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Turning the switch on sets nothing.
  ///
  /// Not today's date, and not a 14-day guess. Every date this app shows has to
  /// be one somebody actually knows — the whole point of [DateSource] — and a
  /// trial the app dated itself would be indistinguishable from one the user
  /// read off a receipt.
  TrialDraft _turnOn() => const TrialDraft(lockedDays: null, start: null);

  String _lengthHint() {
    if (value.lockedDays != null) {
      return 'Trial length · locked · tap again to unlock';
    }
    return value.on
        ? 'Trial length · or set both dates and it is worked out'
        : 'Trial length · set a date first';
  }

  Future<void> _pick(LocalDate? from, ValueChanged<LocalDate> apply) async {
    final picked = await onPickDate?.call(from);
    if (picked != null) apply(picked);
  }
}

class _DateLine extends StatelessWidget {
  final String label;
  final LocalDate? date;
  final bool accent;
  final String? shortcut;
  final bool shortcutOn;
  final VoidCallback? onShortcut;
  final VoidCallback onPick;

  const _DateLine({
    required this.label,
    required this.date,
    required this.onPick,
    this.accent = false,
    this.shortcut,
    this.shortcutOn = false,
    this.onShortcut,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: SubdockText.rowLabel.copyWith(fontSize: 15.5)),
        const Spacer(),
        if (shortcut != null) ...[
          _LengthChip(
            label: shortcut!,
            selected: shortcutOn,
            onTap: onShortcut,
          ),
          const SizedBox(width: 8),
        ],
        InkWell(
          onTap: onPick,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Text(
              date == null ? 'Set' : DateCopy.listedDate(date!),
              style: SubdockText.monoValue.copyWith(
                color: date == null
                    ? SubdockColors.inkMuted
                    : (accent ? SubdockColors.accent : SubdockColors.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A flat tinted chip, not a card one.
///
/// The length presets sit *inside* a card, and a lifted chip on a card is the
/// one place the Glass surfaces stop working — a translucent white pill on
/// translucent white has nothing left to read. On a card the selection is a
/// tint instead.
class _LengthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _LengthChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SubdockColors.accentFaint : const Color(0x00000000),
      borderRadius: BorderRadius.circular(SubdockRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: SubdockText.family,
              fontSize: 13.5,
              height: 1,
              color: selected ? SubdockColors.accent : SubdockColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
