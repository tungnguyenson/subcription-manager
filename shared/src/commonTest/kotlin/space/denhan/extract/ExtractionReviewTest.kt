package space.denhan.extract

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ExtractionReviewTest {

    private fun fields(
        serviceName: String? = "Netflix",
        serviceNameRaw: String? = "Netflix Premium",
        amountMinor: Long? = 231_000,
        amountRaw: String? = "231.000đ",
        currencyCode: String? = "VND",
        dueDateIso: String? = "2026-09-01",
        dueDateRaw: String? = "01/09/2026",
        dateFormat: DateFormat = DateFormat.DMY,
        confidence: Confidence = Confidence.HIGH,
    ) = ExtractedFields(
        sourceType = SourceType.BILLING_EMAIL,
        serviceName = serviceName,
        serviceNameRaw = serviceNameRaw,
        amountMinor = amountMinor,
        amountRaw = amountRaw,
        currencyCode = currencyCode,
        currencySymbolRaw = "đ",
        billingCycle = BillingCycle.MONTHLY,
        billingCycleRaw = "hàng tháng",
        dueDateIso = dueDateIso,
        dueDateRaw = dueDateRaw,
        dateFormat = dateFormat,
        confidence = confidence,
    )

    @Test
    fun `a clean extraction needs no attention`() {
        val result = ExtractionReview.review(fields())
        assertTrue(result.warnings.isEmpty(), "unexpected: ${result.warnings}")
        assertFalse(result.requiresAttention)
    }

    // The verbatim-quote check. A value with nothing behind it is the model
    // inventing something, and this catches it mechanically.
    @Test
    fun `a value with no supporting quote is flagged`() {
        val result = ExtractionReview.review(fields(amountRaw = null))
        assertTrue(result.warnings.any { it is Warning.UnsupportedValue })
        assertTrue(result.requiresAttention)
    }

    @Test
    fun `an unsupported name is flagged`() {
        val result = ExtractionReview.review(fields(serviceNameRaw = ""))
        assertTrue(result.warnings.any { it is Warning.UnsupportedValue })
    }

    @Test
    fun `an unsupported date is flagged`() {
        val result = ExtractionReview.review(fields(dueDateRaw = null))
        assertTrue(result.warnings.any { it is Warning.UnsupportedValue })
    }

    // 03/04 cannot be resolved from the text, so the app must ask rather than
    // guess. This is the failure that silently shifts a reminder by weeks.
    @Test
    fun `an ambiguous date requires a human decision`() {
        val result = ExtractionReview.review(
            fields(dueDateIso = null, dueDateRaw = "03/04/2026", dateFormat = DateFormat.AMBIGUOUS),
        )
        assertTrue(result.warnings.any { it is Warning.AmbiguousDate })
        assertTrue(result.requiresAttention)
    }

    @Test
    fun `both readings of an ambiguous date are offered`() {
        val readings = ExtractionReview.ambiguousReadings("03/04/2026")
        assertEquals("ngày 3 tháng 4" to "ngày 4 tháng 3", readings)
    }

    @Test
    fun `a date that cannot be ambiguous yields no alternative readings`() {
        assertNull(ExtractionReview.ambiguousReadings("25/12/2026"), "25 cannot be a month")
        assertNull(ExtractionReview.ambiguousReadings("no date here"))
        assertNull(ExtractionReview.ambiguousReadings(null))
    }

    @Test
    fun `separators other than slash are handled`() {
        assertEquals("ngày 3 tháng 4" to "ngày 4 tháng 3", ExtractionReview.ambiguousReadings("03-04-2026"))
        assertEquals("ngày 3 tháng 4" to "ngày 4 tháng 3", ExtractionReview.ambiguousReadings("03.04.2026"))
    }

    @Test
    fun `a missing date is flagged unless the text genuinely had none`() {
        assertTrue(
            ExtractionReview.review(fields(dueDateIso = null, dateFormat = DateFormat.DMY))
                .warnings.any { it is Warning.MissingDate },
        )
        assertFalse(
            ExtractionReview.review(
                fields(dueDateIso = null, dueDateRaw = null, amountMinor = null, amountRaw = null, dateFormat = DateFormat.ABSENT),
            ).warnings.any { it is Warning.MissingDate },
        )
    }

    // A bare number could be dong or dollars, and being wrong is a 26,000x error.
    @Test
    fun `an amount with no currency is flagged`() {
        val result = ExtractionReview.review(fields(currencyCode = null))
        assertTrue(result.warnings.any { it is Warning.UnknownCurrency })
        assertTrue(result.requiresAttention)
    }

    @Test
    fun `low confidence always requires review`() {
        val result = ExtractionReview.review(fields(confidence = Confidence.LOW))
        assertTrue(result.warnings.any { it is Warning.LowConfidence })
        assertTrue(result.requiresAttention)
    }

    @Test
    fun `medium confidence alone does not block`() {
        assertFalse(ExtractionReview.review(fields(confidence = Confidence.MEDIUM)).requiresAttention)
    }

    @Test
    fun `every warning carries a Vietnamese message`() {
        val result = ExtractionReview.review(
            fields(serviceNameRaw = null, amountRaw = null, currencyCode = null, confidence = Confidence.LOW),
        )
        assertTrue(result.warnings.isNotEmpty())
        result.warnings.forEach { assertTrue(it.messageVi.isNotBlank(), "$it has no message") }
    }
}
