import Foundation

/// How full the bottle is, and how much air is in it.
///
/// The second number is the one that matters. Oxidation is driven by the ratio
/// of air to liquid, not by elapsed time alone: a bottle a quarter full has
/// three times the headroom of one three-quarters full and fades at a different
/// rate. `OxidationBand` takes headroom, not days, as its primary input for
/// exactly this reason.
public struct FillLevel: Hashable, Sendable {
    public let remainingMilliliters: Double
    public let capacityMilliliters: Double

    public init(remainingMilliliters: Double, capacityMilliliters: Double) {
        self.remainingMilliliters = remainingMilliliters
        self.capacityMilliliters = capacityMilliliters
    }

    /// Proportion of the bottle still holding liquid, 0...1.
    public var fraction: Double {
        guard capacityMilliliters > 0 else { return 0 }
        return min(1, max(0, remainingMilliliters / capacityMilliliters))
    }

    /// Proportion of the bottle holding air, 0...1.
    public var headroomFraction: Double { 1 - fraction }

    /// Coarse bands, because the underlying effect is not precise enough to
    /// justify a percentage. See `OxidationBand`.
    public var headroom: Headroom {
        switch headroomFraction {
        case ..<0.33: return .minimal   // bottle more than two-thirds full
        case ..<0.60: return .moderate  // down to roughly half
        case ..<0.80: return .high      // down to roughly a fifth
        default: return .severe         // heel of the bottle
        }
    }

    public enum Headroom: String, Sendable, CaseIterable, Codable {
        case minimal
        case moderate
        case high
        case severe
    }
}
