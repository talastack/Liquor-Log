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

    struct Result: Identifiable {
        let hit: SearchHit
        let verdict: ShelfCheckResult
        var id: String { hit.product.productId }
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
                        ShelfCheckCard(result: result)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: query) { _, _ in search() }
    }

    private var searchField: some View {
        HStack(spacing: Space.m) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.textMuted)
            TextField("Distillery, brand or expression", text: $query)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textMuted)
                }
                .frame(minWidth: Space.tapTarget, minHeight: Space.tapTarget)
            }
        }
        .padding(.horizontal, Space.l)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
    }

    private var intro: some View {
        VStack(spacing: Space.l) {
            HStack(spacing: Space.m) {
                BottleMark(height: 64).opacity(0.5)
                BottleMark(height: 84).opacity(0.5)
                BottleMark(height: 70).opacity(0.5)
            }
            Text("Bottle in hand? Find out what you already know about it.")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
            Text("Whether you own it, whether you have tried it, and what you said "
                 + "about it last time. Works with no signal.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
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

        let candidates = env.catalog.searchCandidates(history: env.historyProductIds())
        let hits = BottleSearch.search(query: trimmed, in: candidates, limit: 12)

        // The engine takes plain values and does no I/O, so these two reads are
        // the only place the database and the verdict meet.
        let holdings = (try? env.bottles.holdings { env.identity($0) }) ?? []
        let tastings = (try? env.tastings.records { env.identity($0) }) ?? []

        results = hits.map { hit in
            Result(
                hit: hit,
                verdict: ShelfCheck.evaluate(
                    product: hit.product, holdings: holdings, tastings: tastings))
        }
    }
}

/// One answer. The badge and the sentence under it must always agree — a badge
/// saying one verdict over copy describing another is the bug this whole model
/// exists to prevent.
struct ShelfCheckCard: View {
    let result: ShelfCheckView.Result

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
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
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
            return "You have tried it but never owned a bottle."
        case .hadItBefore:
            return "You finished a bottle of this."
        case .neverHadIt:
            return verdict.isOnWishlist ? "On your wishlist." : nil
        }
    }
}

#Preview {
    NavigationStack {
        ShelfCheckView()
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
