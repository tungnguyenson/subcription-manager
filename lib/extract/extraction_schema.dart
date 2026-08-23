import 'package:meta/meta.dart';

/// What the model is asked to return from a screenshot's text.
///
/// Every field is nullable, and that is a correctness requirement rather than
/// defensive style. OpenAI's strict mode forces every declared property into
/// `required`, so a non-nullable `dueDateIso` would compel the model to emit
/// *some* date even when the text contains none: it cannot decline. That is the
/// single biggest hallucination hazard for this task, and it is a schema bug,
/// not a prompting one. See product-spec.md section 8.5.
///
/// Each semantic field is paired with a `*Raw` sibling holding the text copied
/// verbatim. Models fabricate far less when made to point at their evidence, and
/// it gives a cheap client-side falsifier: a value with an empty quote is
/// rejected. The quotes are also what the review screen shows beside each field.
@immutable
class ExtractedFields {
  final SourceType sourceType;

  final String? serviceName;
  final String? serviceNameRaw;

  /// Integer minor units. A double here would be a rounding bug waiting to
  /// happen.
  final int? amountMinor;
  final String? amountRaw;

  final String? currencyCode;
  final String? currencySymbolRaw;

  final BillingCycle? billingCycle;
  final String? billingCycleRaw;

  final String? dueDateIso;
  final String? dueDateRaw;
  final DateFormatKind dateFormat;

  final Confidence confidence;

  const ExtractedFields({
    required this.sourceType,
    this.serviceName,
    this.serviceNameRaw,
    this.amountMinor,
    this.amountRaw,
    this.currencyCode,
    this.currencySymbolRaw,
    this.billingCycle,
    this.billingCycleRaw,
    this.dueDateIso,
    this.dueDateRaw,
    required this.dateFormat,
    required this.confidence,
  });

  /// Parses the model's reply.
  ///
  /// The three non-nullable fields are the ones strict mode genuinely
  /// guarantees, so a reply missing them is malformed rather than partial and
  /// throws. Everything else is allowed to be absent, which is the whole point
  /// of the schema.
  factory ExtractedFields.fromJson(Map<String, dynamic> json) {
    T parseEnum<T>(
      String key,
      Map<String, T> byWire, {
      required bool required,
      T? fallback,
    }) {
      final raw = json[key];
      if (raw == null) {
        if (required && fallback == null) {
          throw FormatException('missing "$key"', json.toString());
        }
        return fallback as T;
      }
      final value = byWire[raw];
      if (value == null) {
        throw FormatException('unknown "$key" value "$raw"', json.toString());
      }
      return value;
    }

    return ExtractedFields(
      sourceType: parseEnum(
        'source_type',
        SourceType.byWire,
        required: true,
        fallback: SourceType.unknown,
      ),
      serviceName: json['service_name'] as String?,
      serviceNameRaw: json['service_name_raw'] as String?,
      amountMinor: (json['amount_minor'] as num?)?.toInt(),
      amountRaw: json['amount_raw'] as String?,
      currencyCode: json['currency_code'] as String?,
      currencySymbolRaw: json['currency_symbol_raw'] as String?,
      billingCycle: json['billing_cycle'] == null
          ? null
          : parseEnum('billing_cycle', BillingCycle.byWire, required: false),
      billingCycleRaw: json['billing_cycle_raw'] as String?,
      dueDateIso: json['due_date_iso'] as String?,
      dueDateRaw: json['due_date_raw'] as String?,
      dateFormat: parseEnum(
        'date_format_detected',
        DateFormatKind.byWire,
        required: true,
        fallback: DateFormatKind.absent,
      ),
      confidence: parseEnum(
        'confidence',
        Confidence.byWire,
        required: true,
        fallback: Confidence.low,
      ),
    );
  }
}

enum SourceType {
  billingEmail('billing_email'),
  subscriptionPage('subscription_page'),
  carrierSms('carrier_sms'),
  document('document'),
  unknown('unknown');

  const SourceType(this.wire);

  final String wire;

  static final Map<String, SourceType> byWire = {
    for (final value in SourceType.values) value.wire: value,
  };
}

enum BillingCycle {
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly'),
  oneTime('one_time');

  const BillingCycle(this.wire);

  final String wire;

  static final Map<String, BillingCycle> byWire = {
    for (final value in BillingCycle.values) value.wire: value,
  };
}

/// Named `DateFormatKind` rather than `DateFormat` so it cannot be confused
/// with `intl`'s formatter of that name at a call site.
enum DateFormatKind {
  mdy('MDY'),
  dmy('DMY'),
  ymd('YMD'),
  textualMonth('textual_month'),

  /// Both components are 12 or under and nothing else disambiguates.
  ambiguous('ambiguous'),
  absent('absent');

  const DateFormatKind(this.wire);

  final String wire;

  static final Map<String, DateFormatKind> byWire = {
    for (final value in DateFormatKind.values) value.wire: value,
  };
}

enum Confidence {
  high('high'),
  medium('medium'),
  low('low');

  const Confidence(this.wire);

  final String wire;

  static final Map<String, Confidence> byWire = {
    for (final value in Confidence.values) value.wire: value,
  };
}

/// The JSON Schema sent to the API.
///
/// Written as a literal string rather than generated so that what ships is
/// exactly what was reviewed. Note the parameter shape: on the Responses API
/// this goes under `text.format`, with `name` a sibling of `schema`. Using
/// `response_format` is the Chat Completions spelling and is the most common
/// porting mistake.
abstract final class ExtractionSchema {
  static const String name = 'subscription_extraction';

  static const String json = '''
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "source_type",
    "service_name", "service_name_raw",
    "amount_minor", "amount_raw",
    "currency_code", "currency_symbol_raw",
    "billing_cycle", "billing_cycle_raw",
    "due_date_iso", "due_date_raw",
    "date_format_detected", "confidence"
  ],
  "properties": {
    "source_type": {
      "type": "string",
      "enum": ["billing_email", "subscription_page", "carrier_sms", "document", "unknown"]
    },
    "service_name":        { "type": ["string", "null"] },
    "service_name_raw":    { "type": ["string", "null"] },
    "amount_minor":        { "type": ["integer", "null"] },
    "amount_raw":          { "type": ["string", "null"] },
    "currency_code":       { "type": ["string", "null"], "enum": ["VND", "USD", null] },
    "currency_symbol_raw": { "type": ["string", "null"] },
    "billing_cycle": {
      "type": ["string", "null"],
      "enum": ["weekly", "monthly", "quarterly", "yearly", "one_time", null]
    },
    "billing_cycle_raw":   { "type": ["string", "null"] },
    "due_date_iso":        { "type": ["string", "null"] },
    "due_date_raw":        { "type": ["string", "null"] },
    "date_format_detected": {
      "type": "string",
      "enum": ["MDY", "DMY", "YMD", "textual_month", "ambiguous", "absent"]
    },
    "confidence": { "type": "string", "enum": ["high", "medium", "low"] }
  }
}''';

  /// System prompt.
  ///
  /// Today's date and the device locale are injected because the 03/04 problem
  /// cannot be solved by instruction: the information genuinely is not in the
  /// text. A due date must be in the future, which eliminates one reading in
  /// most cases, and a Vietnamese locale makes day-first overwhelmingly likely.
  static String systemPrompt(String todayIso, String locale) =>
      '''
Bạn trích xuất thông tin từ nội dung chữ đã được đọc từ ảnh chụp màn hình.

Quy tắc bắt buộc:
- Mọi trường kết thúc bằng _raw phải chép lại NGUYÊN VĂN từ nội dung, không sửa, không chuẩn hóa.
- Nếu một thông tin không xuất hiện rõ ràng, trả về null. TUYỆT ĐỐI không suy đoán, không ước lượng.
- amount_minor là số nguyên theo đơn vị nhỏ nhất: VND không có phần lẻ (25.000đ là 25000),
  USD tính bằng cent (\$20.00 là 2000).
- Nếu ngày viết dạng NN/NN mà cả hai số đều nhỏ hơn hoặc bằng 12 và không có gì để phân biệt,
  đặt due_date_iso là null và date_format_detected là "ambiguous".
- Ưu tiên tháng viết bằng chữ vì nó không mập mờ.

Hôm nay là $todayIso. Ngôn ngữ và khu vực của máy: $locale.
Ngày đến hạn phải nằm ở tương lai, hãy dùng điều này để loại bớt cách đọc sai.''';
}
