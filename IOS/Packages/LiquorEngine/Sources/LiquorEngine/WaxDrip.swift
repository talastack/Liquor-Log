import Foundation

/// The wax on a Maker's Mark, measured.
///
/// Every Maker's is hand-dipped, and collectors hunt the ones where the wax
/// ran: a long single drip, a cascade, a "slow pour". Some pay for it. The
/// lore is real and nobody measures it -- it is eyeballed in a store aisle
/// and argued about afterwards.
///
/// This measures it from a photo, honestly. Two lines on the picture: the
/// bottle, base to cap, and the drip, wax edge to tip. The result is a
/// FRACTION of the bottle's height, which is what makes it comparable
/// between photos taken at different distances with different phones. If
/// the person types the bottle's real height it becomes millimetres too;
/// the app never guesses a bottle's height for them.
///
/// What it will not do is call a drip rare. Nobody has published a
/// distribution, and the research is explicit about invented rarity tiers.
/// A drip is ranked among the person's own bottles, and `standing(among:)`
/// exists so that a community sample, when sync brings one, can place it
/// without a redesign.
public enum WaxDrip: Sendable {

    /// A point on the photo, in whatever coordinate space the screen used.
    /// Only ratios matter, so the units never do.
    public struct Point: Hashable, Sendable {
        public let x: Double
        public let y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }

        func distance(to other: Point) -> Double {
            ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
        }
    }

    /// The colours Maker's has dipped in. Red is the bottle; the others are
    /// releases and picks, and a collector knows which is which on sight.
    public enum Color: String, Sendable, Hashable, CaseIterable, Codable {
        case red, black, gold, green, purple, blue, white, other

        public var label: String {
            switch self {
            case .red: return "Red"
            case .black: return "Black"
            case .gold: return "Gold"
            case .green: return "Green"
            case .purple: return "Purple"
            case .blue: return "Blue"
            case .white: return "White"
            case .other: return "Another colour"
            }
        }
    }

    public struct Measurement: Hashable, Sendable {
        /// Drip length over bottle height. 0.3 means the drip runs almost a
        /// third of the way down the bottle.
        public let fraction: Double
        /// Only when the bottle's real height was given.
        public let millimeters: Double?

        public var percent: Int { Int((fraction * 100).rounded()) }
    }

    /// Nil when either line has no length: two taps in the same place is
    /// a slip, not a bottle of zero height.
    public static func measure(
        bottleBase: Point, bottleTop: Point,
        waxEdge: Point, dripTip: Point,
        bottleHeightMillimeters: Double? = nil
    ) -> Measurement? {
        let bottle = bottleBase.distance(to: bottleTop)
        let drip = waxEdge.distance(to: dripTip)
        guard bottle > 0, drip >= 0 else { return nil }
        let fraction = min(1, drip / bottle)
        let mm = bottleHeightMillimeters.flatMap { $0 > 0 ? fraction * $0 : nil }
        return Measurement(fraction: fraction, millimeters: mm)
    }

    /// Where one drip sits among others -- this person's own Maker's, or a
    /// community sample later. 1-based rank by length, longest first.
    public struct Standing: Hashable, Sendable {
        public let rank: Int
        public let count: Int
        /// Share of the others this one is longer than, 0...1. Nil with
        /// nothing to compare against.
        public let longerThan: Double?

        public var text: String {
            guard count > 1, let longerThan else { return "The only drip measured so far." }
            if rank == 1 { return "Longest of \(count)." }
            return "Longer than \(Int((longerThan * 100).rounded()))% of \(count)."
        }
    }

    /// Everyone's measured drips of a product, reduced on the server to a
    /// count and quartiles. Where yours falls among them is a fact about
    /// the sample, said in quarters, never a word for the drip itself.
    public struct CommunityStanding: Hashable, Sendable, Decodable {
        public let catalogProductId: String
        public let reports: Int
        public let p25: Double
        public let p50: Double
        public let p75: Double

        enum CodingKeys: String, CodingKey {
            case catalogProductId = "catalog_product_id", reports, p25, p50, p75
        }

        public init(catalogProductId: String, reports: Int, p25: Double, p50: Double, p75: Double) {
            self.catalogProductId = catalogProductId
            self.reports = reports; self.p25 = p25; self.p50 = p50; self.p75 = p75
        }

        /// Fewer than this and the quartiles are one person's bottles.
        public static let minimumReports = 4

        /// "Longer than three quarters of the 40 drips people have measured."
        /// Nil until there are enough.
        public func text(for fraction: Double) -> String? {
            guard reports >= Self.minimumReports else { return nil }
            let tail = " of the \(reports) drips people have measured."
            if fraction > p75 { return "Longer than three quarters" + tail }
            if fraction > p50 { return "Longer than half" + tail }
            if fraction > p25 { return "Longer than a quarter" + tail }
            return "Among the shortest quarter" + tail
        }
    }

    public static func standing(of fraction: Double, among fractions: [Double]) -> Standing {
        let others = fractions
        guard !others.isEmpty else { return Standing(rank: 1, count: 1, longerThan: nil) }
        let all = others + [fraction]
        let longer = all.filter { $0 > fraction }.count
        let shorter = others.filter { $0 < fraction }.count
        return Standing(
            rank: longer + 1,
            count: all.count,
            longerThan: Double(shorter) / Double(others.count))
    }

    /// Deliberately absent: words for a length. An earlier version called a
    /// drip "short", "proper", "long" or "a cascade" at bands the app made
    /// up. No data exists for where those lines fall -- Maker's says only
    /// that every bottle is hand-dipped -- so the app shows the number and
    /// the standing among the person's own bottles, and says nothing it
    /// cannot back.
}
