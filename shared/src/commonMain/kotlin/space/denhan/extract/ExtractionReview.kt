package space.denhan.extract

/**
 * Client-side checks on what the model returned, before any of it reaches a
 * form the user might just tap through.
 *
 * The app never writes an extraction straight to storage. A wrong date on an
 * unrecoverable item means a lost phone number, and dates are exactly what
 * models get wrong most often. So everything here is about producing warnings
 * the review screen must surface, and deciding whether the confirm button starts
 * enabled. See product-spec.md section 8.1.
 */
object ExtractionReview {

    fun review(fields: ExtractedFields): ReviewResult {
        val warnings = mutableListOf<Warning>()

        // A value with no verbatim quote behind it is the model inventing
        // something. Cheap, mechanical falsifier.
        if (fields.serviceName != null && fields.serviceNameRaw.isNullOrBlank()) {
            warnings += Warning.UnsupportedValue("tên dịch vụ")
        }
        if (fields.amountMinor != null && fields.amountRaw.isNullOrBlank()) {
            warnings += Warning.UnsupportedValue("số tiền")
        }
        if (fields.dueDateIso != null && fields.dueDateRaw.isNullOrBlank()) {
            warnings += Warning.UnsupportedValue("ngày đến hạn")
        }

        // 03/04 cannot be resolved from the text. The UI shows both readings as
        // tappable choices rather than pre-selecting one.
        if (fields.dateFormat == DateFormat.AMBIGUOUS) {
            warnings += Warning.AmbiguousDate(fields.dueDateRaw)
        }

        if (fields.dueDateIso == null && fields.dateFormat != DateFormat.ABSENT) {
            warnings += Warning.MissingDate
        }

        // A bare number with no symbol or code is not enough to know what it is.
        if (fields.amountMinor != null && fields.currencyCode == null) {
            warnings += Warning.UnknownCurrency(fields.currencySymbolRaw)
        }

        if (fields.confidence == Confidence.LOW) {
            warnings += Warning.LowConfidence
        }

        return ReviewResult(
            fields = fields,
            warnings = warnings,
            // Confirm starts disabled whenever anything needs a human decision,
            // so tapping through cannot silently accept a guess.
            requiresAttention = warnings.any { it.blocksAutoConfirm },
        )
    }

    /**
     * Both readings of an ambiguous NN/NN date, day-first and month-first.
     * Rendered as two tappable chips; the app never picks one.
     */
    fun ambiguousReadings(raw: String?): Pair<String, String>? {
        val match = Regex("""(\d{1,2})[/\-.](\d{1,2})""").find(raw ?: return null) ?: return null
        val (a, b) = match.destructured.toList().map { it.toInt() }
        if (a > 12 || b > 12) return null
        return "ngày $a tháng $b" to "ngày $b tháng $a"
    }
}

data class ReviewResult(
    val fields: ExtractedFields,
    val warnings: List<Warning>,
    val requiresAttention: Boolean,
)

sealed class Warning {

    /** True when the user must resolve this before the form can be accepted. */
    abstract val blocksAutoConfirm: Boolean
    abstract val messageVi: String

    /** A value the model gave without quoting anything to support it. */
    data class UnsupportedValue(val field: String) : Warning() {
        override val blocksAutoConfirm = true
        override val messageVi = "Máy đưa ra $field nhưng không chỉ được chỗ nào trong ảnh. Kiểm tra lại."
    }

    data class AmbiguousDate(val raw: String?) : Warning() {
        override val blocksAutoConfirm = true
        override val messageVi = "Ngày ${raw ?: ""} có thể hiểu theo hai cách. Chọn cách đúng."
    }

    data object MissingDate : Warning() {
        override val blocksAutoConfirm = true
        override val messageVi = "Không tìm thấy ngày đến hạn. Nhập tay."
    }

    data class UnknownCurrency(val symbolRaw: String?) : Warning() {
        override val blocksAutoConfirm = true
        override val messageVi = "Không rõ đơn vị tiền tệ. Chọn đồng hay đô."
    }

    data object LowConfidence : Warning() {
        override val blocksAutoConfirm = true
        override val messageVi = "Máy không chắc về kết quả này. Đối chiếu từng dòng trước khi lưu."
    }
}
