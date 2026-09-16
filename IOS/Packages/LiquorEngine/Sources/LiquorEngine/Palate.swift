import Foundation

/// What your own tastings say about you.
///
/// Not a personality, and not a recommendation engine: the words you reach
/// for most, and how you rate by class, by strength and by mashbill --
/// averages over your ratings, each shown with the count it rests on, and
/// nothing said until there are enough to say it. Three ratings a side is
/// the floor for a comparison; two is a coincidence.
///
/// Everything here counts opinions, never drinks. A tasting is one
/// opinion however large the pour, and the profile does not move for
/// tasting the same bottle again except that the newer opinion counts too.
public enum Palate: Sendable {

    /// One tasting, reduced to what the profile needs.
    public struct Tasting: Hashable, Sendable {
        /// The product, so a blind rating and a sighted one of the same
        /// whiskey can be paired.
        public let productId: String?
        /// Rated without knowing which bottle it was.
        public let isBlind: Bool
        public let classType: ClassType?
        public let abv: Double?
        /// True for a wheated recipe, false for another bourbon recipe,
        /// nil when the product is not a bourbon or the recipe is unknown.
        public let isWheated: Bool?
        public let rating: Int?
        /// 1...5, how hot it drank.
        public let perceivedHeat: Int?
        public let finishSeconds: Int?
        public let wouldRebuy: Bool?
        /// Flavour-wheel keys picked on any stage.
        public let descriptors: [String]

        public init(
            productId: String? = nil, isBlind: Bool = false,
            classType: ClassType? = nil, abv: Double? = nil, isWheated: Bool? = nil,
            rating: Int? = nil, perceivedHeat: Int? = nil, finishSeconds: Int? = nil,
            wouldRebuy: Bool? = nil, descriptors: [String] = []
        ) {
            self.productId = productId; self.isBlind = isBlind
            self.classType = classType; self.abv = abv; self.isWheated = isWheated
            self.rating = rating; self.perceivedHeat = perceivedHeat
            self.finishSeconds = finishSeconds; self.wouldRebuy = wouldRebuy
            self.descriptors = descriptors
        }
    }

    /// An average rating for a group, with the count it rests on.
    public struct Line: Hashable, Sendable, Identifiable {
        public let label: String
        public let count: Int
        public let average: Double
        public var id: String { label }
        public var averageText: String { String(format: "%.1f", average) }
    }

    public struct Word: Hashable, Sendable, Identifiable {
        public let key: String
        public let count: Int
        public var id: String { key }
    }

    public struct Profile: Hashable, Sendable {
        public let tastings: Int
        public let rated: Int
        /// Most used first; ties alphabetical.
        public let words: [Word]
        /// Classes with at least `minimum` ratings, highest average first.
        public let byClass: [Line]
        /// Strength bands with at least `minimum` ratings, strongest first.
        public let byStrength: [Line]
        public let wheated: Line?
        public let otherBourbon: Line?
        public let averageFinishSeconds: Int?
        /// Average rating when it drank hot (4-5) and when it drank easy (1-2).
        public let whenHot: Line?
        public let whenEasy: Line?
        /// Of the tastings that answered, the share that would buy again.
        public let rebuyShare: Double?
        public let rebuyAnswered: Int

        /// Label bias: over products you rated both blind and knowing the
        /// bottle, the average of (sighted − blind). Positive means the
        /// label adds points. Nil under `minimum` pairs.
        public let labelBias: Double?
        public let labelBiasPairs: Int

        public var isEmpty: Bool { tastings == 0 }
    }

    /// Ratings a side before a comparison is drawn.
    public static let minimum = 3

    public static func profile(_ tastings: [Tasting]) -> Profile {
        let rated = tastings.filter { $0.rating != nil }

        var wordCounts: [String: Int] = [:]
        for tasting in tastings {
            for key in Set(tasting.descriptors) { wordCounts[key, default: 0] += 1 }
        }
        let words = wordCounts
            .map { Word(key: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.key < $1.key }

        let byClass = lines(rated.compactMap { t in t.classType.map { ($0.label, t.rating!) } })
            .sorted { $0.average != $1.average ? $0.average > $1.average : $0.label < $1.label }
        let bands = ["80–89 proof", "90–99 proof", "100–114 proof", "115 proof and up"]
        let byStrength = lines(rated.compactMap { t in t.abv.map { (band($0), t.rating!) } })
            .sorted { (bands.firstIndex(of: $0.label) ?? 0) > (bands.firstIndex(of: $1.label) ?? 0) }

        let wheated = line("Wheated bourbon", rated.filter { $0.isWheated == true }.map { $0.rating! })
        let other = line("Other bourbon", rated.filter { $0.isWheated == false }.map { $0.rating! })

        let finishes = tastings.compactMap(\.finishSeconds).filter { $0 > 0 }
        let finish = finishes.count >= minimum
            ? Int((Double(finishes.reduce(0, +)) / Double(finishes.count)).rounded()) : nil

        let hot = line("Drank hot", rated.filter { ($0.perceivedHeat ?? 0) >= 4 }.map { $0.rating! })
        let easy = line("Drank easy", rated.filter { (1...2).contains($0.perceivedHeat ?? 0) }.map { $0.rating! })

        let answered = tastings.compactMap(\.wouldRebuy)
        let rebuy = answered.count >= minimum
            ? Double(answered.filter { $0 }.count) / Double(answered.count) : nil

        // One pair per product: the average of its sighted ratings against
        // the average of its blind ones, so a bottle tasted often does not
        // outvote one tasted twice.
        var sighted: [String: [Int]] = [:]
        var blind: [String: [Int]] = [:]
        for t in rated {
            guard let id = t.productId, let rating = t.rating else { continue }
            if t.isBlind { blind[id, default: []].append(rating) } else { sighted[id, default: []].append(rating) }
        }
        let differences = sighted.compactMap { id, seen -> Double? in
            guard let hidden = blind[id] else { return nil }
            return mean(seen) - mean(hidden)
        }
        let bias = differences.count >= minimum ? differences.reduce(0, +) / Double(differences.count) : nil

        return Profile(
            tastings: tastings.count, rated: rated.count, words: words,
            byClass: byClass, byStrength: byStrength,
            wheated: wheated, otherBourbon: other,
            averageFinishSeconds: finish, whenHot: hot, whenEasy: easy,
            rebuyShare: rebuy, rebuyAnswered: answered.count,
            labelBias: bias, labelBiasPairs: differences.count)
    }

    static func mean(_ values: [Int]) -> Double {
        Double(values.reduce(0, +)) / Double(values.count)
    }

    /// What the profile says, in sentences, each only when the numbers
    /// behind it clear the floor. Descriptor keys are given as labels by
    /// the caller, since the wheel lives outside the engine.
    public static func sentences(_ p: Profile, label: (String) -> String) -> [String] {
        var out: [String] = []
        let words = p.words.filter { $0.count >= 2 }.prefix(3)
        if words.count == 3 {
            let names = words.map { label($0.key) }
            out.append("You reach for \(names[0]), \(names[1]) and \(names[2]) most.")
        }
        if p.byClass.count >= 2, let top = p.byClass.first, let bottom = p.byClass.last, top.average > bottom.average {
            out.append("\(top.label) rates highest with you: \(top.averageText) on average over \(top.count), against \(bottom.averageText) for \(bottom.label).")
        }
        if p.byStrength.count >= 2, let strong = p.byStrength.first, let mild = p.byStrength.last {
            if strong.average > mild.average + 0.5 {
                out.append("The stronger the better: \(strong.label) averages \(strong.averageText) with you, \(mild.label) \(mild.averageText).")
            } else if mild.average > strong.average + 0.5 {
                out.append("Proof does not buy points with you: \(mild.label) averages \(mild.averageText), \(strong.label) \(strong.averageText).")
            } else {
                out.append("Strength does not move your ratings: \(strong.label) and \(mild.label) both sit near \(strong.averageText).")
            }
        }
        if let w = p.wheated, let o = p.otherBourbon {
            if w.average > o.average + 0.5 {
                out.append("Wheated bourbons rate \(w.averageText) with you, other bourbons \(o.averageText).")
            } else if o.average > w.average + 0.5 {
                out.append("Other bourbons rate \(o.averageText) with you, wheated \(w.averageText).")
            }
        }
        if let hot = p.whenHot, let easy = p.whenEasy {
            if easy.average > hot.average + 0.5 {
                out.append("Heat costs a bottle points with you: \(easy.averageText) when it drank easy, \(hot.averageText) when it drank hot.")
            } else if hot.average > easy.average + 0.5 {
                out.append("Heat does not put you off: \(hot.averageText) when it drank hot, \(easy.averageText) when it drank easy.")
            }
        }
        if let seconds = p.averageFinishSeconds {
            out.append("A finish runs about \(seconds) seconds by your count.")
        }
        if let share = p.rebuyShare {
            out.append("You would buy again \(Int((share * 10).rounded())) of every 10 you rated.")
        }
        if let bias = p.labelBias {
            let pairs = "\(p.labelBiasPairs) bottles rated both ways"
            if bias >= 0.5 {
                out.append(String(format: "Knowing the label adds %.1f points: bottles you rated blind and again knowing what they were came in higher the second time (%@).", bias, pairs))
            } else if bias <= -0.5 {
                out.append(String(format: "The label costs %.1f points with you: bottles rated blind came in higher than the same bottles rated knowing what they were (%@).", -bias, pairs))
            } else {
                out.append("The label does not move you: blind and knowing, you rate the same bottles about the same (\(pairs)).")
            }
        }
        return out
    }

    // MARK: - Pieces

    static func band(_ abv: Double) -> String {
        switch abv {
        case ..<45: return "80–89 proof"
        case ..<50: return "90–99 proof"
        case ..<57.5: return "100–114 proof"
        default: return "115 proof and up"
        }
    }

    static func lines(_ pairs: [(String, Int)]) -> [Line] {
        var groups: [String: [Int]] = [:]
        for (label, rating) in pairs { groups[label, default: []].append(rating) }
        return groups.compactMap { line($0.key, $0.value) }
    }

    static func line(_ label: String, _ ratings: [Int]) -> Line? {
        guard ratings.count >= minimum else { return nil }
        return Line(label: label, count: ratings.count,
                    average: Double(ratings.reduce(0, +)) / Double(ratings.count))
    }
}
