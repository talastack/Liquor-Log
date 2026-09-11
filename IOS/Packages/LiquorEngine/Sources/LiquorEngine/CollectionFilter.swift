import Foundation

/// Finding one bottle in a collection that has outgrown a scroll.
///
/// The research puts the point where somebody needs this app at about fifty
/// bottles -- below that they use their eyes -- and the bulk-onboarding paths
/// exist to get a shelf of two hundred in. A flat list is unusable at that
/// size, so the collection screen gets the same three things the shop does:
/// type a few letters, narrow by what the bottle is, and choose an order.
///
/// Pure and I/O-free. The screen turns its rows into `Row`s once and hands
/// them here on every keystroke, so this has to be cheap, and it is: one pass
/// over the rows, then a sort.
public enum CollectionFilter: Sendable {

    /// A bottle as the filter sees it. Flattened on purpose: the screen knows
    /// how to resolve names and products, the filter only compares.
    public struct Row: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let distillery: String?
        /// Anything else worth typing to find the bottle: release label,
        /// barrel and batch numbers, the store, where it is kept.
        public let extraSearchText: [String]
        public let classType: ClassType?
        public let productionType: ProductionType
        public let isBarrelProof: Bool
        public let isBottledInBond: Bool
        public let isStorePick: Bool
        public let isOpen: Bool
        public let isFinished: Bool
        public let storageLocation: String?
        public let addedAt: Date
        public let lastPouredAt: Date?
        public let rating: Int?
        /// 0...1. What is left, so "fullest" and "nearly gone" can sort.
        public let fillFraction: Double

        public init(
            id: String,
            name: String,
            distillery: String? = nil,
            extraSearchText: [String] = [],
            classType: ClassType? = nil,
            productionType: ProductionType = .unspecified,
            isBarrelProof: Bool = false,
            isBottledInBond: Bool = false,
            isStorePick: Bool = false,
            isOpen: Bool = false,
            isFinished: Bool = false,
            storageLocation: String? = nil,
            addedAt: Date,
            lastPouredAt: Date? = nil,
            rating: Int? = nil,
            fillFraction: Double = 1
        ) {
            self.id = id
            self.name = name
            self.distillery = distillery
            self.extraSearchText = extraSearchText
            self.classType = classType
            self.productionType = productionType
            self.isBarrelProof = isBarrelProof
            self.isBottledInBond = isBottledInBond
            self.isStorePick = isStorePick
            self.isOpen = isOpen
            self.isFinished = isFinished
            self.storageLocation = storageLocation
            self.addedAt = addedAt
            self.lastPouredAt = lastPouredAt
            self.rating = rating
            self.fillFraction = fillFraction
        }

        /// Every token somebody might type to find this bottle.
        var searchTokens: [String] {
            ([name, distillery ?? "", storageLocation ?? ""] + extraSearchText)
                .flatMap(\.matchTokens)
        }
    }

    /// `onShelf` is the default: what you own now. Finished bottles are
    /// archived history and only appear when asked for.
    public enum Status: String, Sendable, Hashable, CaseIterable {
        case onShelf
        case open
        case unopened
        case finished
        case any

        public var label: String {
            switch self {
            case .onShelf: return "On the shelf"
            case .any: return "Everything"
            case .open: return "Open"
            case .unopened: return "Unopened"
            case .finished: return "Finished"
            }
        }
    }

    /// What the bottle IS. Class and production are separate facts in the
    /// data model and they stay separate here: "single barrel" and "Kentucky
    /// Straight" are different questions, and somebody can ask both at once.
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case storePick
        case singleBarrel
        case smallBatch
        case barrelProof
        case bottledInBond
        case bourbon
        case rye
        case wheatWhiskey
        case scotch
        case notWhiskey

        public var label: String {
            switch self {
            case .storePick: return "Store pick"
            case .singleBarrel: return "Single barrel"
            case .smallBatch: return "Small batch"
            case .barrelProof: return "Barrel proof"
            case .bottledInBond: return "Bottled in bond"
            case .bourbon: return "Bourbon"
            case .rye: return "Rye"
            case .wheatWhiskey: return "Wheat whiskey"
            case .scotch: return "Scotch"
            case .notWhiskey: return "Not whiskey"
            }
        }

        func matches(_ row: Row) -> Bool {
            switch self {
            case .storePick: return row.isStorePick
            case .singleBarrel:
                return row.productionType == .singleBarrel || row.productionType == .singleCask
            case .smallBatch: return row.productionType == .smallBatch
            case .barrelProof: return row.isBarrelProof
            case .bottledInBond: return row.isBottledInBond
            case .bourbon:
                switch row.classType {
                case .bourbon, .straightBourbon, .kentuckyStraightBourbon, .blendOfStraightBourbon:
                    return true
                default:
                    return false
                }
            case .rye:
                return row.classType == .rye || row.classType == .straightRye
            case .wheatWhiskey:
                return row.classType == .wheatWhiskey || row.classType == .straightWheatWhiskey
            case .scotch:
                switch row.classType {
                case .singleMaltScotch, .blendedMaltScotch, .singleGrainScotch, .blendedScotch:
                    return true
                default:
                    return false
                }
            case .notWhiskey:
                guard let type = row.classType else { return false }
                return type.family != .whiskey
            }
        }
    }

    public enum Sort: String, Sendable, Hashable, CaseIterable {
        case newest
        case name
        case distillery
        case fullest
        case nearlyGone
        case lastPoured
        case rating

        public var label: String {
            switch self {
            case .newest: return "Newest"
            case .name: return "Name"
            case .distillery: return "Distillery"
            case .fullest: return "Fullest"
            case .nearlyGone: return "Nearly gone"
            case .lastPoured: return "Last poured"
            case .rating: return "Rating"
            }
        }
    }

    public struct Criteria: Hashable, Sendable {
        public var query: String
        public var status: Status
        /// Every selected kind must match -- "store pick" AND "barrel proof"
        /// narrows, it does not widen.
        public var kinds: Set<Kind>
        public var location: String?
        public var sort: Sort

        public init(
            query: String = "",
            status: Status = .onShelf,
            kinds: Set<Kind> = [],
            location: String? = nil,
            sort: Sort = .newest
        ) {
            self.query = query
            self.status = status
            self.kinds = kinds
            self.location = location
            self.sort = sort
        }

        public static let none = Criteria()

        /// True when anything narrows the list. The screen uses it to show a
        /// "clear" control only when there is something to clear.
        public var isNarrowing: Bool {
            !query.trimmingCharacters(in: .whitespaces).isEmpty
                || status != .onShelf
                || !kinds.isEmpty
                || location != nil
        }
    }

    // MARK: - Applying

    public static func apply(_ criteria: Criteria, to rows: [Row]) -> [Row] {
        let queryTokens = criteria.query.matchTokens
        let matching = rows.filter { row in
            matchesStatus(criteria.status, row)
                && criteria.kinds.allSatisfy { $0.matches(row) }
                && matchesLocation(criteria.location, row)
                && matchesQuery(queryTokens, row)
        }
        return sorted(matching, by: criteria.sort)
    }

    /// The distinct places bottles are kept, most-used first, for the
    /// location chips. Empty when nobody has recorded a location.
    public static func locations(in rows: [Row]) -> [String] {
        var counts: [String: Int] = [:]
        for row in rows {
            if let location = row.storageLocation?.trimmingCharacters(in: .whitespaces),
               !location.isEmpty {
                counts[location, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    /// Only the kinds at least one row would match. A chip that can never
    /// narrow anything is noise on a screen that exists to narrow.
    public static func availableKinds(in rows: [Row]) -> [Kind] {
        Kind.allCases.filter { kind in rows.contains { kind.matches($0) } }
    }

    private static func matchesStatus(_ status: Status, _ row: Row) -> Bool {
        switch status {
        case .onShelf: return !row.isFinished
        case .any: return true
        case .open: return row.isOpen && !row.isFinished
        case .unopened: return !row.isOpen && !row.isFinished
        case .finished: return row.isFinished
        }
    }

    private static func matchesLocation(_ location: String?, _ row: Row) -> Bool {
        guard let location else { return true }
        return row.storageLocation?.caseInsensitiveCompare(location) == .orderedSame
    }

    /// Every query token prefixes some token of the row, the same rule the
    /// shop search uses, so "eli bar" finds Elijah Craig Barrel Proof here as
    /// well as there.
    private static func matchesQuery(_ queryTokens: [String], _ row: Row) -> Bool {
        guard !queryTokens.isEmpty else { return true }
        let haystack = row.searchTokens
        return queryTokens.allSatisfy { token in
            haystack.contains { $0.hasPrefix(token) }
        }
    }

    private static func sorted(_ rows: [Row], by sort: Sort) -> [Row] {
        switch sort {
        case .newest:
            return rows.sorted { $0.addedAt > $1.addedAt }
        case .name:
            return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .distillery:
            return rows.sorted {
                let a = $0.distillery ?? $0.name
                let b = $1.distillery ?? $1.name
                if a.caseInsensitiveCompare(b) == .orderedSame {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
        case .fullest:
            return rows.sorted { $0.fillFraction > $1.fillFraction }
        case .nearlyGone:
            // Finished bottles are not "nearly gone", they are gone; they go
            // last so the top of the list is bottles still worth pouring.
            return rows.sorted {
                if $0.isFinished != $1.isFinished { return !$0.isFinished }
                return $0.fillFraction < $1.fillFraction
            }
        case .lastPoured:
            // Most recently poured first; never poured last.
            return rows.sorted {
                switch ($0.lastPouredAt, $1.lastPouredAt) {
                case let (a?, b?): return a > b
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return $0.addedAt > $1.addedAt
                }
            }
        case .rating:
            // Highest first; unrated last.
            return rows.sorted {
                switch ($0.rating, $1.rating) {
                case let (a?, b?): return a == b ? $0.addedAt > $1.addedAt : a > b
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return $0.addedAt > $1.addedAt
                }
            }
        }
    }
}
