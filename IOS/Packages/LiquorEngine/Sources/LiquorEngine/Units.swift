import Foundation

// MARK: - Volume

public enum Volume: Sendable {
    /// Exact, by definition of the US fluid ounce.
    public static let usFluidOunceInMilliliters: Double = 29.5735295625

    /// TTB standards of fill for distilled spirits, in millilitres.
    ///
    /// A size outside this list is a data-entry error rather than an exotic
    /// bottle, and it corrupts every pour count derived from it. The list was
    /// expanded in recent years to authorise sizes that previously were not
    /// legal -- see `docs/05-data-sourcing.md`; this transcription must be
    /// checked against the current regulation before the catalog ships.
    public static let standardsOfFill: Set<Int> = [
        50, 100, 200, 355, 375, 500, 700, 720, 750, 900, 1000, 1750, 1800
    ]

    public static func isStandardFill(milliliters: Double) -> Bool {
        standardsOfFill.contains(Int(milliliters.rounded()))
    }
}

// MARK: - ABV

/// Alcohol by volume, stored as a percentage.
///
/// A distinct type rather than a bare `Double` for the reason the metric-only
/// rule exists in Reef-Ledger: storage is always ABV and proof is presentation,
/// and making that a type turns "did this number arrive as 62.6 or 125.2" from
/// a discipline problem into a compile error.
public struct ABV: Hashable, Sendable, Comparable, Codable {
    public let percent: Double

    public init(percent: Double) {
        self.percent = percent
    }

    /// US proof is exactly twice ABV.
    public init(proof: Double) {
        self.percent = proof / 2
    }

    public var proof: Double { percent * 2 }

    public static func < (lhs: ABV, rhs: ABV) -> Bool { lhs.percent < rhs.percent }

    /// A coarse sanity check spanning everything from a light beer to overproof
    /// rum. It is deliberately wide, and therefore weak: it accepts 6.26%,
    /// because that is a real beer strength. Catching a bourbon typed as 6.26
    /// when 62.6 was meant needs the class -- see `Classification`, which holds
    /// American whiskey to a 40% floor.
    public static let plausibleRange: ClosedRange<Double> = 0.5...95.0

    public var isPlausible: Bool { Self.plausibleRange.contains(percent) }
}

// MARK: - Pour size

/// How much goes in the glass. User-configurable; the default is not a constant.
public struct PourSize: Hashable, Sendable, Codable {
    public let milliliters: Double

    public init(milliliters: Double) {
        self.milliliters = milliliters
    }

    public init(usFluidOunces: Double) {
        self.milliliters = usFluidOunces * Volume.usFluidOunceInMilliliters
    }

    /// 1.5 US fl oz = 44.36 ml.
    ///
    /// This constant is pinned by two observations that have to both hold: a
    /// 750 ml bottle gives 17 pours and a 700 ml bottle gives 16. Only a
    /// 1.5 oz pour rounded to nearest satisfies both (16.91 and 15.78).
    public static let standard = PourSize(usFluidOunces: 1.5)

    public var usFluidOunces: Double { milliliters / Volume.usFluidOunceInMilliliters }
}
