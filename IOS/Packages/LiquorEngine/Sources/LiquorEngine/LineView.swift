import Foundation

/// One brand's line, expression by expression, against what you have.
///
/// "Which Wellers do I have" is the aisle question one level up from the
/// shelf check: not this bottle, but this family. The catalogue knows the
/// expressions; the holdings and tastings know which you have, had, or have
/// only tasted. Laid side by side it reads as a fact about the collection,
/// and it is deliberately NOT a progress bar -- there is no "3 of 6" and no
/// percentage, because the research is clear that collection-as-score gets
/// an app rated 1, 1, 1. Somebody who wants to complete a line can count.
public enum LineView: Sendable {

    public enum Standing: String, Sendable, Hashable {
        case onShelf
        /// A sample on hand and no bottle.
        case sample
        case hadItBefore
        case tastedOnly
        case never

        public var label: String {
            switch self {
            case .onShelf: return "On your shelf"
            case .sample: return "Have a sample"
            case .hadItBefore: return "Had it"
            case .tastedOnly: return "Tasted"
            case .never: return "Never had it"
            }
        }
    }

    public struct Row: Hashable, Sendable, Identifiable {
        public let product: ProductIdentity
        public let standing: Standing
        public var id: String { product.productId }
    }

    public struct Line: Hashable, Sendable {
        public let distillery: String
        public let brand: String
        public let rows: [Row]
        public var isEmpty: Bool { rows.isEmpty }

        /// Expressions you have any standing on: owned, sampled, finished
        /// or tasted. "Had" in the sense collectors use it.
        public var hadCount: Int { rows.filter { $0.standing != .never }.count }

        /// "You have had 4 of the 7 releases the catalogue lists." A count,
        /// not a goal: the catalogue is what the app knows, not a checklist
        /// anybody set. Nil for a line of one, where it says nothing.
        public var completionLine: String? {
            guard rows.count > 1 else { return nil }
            let had = hadCount
            if had == 0 { return "None of the \(rows.count) releases the catalogue lists yet." }
            if had == rows.count { return "All \(rows.count) releases the catalogue lists." }
            return "\(had) of the \(rows.count) releases the catalogue lists."
        }

        /// What is left, in catalogue order.
        public var notYet: [ProductIdentity] {
            rows.filter { $0.standing == .never }.map(\.product)
        }
    }

    /// One line's count for a summary screen: "Weller · 4 of 7".
    public struct Completion: Hashable, Sendable, Identifiable {
        public let distillery: String
        public let brand: String
        public let had: Int
        public let total: Int
        public var id: String { distillery + "|" + brand }
        public var fraction: Double { total > 0 ? Double(had) / Double(total) : 0 }
    }

    /// Every line you have a standing on, against what the catalogue lists
    /// of it. Lines of one expression are left out -- "1 of 1" is not a
    /// fact about a collection -- and so are lines you have nothing of.
    /// Most complete first, then biggest, then by name, so the list holds
    /// still between launches.
    public static func completions(
        catalogue: [ProductIdentity],
        holdings: [Holding],
        tastings: [TastingRecord]
    ) -> [Completion] {
        let had = Set(holdings.map(\.product.productId) + tastings.map(\.product.productId))
        let byLine = Dictionary(grouping: catalogue, by: \.lineKey)
        return byLine.values.compactMap { members -> Completion? in
            guard members.count > 1, let first = members.first else { return nil }
            let count = members.filter { had.contains($0.productId) }.count
            guard count > 0 else { return nil }
            return Completion(
                distillery: first.distillery, brand: first.brand, had: count, total: members.count)
        }
        .sorted {
            if $0.fraction != $1.fraction { return $0.fraction > $1.fraction }
            if $0.total != $1.total { return $0.total > $1.total }
            return $0.brand.localizedCaseInsensitiveCompare($1.brand) == .orderedAscending
        }
    }

    /// Every catalogue product sharing the line of `product`, in catalogue
    /// order, with the person's standing on each. The product itself is
    /// included: the line view is where you are, not only what is missing.
    public static func line(
        of product: ProductIdentity,
        catalogue: [ProductIdentity],
        holdings: [Holding],
        tastings: [TastingRecord]
    ) -> Line {
        let key = product.lineKey
        let members = catalogue.filter { $0.lineKey == key }

        let live = holdings.filter { !$0.isFinished }
        let onShelf = Set(live.filter { !$0.isSample }.map(\.product.productId))
        let sampled = Set(live.filter(\.isSample).map(\.product.productId))
        let finished = Set(holdings.filter(\.isFinished).map(\.product.productId))
        let tasted = Set(tastings.map(\.product.productId))

        let rows = members.map { member -> Row in
            let id = member.productId
            let standing: Standing
            if onShelf.contains(id) {
                standing = .onShelf
            } else if sampled.contains(id) {
                standing = .sample
            } else if finished.contains(id) {
                standing = .hadItBefore
            } else if tasted.contains(id) {
                standing = .tastedOnly
            } else {
                standing = .never
            }
            return Row(product: member, standing: standing)
        }
        return Line(distillery: product.distillery, brand: product.brand, rows: rows)
    }
}
