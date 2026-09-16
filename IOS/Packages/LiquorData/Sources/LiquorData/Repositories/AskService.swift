import Foundation
import LiquorEngine

/// Runs what `Ask` understood against the database, and answers what it
/// asked from it.
///
/// This used to live in the screen, which meant the part of Ask that
/// actually writes -- "log a pour of Weller 12" -- was the one part nothing
/// could test. Here it takes the repositories and two resolvers (a product
/// id to its identity, a bottle to its name) and returns sentences; the
/// screen only shows them and asks for the yes.
///
/// `describe` never writes. `execute` writes exactly what `describe` said
/// it would, or throws.
public struct AskService {
    private let bottles: BottleRepository
    private let tastings: TastingRepository
    private let wishlist: WishlistRepository
    private let notes: KnowledgeNoteRepository
    private let sightings: SightingRepository
    private let identity: (String) -> ProductIdentity?
    private let name: (Bottle) -> String

    public init(
        _ db: AppDatabase,
        identity: @escaping (String) -> ProductIdentity?,
        name: @escaping (Bottle) -> String
    ) {
        bottles = BottleRepository(db)
        tastings = TastingRepository(db)
        wishlist = WishlistRepository(db)
        notes = KnowledgeNoteRepository(db)
        sightings = SightingRepository(db)
        self.identity = identity
        self.name = name
    }

    /// Typed-in products as search candidates, so "log a pour of
    /// jefferson's" finds the bottle somebody typed in.
    public func customCandidates() throws -> [SearchCandidate] {
        try bottles.customProducts().map { entry in
            SearchCandidate(
                product: ProductIdentity(
                    productId: entry.id, distillery: entry.distillery, brand: entry.brand,
                    expression: entry.expression, classType: entry.classType,
                    productionType: entry.productionType),
                isInYourHistory: true)
        }
    }

    // MARK: - Commands

    public struct Description: Hashable, Sendable {
        public let text: String
        /// False when the command cannot be done as understood -- unknown
        /// bottle, ambiguous name, nothing on the shelf -- and the text says why.
        public let canRun: Bool
    }

    /// What the command would do, in a sentence, and whether it can be done.
    public func describe(_ command: Ask.Command) -> Description {
        func noMatch(_ subject: Ask.Subject) -> Description {
            Description(
                text: "I could not find \"\(subject.text)\" in the catalogue or on your shelf. "
                    + "Add it as a bottle first, then tell me again.",
                canRun: false)
        }
        func ambiguous(_ subject: Ask.Subject) -> Description {
            let names = subject.matches.prefix(3).map(\.product.displayName).joined(separator: ", ")
            return Description(text: "\"\(subject.text)\" could be \(names). Say which.", canRun: false)
        }
        // A Description thrown here is the answer: the command cannot run
        // and the text says why.
        func resolved(_ subject: Ask.Subject) throws -> ProductIdentity {
            guard let product = subject.best else { throw noMatch(subject) }
            if subject.isAmbiguous { throw ambiguous(subject) }
            return product
        }

        do {
            return try describeResolved(command, resolved: resolved)
        } catch let cannot as Description {
            return cannot
        } catch {
            return Description(text: error.localizedDescription, canRun: false)
        }
    }

    private func describeResolved(
        _ command: Ask.Command,
        resolved: (Ask.Subject) throws -> ProductIdentity
    ) throws -> Description {
        switch command {
        case .pour(let subject, let ml):
            let product = try resolved(subject)
            guard let bottle = openOrAnyBottle(of: product) else {
                return Description(text: "You do not have a bottle of \(product.displayName) on the shelf to pour from.", canRun: false)
            }
            let size = ml.map { "\(Int($0.rounded())) ml" } ?? "a pour"
            return Description(
                text: "Log \(size) from \(product.displayName)\(bottle.isOpen ? "" : " and mark it opened")?",
                canRun: true)
        case .open(let subject):
            let product = try resolved(subject)
            guard sealedBottle(of: product) != nil else {
                return Description(text: "No sealed bottle of \(product.displayName) on the shelf.", canRun: false)
            }
            return Description(text: "Mark \(product.displayName) as opened today?", canRun: true)
        case .finish(let subject):
            let product = try resolved(subject)
            guard openOrAnyBottle(of: product) != nil else {
                return Description(text: "No bottle of \(product.displayName) on the shelf to finish.", canRun: false)
            }
            return Description(
                text: "Mark \(product.displayName) as finished? It leaves the shelf and keeps its history.",
                canRun: true)
        case .setLevel(let subject, let percent):
            let product = try resolved(subject)
            guard openOrAnyBottle(of: product) != nil else {
                return Description(text: "No bottle of \(product.displayName) on the shelf.", canRun: false)
            }
            return Description(text: "Set \(product.displayName) to \(Int(percent))% full?", canRun: true)
        case .rate(let subject, let rating):
            let product = try resolved(subject)
            guard (1...10).contains(rating) else { return Description(text: "A rating is 1 to 10.", canRun: false) }
            return Description(text: "Record a tasting of \(product.displayName) rated \(rating)/10?", canRun: true)
        case .addBottle(let subject, let paid, let store):
            let product = try resolved(subject)
            var line = "Add a sealed 750 ml bottle of \(product.displayName)"
            if let paid { line += ", paid \(Money.short(paid))" }
            if let store { line += " at \(store)" }
            return Description(text: line + "?", canRun: true)
        case .wishlist(let subject, let ceiling):
            let product = try resolved(subject)
            let cap = ceiling.map { ", up to \(Money.short($0))" } ?? ""
            return Description(text: "Put \(product.displayName) on your wishlist\(cap)?", canRun: true)
        case .note(let subject, let body):
            let product = try resolved(subject)
            return Description(text: "Save this note on \(product.displayName): \"\(body)\"?", canRun: true)
        case .saw(let subject, let cents, let store, let count):
            let product = try resolved(subject)
            guard let store, !store.isEmpty else {
                return Description(text: "Where did you see \(product.displayName)? Say \"at\" and the store.", canRun: false)
            }
            var line = "Log that you saw \(product.displayName) at \(store)"
            if let cents { line += " for \(Money.short(cents))" }
            if let count { line += count == 0 ? ", sold out" : ", \(count) on the shelf" }
            return Description(text: line + "?", canRun: true)
        case .entered(let subject, let runner):
            let product = try resolved(subject)
            return Description(
                text: "Log a lottery entry for \(product.displayName)\(runner.map { " at \($0)" } ?? "")?",
                canRun: true)
        }
    }

    public enum AskError: LocalizedError {
        case gone
        case unresolved
        public var errorDescription: String? {
            switch self {
            case .gone: return "That bottle is no longer on the shelf."
            case .unresolved: return "I lost track of which bottle that was."
            }
        }
    }

    /// Does the thing. Returns the sentence that says what happened.
    @discardableResult
    public func execute(_ command: Ask.Command) throws -> String {
        func resolve(_ subject: Ask.Subject) throws -> ProductIdentity {
            guard let best = subject.best else { throw AskError.unresolved }
            return best
        }
        switch command {
        case .pour(let subject, let ml):
            let product = try resolve(subject)
            guard let bottle = openOrAnyBottle(of: product) else { throw AskError.gone }
            let pour = try bottles.logPour(bottleId: bottle.id, volumeMl: ml)
            let after = try bottles.summary(id: bottle.id)
            return "Logged \(Int(pour.volumeMl.rounded())) ml from \(product.displayName). "
                + "\(after?.status.remainingPours ?? 0) pours left."
        case .open(let subject):
            let product = try resolve(subject)
            guard let bottle = sealedBottle(of: product) else { throw AskError.gone }
            try bottles.open(bottleId: bottle.id)
            return "\(product.displayName) is open as of today."
        case .finish(let subject):
            let product = try resolve(subject)
            guard let bottle = openOrAnyBottle(of: product) else { throw AskError.gone }
            try bottles.finish(bottleId: bottle.id)
            return "\(product.displayName) is finished and off the shelf. Its history stays."
        case .setLevel(let subject, let percent):
            let product = try resolve(subject)
            guard let bottle = openOrAnyBottle(of: product) else { throw AskError.gone }
            try bottles.setLevel(bottleId: bottle.id, percentFull: percent)
            let after = try bottles.summary(id: bottle.id)
            return "\(product.displayName) set to \(Int(percent))% — \(after?.status.remainingPours ?? 0) pours left."
        case .rate(let subject, let rating):
            let product = try resolve(subject)
            let bottle = openOrAnyBottle(of: product)
            try tastings.save(Tasting(bottleId: bottle?.id, catalogProductId: product.productId, rating: rating))
            return "Rated \(product.displayName) \(rating)/10."
        case .addBottle(let subject, let paid, let store):
            let product = try resolve(subject)
            try bottles.add(Bottle(
                catalogProductId: product.productId,
                purchaseDate: Bottle.nowMilliseconds(),
                purchasePriceCents: paid,
                purchaseStore: store))
            return "Added \(product.displayName) to the shelf, sealed and full."
        case .wishlist(let subject, let ceiling):
            let product = try resolve(subject)
            try wishlist.add(catalogProductId: product.productId, targetPriceCents: ceiling)
            return "\(product.displayName) is on your wishlist."
        case .note(let subject, let body):
            let product = try resolve(subject)
            try notes.set(productId: product.productId, title: product.displayName, body: body)
            return "Noted on \(product.displayName)."
        case .saw(let subject, let cents, let store, let count):
            let product = try resolve(subject)
            guard let store, !store.isEmpty else { throw AskError.unresolved }
            try sightings.record(catalogProductId: product.productId, store: store, cents: cents, count: count)
            return "Logged: \(product.displayName) at \(store). It is in the hunt log."
        case .entered(let subject, let runner):
            let product = try resolve(subject)
            try sightings.record(
                catalogProductId: product.productId, kind: .entered, store: runner ?? "A lottery")
            return "Logged the entry for \(product.displayName). Mark it won or lost in the hunt log when you hear."
        }
    }

    // MARK: - Questions

    public func answer(_ question: Ask.Question, now: Date = Date()) -> String {
        let shelf = (try? bottles.summaries()) ?? []
        switch question {
        case .whatIsOpen:
            let open = shelf.filter(\.bottle.isOpen)
            guard !open.isEmpty else { return "Nothing is open." }
            return open.map { "• \(name($0.bottle)) — \($0.status.remainingPours) pours left" }
                .joined(separator: "\n")
        case .howMany(nil):
            let open = shelf.filter(\.bottle.isOpen).count
            return "\(shelf.count) \(shelf.count == 1 ? "bottle" : "bottles") on the shelf, \(open) open."
        case .howMany(let subject?):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let same = shelf.filter { matchesLine($0.bottle, product) }
            let exact = same.filter { $0.bottle.catalogProductId == product.productId }
            if same.isEmpty { return "None of \(product.brand) on the shelf." }
            let names = Dictionary(grouping: same, by: { name($0.bottle) })
                .map { "\($0.value.count) × \($0.key)" }.sorted().joined(separator: ", ")
            return "\(same.count) of \(product.brand): \(names)."
                + (exact.isEmpty ? " None is the \(product.displayName) itself." : "")
        case .doIHave(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let exact = shelf.filter { $0.bottle.catalogProductId == product.productId }
            if !exact.isEmpty {
                let open = exact.filter(\.bottle.isOpen).count
                return "Yes — \(exact.count) of \(product.displayName), \(open) open."
            }
            let line = shelf.filter { matchesLine($0.bottle, product) }
            if !line.isEmpty {
                return "Not that one, but you have the line: " + line.map { name($0.bottle) }.joined(separator: ", ") + "."
            }
            let finished = ((try? bottles.summaries(includeFinished: true)) ?? [])
                .filter { $0.bottle.isFinished && $0.bottle.catalogProductId == product.productId }
            if !finished.isEmpty { return "Not now. You finished a bottle of it." }
            return "No. Never had it, as far as the shelf knows."
        case .lastPoured(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let last = shelf.filter { $0.bottle.catalogProductId == product.productId }
                .compactMap(\.lastPouredAt).max()
            guard let last else { return "No pour of \(product.displayName) is logged." }
            let days = Int(now.timeIntervalSince(last) / 86_400)
            return days == 0 ? "Today." : "\(days) \(days == 1 ? "day" : "days") ago."
        case .whatDidIThink(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let history = (try? tastings.history(productId: product.productId)) ?? []
            guard let latest = history.first else { return "No tasting of \(product.displayName) yet." }
            var parts: [String] = []
            if let rating = latest.tasting.rating { parts.append("\(rating)/10") }
            if let liked = latest.tasting.liked, !liked.isEmpty { parts.append("liked: \(liked)") }
            if let disliked = latest.tasting.disliked, !disliked.isEmpty { parts.append("not: \(disliked)") }
            if let rebuy = latest.tasting.wouldRebuy {
                parts.append(rebuy == .yes ? "would buy again" : rebuy == .no ? "would not buy again" : "might buy again")
            }
            return (parts.isEmpty ? "A tasting with no rating." : parts.joined(separator: " · "))
                + (history.count > 1 ? " (\(history.count) tastings in all.)" : "")
        case .whatDidIPay(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let purchases = (try? bottles.purchaseHistory(catalogProductId: product.productId)) ?? []
            guard let summary = PriceHistory.summarise(purchases) else { return "No price recorded for \(product.displayName)." }
            if summary.isSinglePrice { return "\(Money.short(summary.typicalCents)) for \(product.displayName)." }
            return "Usually \(Money.short(summary.typicalCents)) for \(product.displayName) — from "
                + "\(Money.short(summary.lowestCents)) to \(Money.short(summary.highestCents)) over \(summary.count) bottles."
        case .whereIs(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let mine = shelf.filter { $0.bottle.catalogProductId == product.productId }
            guard !mine.isEmpty else { return "No \(product.displayName) on the shelf." }
            let places = mine.compactMap(\.bottle.storageLocation)
            guard !places.isEmpty else { return "You have it, but no place is recorded. Edit the bottle to add one." }
            return Set(places).sorted().joined(separator: ", ") + "."
        case .whatIsOnMyWishlist:
            let items = (try? wishlist.items()) ?? []
            guard !items.isEmpty else { return "The wishlist is empty." }
            return items.map { item in
                let itemName = item.catalogProductId.flatMap { identity($0)?.displayName } ?? item.customName ?? "Untitled"
                let cap = item.targetPriceCents.map { " — up to \(Money.short($0))" } ?? ""
                return "• \(itemName)\(cap)"
            }.joined(separator: "\n")
        case .nearlyGone:
            let low = shelf.filter { $0.bottle.isOpen && $0.status.remainingPours <= Replenish.lastPoursThreshold }
            guard !low.isEmpty else { return "Nothing is down to its last pours." }
            return low.map { "• \(name($0.bottle)) — \($0.status.remainingPours) left" }.joined(separator: "\n")
        case .whereDidISee(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let seen = ((try? sightings.sightings(catalogProductId: product.productId)) ?? [])
                .filter { $0.kind == .seen }
                .map { row in
                    Hunt.Sighting(
                        id: row.id, productId: row.catalogProductId, name: product.displayName, store: row.store,
                        kind: row.kind, outcome: row.outcome, cents: row.cents, count: row.count,
                        at: Date(timeIntervalSince1970: Double(row.seenAt) / 1000), boughtBottleId: row.bottleId)
                }
            guard let latest = seen.first else { return "No sighting of \(product.displayName) in the hunt log." }
            var answer = Hunt.line(latest, now: now) + "."
            let elsewhere = seen.dropFirst()
                .filter { Hunt.storeKey($0.store) != Hunt.storeKey(latest.store) }
                .map { "\($0.store.trimmingCharacters(in: .whitespaces)), \(Hunt.ago(AgeMath.days(from: $0.at, to: now)))" }
            var named = Set<String>()
            let others = elsewhere.filter { named.insert($0.lowercased()).inserted }.prefix(3)
            if !others.isEmpty { answer += " Also " + others.joined(separator: "; ") + "." }
            return answer
        case .whatCameFrom(let person):
            let everything = (try? bottles.summaries(includeFinished: true)) ?? []
            let names = Dictionary(everything.map { ($0.id, name($0.bottle)) }, uniquingKeysWith: { a, _ in a })
            func date(_ millis: Int64) -> Date { Date(timeIntervalSince1970: Double(millis) / 1000) }
            let received = everything.compactMap { summary -> (from: String, bottle: String, milliliters: Double, how: String?, at: Date, rating: Int?)? in
                guard summary.bottle.isSample, let from = summary.bottle.sampleFrom else { return nil }
                return (from: from, bottle: names[summary.id] ?? "A sample", milliliters: summary.bottle.volumeMl,
                        how: summary.bottle.sampleSource?.label, at: date(summary.bottle.purchaseDate ?? summary.bottle.createdAt), rating: nil)
            }
            let given = ((try? bottles.poursGivenAway()) ?? []).compactMap { pour -> (to: String, bottle: String, milliliters: Double, at: Date)? in
                guard let to = pour.givenTo else { return nil }
                return (to: to, bottle: names[pour.bottleId] ?? "A bottle", milliliters: pour.volumeMl, at: date(pour.pouredAt))
            }
            let ledger = People.ledger(received: received, given: given)
            let key = Hunt.storeKey(person)
            guard let match = ledger.first(where: { $0.key == key })
                ?? ledger.first(where: { $0.key.hasPrefix(key) || key.hasPrefix($0.key) }) else {
                // The grammar lowercases; a name reads better capitalised.
                let typed = person.prefix(1).uppercased() + person.dropFirst()
                return "Nothing logged from \(typed). A sample that names who it came from, or a pour marked as theirs, would show here."
            }
            var lines: [String] = []
            if !match.received.isEmpty {
                lines.append("From \(match.name): " + match.received.map { "\($0.bottle) (\(Int($0.milliliters.rounded())) ml)" }.joined(separator: ", ") + ".")
            }
            if !match.given.isEmpty {
                lines.append("To \(match.name): " + match.given.map { "\($0.bottle) (\(Int($0.milliliters.rounded())) ml)" }.joined(separator: ", ") + ".")
            }
            if let balance = People.balance(match) { lines.append(balance + ".") }
            return lines.joined(separator: " ")
        }
    }

    // MARK: - Finding bottles

    private func openOrAnyBottle(of product: ProductIdentity) -> Bottle? {
        let mine = ((try? bottles.summaries()) ?? [])
            .filter { $0.bottle.catalogProductId == product.productId }
            .map(\.bottle)
        return mine.first(where: \.isOpen) ?? mine.first
    }

    private func sealedBottle(of product: ProductIdentity) -> Bottle? {
        ((try? bottles.summaries()) ?? [])
            .map(\.bottle)
            .first { $0.catalogProductId == product.productId && !$0.isOpen }
    }

    private func matchesLine(_ bottle: Bottle, _ product: ProductIdentity) -> Bool {
        guard let id = bottle.catalogProductId, let found = identity(id) else { return false }
        return found.lineKey == product.lineKey
    }
}

extension AskService.Description: Error {}
