package space.denhan.domain

/**
 * Money as an integer count of the currency's smallest unit, never a float.
 *
 * The trap this type exists to prevent: VND has no minor unit at all (ISO 4217
 * exponent 0), so the near-universal "multiply by 100 to get cents" assumption
 * makes every VND amount 100x too large. See product-spec.md section 6.2.
 *
 *   $20.00  -> Money(2000, "USD")   exponent 2
 *   25.000d -> Money(25000, "VND")  exponent 0
 *
 * [minor] is Long, not Int: VND scaled for FX precision overflows Int32 at
 * roughly 55 billion.
 */
data class Money(val minor: Long, val currency: String) {

    init {
        require(currency.length == 3) { "currency must be a 3-letter ISO 4217 code, got '$currency'" }
    }

    val exponent: Int get() = Currencies.exponentOf(currency)

    operator fun plus(other: Money): Money {
        requireSameCurrency(other)
        return copy(minor = minor + other.minor)
    }

    operator fun minus(other: Money): Money {
        requireSameCurrency(other)
        return copy(minor = minor - other.minor)
    }

    operator fun times(factor: Int): Money = copy(minor = minor * factor)

    private fun requireSameCurrency(other: Money) {
        require(currency == other.currency) {
            "cannot combine $currency with ${other.currency}; convert first"
        }
    }

    companion object {
        fun vnd(dong: Long) = Money(dong, "VND")

        /** Builds from a major-unit value, e.g. usd(20, 0) is $20.00. */
        fun usd(dollars: Long, cents: Long = 0) = Money(dollars * 100 + cents, "USD")
    }
}

/**
 * ISO 4217 decimal digits per currency.
 *
 * Deliberately a lookup with a default rather than a fixed allowlist: shipped
 * trackers have burned whole releases adding four currencies at a time
 * (product-spec.md section 10bis). Unknown codes get the common exponent 2.
 */
object Currencies {

    /** Currencies with no minor unit. The full ISO 4217 exponent-0 set. */
    private val ZERO_DECIMAL = setOf(
        "VND", "JPY", "KRW", "BIF", "CLP", "DJF", "GNF", "ISK",
        "KMF", "PYG", "RWF", "UGX", "VUV", "XAF", "XOF", "XPF",
    )

    /** Currencies with three decimal digits. */
    private val THREE_DECIMAL = setOf("BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND")

    const val DEFAULT_EXPONENT = 2

    fun exponentOf(code: String): Int = when (code.uppercase()) {
        in ZERO_DECIMAL -> 0
        in THREE_DECIMAL -> 3
        else -> DEFAULT_EXPONENT
    }

    /** 10^exponent, i.e. how many minor units make one major unit. */
    fun minorUnitsPerMajor(code: String): Long {
        var result = 1L
        repeat(exponentOf(code)) { result *= 10 }
        return result
    }
}
