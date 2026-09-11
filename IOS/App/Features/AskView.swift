import SwiftUI
import LiquorData
import LiquorEngine

/// A text box that understands you.
///
/// Type "log a pour of weller 12" or "what's open" and it does the thing or
/// answers the question, from your own data, on this phone. The grammar is
/// the engine's `Ask`; this screen runs what it understood and shows the
/// answer. A command is always shown back and confirmed before anything is
/// written, because "log a pour" against the wrong bottle is a mistake
/// somebody has to find and undo.
///
/// Where the phone has an on-device language model, `AskModel` turns looser
/// phrasing into the same commands. Older phones get the grammar alone.
/// Nothing here says AI anywhere a person can see.
struct AskView: View {
    @Environment(AppEnvironment.self) private var env

    struct Exchange: Identifiable {
        let id = UUID()
        let asked: String
        var answer: String
        /// A command waiting for a yes.
        var pending: Ask.Command?
        var done = false
    }

    @State private var typed = ""
    @State private var exchanges: [Exchange] = []
    @FocusState private var isTyping: Bool

    private let examples = [
        "What's open", "How many bottles do I have", "Log a pour of Weller 12",
        "Rate the Stagg an 8", "Add a bottle of Eagle Rare, paid 40 at Total Wine",
        "When did I last pour the Blanton's",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.l) {
                        if exchanges.isEmpty {
                            intro
                        }
                        ForEach(exchanges) { exchange in
                            exchangeView(exchange).id(exchange.id)
                        }
                    }
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.l)
                    .padding(.bottom, Space.xl)
                }
                .onChange(of: exchanges.count) { _, _ in
                    if let last = exchanges.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
        .background(Palette.background)
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pieces

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Ask about your shelf, or tell it what you did.")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Everything is answered from what you have entered, on this phone. "
                 + "Nothing you type leaves it.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SectionLabel("Try")
            ForEach(examples, id: \.self) { example in
                Button { submit(example) } label: {
                    Text(example)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, Space.l)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget - 6, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.surfaceRaised))
                }
            }
        }
    }

    private func exchangeView(_ exchange: Exchange) -> some View {
        VStack(alignment: .trailing, spacing: Space.s) {
            Text(exchange.asked)
                .font(TypeScale.body())
                .foregroundStyle(Palette.onGold)
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.gold))
                .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .leading, spacing: Space.m) {
                Text(exchange.answer)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let pending = exchange.pending, !exchange.done {
                    HStack(spacing: Space.m) {
                        Button { run(pending, for: exchange.id) } label: {
                            Text("Yes, do it")
                                .font(TypeScale.secondary().weight(.semibold))
                                .foregroundStyle(Palette.onGold)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Palette.gold))
                        }
                        Button { cancel(exchange.id) } label: {
                            Text("No")
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                        }
                    }
                }
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
        }
    }

    private var composer: some View {
        HStack(spacing: Space.m) {
            TextField("Ask, or tell it what you did", text: $typed, axis: .vertical)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .lineLimit(1...4)
                .focused($isTyping)
                .onSubmit { submit(typed) }
            Button { submit(typed) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(typed.trimmingCharacters(in: .whitespaces).isEmpty ? Palette.textMuted : Palette.gold)
            }
            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .background(Palette.surface)
        .overlay(Rectangle().fill(Palette.line).frame(height: 1), alignment: .top)
    }

    // MARK: - Understanding

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        typed = ""
        let catalog = env.catalog.searchCandidates(history: env.historyProductIds()) + customCandidates()
        var exchange = Exchange(asked: trimmed, answer: "")
        if let understood = interpret(trimmed, catalog: catalog) {
            exchange = understood(exchange)
            exchanges.append(exchange)
            return
        }

        // The grammar did not follow. On a phone with the on-device model,
        // let it rephrase into the grammar's shape and try once more; the
        // model never touches the database, it only rewords.
        guard AskModel.isAvailable else {
            exchange.answer = didNotFollow
            exchange.done = true
            exchanges.append(exchange)
            return
        }
        exchange.answer = "…"
        exchanges.append(exchange)
        let id = exchange.id
        let names = catalog.map(\.product.displayName)
        Task {
            let rephrased = await AskModel.rephrase(trimmed, bottleNames: names)
            guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
            if let rephrased, let understood = interpret(rephrased, catalog: catalog) {
                exchanges[index] = understood(exchanges[index])
            } else {
                exchanges[index].answer = didNotFollow
                exchanges[index].done = true
            }
        }
    }

    private var didNotFollow: String {
        "I did not follow that. Try \"log a pour of …\", \"what's open\", "
            + "\"how many … do I have\", \"rate … an 8\" or \"add a bottle of …\"."
    }

    /// The grammar's reading of a sentence as a change to apply to an
    /// exchange, or nil when it did not follow.
    private func interpret(_ text: String, catalog: [SearchCandidate]) -> ((Exchange) -> Exchange)? {
        switch Ask.understand(text, catalog: catalog) {
        case .question(let question):
            let reply = answer(question)
            return { var e = $0; e.answer = reply; e.done = true; return e }
        case .command(let command):
            let (reply, ok) = describe(command)
            return { var e = $0; e.answer = reply; e.pending = ok ? command : nil; e.done = !ok; return e }
        case .unknown:
            return nil
        }
    }

    /// Typed-in products join the catalogue so "log a pour of jefferson's"
    /// finds the bottle you typed in.
    private func customCandidates() -> [SearchCandidate] {
        ((try? env.bottles.customProducts()) ?? []).map { entry in
            SearchCandidate(
                product: ProductIdentity(
                    productId: entry.id, distillery: entry.distillery, brand: entry.brand,
                    expression: entry.expression, classType: entry.classType,
                    productionType: entry.productionType),
                isInYourHistory: true)
        }
    }

    // MARK: - Commands

    /// What the command would do, in a sentence, and whether it can be done.
    private func describe(_ command: Ask.Command) -> (String, Bool) {
        func noMatch(_ subject: Ask.Subject) -> (String, Bool) {
            ("I could not find \"\(subject.text)\" in the catalogue or on your shelf. "
             + "Add it as a bottle first, then tell me again.", false)
        }
        func ambiguous(_ subject: Ask.Subject) -> (String, Bool) {
            let names = subject.matches.prefix(3).map(\.product.displayName).joined(separator: ", ")
            return ("\"\(subject.text)\" could be \(names). Say which.", false)
        }

        switch command {
        case .pour(let subject, let ml):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            guard let bottle = openOrAnyBottle(of: product) else {
                return ("You do not have a bottle of \(name) on the shelf to pour from.", false)
            }
            let size = ml.map { VolumeDisplay.text($0, ounces: false) } ?? "a pour"
            return ("Log \(size) from \(name)\(bottle.isOpen ? "" : " and mark it opened")?", true)
        case .open(let subject):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            guard sealedBottle(of: product) != nil else {
                return ("No sealed bottle of \(name) on the shelf.", false)
            }
            return ("Mark \(name) as opened today?", true)
        case .finish(let subject):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            guard openOrAnyBottle(of: product) != nil else {
                return ("No bottle of \(name) on the shelf to finish.", false)
            }
            return ("Mark \(name) as finished? It leaves the shelf and keeps its history.", true)
        case .setLevel(let subject, let percent):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            guard openOrAnyBottle(of: product) != nil else {
                return ("No bottle of \(name) on the shelf.", false)
            }
            return ("Set \(name) to \(Int(percent))% full?", true)
        case .rate(let subject, let rating):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            guard (1...10).contains(rating) else { return ("A rating is 1 to 10.", false) }
            return ("Record a tasting of \(name) rated \(rating)/10?", true)
        case .addBottle(let subject, let paid, let store):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            var line = "Add a sealed 750 ml bottle of \(name)"
            if let paid { line += ", paid \(Money.short(paid))" }
            if let store { line += " at \(store)" }
            return (line + "?", true)
        case .wishlist(let subject, let ceiling):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            let cap = ceiling.map { ", up to \(Money.short($0))" } ?? ""
            return ("Put \(name) on your wishlist\(cap)?", true)
        case .note(let subject, let body):
            guard let product = subject.best else { return noMatch(subject) }
            let name = product.displayName
            if subject.isAmbiguous { return ambiguous(subject) }
            return ("Save this note on \(name): \"\(body)\"?", true)
        }
    }

    private func run(_ command: Ask.Command, for id: UUID) {
        guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
        do {
            let result: String
            switch command {
            case .pour(let subject, let ml):
                let product = try resolve(subject)
                guard let bottle = openOrAnyBottle(of: product) else { throw AskError.gone }
                let pour = try env.bottles.logPour(bottleId: bottle.id, volumeMl: ml)
                let after = try env.bottles.summary(id: bottle.id)
                result = "Logged \(VolumeDisplay.text(pour.volumeMl, ounces: false)) from \(product.displayName). "
                    + "\(after?.status.remainingPours ?? 0) pours left."
            case .open(let subject):
                let product = try resolve(subject)
                guard let bottle = sealedBottle(of: product) else { throw AskError.gone }
                try env.bottles.open(bottleId: bottle.id)
                result = "\(product.displayName) is open as of today."
            case .finish(let subject):
                let product = try resolve(subject)
                guard let bottle = openOrAnyBottle(of: product) else { throw AskError.gone }
                try env.bottles.finish(bottleId: bottle.id)
                result = "\(product.displayName) is finished and off the shelf. Its history stays."
            case .setLevel(let subject, let percent):
                let product = try resolve(subject)
                guard let bottle = openOrAnyBottle(of: product) else { throw AskError.gone }
                try env.bottles.setLevel(bottleId: bottle.id, percentFull: percent)
                let after = try env.bottles.summary(id: bottle.id)
                result = "\(product.displayName) set to \(Int(percent))% — "
                    + "\(after?.status.remainingPours ?? 0) pours left."
            case .rate(let subject, let rating):
                let product = try resolve(subject)
                let bottle = openOrAnyBottle(of: product)
                try env.tastings.save(Tasting(
                    bottleId: bottle?.id, catalogProductId: product.productId, rating: rating))
                result = "Rated \(product.displayName) \(rating)/10."
            case .addBottle(let subject, let paid, let store):
                let product = try resolve(subject)
                try env.bottles.add(Bottle(
                    catalogProductId: product.productId,
                    purchaseDate: Bottle.nowMilliseconds(),
                    purchasePriceCents: paid,
                    purchaseStore: store))
                result = "Added \(product.displayName) to the shelf, sealed and full."
            case .wishlist(let subject, let ceiling):
                let product = try resolve(subject)
                try env.wishlist.add(catalogProductId: product.productId, targetPriceCents: ceiling)
                result = "\(product.displayName) is on your wishlist."
            case .note(let subject, let body):
                let product = try resolve(subject)
                try env.notes.set(productId: product.productId, title: product.displayName, body: body)
                result = "Noted on \(product.displayName)."
            }
            exchanges[index].answer = result
        } catch {
            exchanges[index].answer = "That did not work: \(error.localizedDescription)"
        }
        exchanges[index].done = true
        exchanges[index].pending = nil
    }

    private func cancel(_ id: UUID) {
        guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
        exchanges[index].answer = "Not done."
        exchanges[index].done = true
        exchanges[index].pending = nil
    }

    private enum AskError: LocalizedError {
        case gone
        case unresolved
        var errorDescription: String? {
            switch self {
            case .gone: return "That bottle is no longer on the shelf."
            case .unresolved: return "I lost track of which bottle that was."
            }
        }
    }

    /// The product a confirmed command is about. Confirmed commands always
    /// have one; this is the non-crashing way to say so.
    private func resolve(_ subject: Ask.Subject) throws -> ProductIdentity {
        guard let best = subject.best else { throw AskError.unresolved }
        return best
    }

    // MARK: - Questions

    private func answer(_ question: Ask.Question) -> String {
        let shelf = (try? env.bottles.summaries()) ?? []
        switch question {
        case .whatIsOpen:
            let open = shelf.filter(\.bottle.isOpen)
            guard !open.isEmpty else { return "Nothing is open." }
            return open.map { "• \(env.name(for: $0.bottle)) — \($0.status.remainingPours) pours left" }
                .joined(separator: "\n")
        case .howMany(nil):
            let open = shelf.filter(\.bottle.isOpen).count
            return "\(shelf.count) \(shelf.count == 1 ? "bottle" : "bottles") on the shelf, \(open) open."
        case .howMany(let subject?):
            guard let product = subject.best else {
                return "I do not know \"\(subject.text)\"."
            }
            let same = shelf.filter { matchesLine($0.bottle, product) }
            let exact = same.filter { $0.bottle.catalogProductId == product.productId }
            if same.isEmpty { return "None of \(product.brand) on the shelf." }
            let names = Dictionary(grouping: same, by: { env.name(for: $0.bottle) })
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
                return "Not that one, but you have the line: "
                    + line.map { env.name(for: $0.bottle) }.joined(separator: ", ") + "."
            }
            let finished = ((try? env.bottles.summaries(includeFinished: true)) ?? [])
                .filter { $0.bottle.isFinished && $0.bottle.catalogProductId == product.productId }
            if !finished.isEmpty { return "Not now. You finished a bottle of it." }
            return "No. Never had it, as far as the shelf knows."
        case .lastPoured(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let last = shelf.filter { $0.bottle.catalogProductId == product.productId }
                .compactMap(\.lastPouredAt).max()
            guard let last else { return "No pour of \(product.displayName) is logged." }
            let days = Int(Date().timeIntervalSince(last) / 86_400)
            return days == 0 ? "Today." : "\(days) \(days == 1 ? "day" : "days") ago, on \(last.formatted(date: .abbreviated, time: .omitted))."
        case .whatDidIThink(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let history = (try? env.tastings.history(productId: product.productId)) ?? []
            guard let latest = history.first else { return "No tasting of \(product.displayName) yet." }
            var parts: [String] = []
            if let rating = latest.tasting.rating { parts.append("\(rating)/10") }
            if let liked = latest.tasting.liked, !liked.isEmpty { parts.append("liked: \(liked)") }
            if let disliked = latest.tasting.disliked, !disliked.isEmpty { parts.append("not: \(disliked)") }
            if let rebuy = latest.tasting.wouldRebuy { parts.append(rebuy == .yes ? "would buy again" : rebuy == .no ? "would not buy again" : "might buy again") }
            let when = Date(timeIntervalSince1970: Double(latest.tasting.tastedAt) / 1000).formatted(date: .abbreviated, time: .omitted)
            return "\(when): " + (parts.isEmpty ? "a tasting with no rating." : parts.joined(separator: " · "))
                + (history.count > 1 ? " (\(history.count) tastings in all.)" : "")
        case .whatDidIPay(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let purchases = (try? env.bottles.purchaseHistory(catalogProductId: product.productId)) ?? []
            guard let summary = PriceHistory.summarise(purchases) else { return "No price recorded for \(product.displayName)." }
            if summary.isSinglePrice { return "\(Money.short(summary.typicalCents)) for \(product.displayName)." }
            return "Usually \(Money.short(summary.typicalCents)) for \(product.displayName) — from \(Money.short(summary.lowestCents)) to \(Money.short(summary.highestCents)) over \(summary.count) bottles."
        case .whereIs(let subject):
            guard let product = subject.best else { return "I do not know \"\(subject.text)\"." }
            let bottles = shelf.filter { $0.bottle.catalogProductId == product.productId }
            guard !bottles.isEmpty else { return "No \(product.displayName) on the shelf." }
            let places = bottles.compactMap(\.bottle.storageLocation)
            guard !places.isEmpty else { return "You have it, but no place is recorded. Edit the bottle to add one." }
            return Set(places).sorted().joined(separator: ", ") + "."
        case .whatIsOnMyWishlist:
            let items = (try? env.wishlist.items()) ?? []
            guard !items.isEmpty else { return "The wishlist is empty." }
            return items.map { item in
                let name = item.catalogProductId.flatMap { env.identity($0)?.displayName } ?? item.customName ?? "Untitled"
                let cap = item.targetPriceCents.map { " — up to \(Money.short($0))" } ?? ""
                return "• \(name)\(cap)"
            }.joined(separator: "\n")
        case .nearlyGone:
            let low = shelf.filter { $0.bottle.isOpen && $0.status.remainingPours <= Replenish.lastPoursThreshold }
            guard !low.isEmpty else { return "Nothing is down to its last pours." }
            return low.map { "• \(env.name(for: $0.bottle)) — \($0.status.remainingPours) left" }.joined(separator: "\n")
        }
    }

    // MARK: - Finding bottles

    private func openOrAnyBottle(of product: ProductIdentity) -> Bottle? {
        let mine = ((try? env.bottles.summaries()) ?? [])
            .filter { $0.bottle.catalogProductId == product.productId }
            .map(\.bottle)
        return mine.first(where: \.isOpen) ?? mine.first
    }

    private func sealedBottle(of product: ProductIdentity) -> Bottle? {
        ((try? env.bottles.summaries()) ?? [])
            .map(\.bottle)
            .first { $0.catalogProductId == product.productId && !$0.isOpen }
    }

    private func matchesLine(_ bottle: Bottle, _ product: ProductIdentity) -> Bool {
        guard let id = bottle.catalogProductId, let identity = env.identity(id) else { return false }
        return identity.lineKey == product.lineKey
    }
}
