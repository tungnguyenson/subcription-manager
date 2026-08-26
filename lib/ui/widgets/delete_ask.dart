import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The last thing between an item and the row that stops existing.
///
/// Deleting is not archiving. `handledEventRow` carries `ON DELETE CASCADE`, so
/// the payments the user recorded by hand go with the item, and this app has no
/// account, no server and no second copy to get them back from. That makes the
/// two counts on this sheet the whole point of it: the pending reminders the
/// user cannot see anywhere, and the payments they can.
///
/// Same shape as the restore sheet, for the same reason: the safe answer is the
/// filled button and the destructive one is quiet ink. A destructive action
/// that is also the prettiest thing on screen gets tapped by people who were
/// not reading.
class DeleteAsk extends StatelessWidget {
  /// What the user called it. Named, never summarised as "this item" — the
  /// savings screen can open this sheet over a list, and the name is the only
  /// way to tell that the right row was tapped.
  final String name;

  /// Reminders already handed to the operating system for this item.
  final int reminderCount;

  /// Payments the user recorded by hand. These are deleted with the item.
  final int paymentCount;

  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const DeleteAsk({
    super.key,
    required this.name,
    this.reminderCount = 0,
    this.paymentCount = 0,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String name,
    int reminderCount = 0,
    int paymentCount = 0,
  }) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0x00000000),
    isScrollControlled: true,
    builder: (sheet) => DeleteAsk(
      name: name,
      reminderCount: reminderCount,
      paymentCount: paymentCount,
      onConfirm: () => Navigator.of(sheet).pop(true),
      onCancel: () => Navigator.of(sheet).pop(false),
    ),
  );

  /// `12 recorded payments`, or the sentence that says there are none.
  static String paymentLine(int count) => switch (count) {
    0 => 'Nothing recorded yet',
    1 => '1 recorded payment',
    _ => '$count recorded payments',
  };

  /// `4 pending`, or the sentence that says nothing is waiting.
  static String reminderLine(int count) => switch (count) {
    0 => 'None pending',
    1 => '1 pending reminder',
    _ => '$count pending reminders',
  };

  @override
  Widget build(BuildContext context) {
    return BlurLayer(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SubdockRadius.sheet),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: SubdockColors.solid,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SubdockRadius.sheet),
          ),
          boxShadow: SubdockShadow.sheet,
        ),
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
                'Delete $name?',
                style: SubdockText.detailTitle.copyWith(fontSize: 25),
              ),
              const SizedBox(height: 16),
              _Line(
                icon: Icons.receipt_long_rounded,
                label: 'Deleted with it',
                value: paymentLine(paymentCount),
                danger: paymentCount > 0,
              ),
              const SizedBox(height: 8),
              _Line(
                icon: Icons.notifications_off_rounded,
                label: 'Reminders stopped',
                value: reminderLine(reminderCount),
              ),
              const SizedBox(height: 18),
              PrimaryButton('Keep it', onPressed: onCancel),
              const SizedBox(height: 6),
              QuietButton('Delete', onPressed: onConfirm, danger: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? SubdockColors.danger : SubdockColors.accent;

    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.hairline,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SubdockText.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: SubdockText.footnote.copyWith(fontSize: 14.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
