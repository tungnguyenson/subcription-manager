import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// The sheet that asks for notification permission, the moment after the user
/// has saved their first item.
///
/// **The timing is the whole feature.** A permission prompt at launch is a
/// question about plumbing asked before the user has any reason to care, and it
/// is the one prompt they only get once — iOS never asks again after a decline,
/// so a "no" at launch costs the app its entire purpose. Asked here, the user
/// has just typed a date they are afraid of forgetting, and the prompt can name
/// it: *"Notification on 19/08, three days before (22/08), 260,000 ₫ from VCB
/// 4412."* That is not a permission request, it is a summary of what they just
/// asked for.
///
/// Declining is a real answer and is remembered. The caller must not re-ask on
/// the next save; two adds later is the earliest it should come back, which is
/// the rule [NotificationAsk] itself cannot enforce and its caller must.
class NotificationAsk extends StatelessWidget {
  /// The item that was just saved, so the sheet is about something specific.
  final String itemName;
  final String? iconName;

  /// `Remind you before Netflix charges?`
  final String title;

  /// The reminder in full, with real dates in it. This is the sentence that
  /// earns the tap.
  final String line;

  final VoidCallback? onAllow;
  final VoidCallback? onLater;

  const NotificationAsk({
    super.key,
    required this.itemName,
    required this.title,
    required this.line,
    this.iconName,
    this.onAllow,
    this.onLater,
  });

  /// Shows it over whatever is on screen. Resolves to true if the user asked
  /// for reminders, false or null otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String itemName,
    String? iconName,
    required String title,
    required String line,
  }) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0x00000000),
    // Dismissible by tapping away, which is a "not now" rather than a
    // refusal — the same as the button, and it must not be harder to decline
    // than to accept.
    isScrollControlled: true,
    builder: (sheet) => NotificationAsk(
      itemName: itemName,
      iconName: iconName,
      title: title,
      line: line,
      onAllow: () => Navigator.of(sheet).pop(true),
      onLater: () => Navigator.of(sheet).pop(false),
    ),
  );

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
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
              // What was just saved, confirmed before anything is asked for.
              // The sheet arrives on top of a list the user has not had a
              // chance to look at yet, so it has to say the save worked.
              Row(
                children: [
                  ServiceTile(itemName, iconName: iconName, size: 44),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SubdockText.itemName,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          S.t.addedToSubdock,
                          style: SubdockText.itemSubtitle,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 22,
                    color: SubdockColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: SubdockText.detailTitle.copyWith(fontSize: 25),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: SubdockColors.hairline,
                  borderRadius: BorderRadius.circular(SubdockRadius.card),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 19,
                      color: SubdockColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: SubdockText.footnote.copyWith(fontSize: 14.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(S.t.turnOnReminders, onPressed: onAllow),
              const SizedBox(height: 6),
              QuietButton(S.t.notNow, onPressed: onLater),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  // The scope of what is being asked for, on the sheet rather
                  // than in a privacy policy. This app sends exactly one kind
                  // of notification and nothing would ever make it send
                  // another, so saying so costs nothing and buys the tap.
                  S.t.onlyDueDateReminders,
                  style: SubdockText.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
