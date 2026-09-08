import Foundation

/// Does it drink like its proof?
///
/// The question behind "do I taste 62.6%": a barrel-proof bourbon that goes
/// down easy is a different bottle from one that scorches at the same strength,
/// and the number on the label does not tell you which you have. Over a
/// collection it is one of the more useful things to know — it is why people
/// keep a cask-strength bottle they can drink neat.
///
/// Heat is recorded on a 1-5 scale because that is the resolution a person
/// actually has. Anything finer would be invented precision.
public enum PerceivedProof: Sendable {

    /// How hot it actually drank.
    public enum Heat: Int, Sendable, Hashable, CaseIterable, Codable {
        case gentle = 1
        case warm = 2
        case firm = 3
        case hot = 4
        case scorching = 5

        public var label: String {
            switch self {
            case .gentle: return "Gentle"
            case .warm: return "Warm"
            case .firm: return "Firm"
            case .hot: return "Hot"
            case .scorching: return "Scorching"
            }
        }
    }

    public enum Verdict: String, Sendable, Hashable, CaseIterable {
        /// Drinks softer than the label says. The compliment.
        case drinksBelowItsProof
        case drinksAtItsProof
        /// Harsher than the strength alone would explain.
        case drinksAboveItsProof

        public var label: String {
            switch self {
            case .drinksBelowItsProof: return "Drinks below its proof"
            case .drinksAtItsProof: return "Drinks about right"
            case .drinksAboveItsProof: return "Drinks above its proof"
            }
        }
    }

    /// What a given strength usually feels like, before the whiskey gets a say.
    ///
    /// Bands rather than a formula: the step from 40% to 45% is barely
    /// noticeable and the step from 60% to 65% is not, so a linear map would be
    /// wrong at both ends.
    public static func expectedHeat(for abv: ABV) -> Heat {
        switch abv.percent {
        case ..<43: return .gentle
        case ..<48: return .warm
        case ..<54: return .firm
        case ..<60: return .hot
        default: return .scorching
        }
    }

    public struct Result: Hashable, Sendable {
        public let abv: ABV
        public let expected: Heat
        public let actual: Heat
        public let verdict: Verdict
        /// Negative means softer than expected.
        public let difference: Int

        public var headline: String { verdict.label }

        public var summary: String {
            let proof = String(format: "%.1f", abv.proof)
            switch verdict {
            case .drinksBelowItsProof:
                return "You would not guess \(proof) proof from tasting it."
            case .drinksAtItsProof:
                return "Tastes about like \(proof) proof should."
            case .drinksAboveItsProof:
                return "Harsher than \(proof) proof alone would explain — worth a "
                    + "few drops of water."
            }
        }
    }

    public static func compare(abv: ABV, felt: Heat) -> Result {
        let expected = expectedHeat(for: abv)
        let difference = felt.rawValue - expected.rawValue

        let verdict: Verdict
        if difference <= -1 {
            verdict = .drinksBelowItsProof
        } else if difference >= 1 {
            verdict = .drinksAboveItsProof
        } else {
            verdict = .drinksAtItsProof
        }

        return Result(
            abv: abv, expected: expected, actual: felt,
            verdict: verdict, difference: difference)
    }
}
