import Foundation

/// Bottles that are the same thing: three of one store pick, two backups of
/// a standard release.
///
/// Picks are bought in multiples -- a group that selects a barrel takes a
/// case -- and every bottle is still its own record with its own fill and
/// its own open date, which is the whole model. What the screen needs is to
/// know that these three cards are one thing, so it can say "1 of 3" on each
/// and list the others on the bottle.
///
/// Two bottles are the same thing when they are the same product AND the
/// same barrel AND the same batch. Two bottles of Elijah Craig Barrel Proof
/// from different batches are not multiples; they are different whiskeys
/// with one name, which is the point of tracking batches at all.
public enum Multiples: Sendable {

    public struct Bottle: Hashable, Sendable {
        public let id: String
        /// The product, or for a typed-in bottle its custom entry id or name.
        public let productKey: String
        public let barrel: String?
        public let batch: String?
        public let isFinished: Bool

        public init(id: String, productKey: String, barrel: String? = nil, batch: String? = nil, isFinished: Bool = false) {
            self.id = id
            self.productKey = productKey
            self.barrel = barrel
            self.batch = batch
            self.isFinished = isFinished
        }

        var groupKey: String {
            [productKey, barrel ?? "", batch ?? ""]
                .map { $0.normalizedForMatching() }
                .joined(separator: "|")
        }
    }

    /// One bottle's place among its multiples. `count` is the bottles still
    /// on the shelf, `position` this bottle's 1-based place among them in
    /// the order given, and `siblings` the other on-shelf ids.
    public struct Place: Hashable, Sendable {
        public let count: Int
        public let position: Int
        public let siblings: [String]
        public var isOneOfSeveral: Bool { count > 1 }

        /// "1 of 3", or nil when there is only the one.
        public var label: String? {
            isOneOfSeveral ? "\(position) of \(count)" : nil
        }
    }

    /// Places for every on-shelf bottle. Finished bottles neither count nor
    /// get a place: a killed bottle is history, and "1 of 3" on a shelf with
    /// one bottle and two empties is wrong in the way that matters.
    public static func places(in bottles: [Bottle]) -> [String: Place] {
        let live = bottles.filter { !$0.isFinished }
        var groups: [String: [Bottle]] = [:]
        var order: [String] = []
        for bottle in live {
            let key = bottle.groupKey
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(bottle)
        }

        var places: [String: Place] = [:]
        for key in order {
            let members = groups[key] ?? []
            for (index, bottle) in members.enumerated() {
                places[bottle.id] = Place(
                    count: members.count,
                    position: index + 1,
                    siblings: members.filter { $0.id != bottle.id }.map(\.id))
            }
        }
        return places
    }
}
