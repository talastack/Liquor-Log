import Foundation

/// What the collection cost, for the people who want the number.
///
/// Two findings pull in opposite directions and both are real.
///
/// It is wanted, for recall and for insurance. And it causes genuine distress:
/// *"I added my collection to OnlyDrams when I had 50 bottles and was taken
/// aback by the value. Now I have at least double that number and **I don't
/// want to know**."* / *"Only thing I don't include is price — guaranteed heart
/// attack if I faced the reality of what I've spent."*
///
/// So the number exists and is **off by default**. It is never shown as a
/// side effect of opening a screen; somebody has to ask for it.
///
/// It is also strictly **what you paid**, never what a bottle is now worth.
/// Apps that ship their own secondary-market estimate get checked against
/// reality and lose: *"the fair price on a ton of bottles is absolute horse
/// shit making the app useless as a guide."* We do not have that data, we
/// cannot keep it current, and being wrong about it costs more than being
/// silent.
public enum CollectionValue: Sendable {

    /// One bottle's contribution.
    public struct Holding: Hashable, Sendable {
        public let purchasePriceCents: Int?
        /// Killed bottles are excluded from the shelf total. See `Total`.
        public let isFinished: Bool

        public init(purchasePriceCents: Int?, isFinished: Bool) {
            self.purchasePriceCents = purchasePriceCents
            self.isFinished = isFinished
        }
    }

    /// The total, with enough context that it cannot be read as more than it is.
    public struct Total: Hashable, Sendable {
        /// Sum of purchase prices for bottles still on the shelf.
        public let cents: Int
        public let bottlesCounted: Int
        /// Bottles on the shelf with no price recorded. These are why the
        /// figure is a floor and not a total.
        public let bottlesWithoutPrice: Int

        public init(cents: Int, bottlesCounted: Int, bottlesWithoutPrice: Int) {
            self.cents = cents
            self.bottlesCounted = bottlesCounted
            self.bottlesWithoutPrice = bottlesWithoutPrice
        }

        /// True when some bottles carry no price, which makes the sum a
        /// lower bound rather than an answer.
        public var isPartial: Bool { bottlesWithoutPrice > 0 }

        /// Never optional, and never omitted when the figure is partial.
        public var caveat: String {
            let base = "What you paid, not what it is worth."
            guard isPartial else { return base }
            let bottles = bottlesWithoutPrice == 1 ? "1 bottle has" : "\(bottlesWithoutPrice) bottles have"
            return base + " \(bottles) no price recorded, so the real figure is higher."
        }
    }

    /// **Off until asked for.** The one place this default is written down.
    public static let shownByDefault = false

    /// Totals what is currently on the shelf.
    ///
    /// Finished bottles are excluded on purpose. The number people want is for
    /// insurance and for recall — both are about what is in the house. Lifetime
    /// spend is the figure the quotes above are running away from, and this
    /// app has no reason to compute it.
    public static func onTheShelf(_ holdings: [Holding]) -> Total {
        let live = holdings.filter { !$0.isFinished }
        let priced = live.compactMap(\.purchasePriceCents)
        return Total(
            cents: priced.reduce(0, +),
            bottlesCounted: priced.count,
            bottlesWithoutPrice: live.count - priced.count)
    }
}
