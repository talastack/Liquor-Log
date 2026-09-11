import SwiftUI
import LiquorData
import LiquorEngine

/// The screen this app is for: standing in a shop with a bottle in your hand.
///
/// **Works with no signal.** The catalog is a file in the app bundle and your
/// collection is a local database, so nothing on this screen waits on a network
/// that a concrete building will not give it.
struct ShelfCheckView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var query = ""
    @State private var results: [Result] = []
    @State private var isScanning = false
    @State private var shelfCount = 0
    @State private var openCount = 0

    /// The last few things looked up, newest first.
    ///
    /// Per device, in UserDefaults: it is a convenience and not part of the
    /// collection, and what somebody searched for in a shop is not something
    /// to sync to their other devices.
    @AppStorage("shelfCheck.recent") private var recentData: Data = Data()

    /// Three bottles to tap, so an empty screen demonstrates what the verdicts
    /// look like instead of describing them. Chosen so the catalogue has all
    /// three and they span a range people recognise.
    private let examples = ["Blanton's", "Weller 12", "Elijah Craig Barrel Proof"]

    struct Result: Identifiable {
        let hit: SearchHit
        let verdict: ShelfCheckResult
        /// What else this might be, for a bottle you have never had. Empty on
        /// every other verdict: when you own the thing, the answer is "yes"
        /// and nothing should crowd it.
        let related: [Related]
        /// Your own note on the product, when you wrote one. In the aisle,
        /// "not worth it over $60" is the most useful sentence on the card.
        let note: String?
        /// The most you said you would pay, when it is on your wishlist.
        let wishlistCents: Int?
        var id: String { hit.product.productId }
    }

    /// A structurally related product -- same line, distillery or recipe --
    /// and whether it is one of yours. Yours come first: standing in a shop,
    /// "you have the wheated sibling of this at home" beats a list of
    /// catalogue names.
    struct Related: Identifiable {
        let product: ProductIdentity
        let reason: SearchHit.Reason
        let isYours: Bool
        var id: String { product.productId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Shelf Check")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                    .padding(.top, Space.s)

                searchField

                if query.isEmpty {
                    intro
                } else if results.isEmpty {
                    noMatch
                } else {
                    ForEach(results) { result in
                        ShelfCheckCard(result: result) { picked in
                            query = picked
                            remember(picked)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: query) { _, _ in search() }
        .task { countShelf() }
        .sheet(isPresented: $isScanning) {
            NavigationStack {
                ScanLabelView { reading, product, _ in
                    // Straight to the verdict. The chosen product's name is
                    // the query, so the same search that answers a typed
                    // lookup answers a scanned one.
                    query = product?.identity.displayName ?? reading.nameCandidate.capitalized
                    remember(query)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textMuted)
            TextField("Distillery, brand or expression", text: $query)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { remember(query) }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textMuted)
                }
                .frame(minWidth: Space.tapTarget, minHeight: Space.tapTarget)
            }
            // The camera lives HERE, on the home tab, because the whole use
            // case is a bottle in your hand in a shop. A scan lands on a
            // verdict, never on a form.
            Button { isScanning = true } label: {
                Image(systemName: "camera")
                    .foregroundStyle(Palette.gold)
            }
            .frame(minWidth: Space.tapTarget, minHeight: Space.tapTarget)
            .accessibilityLabel("Scan a label")
        }
        .padding(.horizontal, Space.l)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            // What is on the shelf, so the screen is never blank for somebody
            // who has bottles. Counts bottles, never drinks.
            if shelfCount > 0 {
                HStack(spacing: Space.xl) {
                    figure("\(shelfCount)", shelfCount == 1 ? "bottle" : "bottles")
                    figure("\(openCount)", "open")
                    Spacer()
                }
                .padding(Space.l)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
            }

            Button { isScanning = true } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "camera")
                    Text("Scan the bottle in your hand")
                }
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }

            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("Recent")
                    ForEach(recent, id: \.self) { item in
                        Button { query = item } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(Palette.textMuted)
                                Text(item)
                                    .font(TypeScale.body())
                                    .foregroundStyle(Palette.text)
                                Spacer()
                            }
                            .frame(minHeight: Space.tapTarget)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel(recent.isEmpty ? "Try one" : "Or try")
                // Tapping one is the fastest possible demonstration of what
                // the three verdicts look like, which no paragraph can do.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(examples, id: \.self) { example in
                            Button { query = example } label: {
                                Text(example)
                                    .font(TypeScale.secondary())
                                    .foregroundStyle(Palette.textSecondary)
                                    .padding(.horizontal, Space.l)
                                    .frame(minHeight: Space.tapTarget)
                                    .background(RoundedRectangle(cornerRadius: 9)
                                        .fill(Palette.surfaceRaised))
                            }
                        }
                    }
                }
            }

            Text("Whether you own it, whether you have tried it, and what you said "
                 + "about it last time. Works with no signal.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.m)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text(label)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    // MARK: - Recent lookups

    private var recent: [String] {
        (try? JSONDecoder().decode([String].self, from: recentData)) ?? []
    }

    /// Keeps the last five, newest first, no duplicates. Five because the
    /// list is for "the thing I looked at a minute ago", not a history.
    private func remember(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        var items = recent.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        items.insert(trimmed, at: 0)
        recentData = (try? JSONEncoder().encode(Array(items.prefix(5)))) ?? Data()
    }

    private func countShelf() {
        let bottles = (try? env.bottles.summaries()) ?? []
        shelfCount = bottles.count
        openCount = bottles.filter(\.bottle.isOpen).count
    }

    private var noMatch: some View {
        VStack(spacing: Space.m) {
            Text("Nothing matching that")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("The catalogue is small so far. You can add the bottle yourself and "
                 + "it becomes yours alone.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        let history = env.historyProductIds()
        let candidates = env.catalog.searchCandidates(history: history)
        let hits = BottleSearch.search(query: trimmed, in: candidates, limit: 12)

        // The engine takes plain values and does no I/O, so these two reads are
        // the only place the database and the verdict meet.
        let holdings = (try? env.bottles.holdings { env.identity($0) }) ?? []
        let tastings = (try? env.tastings.records { env.identity($0) }) ?? []
        // Without this the engine's isOnWishlist was always false and the
        // "On your wishlist" line could never appear -- the copy existed, the
        // data never reached it.
        let wishes = (try? env.wishlist.items()) ?? []
        let wanted = Set(wishes.compactMap(\.catalogProductId))
        let ceilings = Dictionary(
            wishes.compactMap { item in item.catalogProductId.map { ($0, item.targetPriceCents) } },
            uniquingKeysWith: { first, _ in first })
        let noted = (try? env.notes.productIdsWithNotes()) ?? []

        results = hits.map { hit in
            let verdict = ShelfCheck.evaluate(
                product: hit.product,
                holdings: holdings,
                tastings: tastings,
                wishlistProductIds: wanted)
            return Result(
                hit: hit,
                verdict: verdict,
                related: related(to: hit.product, verdict: verdict, in: candidates, history: history),
                note: noted.contains(hit.product.productId)
                    ? (try? env.notes.note(productId: hit.product.productId))?.body
                    : nil,
                wishlistCents: ceilings[hit.product.productId] ?? nil)
        }
    }

    /// The "you might also mean" row. Structural, never textual: a shared
    /// line, distillery or recipe is what lets Weller surface its wheated
    /// siblings and an OESQ pick surface the other Four Roses recipes, which
    /// string similarity would never find.
    private func related(
        to product: ProductIdentity,
        verdict: ShelfCheckResult,
        in candidates: [SearchCandidate],
        history: Set<String>
    ) -> [Related] {
        switch verdict.headline {
        case .neverHadIt, .tastedNeverOwned: break
        default: return []
        }
        let hits = BottleSearch.related(
            to: product,
            recipeCode: env.catalog.product(product.productId)?.code,
            in: candidates,
            limit: 8)
        return hits
            .map { Related(product: $0.product, reason: $0.reason, isYours: history.contains($0.product.productId)) }
            .sorted { a, b in a.isYours != b.isYours ? a.isYours : false }
            .prefix(4)
            .map { $0 }
    }
}

/// One answer. The badge and the sentence under it must always agree — a badge
/// saying one verdict over copy describing another is the bug this whole model
/// exists to prevent.
struct ShelfCheckCard: View {
    let result: ShelfCheckView.Result
    /// Tapping a related product looks it up, so the row is a way to keep
    /// asking rather than a dead end.
    var onPick: (String) -> Void = { _ in }

    private var verdict: ShelfCheckResult { result.verdict }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                BottleMark(height: 58)

                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel(verdict.product.brand)
                    Text(verdict.product.expression.isEmpty
                         ? verdict.product.brand : verdict.product.expression)
                        .font(TypeScale.title())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Space.s) {
                        VerdictBadge(headline: verdict.headline)
                        if let rating = verdict.bestRating {
                            RatingChip(rating: rating)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            if let detail {
                Text(detail)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let liked = verdict.latestTasting?.liked, !liked.isEmpty {
                HStack(alignment: .top, spacing: Space.s) {
                    Text("LIKED")
                        .font(TypeScale.caption())
                        .foregroundStyle(Palette.good)
                    Text(liked)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AislePriceCheck(result: result)

            if let note = result.note {
                HStack(alignment: .top, spacing: Space.s) {
                    Text("NOTED")
                        .font(TypeScale.caption())
                        .foregroundStyle(Palette.gold)
                    Text(note)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !result.related.isEmpty {
                relatedRow
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// "You might also mean". Each chip says WHY it is here, because a related
    /// result that does not say how it is related reads as a broken search.
    private var relatedRow: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(result.related.contains(where: \.isYours)
                 ? "Related, and some are yours"
                 : "You might also mean")
                .font(TypeScale.caption())
                .foregroundStyle(Palette.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(result.related) { item in
                        Button { onPick(item.product.displayName) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.product.expression.isEmpty
                                     ? item.product.brand : item.product.expression)
                                    .font(TypeScale.secondary())
                                    .foregroundStyle(item.isYours ? Palette.gold : Palette.text)
                                    .lineLimit(1)
                                Text(reasonLabel(item))
                                    .font(TypeScale.caption())
                                    .textCase(nil)
                                    .foregroundStyle(Palette.textMuted)
                            }
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: Space.tapTarget)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Palette.surfaceRaised))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(item.isYours ? Palette.gold : Palette.line, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private func reasonLabel(_ item: ShelfCheckView.Related) -> String {
        let why: String
        switch item.reason {
        case .sameLine: why = "Same line"
        case .sameRecipe: why = "Same recipe"
        case .sameDistillery: why = "Same distillery"
        case .exact, .prefix, .fuzzy: why = "Related"
        }
        return item.isYours ? why + " · yours" : why
    }

    /// The sentence under the badge. It explains the verdict rather than
    /// repeating it.
    private var detail: String? {
        switch verdict.headline {
        case .onYourShelf:
            let count = verdict.onShelf.count
            let open = verdict.openBottleCount
            if open > 0 { return "\(open) open of \(count) you own." }
            return count == 1 ? "One unopened bottle." : "\(count) bottles, none open."
        case .haveTheLineNotThisRelease:
            let others = verdict.sameLine.map(\.displayName).joined(separator: ", ")
            return "You have \(others). This one you have never had."
        case .tastedNeverOwned:
            if let where_ = verdict.latestTasting?.where_ {
                return "You have tried it — \(where_) — but never owned a bottle."
            }
            return "You have tried it but never owned a bottle."
        case .hadItBefore:
            return "You finished a bottle of this."
        case .neverHadIt:
            guard verdict.isOnWishlist else { return nil }
            if let cents = result.wishlistCents {
                return "On your wishlist, up to \(Money.short(cents))."
            }
            return "On your wishlist."
        }
    }
}

/// "Is this a good price?", answered standing in the aisle.
///
/// The bottle screen already compares what you paid against what you
/// usually pay and against a shelf reference; this is the same comparison
/// BEFORE buying, which is when it is worth something. Three answers, each
/// only when there is data behind it: against what you usually pay, against
/// a published or observed shelf price, and against the ceiling you set on
/// the wishlist. No data, no line -- an invented verdict here costs somebody
/// real money.
struct AislePriceCheck: View {
    @Environment(AppEnvironment.self) private var env
    let result: ShelfCheckView.Result

    @State private var typed = ""
    @State private var lines: [(text: String, tone: Tone)] = []

    enum Tone { case good, neutral, bad }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Text("$")
                    .font(TypeScale.code(14))
                    .foregroundStyle(Palette.textMuted)
                TextField("Price on the shelf?", text: $typed)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .keyboardType(.decimalPad)
                    .onChange(of: typed) { _, _ in check() }
            }
            .padding(.horizontal, Space.m)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 9).fill(Palette.surfaceRaised))

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.text)
                    .font(TypeScale.secondary())
                    .foregroundStyle(color(line.tone))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func color(_ tone: Tone) -> Color {
        switch tone {
        case .good: return Palette.good
        case .neutral: return Palette.textSecondary
        case .bad: return Palette.bad
        }
    }

    private func check() {
        guard let dollars = Double(typed.trimmingCharacters(in: .whitespaces)), dollars > 0 else {
            lines = []
            return
        }
        let asking = Int((dollars * 100).rounded())
        let productId = result.hit.product.productId
        var next: [(String, Tone)] = []

        // Against what you usually pay, when you have bought it before.
        let purchases = (try? env.bottles.purchaseHistory(catalogProductId: productId)) ?? []
        if let history = PriceHistory.summarise(purchases) {
            let verdict = PriceHistory.compare(askingCents: asking, with: history)
            let tone: Tone
            switch verdict {
            case .cheaperThanUsual: tone = .good
            case .aboutWhatYouPay: tone = .neutral
            case .moreThanUsual, .muchMoreThanUsual: tone = .bad
            case .noHistory: tone = .neutral
            }
            next.append(("\(verdict.headline) — usually \(Money.short(history.typicalCents)).", tone))
        }

        // Against a shelf reference: your own sightings first, then the
        // bundled figure with its source.
        let reference = PriceHistory.shelfReference(purchases)
            ?? env.catalog.product(productId)?.priceReference
        if let reference {
            let check = PriceCheck.compare(paidCents: asking, reference: reference)
            let tone: Tone
            switch check.band {
            case .atOrBelow: tone = .good
            case .slightlyOver: tone = .neutral
            case .wellOver, .farOver: tone = .bad
            case .noReference: tone = .neutral
            }
            next.append(("\(check.headline) — \(Money.short(reference.cents)) \(reference.source).", tone))
        }

        // Against the ceiling you set yourself.
        if let ceiling = result.wishlistCents {
            if asking <= ceiling {
                next.append(("Under the \(Money.short(ceiling)) you said you would pay.", .good))
            } else {
                next.append(("\(Money.short(asking - ceiling)) over the \(Money.short(ceiling)) you said you would pay.", .bad))
            }
        }

        if next.isEmpty {
            next.append(("Nothing to compare it with yet. Buy it, or wishlist it with a price, and there will be.", .neutral))
        }
        lines = next.map { (text: $0.0, tone: $0.1) }
    }
}

#Preview {
    NavigationStack {
        ShelfCheckView()
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
