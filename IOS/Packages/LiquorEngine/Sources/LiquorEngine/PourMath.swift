import Foundation

/// What is left in the bottle, and what that is worth.
///
/// The rounding rule is the whole of the difficulty here, so it is stated once
/// and applied everywhere:
///
/// **Round to nearest, for both capacity and remaining.**
///
/// Flooring would report a full 750 ml bottle as 16 pours and a full 700 ml as
/// 15, contradicting the two numbers this design is pinned to. Rounding to
/// nearest gives 17 and 16.
///
/// Applying it to *remaining* means a bottle holding 16.6 pours reads "17". That
/// is accepted, and it is why `PourStatus` always carries `remainingMilliliters`
/// alongside the count -- the rounding never has to carry weight on its own.
/// Using different rules for the two would produce a full bottle reading "16 of
/// 17", which reads as a bug.
public enum PourMath: Sendable {

    /// Pours a volume yields, rounded to nearest. Zero for a non-positive volume.
    public static func pourCount(milliliters: Double, pourSize: PourSize) -> Int {
        guard milliliters > 0, pourSize.milliliters > 0 else { return 0 }
        return Int((milliliters / pourSize.milliliters).rounded())
    }

    /// Volume left after everything poured so far. Never negative: over-pouring
    /// past empty is a logging mistake, not a bottle that owes you whiskey.
    public static func remainingMilliliters(capacity: Double, poured: Double) -> Double {
        max(0, capacity - poured)
    }

    /// Cost of one pour, in cents, derived from the pour count the user is
    /// actually shown.
    ///
    /// Dividing by the displayed count rather than by the exact fractional one
    /// means the arithmetic checks out in the user's head: price divided by the
    /// number on screen. Nil when the bottle yields no pours or had no price.
    public static func costPerPourCents(
        priceCents: Int,
        capacityMilliliters: Double,
        pourSize: PourSize
    ) -> Int? {
        let count = pourCount(milliliters: capacityMilliliters, pourSize: pourSize)
        guard count > 0, priceCents > 0 else { return nil }
        return Int((Double(priceCents) / Double(count)).rounded())
    }

    /// Everything the bottle detail and the shelf check need in one value.
    public static func status(
        capacityMilliliters capacity: Double,
        pouredMilliliters poured: Double,
        pourSize: PourSize = .standard
    ) -> PourStatus {
        let remaining = remainingMilliliters(capacity: capacity, poured: poured)
        return PourStatus(
            capacityMilliliters: capacity,
            remainingMilliliters: remaining,
            totalPours: pourCount(milliliters: capacity, pourSize: pourSize),
            remainingPours: pourCount(milliliters: remaining, pourSize: pourSize),
            pourSize: pourSize
        )
    }
}

/// A bottle's fill, as displayed. Count and millilitres travel together on
/// purpose -- see the rounding note on `PourMath`.
public struct PourStatus: Hashable, Sendable {
    public let capacityMilliliters: Double
    public let remainingMilliliters: Double
    public let totalPours: Int
    public let remainingPours: Int
    public let pourSize: PourSize

    public init(
        capacityMilliliters: Double,
        remainingMilliliters: Double,
        totalPours: Int,
        remainingPours: Int,
        pourSize: PourSize
    ) {
        self.capacityMilliliters = capacityMilliliters
        self.remainingMilliliters = remainingMilliliters
        self.totalPours = totalPours
        self.remainingPours = remainingPours
        self.pourSize = pourSize
    }

    public var isEmpty: Bool { remainingMilliliters <= 0 }

    /// There is liquid left but not enough to round to a pour. The UI says
    /// "less than a pour" rather than "0", which would read as empty.
    public var hasPartialPourOnly: Bool {
        remainingPours == 0 && remainingMilliliters > 0
    }
}
