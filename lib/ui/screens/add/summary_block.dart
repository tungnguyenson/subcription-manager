import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';

/// What the app will actually do, in two sentences.
///
/// The last thing above the save button, and the only place the form states
/// its own consequences: the charge, then the reminder, both with real dates
/// in them. Every field above is an input; this is the output, and a user who
/// mis-set the lead by one chip finds it here rather than in three weeks.
class SummaryBlock extends StatelessWidget {
  /// The due date the form settled on: a trial's first charge, or the date
  /// field. Null while neither is set.
  final LocalDate? due;

  /// The amount as typed, already parsed, or null when the field is empty.
  final Money? amount;

  /// True when a free trial is on, which changes the charge sentence from
  /// "you will be charged" to "free until — then".
  final bool trial;

  final int leadDays;

  const SummaryBlock({
    super.key,
    required this.due,
    required this.amount,
    required this.trial,
    required this.leadDays,
  });

  @override
  Widget build(BuildContext context) {
    final money = amount == null
        ? 'an amount you have not set yet'
        : MoneyFormat.full(amount!);

    final charge = due == null
        ? 'Set the next payment date and this is where the charge shows up.'
        : (trial
              ? 'Free until ${DateCopy.longDate(due!)} — then $money is charged.'
              : 'You will be charged $money on ${DateCopy.longDate(due!)}.');

    final remind = due == null
        ? null
        : (leadDays == 0
              ? 'Reminder on the day, ${DateCopy.longDate(due!)}.'
              : 'Reminder ${ItemPresenter.leadLabel(leadDays).toLowerCase()}, on '
                    '${DateCopy.longDate(due!.minusDays(leadDays))}.');

    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.accentFaint,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            charge,
            style: SubdockText.footnote.copyWith(
              fontSize: 15.5,
              color: SubdockColors.ink,
            ),
          ),
          if (remind != null) ...[
            const SizedBox(height: 7),
            Text(remind, style: SubdockText.footnote.copyWith(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
