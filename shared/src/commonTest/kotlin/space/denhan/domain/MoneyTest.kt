package space.denhan.domain

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class MoneyTest {

    // The 100x bug: VND has no minor unit, so the usual "times 100" is wrong.
    @Test
    fun `VND has exponent zero`() {
        assertEquals(0, Currencies.exponentOf("VND"))
        assertEquals(1L, Currencies.minorUnitsPerMajor("VND"))
        assertEquals(25_000L, Money.vnd(25_000).minor)
    }

    @Test
    fun `USD has exponent two`() {
        assertEquals(2, Currencies.exponentOf("USD"))
        assertEquals(100L, Currencies.minorUnitsPerMajor("USD"))
        assertEquals(2000L, Money.usd(20).minor)
        assertEquals(2099L, Money.usd(20, 99).minor)
    }

    @Test
    fun `the other zero-decimal currencies are covered`() {
        listOf("JPY", "KRW", "ISK", "XOF", "XAF", "CLP", "PYG", "UGX", "VUV", "XPF")
            .forEach { assertEquals(0, Currencies.exponentOf(it), "$it should be zero-decimal") }
    }

    @Test
    fun `three-decimal currencies are covered`() {
        listOf("KWD", "BHD", "OMR", "JOD", "TND", "IQD", "LYD")
            .forEach { assertEquals(3, Currencies.exponentOf(it), "$it should be three-decimal") }
    }

    @Test
    fun `unknown currencies fall back to two rather than being rejected`() {
        // Shipped trackers have burned releases adding currencies one batch at a
        // time; an allowlist is the thing being avoided here.
        assertEquals(2, Currencies.exponentOf("GBP"))
        assertEquals(2, Currencies.exponentOf("ZZZ"))
    }

    @Test
    fun `exponent lookup is case-insensitive`() {
        assertEquals(0, Currencies.exponentOf("vnd"))
        assertEquals(2, Currencies.exponentOf("usd"))
    }

    @Test
    fun `same-currency arithmetic works`() {
        assertEquals(Money.vnd(99_000), Money.vnd(74_000) + Money.vnd(25_000))
        assertEquals(Money.vnd(49_000), Money.vnd(74_000) - Money.vnd(25_000))
        assertEquals(Money.vnd(888_000), Money.vnd(74_000) * 12)
    }

    @Test
    fun `mixing currencies is a hard error, never a silent conversion`() {
        assertFailsWith<IllegalArgumentException> { Money.vnd(25_000) + Money.usd(20) }
    }

    @Test
    fun `currency code must be three letters`() {
        assertFailsWith<IllegalArgumentException> { Money(100, "DONG") }
        assertFailsWith<IllegalArgumentException> { Money(100, "") }
    }

    // Int32 overflows around 2.1 billion; VND scaled for FX precision passes that.
    @Test
    fun `large VND totals do not overflow`() {
        val big = Money.vnd(55_000_000_000L)
        assertEquals(110_000_000_000L, (big + big).minor)
    }

    @Test
    fun `exponent is exposed on the value itself`() {
        assertEquals(0, Money.vnd(1).exponent)
        assertEquals(2, Money.usd(1).exponent)
    }
}
