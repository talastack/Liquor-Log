import Foundation

/// Who made it and what it is, at the level the catalog records.
///
/// `brand` is the line -- "Elijah Craig" -- and `expression` is the release
/// within it -- "Small Batch", "Barrel Proof", "18 Year". Two products sharing a
/// distillery and brand are the same line; differing in expression makes them
/// different whiskey. That distinction is the entire point of this file.
public struct ProductIdentity: Hashable, Sendable {
    public let productId: String
    public let distillery: String
    public let brand: String
    public let expression: String
    public let classType: ClassType
    public let productionType: ProductionType

    public init(
        productId: String,
        distillery: String,
        brand: String,
        expression: String,
        classType: ClassType,
        productionType: ProductionType = .unspecified
    ) {
        self.productId = productId
        self.distillery = distillery
        self.brand = brand
        self.expression = expression
        self.classType = classType
        self.productionType = productionType
    }

    /// Identity of the product line, ignoring which expression it is.
    public var lineKey: String {
        "\(distillery.normalizedForMatching())|\(brand.normalizedForMatching())"
    }

    public var displayName: String {
        expression.isEmpty ? brand : "\(brand) \(expression)"
    }
}

/// A bottle you have or had. `releaseLabel` is the batch, pick or barrel that
/// distinguishes it from another bottle of the same product.
public struct Holding: Hashable, Sendable {
    public let bottleId: String
    public let product: ProductIdentity
    public let releaseLabel: String?
    public let isOpen: Bool
    public let isFinished: Bool

    public init(
        bottleId: String,
        product: ProductIdentity,
        releaseLabel: String? = nil,
        isOpen: Bool = false,
        isFinished: Bool = false
    ) {
        self.bottleId = bottleId
        self.product = product
        self.releaseLabel = releaseLabel
        self.isOpen = isOpen
        self.isFinished = isFinished
    }
}

/// A tasting. Note it carries a product rather than a bottle: you can taste
/// something at a bar and never own it, which is a state the shelf check has to
/// be able to report.
public struct TastingRecord: Hashable, Sendable {
    public let tastingId: String
    public let product: ProductIdentity
    public let tastedAt: Date
    public let rating: Int?
    public let wouldRebuy: Bool?
    public let liked: String?
    public let disliked: String?

    public init(
        tastingId: String,
        product: ProductIdentity,
        tastedAt: Date,
        rating: Int? = nil,
        wouldRebuy: Bool? = nil,
        liked: String? = nil,
        disliked: String? = nil
    ) {
        self.tastingId = tastingId
        self.product = product
        self.tastedAt = tastedAt
        self.rating = rating
        self.wouldRebuy = wouldRebuy
        self.liked = liked
        self.disliked = disliked
    }
}

/// The answer to "do I have this", standing in a shop with the bottle in hand.
///
/// **Ownership and tasting are independent, not a sequence.** You can have
/// tasted something at a bar and never owned it, and own something unopened you
/// have never tried. `headline` therefore describes ownership only; the tasting
/// fields are populated regardless of what the headline says, and the card shows
/// both.
public struct ShelfCheckResult: Sendable {
    public let product: ProductIdentity
    public let headline: Headline
    public let onShelf: [Holding]
    public let finished: [Holding]
    public let tastings: [TastingRecord]
    /// Bottles and tastings from the same line but a *different* expression.
    public let sameLine: [ProductIdentity]
    public let isOnWishlist: Bool

    public enum Headline: String, Sendable, Hashable {
        case neverHadIt
        /// You own or have tried this line, but not this release. The answer a
        /// flat "do I own this brand" lookup gets wrong.
        case haveTheLineNotThisRelease
        case onYourShelf
        case hadItBefore
        case tastedNeverOwned
    }

    public var hasTasted: Bool { !tastings.isEmpty }

    /// Most recent tasting, which is what the card leads with -- your current
    /// opinion beats your first one.
    public var latestTasting: TastingRecord? {
        tastings.max { $0.tastedAt < $1.tastedAt }
    }

    public var bestRating: Int? {
        tastings.compactMap(\.rating).max()
    }

    public var openBottleCount: Int { onShelf.filter(\.isOpen).count }
}

public enum ShelfCheck: Sendable {

    /// Pure function over what the repositories hand it. No I/O, so the whole
    /// verdict is testable without a database or a network -- which matters
    /// because this screen has to work in a shop with no signal.
    public static func evaluate(
        product: ProductIdentity,
        holdings: [Holding],
        tastings allTastings: [TastingRecord],
        wishlistProductIds: Set<String> = []
    ) -> ShelfCheckResult {
        let exactHoldings = holdings.filter { $0.product.productId == product.productId }
        let onShelf = exactHoldings.filter { !$0.isFinished }
        let finished = exactHoldings.filter(\.isFinished)

        let tastings = allTastings.filter { $0.product.productId == product.productId }

        // Same line, different expression. Deduplicated and ordered so the card
        // is stable between launches.
        let lineProducts = (holdings.map(\.product) + allTastings.map(\.product))
            .filter { $0.lineKey == product.lineKey && $0.productId != product.productId }
        var seen = Set<String>()
        let sameLine = lineProducts
            .filter { seen.insert($0.productId).inserted }
            .sorted { $0.displayName < $1.displayName }

        let headline: ShelfCheckResult.Headline
        if !onShelf.isEmpty {
            headline = .onYourShelf
        } else if !finished.isEmpty {
            headline = .hadItBefore
        } else if !tastings.isEmpty {
            headline = .tastedNeverOwned
        } else if !sameLine.isEmpty {
            headline = .haveTheLineNotThisRelease
        } else {
            headline = .neverHadIt
        }

        return ShelfCheckResult(
            product: product,
            headline: headline,
            onShelf: onShelf,
            finished: finished,
            tastings: tastings,
            sameLine: sameLine,
            isOnWishlist: wishlistProductIds.contains(product.productId)
        )
    }
}
