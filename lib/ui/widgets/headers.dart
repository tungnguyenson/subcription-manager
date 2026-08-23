import 'package:flutter/material.dart';
import 'package:subdock/ui/theme.dart';

/// The back link at the top of a pushed screen.
///
/// A bare `‹ Back` rather than the name of the destination. In this design the
/// screen title lands two lines below it and says where you are; naming where
/// you came from as well made the top of every pushed screen read as two
/// competing headings.
class BackLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const BackLink({super.key, this.label = 'Back', this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 12, 14),
          child: Text('‹ $label', style: SubdockText.quietAction),
        ),
      ),
    );
  }
}

/// The title of a root screen, optionally with one line under it.
class ScreenHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle style;

  const ScreenHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.style = SubdockText.screenTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: style),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: SubdockText.summary),
        ],
      ],
    );
  }
}

/// Title on the left, a way out on the right, for a screen that is filling
/// something in.
///
/// The confirm action does not live here: on every form in this design it is a
/// full-width button pinned to the bottom of the screen, where a thumb reaches
/// it. Only the escape hatch sits at the top.
class EditorHeader extends StatelessWidget {
  final String title;
  final String cancelLabel;
  final VoidCallback? onCancel;

  const EditorHeader({
    super.key,
    required this.title,
    this.cancelLabel = 'Cancel',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SubdockText.editorTitle,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onCancel ?? () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(cancelLabel, style: SubdockText.quietAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// The verbatim text a model was quoting, shown beside every extracted value.
///
/// Monospace and rule-marked so the user can compare it character by character
/// against the original screenshot. This is the only thing on the review screen
/// that is definitely true, so it is never abbreviated or reflowed.
class SourceQuote extends StatelessWidget {
  final String text;

  const SourceQuote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(left: 9),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: SubdockColors.hairline, width: 2),
        ),
      ),
      child: Text(text, style: SubdockText.monoInline.copyWith(height: 1.5)),
    );
  }
}

/// A destructive row, kept in its own card at the bottom of a screen so it can
/// never be hit while scanning the rows above it.
class DangerRow extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const DangerRow(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SubdockSpacing.rowH,
          vertical: 15,
        ),
        child: Text(
          label,
          style: SubdockText.rowLink.copyWith(color: SubdockColors.danger),
        ),
      ),
    );
  }
}
