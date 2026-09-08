import Foundation

/// How far along an open bottle is.
///
/// **This is a rule of thumb, not chemistry.** Nobody has published a curve for
/// how fast a part-empty bourbon fades, so this gives a BAND and never a date.
/// Every result carries `caveat`, and the UI must show it — a hedged estimate
/// presented confidently is worse than no estimate at all.
///
/// The input that matters is **headroom, not time**. A bottle you drank
/// three-quarters of in a fortnight has barely changed; one sitting at the same
/// level for two years has. So the model is air multiplied by time, not either
/// alone.
public enum OxidationBand: Sendable {

    public enum Band: String, Sendable, Hashable, CaseIterable {
        case fresh
        case peak
        case fading
        case faded

        public var label: String {
            switch self {
            case .fresh: return "Still fresh"
            case .peak: return "Drinking well"
            case .fading: return "Fading"
            case .faded: return "Well past its best"
            }
        }

        /// Position in the four-step meter the design draws, 0-3.
        public var step: Int {
            switch self {
            case .fresh: return 0
            case .peak: return 1
            case .fading: return 2
            case .faded: return 3
            }
        }
    }

    /// Air times time, normalised so a year of exposure is the full scale.
    ///
    /// Pinned by two cases the design shows: a bottle at 24% headroom open 44
    /// days reads *fresh*, and one at 70% headroom open 213 days reads
    /// *fading*.
    static let referenceDays = 365.0

    public static let peakThreshold = 0.08
    public static let fadingThreshold = 0.25
    public static let fadedThreshold = 0.50

    public struct Estimate: Hashable, Sendable {
        public let band: Band
        public let headroomFraction: Double
        public let daysOpen: Int
        /// Air times time. Exposed for tests and for tuning, not for display —
        /// showing it would imply a precision this does not have.
        public let exposure: Double

        public var headroomPercent: Int { Int((headroomFraction * 100).rounded()) }

        /// What the card says. Plain language, no number.
        public var summary: String {
            switch band {
            case .fresh:
                return "Little air in the bottle and not long open. No hurry."
            case .peak:
                return "Open long enough to have settled, with plenty left. This is "
                    + "usually when a bottle is at its best."
            case .fading:
                return "Mostly air now, and open a while. Whiskey at this fill tends "
                    + "to flatten — the sweetness goes first."
            case .faded:
                return "A small amount left in a mostly empty bottle, open a long "
                    + "time. Expect it to taste tired next to a fresh pour."
            }
        }

        /// **Always shown.** The estimate is not defensible without it.
        public var caveat: String {
            "A rule of thumb, not chemistry. Nobody has published a real curve for "
                + "this, so the app gives you a band and never a date."
        }
    }

    public static func estimate(headroomFraction: Double, daysOpen: Int) -> Estimate {
        let air = min(1, max(0, headroomFraction))
        let time = min(1, max(0, Double(daysOpen) / referenceDays))
        let exposure = air * time

        let band: Band
        switch exposure {
        case ..<peakThreshold: band = .fresh
        case ..<fadingThreshold: band = .peak
        case ..<fadedThreshold: band = .fading
        default: band = .faded
        }

        return Estimate(
            band: band, headroomFraction: air, daysOpen: max(0, daysOpen), exposure: exposure)
    }

    public static func estimate(fillLevel: FillLevel, daysOpen: Int) -> Estimate {
        estimate(headroomFraction: fillLevel.headroomFraction, daysOpen: daysOpen)
    }

    /// Which descriptors to expect as a bottle ages. `oxidation` notes arrive;
    /// `maturation` notes are the ones that flatten. This is the payoff of
    /// tagging every descriptor with an origin.
    public static func expectedChanges(
        band: Band, wheel: FlavorWheel
    ) -> (arriving: [FlavorDescriptor], fading: [FlavorDescriptor]) {
        guard band == .fading || band == .faded else { return ([], []) }
        return (wheel.descriptors(from: .oxidation), wheel.descriptors(from: .maturation))
    }
}
