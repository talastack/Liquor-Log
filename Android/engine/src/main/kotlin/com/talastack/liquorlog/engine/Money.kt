package com.talastack.liquorlog.engine

import java.util.Locale

object Money {
    /**
     * "$74.99". Locale.ROOT rather than the device's: this is a US shelf
     * price with a dollar sign already hard-coded beside it, so formatting
     * the number by a comma-decimal convention would produce "$74,99",
     * which is neither one thing nor the other.
     */
    fun short(cents: Int): String = String.format(Locale.ROOT, "$%.2f", cents / 100.0)
}
