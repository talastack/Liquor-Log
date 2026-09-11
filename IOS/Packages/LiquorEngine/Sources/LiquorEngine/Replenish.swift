import Foundation

/// Whether a pour that leaves a bottle nearly empty should offer to put it on
/// the wishlist.
///
/// This closes the loop between the two lists. The research's complaint about
/// every inventory app is drift -- *"I forget to add a bottle sometimes and
/// forget to delete one sometimes when it's finished"* -- and the moment a
/// bottle is about to go is the one moment somebody knows whether they want
/// another. Asking then, once, beats a wishlist they have to remember to
/// maintain.
///
/// **Once.** The offer fires only on the pour that crosses the line, never on
/// every pour after it, and never at all when the person already said they
/// would not buy it again. An app that nags on every pour of a dying bottle
/// is an app that gets its notifications turned off.
public enum Replenish: Sendable {

    /// Pours left at which a bottle counts as nearly gone. Two, because one
    /// is the last pour and the question needs asking before that.
    public static let lastPoursThreshold = 2

    public struct Offer: Hashable, Sendable {
        public let remainingPours: Int
        /// The sentence to ask with. Mentions what the person said last time
        /// when they said anything.
        public let text: String
    }

    /// Nil means do not ask.
    public static func offer(
        remainingBefore: Int,
        remainingAfter: Int,
        isOnWishlist: Bool,
        wouldRebuy: Bool?
    ) -> Offer? {
        // Only the crossing pour. Before was above the line, after is at or
        // below it. A bottle set to two pours by a fill reading and then
        // poured from is "after: 1, before: 2" -- still not a crossing, and
        // still not asked, because the reading was the moment it became
        // nearly gone and nobody was pouring then.
        guard remainingBefore > lastPoursThreshold,
              remainingAfter <= lastPoursThreshold
        else { return nil }

        guard !isOnWishlist else { return nil }
        if wouldRebuy == false { return nil }

        let left: String
        switch remainingAfter {
        case ..<1: left = "That was the last pour."
        case 1: left = "About one pour left."
        default: left = "About \(remainingAfter) pours left."
        }
        let said = wouldRebuy == true ? " You said you would buy it again." : ""
        return Offer(remainingPours: max(0, remainingAfter), text: left + said)
    }
}
