import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/extract/extraction_review.dart';
import 'package:subdock/extract/extraction_schema.dart';

void main() {
  ExtractedFields fields({
    String? serviceName = 'Netflix',
    String? serviceNameRaw = 'Netflix Premium',
    int? amountMinor = 231000,
    String? amountRaw = '231.000đ',
    String? currencyCode = 'VND',
    String? dueDateIso = '2026-09-01',
    String? dueDateRaw = '01/09/2026',
    DateFormatKind dateFormat = DateFormatKind.dmy,
    Confidence confidence = Confidence.high,
  }) {
    return ExtractedFields(
      sourceType: SourceType.billingEmail,
      serviceName: serviceName,
      serviceNameRaw: serviceNameRaw,
      amountMinor: amountMinor,
      amountRaw: amountRaw,
      currencyCode: currencyCode,
      currencySymbolRaw: 'đ',
      billingCycle: BillingCycle.monthly,
      billingCycleRaw: 'hàng tháng',
      dueDateIso: dueDateIso,
      dueDateRaw: dueDateRaw,
      dateFormat: dateFormat,
      confidence: confidence,
    );
  }

  test('a clean extraction needs no attention', () {
    final result = ExtractionReview.review(fields());
    expect(result.warnings, isEmpty, reason: 'unexpected: ${result.warnings}');
    expect(result.requiresAttention, isFalse);
  });

  // A value the model gave without quoting anything to support it is the model
  // inventing something. Cheap, mechanical falsifier.
  test('a value with no supporting quote is flagged', () {
    final result = ExtractionReview.review(fields(amountRaw: null));
    expect(result.warnings.whereType<UnsupportedValue>(), isNotEmpty);
    expect(result.requiresAttention, isTrue);
  });

  test('an unsupported name is flagged', () {
    final result = ExtractionReview.review(fields(serviceNameRaw: '  '));
    expect(
      result.warnings.whereType<UnsupportedValue>().map((w) => w.field),
      contains('service name'),
    );
  });

  test('an unsupported date is flagged', () {
    final result = ExtractionReview.review(fields(dueDateRaw: null));
    expect(
      result.warnings.whereType<UnsupportedValue>().map((w) => w.field),
      contains('due date'),
    );
  });

  // 03/04 cannot be resolved from the text at all, so the app must not pick.
  test('an ambiguous date requires a human decision', () {
    final result = ExtractionReview.review(
      fields(
        dueDateIso: null,
        dueDateRaw: '03/04/2026',
        dateFormat: DateFormatKind.ambiguous,
      ),
    );
    expect(result.warnings.whereType<AmbiguousDate>(), isNotEmpty);
    expect(result.requiresAttention, isTrue);
  });

  test('both readings of an ambiguous date are offered', () {
    final readings = ExtractionReview.ambiguousReadings('03/04/2026');
    expect(readings, isNotNull);
    expect(readings!.$1, '3 April');
    expect(readings.$2, '4 March');
  });

  test('a date that cannot be ambiguous yields no alternative readings', () {
    expect(ExtractionReview.ambiguousReadings('18/08/2026'), isNull);
    expect(ExtractionReview.ambiguousReadings(null), isNull);
    expect(ExtractionReview.ambiguousReadings('no digits here'), isNull);
  });

  test('separators other than slash are handled', () {
    expect(ExtractionReview.ambiguousReadings('03-04-2026'), isNotNull);
    expect(ExtractionReview.ambiguousReadings('03.04.2026'), isNotNull);
  });

  test('a missing date is flagged unless the text genuinely had none', () {
    final missing = ExtractionReview.review(
      fields(
        dueDateIso: null,
        dueDateRaw: null,
        dateFormat: DateFormatKind.dmy,
      ),
    );
    expect(missing.warnings.whereType<MissingDate>(), isNotEmpty);

    final none = ExtractionReview.review(
      fields(
        dueDateIso: null,
        dueDateRaw: null,
        dateFormat: DateFormatKind.absent,
      ),
    );
    expect(none.warnings.whereType<MissingDate>(), isEmpty);
  });

  test('an amount with no currency is flagged', () {
    final result = ExtractionReview.review(fields(currencyCode: null));
    expect(result.warnings.whereType<UnknownCurrency>(), isNotEmpty);
    expect(result.requiresAttention, isTrue);
  });

  test('low confidence always requires review', () {
    final result = ExtractionReview.review(fields(confidence: Confidence.low));
    expect(result.warnings.whereType<LowConfidence>(), isNotEmpty);
    expect(result.requiresAttention, isTrue);
  });

  test('medium confidence alone does not block', () {
    final result = ExtractionReview.review(
      fields(confidence: Confidence.medium),
    );
    expect(result.requiresAttention, isFalse);
  });

  // These strings are what the user reads on the review screen; an English
  // fallback slipping through would be a visible defect.
  test('every warning carries a Vietnamese message', () {
    const warnings = <Warning>[
      UnsupportedValue('x'),
      AmbiguousDate('03/04'),
      MissingDate(),
      UnknownCurrency('đ'),
      LowConfidence(),
    ];
    for (final warning in warnings) {
      expect(warning.message, isNotEmpty);
      expect(warning.blocksAutoConfirm, isTrue);
    }
  });

  group('parsing the model reply', () {
    test('every field being absent is a valid reply, not a parse error', () {
      final parsed = ExtractedFields.fromJson(const {
        'source_type': 'unknown',
        'service_name': null,
        'service_name_raw': null,
        'amount_minor': null,
        'amount_raw': null,
        'currency_code': null,
        'currency_symbol_raw': null,
        'billing_cycle': null,
        'billing_cycle_raw': null,
        'due_date_iso': null,
        'due_date_raw': null,
        'date_format_detected': 'absent',
        'confidence': 'low',
      });

      expect(parsed.dueDateIso, isNull);
      expect(parsed.amountMinor, isNull);
      expect(parsed.dateFormat, DateFormatKind.absent);
    });

    test('an unrecognised enum value is refused rather than guessed', () {
      expect(
        () => ExtractedFields.fromJson(const {
          'source_type': 'from_the_future',
          'date_format_detected': 'absent',
          'confidence': 'low',
        }),
        throwsFormatException,
      );
    });
  });
}
