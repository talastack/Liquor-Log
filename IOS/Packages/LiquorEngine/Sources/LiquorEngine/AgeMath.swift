import Foundation

/// Four different numbers that all get called "age", kept apart because
/// conflating them is how a bottle gets described as 27 years old when the
/// whiskey in it is 12.
public enum AgeMath: Sendable {

    /// Maturation: time in the barrel. **The only ageing that changes the
    /// whiskey.** Nil when either year is missing or the pair is impossible.
    public static func maturationYears(distilledYear: Int?, bottledYear: Int?) -> Int? {
        guard let distilled = distilledYear, let bottled = bottledYear else { return nil }
        let years = bottled - distilled
        return years >= 0 ? years : nil
    }

    /// Time since bottling.
    ///
    /// Whiskey does not mature in glass. This is provenance -- how dusty the
    /// bottle is -- and the UI must never present it as age. A 1985 bottling of
    /// a 12-year is a 12-year-old whiskey in a 40-year-old bottle.
    public static func yearsInGlass(
        bottledYear: Int?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let bottled = bottledYear else { return nil }
        let currentYear = calendar.component(.year, from: now)
        let years = currentYear - bottled
        return years >= 0 ? years : nil
    }

    /// How long this bottle has been yours.
    public static func daysOwned(
        purchasedAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let purchased = purchasedAt else { return nil }
        return days(from: purchased, to: now, calendar: calendar)
    }

    /// How long it has been open -- one of the two inputs to oxidation, the
    /// other being headroom.
    public static func daysOpen(
        openedAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let opened = openedAt else { return nil }
        return days(from: opened, to: now, calendar: calendar)
    }

    /// Whole days between two instants. Negative spans clamp to zero: a device
    /// clock that has jumped backwards should not produce a bottle opened in
    /// the future.
    public static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }
}
