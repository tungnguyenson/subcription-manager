package space.denhan.extract

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * What the model is asked to return from a screenshot's text.
 *
 * Every field is nullable, and that is a correctness requirement rather than
 * defensive style. OpenAI's strict mode forces every declared property into
 * `required`, so a non-nullable `dueDateIso` would compel the model to emit
 * *some* date even when the text contains none: it cannot decline. That is the
 * single biggest hallucination hazard for this task, and it is a schema bug, not
 * a prompting one. See product-spec.md section 8.5.
 *
 * Each semantic field is paired with a `*Raw` sibling holding the text copied
 * verbatim. Models fabricate far less when made to point at their evidence, and
 * it gives a cheap client-side falsifier: a value with an empty quote is
 * rejected. The quotes are also what the review screen shows beside each field.
 */
@Serializable
data class ExtractedFields(
    @SerialName("source_type") val sourceType: SourceType,

    @SerialName("service_name") val serviceName: String? = null,
    @SerialName("service_name_raw") val serviceNameRaw: String? = null,

    /** Integer minor units. A float here would be a rounding bug waiting to happen. */
    @SerialName("amount_minor") val amountMinor: Long? = null,
    @SerialName("amount_raw") val amountRaw: String? = null,

    @SerialName("currency_code") val currencyCode: String? = null,
    @SerialName("currency_symbol_raw") val currencySymbolRaw: String? = null,

    @SerialName("billing_cycle") val billingCycle: BillingCycle? = null,
    @SerialName("billing_cycle_raw") val billingCycleRaw: String? = null,

    @SerialName("due_date_iso") val dueDateIso: String? = null,
    @SerialName("due_date_raw") val dueDateRaw: String? = null,
    @SerialName("date_format_detected") val dateFormat: DateFormat,

    @SerialName("confidence") val confidence: Confidence,
)

@Serializable
enum class SourceType {
    @SerialName("billing_email") BILLING_EMAIL,
    @SerialName("subscription_page") SUBSCRIPTION_PAGE,
    @SerialName("carrier_sms") CARRIER_SMS,
    @SerialName("document") DOCUMENT,
    @SerialName("unknown") UNKNOWN,
}

@Serializable
enum class BillingCycle {
    @SerialName("weekly") WEEKLY,
    @SerialName("monthly") MONTHLY,
    @SerialName("quarterly") QUARTERLY,
    @SerialName("yearly") YEARLY,
    @SerialName("one_time") ONE_TIME,
}

@Serializable
enum class DateFormat {
    @SerialName("MDY") MDY,
    @SerialName("DMY") DMY,
    @SerialName("YMD") YMD,
    @SerialName("textual_month") TEXTUAL_MONTH,

    /** Both components are 12 or under and nothing else disambiguates. */
    @SerialName("ambiguous") AMBIGUOUS,
    @SerialName("absent") ABSENT,
}

@Serializable
enum class Confidence {
    @SerialName("high") HIGH,
    @SerialName("medium") MEDIUM,
    @SerialName("low") LOW,
}

/**
 * The JSON Schema sent to the API.
 *
 * Written as a literal string rather than generated so that what ships is
 * exactly what was reviewed. Note the parameter shape: on the Responses API this
 * goes under `text.format`, with `name` a sibling of `schema`. Using
 * `response_format` is the Chat Completions spelling and is the most common
 * porting mistake.
 */
object ExtractionSchema {

    const val NAME = "subscription_extraction"

    val json: String = """
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
    }
    """.trimIndent()

    /**
     * System prompt.
     *
     * Today's date and the device locale are injected because the 03/04 problem
     * cannot be solved by instruction: the information genuinely is not in the
     * text. A due date must be in the future, which eliminates one reading in
     * most cases, and a Vietnamese locale makes day-first overwhelmingly likely.
     */
    fun systemPrompt(todayIso: String, locale: String): String = """
        Bạn trích xuất thông tin từ nội dung chữ đã được đọc từ ảnh chụp màn hình.

        Quy tắc bắt buộc:
        - Mọi trường kết thúc bằng _raw phải chép lại NGUYÊN VĂN từ nội dung, không sửa, không chuẩn hóa.
        - Nếu một thông tin không xuất hiện rõ ràng, trả về null. TUYỆT ĐỐI không suy đoán, không ước lượng.
        - amount_minor là số nguyên theo đơn vị nhỏ nhất: VND không có phần lẻ (25.000đ là 25000),
          USD tính bằng cent (${'$'}20.00 là 2000).
        - Nếu ngày viết dạng NN/NN mà cả hai số đều nhỏ hơn hoặc bằng 12 và không có gì để phân biệt,
          đặt due_date_iso là null và date_format_detected là "ambiguous".
        - Ưu tiên tháng viết bằng chữ vì nó không mập mờ.

        Hôm nay là $todayIso. Ngôn ngữ và khu vực của máy: $locale.
        Ngày đến hạn phải nằm ở tương lai, hãy dùng điều này để loại bớt cách đọc sai.
    """.trimIndent()
}
