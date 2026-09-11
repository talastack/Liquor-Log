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
        case hadItBefore
        case tastedOnly
        case never

        public var label: String {
            switch self {
            case .onShelf: return "On your shelf"
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

        let onShelf = Set(holdings.filter { !$0.isFinished }.map(\.product.productId))
        let finished = Set(holdings.filter(\.isFinished).map(\.product.productId))
        let tasted = Set(tastings.map(\.product.productId))

        let rows = members.map { member -> Row in
            let id = member.productId
            let standing: Standing
            if onShelf.contains(id) {
                standing = .onShelf
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
