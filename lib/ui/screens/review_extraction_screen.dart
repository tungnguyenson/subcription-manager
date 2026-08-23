import 'package:flutter/material.dart';
import 'package:subdock/extract/extraction_review.dart';
import 'package:subdock/extract/extraction_schema.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// Confirms what a model read out of a screenshot, field by field.
///
/// Nothing here is written until the user confirms, and Save stays disabled
/// while any warning is unresolved. Dates are what models get wrong most
/// often, and a wrong date is the one error this app cannot recover from, so
/// this screen is deliberately slow to pass.
///
/// The heading says "Scan a bill" rather than "Review": the user does not
/// think of this as a second step, and calling it one invites them to treat it
/// as a formality to tap through.
class ReviewExtractionScreen extends StatefulWidget {
  final ReviewResult result;

  /// The image the values were read from, when the caller has one to show.
  /// Kept on screen beside the values so the comparison is possible at all.
  final Widget? preview;

  final VoidCallback? onCancel;
  final VoidCallback? onRetake;
  final void Function(ExtractedFields confirmed)? onConfirm;

  const ReviewExtractionScreen({
    super.key,
    required this.result,
    this.preview,
    this.onCancel,
    this.onRetake,
    this.onConfirm,
  });

  @override
  State<ReviewExtractionScreen> createState() => _ReviewExtractionScreenState();
}

class _ReviewExtractionScreenState extends State<ReviewExtractionScreen> {
  /// Which reading of an ambiguous date the user picked. Null until they do,
  /// which is what keeps Save disabled.
  int? _dateChoice;

  ReviewResult get _result => widget.result;
  ExtractedFields get _fields => _result.fields;

  bool get _ambiguous => _result.warnings.whereType<AmbiguousDate>().isNotEmpty;

  bool get _canConfirm {
    if (_ambiguous && _dateChoice == null) return false;

    // An ambiguous date is also reported as a missing one, because the model
    // returns null rather than guessing. Picking a reading resolves both, so
    // the missing-date warning must not keep blocking after the choice.
    final resolvedByChoice = _dateChoice != null;

    return !_result.warnings.any((warning) {
      if (!warning.blocksAutoConfirm) return false;
      if (warning is AmbiguousDate) return false;
      if (warning is MissingDate && resolvedByChoice) return false;
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final readings = ExtractionReview.ambiguousReadings(_fields.dueDateRaw);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SubdockSpacing.screenH,
              6,
              SubdockSpacing.screenH,
              12,
            ),
            children: [
              EditorHeader(title: 'Scan a bill', onCancel: widget.onCancel),
              if (widget.preview != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(SubdockRadius.card),
                  child: SizedBox(height: 280, child: widget.preview),
                ),
              const SectionLabel('Detected — check before saving'),
              GroupedCard(
                children: [
                  _ReadRow(
                    label: 'Name',
                    value: _fields.serviceName ?? 'could not read',
                    quote: _fields.serviceNameRaw,
                    confidence: _confidenceOf('service name'),
                  ),
                  if (_ambiguous && readings != null)
                    _AmbiguousDateRow(
                      readings: readings,
                      raw: _fields.dueDateRaw,
                      selected: _dateChoice,
                      onSelect: (index) => setState(() => _dateChoice = index),
                    )
                  else
                    _ReadRow(
                      label: 'Due',
                      value: _fields.dueDateIso ?? 'could not read',
                      quote: _fields.dueDateRaw,
                      mono: true,
                      confidence: _confidenceOf('due date'),
                    ),
                  _ReadRow(
                    label: 'Amount',
                    value: _amountLine(),
                    quote: _fields.amountRaw,
                    mono: true,
                    confidence: _confidenceOf('amount'),
                  ),
                ],
              ),
              for (final warning in _result.warnings.where(
                (w) => w is! AmbiguousDate,
              ))
                Footnote(warning.message),
              // The provenance line is not a disclaimer. It is the reason the
              // Save button exists: everything above came from a model reading
              // pixels, and none of it has been checked against the source it
              // claims to quote.
              const Footnote(
                'Read from the image or the text you pasted. Nothing here is '
                'confirmed until you save it.',
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
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton('Retake', onPressed: widget.onRetake),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  'Save',
                  onPressed: _canConfirm
                      ? () => widget.onConfirm?.call(_fields)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _amountLine() {
    final minor = _fields.amountMinor;
    if (minor == null) return 'could not read';

    final code = _fields.currencyCode;
    // A bare number with no symbol or code is not enough to know what it is,
    // and guessing "probably dong" is exactly the error this screen prevents.
    return code == null ? '$minor · unit unclear' : '$minor $code';
  }

  /// Confidence per field, derived from whether the model could quote it.
  _FieldConfidence _confidenceOf(String field) {
    final unsupported = _result.warnings.whereType<UnsupportedValue>().any(
      (w) => w.field == field,
    );
    if (unsupported) return _FieldConfidence.unsupported;

    return _fields.confidence == Confidence.low
        ? _FieldConfidence.unsure
        : _FieldConfidence.confident;
  }
}

enum _FieldConfidence { confident, unsure, unsupported }

/// One read value, with the text it was read from underneath it.
class _ReadRow extends StatelessWidget {
  final String label;
  final String value;
  final String? quote;
  final bool mono;
  final _FieldConfidence confidence;

  const _ReadRow({
    required this.label,
    required this.value,
    this.quote,
    this.mono = false,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final badge = switch (confidence) {
      _FieldConfidence.confident => null,
      _FieldConfidence.unsure => 'not sure',
      _FieldConfidence.unsupported => 'nothing to quote',
    };

    return Padding(
      padding: const EdgeInsets.all(SubdockSpacing.rowH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Both sides flex: a field label and a confidence badge together can
          // exceed a card's width on a 390pt phone, and an overflow here would
          // clip exactly the warning the user needs to read.
          Row(
            children: [
              Expanded(child: Text(label, style: SubdockText.rowLabel)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: mono ? SubdockText.monoValue : SubdockText.rowValue,
                ),
              ),
            ],
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Text(
              badge,
              style: SubdockText.footnote.copyWith(
                color: confidence == _FieldConfidence.unsupported
                    ? SubdockColors.danger
                    : SubdockColors.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          // The quote is the only thing on this row that is certainly true, so
          // it is never omitted when it exists and never reflowed.
          if (quote != null && quote!.trim().isNotEmpty) SourceQuote(quote!),
        ],
      ),
    );
  }
}

/// Two readings of an `NN/NN` date, offered as a choice.
///
/// The app never pre-selects one. The information that would disambiguate is
/// genuinely absent from the text, so picking a default would be a guess
/// wearing the costume of a fact.
class _AmbiguousDateRow extends StatelessWidget {
  final (String, String) readings;
  final String? raw;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _AmbiguousDateRow({
    required this.readings,
    required this.raw,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SubdockSpacing.rowH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Due', style: SubdockText.rowLabel)),
              const SizedBox(width: 12),
              Text(
                'two readings',
                style: SubdockText.rowValue.copyWith(
                  color: SubdockColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ReadingTile(
                  label: readings.$1,
                  hint: 'day before month',
                  selected: selected == 0,
                  onTap: () => onSelect(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReadingTile(
                  label: readings.$2,
                  hint: 'month before day',
                  selected: selected == 1,
                  onTap: () => onSelect(1),
                ),
              ),
            ],
          ),
          if (raw != null) SourceQuote(raw!),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _ReadingTile({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.control),
        boxShadow: selected ? const [] : SubdockShadow.soft,
      ),
      child: Material(
        color: selected ? SubdockColors.accent : SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SubdockRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: SubdockText.monoValue.copyWith(
                    fontSize: 13.5,
                    color: selected ? SubdockColors.card : SubdockColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: SubdockText.footnote.copyWith(
                    color: selected
                        ? const Color(0xCCFFFFFF)
                        : SubdockColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
