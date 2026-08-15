package space.denhan.domain

import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class FxTest {

    private val today = LocalDate.parse("2026-08-15")
    private val rate = Fx.BUNDLED_USD_VND

    @Test
    fun `converts USD to VND at the bundled rate`() {
        // $20.00 at 26,046 = 520,920 dong.
        assertEquals(Money.vnd(520_920), rate.convert(Money.usd(20)))
    }

    @Test
    fun `conversion handles cents`() {
        // $22.99 at 26,046 = 598,797.54 -> 598,798 after one final rounding.
        assertEquals(Money.vnd(598_798), rate.convert(Money.usd(22, 99)))
    }

    @Test
    fun `converting the wrong currency is rejected rather than guessed`() {
        val failed = runCatching { rate.convert(Money.vnd(1000)) }.isFailure
        assertTrue(failed)
    }

    @Test
    fun `age is measured from the rate date`() {
        assertEquals(1, rate.ageInDays(today))
        assertFalse(rate.isStale(today))
    }

    @Test
    fun `a rate older than the display limit is stale`() {
        assertTrue(rate.isStale(LocalDate.parse("2026-10-01")))
    }

    @Test
    fun `same-currency amounts total exactly with no rate needed`() {
        val total = Fx.total(listOf(Money.vnd(74_000), Money.vnd(25_000)), rate, today)
        assertEquals(Money.vnd(99_000), total.perCurrency["VND"])
        assertEquals(Money.vnd(99_000), total.approximateBase)
        assertEquals(0, total.unconvertedCount)
    }

    @Test
    fun `mixed currencies keep exact per-currency subtotals`() {
        val total = Fx.total(
            listOf(Money.vnd(618_000), Money.usd(20), Money.usd(19, 99)),
            rate,
            today,
        )
        assertEquals(Money.vnd(618_000), total.perCurrency["VND"])
        assertEquals(Money.usd(39, 99), total.perCurrency["USD"])
    }

    @Test
    fun `the approximate base total includes converted rows`() {
        val total = Fx.total(listOf(Money.vnd(618_000), Money.usd(20)), rate, today)
        assertEquals(Money.vnd(618_000 + 520_920), total.approximateBase)
        assertNotNull(total.rate)
    }

    // The Firefly III bug: a missing rate defaulting to 1 turns $20 into 20 dong,
    // wrong by four orders of magnitude but shaped like a plausible number.
    @Test
    fun `an unconvertible currency is excluded and counted, never treated as one-to-one`() {
        val total = Fx.total(listOf(Money.vnd(100_000), Money(5000, "EUR")), rate, today)

        assertEquals(Money.vnd(100_000), total.approximateBase, "EUR must not leak in at rate 1")
        assertEquals(1, total.unconvertedCount)
        assertEquals(Money(5000, "EUR"), total.perCurrency["EUR"])
    }

    @Test
    fun `with no rate at all only base-currency rows are totalled`() {
        val total = Fx.total(listOf(Money.vnd(100_000), Money.usd(20)), rate = null)
        assertEquals(Money.vnd(100_000), total.approximateBase)
        assertEquals(1, total.unconvertedCount)
        assertNull(total.rate)
    }

    @Test
    fun `a stale rate is refused so no confident wrong number is shown`() {
        val total = Fx.total(listOf(Money.usd(20)), rate, today = LocalDate.parse("2026-12-01"))
        assertNull(total.approximateBase)
        assertNull(total.rate)
        assertEquals(1, total.unconvertedCount)
    }

    @Test
    fun `an all-foreign list with no usable rate yields no base total`() {
        val total = Fx.total(listOf(Money(100, "GBP")), rate, today)
        assertNull(total.approximateBase)
    }

    @Test
    fun `an empty list totals to nothing rather than zero`() {
        val total = Fx.total(emptyList(), rate, today)
        assertTrue(total.perCurrency.isEmpty())
        assertNull(total.approximateBase)
    }

    @Test
    fun `rate rejects nonsense values`() {
        assertTrue(runCatching { FxRate("USD", "VND", -1, 4, today, "x") }.isFailure)
        assertTrue(runCatching { FxRate("USD", "VND", 1, -1, today, "x") }.isFailure)
    }
}
