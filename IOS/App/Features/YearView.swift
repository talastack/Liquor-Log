import SwiftUI
import LiquorEngine
import LiquorData

/// A year of collecting in a few sentences, and the same as a card. What
/// came onto the shelf, what was tasted, the word of the year, who sent
/// samples, where the hunting happened. Money only behind the switch, and
/// never on the card.
struct YearView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("showsCollectionValue") private var showsValue = CollectionValue.shownByDefault

    @State private var years: [Int] = []
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var facts = YearInReview.Facts()
    @State private var review: YearInReview.Review?
    @State private var hasLooked = false
    @State private var rendered: RenderedCard?

    struct RenderedCard: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Your year")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("What was collected and written, in a few sentences. Bottles, tastings, words, people and stores; nothing about how much was poured.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if years.count > 1 {
                    Picker("Year", selection: $year) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: year) { _, _ in rebuild() }
                }

                if let review {
                    VStack(alignment: .leading, spacing: Space.m) {
                        ForEach(Array(review.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if showsValue, let money = review.moneyLine {
                            Text(money)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

                    Button { render(review) } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share as a card")
                        }
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }
                    Text("The card carries no prices, whatever the switch says.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                } else if hasLooked {
                    Text("Nothing recorded in \(String(year)) yet. A bottle added, a tasting written or a sighting logged starts it.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Your year")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .onChange(of: env.changeCount) { _, _ in load() }
        .sheet(item: $rendered) { card in
            ShareSheet(items: [card.image])
        }
    }

    @MainActor
    private func render(_ review: YearInReview.Review) {
        let renderer = ImageRenderer(content: YearCard(review: review))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 420, height: nil)
        if let image = renderer.uiImage { rendered = RenderedCard(image: image) }
    }

    // MARK: - Data

    private func load() {
        facts = Self.facts(env)
        years = YearInReview.years(facts)
        if !years.contains(year), let newest = years.first { year = newest }
        rebuild()
        hasLooked = true
    }

    private func rebuild() {
        review = YearInReview.review(facts, year: year, words: { env.wheel.descriptor($0)?.label ?? $0 })
    }

    /// The year's raw material, from every repository that dates things.
    static func facts(_ env: AppEnvironment) -> YearInReview.Facts {
        func date(_ millis: Int64) -> Date { Date(timeIntervalSince1970: Double(millis) / 1000) }
        let summaries = (try? env.bottles.summaries(includeFinished: true)) ?? []
        let names = Dictionary(summaries.map { ($0.id, env.name(for: $0.bottle)) }, uniquingKeysWith: { a, _ in a })

        // Samples are somebody else's bottle, not an addition to the shelf.
        let added = summaries.filter { !$0.bottle.isSample }.map { summary in
            (name: names[summary.id] ?? "A bottle",
             classLabel: env.classType(for: summary.bottle)?.label,
             distillery: env.distillery(for: summary.bottle),
             cents: summary.bottle.purchasePriceCents,
             at: date(summary.bottle.purchaseDate ?? summary.bottle.createdAt))
        }
        let opened = summaries.compactMap { $0.bottle.openedAt.map(date) }
        let tastings = ((try? env.tastings.allDetails()) ?? []).map { detail -> (name: String, rating: Int?, at: Date, words: [String]) in
            let productName = detail.tasting.catalogProductId.flatMap { env.identity($0)?.displayName }
            let bottleName = detail.tasting.bottleId.flatMap { names[$0] }
            return (name: productName ?? bottleName ?? "A tasting",
                    rating: detail.tasting.rating,
                    at: date(detail.tasting.tastedAt),
                    words: TastingStage.allCases.flatMap { detail.descriptors(on: $0) })
        }
        let samples = summaries.compactMap { summary -> (from: String, at: Date)? in
            guard summary.bottle.isSample, let from = summary.bottle.sampleFrom else { return nil }
            return (from: from, at: date(summary.bottle.purchaseDate ?? summary.bottle.createdAt))
        }
        let log = (try? env.sightings.all()) ?? []
        let sightings = log.filter { $0.kind == .seen }.map { (store: $0.store, at: date($0.seenAt)) }
        let lotteries = log.filter { $0.kind == .entered }.map { row in
            (won: row.outcome.map { $0 == .won }, at: date(row.seenAt))
        }
        return YearInReview.Facts(
            added: added, opened: opened, tastings: tastings,
            samples: samples, sightings: sightings, lotteries: lotteries)
    }
}

/// The year as one image. No prices on it, ever.
struct YearCard: View {
    let review: YearInReview.Review

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MY YEAR ON THE SHELF")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Palette.textSecondary)
            Text(String(review.year))
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.text)
            Rectangle().fill(Palette.gold).frame(height: 2)
            ForEach(Array(review.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
        .background(Palette.background)
    }
}

#Preview {
    NavigationStack { YearView() }
        .environment(AppEnvironment.preview())
}
