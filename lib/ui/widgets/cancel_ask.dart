import 'package:flutter/material.dart';

import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/ask_line.dart';
import 'package:subdock/ui/widgets/delete_ask.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// The last thing between an item and the button that stops its reminders.
///
/// The button used to write straight to the database and pop, and the word on
/// it was the only account the user ever got of what it did. That word is not
/// enough for what actually happens: the reminders stop, which for this app is
/// the whole of the product, and the item goes on being charged until a date
/// nothing on that screen was naming. Someone reading `Cancel this
/// subscription` has no way to tell whether the app is about to forget the
/// item, stop nagging them about it, or claim to have cancelled it with the
/// vendor -- and it does not do the last of those at all.
///
/// So the sheet says the three things a person is deciding between, and two of
/// them appear nowhere else in the app: how many reminders are waiting, and
/// what date the item stays usable until. See [DeleteAsk], whose two counts
/// exist for that same reason.
///
/// Same shape as the delete and restore sheets: the filled button is the one
/// that does *nothing*, and the one that acts is quiet ink. A destructive
/// action that is also the prettiest thing on screen gets tapped by people who
/// were not reading.
class CancelAsk extends StatelessWidget {
  /// What the user called it. Named rather than "this subscription", because
  /// the savings screen can open a sheet over a list and the name is the only
  /// way to tell that the right row was tapped.
  final String name;

  /// Where the item is in a counted plan, or null for an open-ended one.
  ///
  /// The two are different actions wearing one button, and the sheet has to
  /// follow. An open-ended plan is cancelled: reminders stop and the item
  /// closes when the period runs out. A counted plan is only shortened to the
  /// payment the user is on -- reminders go on running, and nothing is lost
  /// that editing the count would not put back. So the second one is not
  /// dressed in danger ink; red where nothing is at risk teaches people to
  /// read past red.
  final Instalments? position;

  /// The date the item is paid up to. Null when it has none to name.
  final LocalDate? usableUntil;

  /// Whether [usableUntil] has already gone by. The item then closes on the
  /// next sweep rather than on some future day, and saying "usable until
  /// 20/08" on the 28th would be describing a window that shut last week.
  final bool alreadyLapsed;

  /// Reminders already handed to the operating system for this item. Every one
  /// of them is dropped, and this sheet is the only place the number is shown.
  final int reminderCount;

  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const CancelAsk({
    super.key,
    required this.name,
    this.position,
    this.usableUntil,
    this.alreadyLapsed = false,
    this.reminderCount = 0,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String name,
    Instalments? position,
    LocalDate? usableUntil,
    bool alreadyLapsed = false,
    int reminderCount = 0,
  }) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0x00000000),
    isScrollControlled: true,
    builder: (sheet) => CancelAsk(
      name: name,
      position: position,
      usableUntil: usableUntil,
      alreadyLapsed: alreadyLapsed,
      reminderCount: reminderCount,
      onConfirm: () => Navigator.of(sheet).pop(true),
      onCancel: () => Navigator.of(sheet).pop(false),
    ),
  );

  /// What the middle line says about the window this cancellation opens.
  ///
  /// Three answers, and the app is only allowed the first one when it has a
  /// date to stand behind. An item with no date to name gets no line at all
  /// rather than a reassuring sentence with nothing under it.
  ///
  /// The full date, year and all, unlike the day-and-month the list rows use.
  /// A yearly plan cancelled today runs to a date eleven months out, and
  /// `05/09` on a sheet read in September is a date that has just gone by.
  static String? usableLine(LocalDate? until, {required bool alreadyLapsed}) {
    if (until == null) return null;
    if (alreadyLapsed) return S.t.cancelAskClosesNow;
    return S.t.cancelAskUsableUntil(MoneyFormat.date(until));
  }

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);

    final shortening = position != null;
    final usable = usableLine(usableUntil, alreadyLapsed: alreadyLapsed);

    return BlurLayer(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SubdockRadius.sheet),
      ),
      child: Container(
        decoration: SubdockSurface.sheet(),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SubdockColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                shortening
                    ? S.t.cancelAskStopTitle(position!.index)
                    : S.t.cancelAskTitle(name),
                style: SubdockText.detailTitle.copyWith(fontSize: 25),
              ),
              const SizedBox(height: 16),

              // Reminders first in both variants, because it is the line that
              // differs most between them and the one the user is really
              // deciding about. Shortening a plan does not touch them.
              if (shortening)
                AskLine(
                  icon: Icons.notifications_active_rounded,
                  label: S.t.rowReminders,
                  value: S.t.cancelAskRemindersKept,
                )
              else
                AskLine(
                  icon: Icons.notifications_off_rounded,
                  label: S.t.deleteAskRemindersStopped,
                  value: DeleteAsk.reminderLine(reminderCount),
                  danger: reminderCount > 0,
                ),
              const SizedBox(height: 8),

              if (shortening) ...[
                AskLine(
                  icon: Icons.playlist_add_check_rounded,
                  label: S.t.cancelAskPlanLabel,
                  value: S.t.cancelAskPlanPayments(
                    position!.index,
                    position!.total,
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (usable != null) ...[
                AskLine(
                  icon: Icons.event_available_rounded,
                  // The label has to follow the value here. `Usable until` over
                  // `That date has gone` is a row arguing with itself, and the
                  // reader has to work out which half to believe.
                  label: alreadyLapsed
                      ? S.t.cancelAskLapsedLabel
                      : S.t.cancelAskUsableLabel,
                  value: usable,
                ),
                const SizedBox(height: 8),
              ],

              // Last, and never omitted. The sheet above it is a list of
              // things that stop, and a reader who has just read two of those
              // is entitled to know what the delete button beside it would
              // have taken and this one does not.
              AskLine(
                icon: Icons.receipt_long_rounded,
                label: S.t.cancelAskKeptLabel,
                value: S.t.cancelAskKeptValue,
              ),
              const SizedBox(height: 18),
              PrimaryButton(S.t.deleteAskKeep, onPressed: onCancel),
              const SizedBox(height: 6),
              QuietButton(
                shortening ? S.t.cancelAskStopConfirm : S.t.cancelAskConfirm,
                onPressed: onConfirm,
                danger: !shortening,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
