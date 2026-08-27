import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/i18n.dart';

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
        ? S.t.summaryAmountNotSet
        : MoneyFormat.full(amount!);

    final charge = due == null
        ? S.t.summaryNoDate
        : (trial
              ? S.t.summaryTrial(DateCopy.longDate(due!), money)
              : S.t.summaryCharge(money, DateCopy.longDate(due!)));

    final remind = due == null
        ? null
        : (leadDays == 0
              ? S.t.summaryReminderOnTheDay(DateCopy.longDate(due!))
              : S.t.summaryReminderBefore(
                  ItemPresenter.leadLabel(leadDays).toLowerCase(),
                  DateCopy.longDate(due!.minusDays(leadDays)),
                ));

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
