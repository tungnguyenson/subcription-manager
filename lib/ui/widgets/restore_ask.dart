import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/ask_line.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// The last thing between a backup file and the list it overwrites.
///
/// Restoring replaces everything, and there is nowhere to undo it from: this
/// app has no account, no server and no second copy, so the rows it is about to
/// delete stop existing. That makes this the one sheet in the app whose job is
/// to be read rather than dismissed, and it earns that by naming both sides —
/// what is in the file, and what is on the phone right now.
///
/// The safe answer is the filled button and the destructive one is quiet ink,
/// which is the same shape the item screen uses for "Mark as paid" against
/// "Delete this item". A destructive action that is also the prettiest thing on
/// screen gets tapped by people who were not reading.
class RestoreAsk extends StatelessWidget {
  /// `12 items, 40 payments, 2 payment sources`, read out of the file.
  final String incoming;

  /// The same count for what is on the device now, or null when there is
  /// nothing to lose — a fresh install, which is the common case for a restore
  /// and the one where this sheet should not be shouting.
  final String? existing;

  /// When the backup was taken, already formatted for reading. Null when the
  /// file does not say.
  final String? takenOn;

  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const RestoreAsk({
    super.key,
    required this.incoming,
    this.existing,
    this.takenOn,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String incoming,
    String? existing,
    String? takenOn,
  }) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0x00000000),
    isScrollControlled: true,
    builder: (sheet) => RestoreAsk(
      incoming: incoming,
      existing: existing,
      takenOn: takenOn,
      onConfirm: () => Navigator.of(sheet).pop(true),
      onCancel: () => Navigator.of(sheet).pop(false),
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
              Text(
                existing == null
                    ? S.t.restoreAskTitle
                    : S.t.restoreAskReplaceTitle,
                style: SubdockText.detailTitle.copyWith(fontSize: 25),
              ),
              const SizedBox(height: 16),
              AskLine(
                icon: Icons.download_rounded,
                label: S.t.restoreAskFrom,
                value: takenOn == null
                    ? incoming
                    : S.t.restoreAskSummary(incoming, takenOn!),
              ),
              if (existing case final onDevice?) ...[
                const SizedBox(height: 8),
                // Named, not summarised as "your data". The user is about to
                // delete rows they typed, and the count is the only way they
                // can tell whether they picked the right file.
                AskLine(
                  icon: Icons.delete_outline_rounded,
                  label: S.t.restoreAskLost,
                  value: onDevice,
                  danger: true,
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(S.t.restoreAskKeep, onPressed: onCancel),
              const SizedBox(height: 6),
              QuietButton(
                existing == null
                    ? S.t.restoreAskConfirm
                    : S.t.restoreAskReplace,
                onPressed: onConfirm,
                danger: existing != null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
