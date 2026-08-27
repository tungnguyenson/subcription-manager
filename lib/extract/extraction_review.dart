import 'package:meta/meta.dart';

import 'extraction_schema.dart';

import 'package:subdock/i18n.dart';

/// Client-side checks on what the model returned, before any of it reaches a
/// form the user might just tap through.
///
/// The app never writes an extraction straight to storage. A wrong date on an
/// unrecoverable item means a lost phone number, and dates are exactly what
/// models get wrong most often. So everything here is about producing warnings
/// the review screen must surface, and deciding whether the confirm button
/// starts enabled. See product-spec.md section 8.1.
abstract final class ExtractionReview {
  static ReviewResult review(ExtractedFields fields) {
    final warnings = <Warning>[];

    bool isBlank(String? text) => text == null || text.trim().isEmpty;

    // A value with no verbatim quote behind it is the model inventing
    // something. Cheap, mechanical falsifier.
    if (fields.serviceName != null && isBlank(fields.serviceNameRaw)) {
      warnings.add(UnsupportedValue(S.t.fieldServiceNameLower));
    }
    if (fields.amountMinor != null && isBlank(fields.amountRaw)) {
      warnings.add(UnsupportedValue(S.t.fieldAmountLower));
    }
    if (fields.dueDateIso != null && isBlank(fields.dueDateRaw)) {
      warnings.add(UnsupportedValue(S.t.fieldDueLower));
    }

    // 03/04 cannot be resolved from the text. The UI shows both readings as
    // tappable choices rather than pre-selecting one.
    if (fields.dateFormat == DateFormatKind.ambiguous) {
      warnings.add(AmbiguousDate(fields.dueDateRaw));
    }

    if (fields.dueDateIso == null &&
        fields.dateFormat != DateFormatKind.absent) {
      warnings.add(const MissingDate());
    }

    // A bare number with no symbol or code is not enough to know what it is.
    if (fields.amountMinor != null && fields.currencyCode == null) {
      warnings.add(UnknownCurrency(fields.currencySymbolRaw));
    }

    if (fields.confidence == Confidence.low) {
      warnings.add(const LowConfidence());
    }

    return ReviewResult(
      fields: fields,
      warnings: List.unmodifiable(warnings),
      // Confirm starts disabled whenever anything needs a human decision, so
      // tapping through cannot silently accept a guess.
      requiresAttention: warnings.any((w) => w.blocksAutoConfirm),
    );
  }

  /// Both readings of an ambiguous NN/NN date, day-first and month-first.
  /// Rendered as two tappable chips; the app never picks one.
  /// The month is named rather than numbered. `3/4` and `4/3` side by side are
  /// two arrangements of the same two digits, and a reader picking between them
  /// under time pressure will pick the one on the left; `3 April` and `4 March`
  /// are two different dates.
  static (String, String)? ambiguousReadings(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d{1,2})[/\-.](\d{1,2})').firstMatch(raw);
    if (match == null) return null;

    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    if (a > 12 || b > 12) return null;

    return ('$a ${_month(b)}', '$b ${_month(a)}');
  }

  static String _month(int month) => S.t.monthName(month);
}

@immutable
class ReviewResult {
  final ExtractedFields fields;
  final List<Warning> warnings;
  final bool requiresAttention;

  const ReviewResult({
    required this.fields,
    required this.warnings,
    required this.requiresAttention,
  });
}

@immutable
sealed class Warning {
  const Warning();

  /// True when the user must resolve this before the form can be accepted.
  bool get blocksAutoConfirm;

  String get message;
}

/// A value the model gave without quoting anything to support it.
class UnsupportedValue extends Warning {
  final String field;

  const UnsupportedValue(this.field);

  @override
  bool get blocksAutoConfirm => true;

  @override
  String get message => S.t.warnUnsupportedValue(field);
}

class AmbiguousDate extends Warning {
  final String? raw;

  const AmbiguousDate(this.raw);

  @override
  bool get blocksAutoConfirm => true;

  @override
  String get message => S.t.warnAmbiguousDate(raw ?? '');
}

class MissingDate extends Warning {
  const MissingDate();

  @override
  bool get blocksAutoConfirm => true;

  @override
  String get message => S.t.warnMissingDate;
}

class UnknownCurrency extends Warning {
  final String? symbolRaw;

  const UnknownCurrency(this.symbolRaw);

  @override
  bool get blocksAutoConfirm => true;

  @override
  String get message => S.t.warnUnknownCurrency;
}

class LowConfidence extends Warning {
  const LowConfidence();

  @override
  bool get blocksAutoConfirm => true;

  @override
  String get message => S.t.warnLowConfidence;
}
