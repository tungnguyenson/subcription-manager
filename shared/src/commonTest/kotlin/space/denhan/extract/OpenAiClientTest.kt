package space.denhan.extract

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.http.HttpHeaders
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class OpenAiClientTest {

    private fun clientReturning(
        status: HttpStatusCode,
        body: String,
        headers: io.ktor.http.Headers = headersOf(HttpHeaders.ContentType, "application/json"),
    ): OpenAiClient {
        val engine = MockEngine { respond(content = body, status = status, headers = headers) }
        return OpenAiClient(HttpClient(engine), apiKeyProvider = { "sk-test" })
    }

    private fun errorBody(code: String, type: String = "insufficient_quota") =
        """{"error":{"message":"nope","type":"$type","code":"$code"}}"""

    private fun successBody(payload: String) =
        """{"status":"completed","output":[{"content":[{"type":"output_text","text":${payload.jsonQuoted()}}]}]}"""

    private fun String.jsonQuoted(): String =
        "\"" + replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""

    private suspend fun errorFrom(client: OpenAiClient): ExtractionError {
        val result = client.extract("text", "2026-08-15", "vi-VN")
        return (result.exceptionOrNull() as ExtractionException).error
    }

    @Test
    fun `a well-formed response parses into fields`() = runTest {
        val payload = """
            {"source_type":"billing_email",
             "service_name":"Netflix","service_name_raw":"Netflix Premium",
             "amount_minor":231000,"amount_raw":"231.000đ",
             "currency_code":"VND","currency_symbol_raw":"đ",
             "billing_cycle":"monthly","billing_cycle_raw":"hàng tháng",
             "due_date_iso":"2026-09-01","due_date_raw":"01/09/2026",
             "date_format_detected":"DMY","confidence":"high"}
        """.trimIndent()

        val fields = clientReturning(HttpStatusCode.OK, successBody(payload))
            .extract("text", "2026-08-15", "vi-VN").getOrThrow()

        assertEquals("Netflix", fields.serviceName)
        assertEquals(231_000, fields.amountMinor)
        assertEquals("VND", fields.currencyCode)
        assertEquals(BillingCycle.MONTHLY, fields.billingCycle)
        assertEquals("2026-09-01", fields.dueDateIso)
        assertEquals(Confidence.HIGH, fields.confidence)
    }

    // Nullable everywhere is a correctness requirement: strict mode forces every
    // field into `required`, so a non-nullable date would make the model invent
    // one rather than admit the text has none.
    @Test
    fun `every field being absent is a valid response, not a parse error`() = runTest {
        val payload = """
            {"source_type":"unknown",
             "service_name":null,"service_name_raw":null,
             "amount_minor":null,"amount_raw":null,
             "currency_code":null,"currency_symbol_raw":null,
             "billing_cycle":null,"billing_cycle_raw":null,
             "due_date_iso":null,"due_date_raw":null,
             "date_format_detected":"absent","confidence":"low"}
        """.trimIndent()

        val fields = clientReturning(HttpStatusCode.OK, successBody(payload))
            .extract("text", "2026-08-15", "vi-VN").getOrThrow()

        assertEquals(null, fields.dueDateIso)
        assertEquals(DateFormat.ABSENT, fields.dateFormat)
    }

    @Test
    fun `no API key fails before any network call`() = runTest {
        val client = OpenAiClient(HttpClient(MockEngine { respondError(HttpStatusCode.OK) }), { null })
        assertIs<ExtractionError.NoApiKey>(errorFrom(client))
    }

    @Test
    fun `an invalid key is reported as such, not as a retryable failure`() = runTest {
        val error = errorFrom(clientReturning(HttpStatusCode.Unauthorized, errorBody("invalid_api_key")))
        assertIs<ExtractionError.InvalidKey>(error)
        assertFalse(error.retryable)
    }

    // The five-way 429. Treating them all as "wait and retry" leaves a user with
    // no credit watching a spinner forever.
    @Test
    fun `429 for exhausted credit is not retryable`() = runTest {
        val error = errorFrom(
            clientReturning(HttpStatusCode.TooManyRequests, errorBody("credit_balance_exhausted")),
        )
        assertIs<ExtractionError.CreditExhausted>(error)
        assertFalse(error.retryable)
        assertTrue(error.messageVi.contains("nạp thêm"))
    }

    @Test
    fun `429 for a spend limit is not retryable`() = runTest {
        val error = errorFrom(
            clientReturning(HttpStatusCode.TooManyRequests, errorBody("organization_spend_limit_exceeded")),
        )
        assertIs<ExtractionError.SpendLimitReached>(error)
        assertFalse(error.retryable)
    }

    @Test
    fun `429 for genuine rate limiting is retryable and honours Retry-After`() = runTest {
        val client = clientReturning(
            HttpStatusCode.TooManyRequests,
            errorBody("rate_limit_exceeded", type = "requests"),
            headersOf(HttpHeaders.RetryAfter, "12"),
        )
        val error = errorFrom(client)
        assertIs<ExtractionError.RateLimited>(error)
        assertTrue(error.retryable)
        assertEquals(12, error.retryAfterSeconds)
    }

    @Test
    fun `403 is reported as an unsupported region`() = runTest {
        assertIs<ExtractionError.RegionUnsupported>(
            errorFrom(clientReturning(HttpStatusCode.Forbidden, errorBody("unsupported_country_region"))),
        )
    }

    @Test
    fun `server errors are retryable`() = runTest {
        val error = errorFrom(clientReturning(HttpStatusCode.ServiceUnavailable, errorBody("overloaded")))
        assertIs<ExtractionError.ServerError>(error)
        assertTrue(error.retryable)
    }

    // A truncated strict-JSON response is unparseable, not partially valid, so
    // the status has to be checked before parsing.
    @Test
    fun `an incomplete response is reported as truncated rather than malformed`() = runTest {
        val body = """{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}"""
        assertIs<ExtractionError.Truncated>(errorFrom(clientReturning(HttpStatusCode.OK, body)))
    }

    @Test
    fun `a refusal is surfaced as a refusal, since the schema is not honoured`() = runTest {
        val body = """{"status":"completed","output":[{"content":[{"type":"refusal","refusal":"cannot help"}]}]}"""
        val error = errorFrom(clientReturning(HttpStatusCode.OK, body))
        assertIs<ExtractionError.Refused>(error)
        assertEquals("cannot help", error.reason)
    }

    @Test
    fun `non-JSON output is reported as malformed`() = runTest {
        assertIs<ExtractionError.Malformed>(
            errorFrom(clientReturning(HttpStatusCode.OK, successBody("this is not json"))),
        )
    }

    @Test
    fun `a network failure is reported as no network`() = runTest {
        val engine = MockEngine { throw kotlinx.io.IOException("offline") }
        val client = OpenAiClient(HttpClient(engine), { "sk-test" })
        assertIs<ExtractionError.NoNetwork>(errorFrom(client))
    }

    @Test
    fun `every error carries a Vietnamese message`() {
        listOf(
            ExtractionError.NoApiKey,
            ExtractionError.InvalidKey,
            ExtractionError.CreditExhausted,
            ExtractionError.SpendLimitReached,
            ExtractionError.RegionUnsupported,
            ExtractionError.Truncated,
            ExtractionError.NoNetwork,
            ExtractionError.RateLimited(null),
            ExtractionError.ServerError(500),
            ExtractionError.Refused(null),
            ExtractionError.Malformed(null),
        ).forEach { assertTrue(it.messageVi.isNotBlank(), "$it has no message") }
    }

    @Test
    fun `the default model is the current generation, not the deprecated nano`() {
        assertEquals("gpt-5.6-luna", OpenAiClient.DEFAULT_MODEL)
    }
}
