import Foundation

/// Four Roses recipe codes: `OESQ`, `OBSV`, and the eight others.
///
/// Four letters, each fixed in meaning:
///
/// ```
/// O E S Q
/// | | | +-- yeast strain      V K O Q F
/// | | +---- straight whiskey  always S
/// | +------ mashbill          B or E
/// +-------- Four Roses        always O
/// ```
///
/// Exactly ten codes exist. An unrecognised string returns nil rather than a
/// partial guess -- decoding three of four letters and inventing the fourth is
/// worse than saying nothing, because the user cannot tell which happened.
public struct RecipeCode: Hashable, Sendable, Codable, CustomStringConvertible {

    public enum Mashbill: String, Sendable, CaseIterable, Codable {
        case b = "B"
        case e = "E"

        /// Percentages of corn, rye and malted barley.
        public var grains: (corn: Int, rye: Int, maltedBarley: Int) {
            switch self {
            case .b: return (60, 35, 5)
            case .e: return (75, 20, 5)
            }
        }

        public var ryePercent: Int { grains.rye }

        public var summary: String {
            let g = grains
            return "\(g.corn)% corn, \(g.rye)% rye, \(g.maltedBarley)% malted barley"
        }
    }

    public enum Yeast: String, Sendable, CaseIterable, Codable {
        case v = "V"
        case k = "K"
        case o = "O"
        case q = "Q"
        case f = "F"

        /// The distillery's own descriptors.
        public var character: String {
            switch self {
            case .v: return "Delicate fruit"
            case .k: return "Slight spice"
            case .o: return "Rich fruit"
            case .q: return "Floral essence"
            case .f: return "Herbal"
            }
        }
    }

    public let mashbill: Mashbill
    public let yeast: Yeast

    public init(mashbill: Mashbill, yeast: Yeast) {
        self.mashbill = mashbill
        self.yeast = yeast
    }

    /// Parses a four-letter code. Case- and whitespace-insensitive; nil for
    /// anything that is not one of the ten.
    public init?(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 4 else { return nil }

        let letters = Array(code)
        guard letters[0] == "O", letters[2] == "S" else { return nil }
        guard let mashbill = Mashbill(rawValue: String(letters[1])),
              let yeast = Yeast(rawValue: String(letters[3]))
        else { return nil }

        self.mashbill = mashbill
        self.yeast = yeast
    }

    public var description: String { "O\(mashbill.rawValue)S\(yeast.rawValue)" }
    public var code: String { description }

    /// All ten, for the picker and for the catalog validator.
    public static let all: [RecipeCode] = Mashbill.allCases.flatMap { mashbill in
        Yeast.allCases.map { RecipeCode(mashbill: mashbill, yeast: $0) }
    }

    public static let validCodes: Set<String> = Set(all.map(\.code))
}
