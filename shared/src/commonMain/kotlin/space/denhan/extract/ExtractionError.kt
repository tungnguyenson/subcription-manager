package space.denhan.extract

/**
 * What went wrong, and crucially whether retrying could ever help.
 *
 * HTTP 429 covers five distinct conditions and three of them are permanent:
 * treating every 429 as "back off and retry" leaves a user with no credit
 * watching a spinner forever. So the branch is on the error `code` in the body,
 * never on the status alone. See product-spec.md section 8.7.
 */
sealed class ExtractionError {

    abstract val retryable: Boolean

    /** Message shown to the user, in Vietnamese. */
    abstract val messageVi: String

    /** Genuine rate limiting. Honour [retryAfterSeconds] when present. */
    data class RateLimited(val retryAfterSeconds: Int?) : ExtractionError() {
        override val retryable = true
        override val messageVi = "Đang bận, thử lại sau vài giây."
    }

    /** The account has no prepaid credit. Retrying never succeeds. */
    data object CreditExhausted : ExtractionError() {
        override val retryable = false
        override val messageVi = "Tài khoản OpenAI hết tiền. Cần nạp thêm rồi thử lại."
    }

    /** A spend cap the user set on their own account. */
    data object SpendLimitReached : ExtractionError() {
        override val retryable = false
        override val messageVi = "Đã chạm giới hạn chi tiêu bạn đặt trên OpenAI."
    }

    /** The most common failure with a user-supplied key. */
    data object InvalidKey : ExtractionError() {
        override val retryable = false
        override val messageVi = "API key không đúng hoặc đã bị thu hồi. Kiểm tra lại trong Cài đặt."
    }

    data object RegionUnsupported : ExtractionError() {
        override val retryable = false
        override val messageVi = "Khu vực của bạn chưa được OpenAI hỗ trợ."
    }

    data class ServerError(val status: Int) : ExtractionError() {
        override val retryable = true
        override val messageVi = "Máy chủ OpenAI đang lỗi. Thử lại sau."
    }

    data object NoNetwork : ExtractionError() {
        override val retryable = true
        override val messageVi = "Không có kết nối mạng."
    }

    /** The model declined. The schema is not honoured in this case. */
    data class Refused(val reason: String?) : ExtractionError() {
        override val retryable = false
        override val messageVi = "Không đọc được nội dung này."
    }

    /**
     * Output hit the token cap, so the JSON is cut off mid-structure.
     * Unparseable, not partially valid.
     */
    data object Truncated : ExtractionError() {
        override val retryable = true
        override val messageVi = "Nội dung quá dài, không đọc hết được."
    }

    data class Malformed(val detail: String?) : ExtractionError() {
        override val retryable = false
        override val messageVi = "Kết quả trả về không đúng định dạng."
    }

    data object NoApiKey : ExtractionError() {
        override val retryable = false
        override val messageVi = "Chưa có API key. Thêm trong Cài đặt để dùng tính năng này."
    }
}

/**
 * Maps an API failure onto the right branch.
 *
 * Deliberately takes the error code as well as the status, because the status
 * alone cannot distinguish "wait a moment" from "you have no money".
 */
object ErrorMapper {

    fun map(status: Int, errorCode: String?, errorType: String?, retryAfterSeconds: Int? = null): ExtractionError {
        val code = errorCode ?: errorType

        return when {
            status == 401 -> ExtractionError.InvalidKey
            status == 403 -> ExtractionError.RegionUnsupported

            status == 429 -> when (code) {
                "credit_balance_exhausted",
                "insufficient_quota",
                -> ExtractionError.CreditExhausted

                "organization_spend_limit_exceeded",
                "project_spend_limit_exceeded",
                "organization_usage_limit_exceeded",
                -> ExtractionError.SpendLimitReached

                else -> ExtractionError.RateLimited(retryAfterSeconds)
            }

            status >= 500 -> ExtractionError.ServerError(status)
            else -> ExtractionError.Malformed(code)
        }
    }
}
