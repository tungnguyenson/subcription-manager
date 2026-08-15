package space.denhan.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.daysUntil

/**
 * An exchange rate as a scaled integer, plus where and when it came from.
 *
 * Provenance is not optional metadata. Free rate sources disagree by around
 * 0.2% on the same day, which is larger than any rounding this code could
 * introduce, so a stored rate without its source silently rewrites history when
 * the source changes. See product-spec.md section 6.4.
 */
data class FxRate(
    val from: String,
    val to: String,
    /** rate * 10^scale, e.g. 26046.0 at scale 4 is 260_460_000. */
    val scaled: Long,
    val scale: Int,
    val asOf: LocalDate,
    val source: String,
) {
    init {
        require(scale >= 0) { "scale must not be negative" }
        require(scaled > 0) { "rate must be positive" }
    }

    fun ageInDays(today: LocalDate): Int = asOf.daysUntil(today)

    fun isStale(today: LocalDate, maxAgeDays: Int = Fx.MAX_DISPLAY_AGE_DAYS): Boolean =
        ageInDays(today) > maxAgeDays

    /**
     * Converts an amount, widening to the target currency's exponent before
     * rounding once at the end rather than per line item.
     */
    fun convert(amount: Money): Money {
        require(amount.currency == from) { "rate converts $from, not ${amount.currency}" }

        val fromExp = Currencies.exponentOf(from)
        val toExp = Currencies.exponentOf(to)

        // Work in the target's minor units: value_major * rate * 10^toExp.
        var numerator = amount.minor * scaled
        var denominator = pow10(scale) * pow10(fromExp)
        val widen = pow10(toExp)
        numerator *= widen

        return Money(roundHalfUp(numerator, denominator), to)
    }

    private fun pow10(n: Int): Long {
        var r = 1L
        repeat(n) { r *= 10 }
        return r
    }

    private fun roundHalfUp(numerator: Long, denominator: Long): Long {
        val q = numerator / denominator
        val rem = numerator % denominator
        return if (rem * 2 >= denominator) q + 1 else q
    }
}

/** The result of totalling a mixed-currency list. */
data class MixedTotal(
    /** The truth: one exact subtotal per currency. Always shown. */
    val perCurrency: Map<String, Money>,
    /** Orientation only. Null when no usable rate exists. Always shown with a tilde. */
    val approximateBase: Money?,
    val rate: FxRate?,
    /** Items excluded because no rate covered them. Must be surfaced, not hidden. */
    val unconvertedCount: Int,
)

object Fx {

    const val BASE_CURRENCY = "VND"

    /**
     * Past this age the converted line is hidden entirely rather than shown with
     * a stale date. A confident wrong number is worse than no number.
     */
    const val MAX_DISPLAY_AGE_DAYS = 30

    /**
     * Rate compiled into the binary, refreshed at release time. VND is a managed
     * crawling peg that drifts about 2% a year, so a six-month-old bundled rate
     * is roughly 1% off, which is invisible behind a tilde. This is what lets the
     * app work forever with no network. See spec section 6.4.
     */
    val BUNDLED_USD_VND = FxRate(
        from = "USD",
        to = "VND",
        scaled = 260_460_000L,
        scale = 4,
        asOf = LocalDate.parse("2026-08-14"),
        source = "bundled",
    )

    /**
     * Totals a mixed-currency list.
     *
     * Never defaults a missing rate to 1. Firefly III does, which turns a $20
     * charge into 20 dong: wrong by four orders of magnitude but shaped like a
     * plausible number. Here an unconvertible row stays in its own currency,
     * drops out of the approximate total, and is counted so the UI can say so.
     */
    fun total(
        amounts: List<Money>,
        rate: FxRate? = null,
        today: LocalDate? = null,
        base: String = BASE_CURRENCY,
    ): MixedTotal {
        val perCurrency = amounts
            .groupBy { it.currency }
            .mapValues { (currency, list) ->
                Money(list.sumOf { it.minor }, currency)
            }

        val usableRate = rate?.takeUnless { today != null && it.isStale(today) }

        var approx = 0L
        var unconverted = 0
        for ((currency, money) in perCurrency) {
            when {
                currency == base -> approx += money.minor
                usableRate != null && usableRate.from == currency && usableRate.to == base ->
                    approx += usableRate.convert(money).minor
                else -> unconverted++
            }
        }

        val hasBaseContribution = perCurrency.keys.any {
            it == base || (usableRate != null && usableRate.from == it && usableRate.to == base)
        }

        return MixedTotal(
            perCurrency = perCurrency,
            approximateBase = if (hasBaseContribution) Money(approx, base) else null,
            rate = usableRate,
            unconvertedCount = unconverted,
        )
    }
}
