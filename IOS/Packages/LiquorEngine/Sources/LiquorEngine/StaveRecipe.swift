import Foundation

/// A Maker's Mark Private Select stave recipe.
///
/// Private Select is Maker's Mark's store-pick programme, and its picks are
/// not barrels: every one starts as fully matured Maker's, then ten oak
/// staves are chosen from five kinds and finished into the barrel for nine
/// weeks in a cold cellar. The label prints the ten. Two picks with
/// different staves are different whiskeys with one name, which is the same
/// fact about barrel-level identity this whole app is built on.
///
/// The five kinds are Maker's own, with the flavours Maker's says each
/// brings; the counts are what the label says. A recipe must total ten,
/// because that is the rule of the programme, and one that does not is a
/// typo rather than a bottle.
public struct StaveRecipe: Hashable, Sendable, Codable {

    public enum Stave: String, Sendable, Hashable, CaseIterable, Codable {
        case bakedAmericanPure2 = "P2"
        case searedFrenchCuvee = "Cu"
        case makers46 = "46"
        case roastedFrenchMocha = "Mo"
        case toastedFrenchSpice = "Sp"

        public var name: String {
            switch self {
            case .bakedAmericanPure2: return "Baked American Pure 2"
            case .searedFrenchCuvee: return "Seared French Cuvée"
            case .makers46: return "Maker's 46"
            case .roastedFrenchMocha: return "Roasted French Mocha"
            case .toastedFrenchSpice: return "Toasted French Spice"
            }
        }

        /// What each stave is designed to bring, as the Private Selection
        /// programme describes it. Maker's own site states only that there
        /// are five staves and ten per barrel; the per-stave descriptions
        /// below are the programme's stave cards as reported by two
        /// independent write-ups (both read 15 September 2026), which agree:
        /// https://www.bourbonguy.com/blog/2017/12/12/makers-mark-private-select-part-1
        /// https://www.bourbonbanter.com/makers-mark-private-select-review-randalls-wine-spirits/
        public var character: String {
            switch self {
            case .bakedAmericanPure2: return "oak, vanilla, caramel and sweetness"
            case .searedFrenchCuvee: return "butterscotch, caramel, toasted oak and nuttiness"
            case .makers46: return "spicy vanilla -- the same stave as Maker's 46"
            case .roastedFrenchMocha: return "dark chocolate, coffee and char"
            case .toastedFrenchSpice: return "fruit and baking spice"
            }
        }
    }

    /// The total the programme fixes.
    public static let staveCount = 10

    public let counts: [Stave: Int]

    /// Nil unless the counts are non-negative and total ten.
    public init?(counts: [Stave: Int]) {
        guard counts.values.allSatisfy({ $0 >= 0 }),
              counts.values.reduce(0, +) == Self.staveCount
        else { return nil }
        self.counts = counts.filter { $0.value > 0 }
    }

    public func count(of stave: Stave) -> Int { counts[stave] ?? 0 }

    /// The compact form the community writes: "P2×3 Cu×2 46×2 Mo×1 Sp×2",
    /// in the label's own order.
    public var code: String {
        Stave.allCases.compactMap { stave in
            let n = count(of: stave)
            return n > 0 ? "\(stave.rawValue)×\(n)" : nil
        }
        .joined(separator: " ")
    }

    /// Reads the compact form back, tolerating "x" for "×", commas, and
    /// missing zeros. Nil when it does not total ten.
    public init?(_ raw: String) {
        var counts: [Stave: Int] = [:]
        let cleaned = raw.replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: ",", with: " ")
        guard let regex = try? NSRegularExpression(pattern: #"(P2|CU|46|MO|SP)\s*[xX]\s*(\d{1,2})"#, options: .caseInsensitive)
        else { return nil }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        for match in regex.matches(in: cleaned, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: cleaned),
                  let nRange = Range(match.range(at: 2), in: cleaned),
                  let n = Int(cleaned[nRange])
            else { continue }
            let key = cleaned[keyRange].uppercased()
            let stave: Stave?
            switch key {
            case "P2": stave = .bakedAmericanPure2
            case "CU": stave = .searedFrenchCuvee
            case "46": stave = .makers46
            case "MO": stave = .roastedFrenchMocha
            case "SP": stave = .toastedFrenchSpice
            default: stave = nil
            }
            if let stave { counts[stave, default: 0] += n }
        }
        self.init(counts: counts)
    }

    /// The staves that dominate, most first. A recipe of ten 46 staves
    /// reads "all Maker's 46"; a spread reads as its top two.
    public var leaning: String {
        let ordered = Stave.allCases
            .map { ($0, count(of: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 == $1.1 ? Stave.allCases.firstIndex(of: $0.0)! < Stave.allCases.firstIndex(of: $1.0)! : $0.1 > $1.1 }
        guard let top = ordered.first else { return "" }
        if top.1 == Self.staveCount { return "All \(top.0.name): \(top.0.character)." }
        if ordered.count == 1 { return "\(top.0.name): \(top.0.character)." }
        let second = ordered[1]
        if top.1 == second.1 {
            return "Led equally by \(top.0.name) and \(second.0.name): \(top.0.character); \(second.0.character)."
        }
        return "Led by \(top.0.name) (\(top.1) of 10): \(top.0.character). Then \(second.0.name): \(second.0.character)."
    }

    /// Two recipes side by side: the staves they share, and where each one
    /// has more.
    public struct Comparison: Hashable, Sendable {
        public let shared: [Stave]
        /// Staves where the first recipe has more, with the difference.
        public let moreInFirst: [(Stave, Int)]
        public let moreInSecond: [(Stave, Int)]
        public var isIdentical: Bool { moreInFirst.isEmpty && moreInSecond.isEmpty }

        public static func == (a: Comparison, b: Comparison) -> Bool {
            a.shared == b.shared
                && a.moreInFirst.map { "\($0.0.rawValue)\($0.1)" } == b.moreInFirst.map { "\($0.0.rawValue)\($0.1)" }
                && a.moreInSecond.map { "\($0.0.rawValue)\($0.1)" } == b.moreInSecond.map { "\($0.0.rawValue)\($0.1)" }
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(shared)
            hasher.combine(moreInFirst.map { "\($0.0.rawValue)\($0.1)" })
            hasher.combine(moreInSecond.map { "\($0.0.rawValue)\($0.1)" })
        }

        /// "Identical recipes." / "Yours leans more to Roasted French Mocha
        /// (+2); the other to Toasted French Spice (+2)."
        public var text: String {
            if isIdentical { return "Identical recipes." }
            var parts: [String] = []
            if let first = moreInFirst.first {
                parts.append("The first leans more to \(first.0.name) (+\(first.1))")
            }
            if let second = moreInSecond.first {
                parts.append("the second to \(second.0.name) (+\(second.1))")
            }
            return parts.joined(separator: "; ") + "."
        }
    }

    public static func compare(_ a: StaveRecipe, _ b: StaveRecipe) -> Comparison {
        var shared: [Stave] = []
        var first: [(Stave, Int)] = []
        var second: [(Stave, Int)] = []
        for stave in Stave.allCases {
            let x = a.count(of: stave), y = b.count(of: stave)
            if x > 0, y > 0 { shared.append(stave) }
            if x > y { first.append((stave, x - y)) }
            if y > x { second.append((stave, y - x)) }
        }
        return Comparison(
            shared: shared,
            moreInFirst: first.sorted { $0.1 > $1.1 },
            moreInSecond: second.sorted { $0.1 > $1.1 })
    }
}
