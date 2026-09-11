import SwiftUI
import LiquorData
import LiquorEngine

/// What your collection looks like.
///
/// The research says the growth loop in this category is a shareable stats
/// screenshot — *"My OnlyDrams Post (10 years of collecting)"*, *"Can some one
/// do the OnlyDrams thing for me?"* — and that the chart is the marketing
/// asset. So this screen is built to be photographed.
///
/// **It counts the collection and never the drinking.** Bottles owned, classes
/// represented, distilleries, the strongest thing on the shelf. Nothing counts
/// pours, nothing is a streak, and no number here goes up because somebody
/// drank more — which is Apple guideline 1.4.3, and also what the research
/// found people want: an app pitched on "collection progress and competition"
/// scored 1, 1, 1 across three r/bourbon posts.
struct StatsView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var summary: CollectionStats.Summary?

    /// The same switch as More and the Collection. Money appears here only
    /// when it was asked for.
    @AppStorage("showsCollectionValue") private var showsValue = CollectionValue.shownByDefault

    /// The rendered card, while its share sheet is up.
    @State private var shareCard: RenderedCard?

    struct RenderedCard: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let summary, !summary.isEmpty {
                    headline(summary)
                    shareButton(summary)
                    breakdown("By kind", summary.byClass, total: summary.onShelf)
                    breakdown("By distillery", summary.byDistillery, total: summary.onShelf)
                    if summary.byBrand.count > 1 {
                        breakdown("By brand", summary.byBrand, total: summary.onShelf)
                    }
                    breakdown("By strength", summary.byStrength, total: summary.onShelf)
                    if !summary.byPlace.isEmpty {
                        breakdown("Where they are", summary.byPlace, total: summary.onShelf)
                    }
                    if summary.addedByYear.count > 1 {
                        growth(summary)
                    }
                    notes(summary)
                    if showsValue {
                        money(summary)
                    }
                } else {
                    empty
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Your collection")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .sheet(item: $shareCard) { card in
            ShareSheet(items: [card.image])
        }
    }

    /// The research's one growth loop: *"OnlyDrams' growth loop is a
    /// shareable stats screenshot. Build something screenshot-worthy."* This
    /// is that, as a card rather than a screenshot: bottles, distilleries,
    /// kinds, the top of each list -- and never money, never pours, never
    /// anything drunk. Rendered on tap.
    private func shareButton(_ summary: CollectionStats.Summary) -> some View {
        Button {
            renderCard(summary)
        } label: {
            HStack(spacing: Space.s) {
                Image(systemName: "square.and.arrow.up")
                Text("Share as a card")
            }
            .font(TypeScale.secondary().weight(.semibold))
            .foregroundStyle(Palette.gold)
            .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
        }
    }

    @MainActor
    private func renderCard(_ summary: CollectionStats.Summary) {
        let renderer = ImageRenderer(content: CollectionCard(summary: summary))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 400, height: nil)
        if let image = renderer.uiImage {
            shareCard = RenderedCard(image: image)
        }
    }

    // MARK: - Sections

    private func headline(_ summary: CollectionStats.Summary) -> some View {
        VStack(spacing: Space.m) {
            Text("\(summary.onShelf)")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.gold)
            Text(summary.onShelf == 1 ? "bottle" : "bottles")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)

            HStack(spacing: Space.xl) {
                figure("\(summary.open)", "open")
                figure("\(summary.distilleryCount)", "distilleries")
                figure("\(summary.classCount)", "kinds")
                if summary.picks > 0 {
                    figure("\(summary.picks)", summary.picks == 1 ? "pick" : "picks")
                }
            }
            .padding(.top, Space.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text(label)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    /// Bars rather than a pie. A pie chart of twelve distilleries is unreadable
    /// and a screenshot of one is worse; a sorted bar list stays legible at any
    /// length and reads correctly to somebody who cannot distinguish the
    /// colours.
    private func breakdown(
        _ title: String, _ slices: [CollectionStats.Slice], total: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(title)
            if slices.isEmpty {
                Text("Not recorded on any bottle yet.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            } else {
                ForEach(slices.prefix(8)) { slice in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(slice.label)
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: Space.s)
                            Text("\(slice.count)")
                                .font(TypeScale.code(13))
                                .foregroundStyle(Palette.textMuted)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.surfaceRaised)
                                Capsule()
                                    .fill(Palette.gold)
                                    .frame(width: geometry.size.width * slice.share(of: total))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    /// Bottles added per year. The collection growing is the one curve that
    /// is allowed to go up: it counts what was bought, never what was drunk.
    private func growth(_ summary: CollectionStats.Summary) -> some View {
        let peak = summary.addedByYear.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Added by year")
            HStack(alignment: .bottom, spacing: Space.s) {
                ForEach(summary.addedByYear) { slice in
                    VStack(spacing: 4) {
                        Text("\(slice.count)")
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textSecondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Palette.gold)
                            .frame(height: max(6, 72 * CGFloat(slice.count) / CGFloat(peak)))
                        Text(slice.label)
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(Space.l)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
        }
    }

    /// What the shelf cost. Never what it is worth, and never shown unless
    /// the switch in More is on.
    private func money(_ summary: CollectionStats.Summary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("What it cost")
                .padding(.bottom, Space.xs)
            if let average = summary.averageCostPerPourCents {
                FactRow(label: "A pour, on average", value: Money.short(average))
            }
            if let dear = summary.dearestPour {
                FactRow(label: "Dearest pour", value: "\(Money.short(dear.value)) · \(dear.name)")
            }
            if let cheap = summary.cheapestPour, cheap != summary.dearestPour {
                FactRow(label: "Cheapest pour", value: "\(Money.short(cheap.value)) · \(cheap.name)")
            }
            ForEach(Array(summary.spentByYear.enumerated()), id: \.element.id) { index, year in
                FactRow(
                    label: "Spent in \(year.label)",
                    value: Money.short(year.cents),
                    isLast: index == summary.spentByYear.count - 1)
            }
            Text("Bottles on the shelf with a price and a purchase date. What you "
                 + "paid, not what it is worth.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s)
        }
    }

    /// Facts about bottles, which the research says generate genuine delight —
    /// as opposed to a score, which does not.
    private func notes(_ summary: CollectionStats.Summary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Notable")
                .padding(.bottom, Space.xs)
            if let proof = summary.highestProof {
                FactRow(label: "Strongest", value: String(format: "%.1f proof", proof))
            }
            if let months = summary.oldestStatedAgeMonths {
                FactRow(label: "Oldest stated age", value: AgeMath.describe(months: months))
            }
            // Oxidation bookkeeping, not a prompt: which bottle has been open
            // longest is a fact somebody wants for the same reason they set
            // a fill level.
            if let longest = summary.longestOpen {
                FactRow(
                    label: "Open longest",
                    value: "\(longest.value) \(longest.value == 1 ? "day" : "days") · \(longest.name)")
            }
            // The stopper set, as a fact about the shelf. Complete or not,
            // it is never a goal bar: the research's one welcomed registry
            // records these letters and nobody there is awarded anything.
            if let toppers = summary.topperLetters {
                FactRow(
                    label: "Blanton's toppers",
                    value: toppers.isComplete
                        ? "All eight · \(toppers.wordLine)"
                        : "\(toppers.ownedCount) of 8 · \(toppers.wordLine)")
            }
            // Stated plainly. Finishing a bottle is bookkeeping, not a score,
            // so there is no celebration and no total attached to it.
            FactRow(label: "Finished and archived", value: "\(summary.finished)", isLast: true)
        }
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            BottleMark(height: 84)
            Text("Nothing to summarise yet")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("Add a few bottles and this becomes a picture of your shelf.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    private func reload() {
        let bottles = (try? env.bottles.summaries(includeFinished: true)) ?? []
        summary = CollectionStats.summarise(bottles.map { row in
            let bottle = row.bottle
            let product = env.product(for: bottle)
            return CollectionStats.Entry(
                name: env.name(for: bottle),
                classType: env.classType(for: bottle),
                distillery: env.distillery(for: bottle),
                brand: bottle.catalogProductId.flatMap { env.identity($0)?.brand },
                // The bottle's MEASURED strength first: for a barrel-proof
                // release the catalogue figure is null on purpose.
                abv: bottle.abv ?? product?.abv,
                isOpen: bottle.isOpen,
                isFinished: bottle.isFinished,
                isPick: bottle.hasPickDetail,
                addedAt: Date(timeIntervalSince1970: Double(bottle.createdAt) / 1000),
                openedAt: bottle.openedAt.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                ageMonths: bottle.ageMonths
                    ?? product?.statedAgeYears.map { $0 * 12 },
                storageLocation: bottle.storageLocation,
                purchasePriceCents: bottle.purchasePriceCents,
                purchasedAt: bottle.purchaseDate.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                costPerPourCents: row.costPerPourCents,
                topperLetter: bottle.topperLetter)
        })
    }
}


/// The collection as a card to post. Counts the shelf, never the drinking,
/// and never the money: a card with a dollar figure on it is a card that
/// gets somebody's house looked at.
struct CollectionCard: View {
    let summary: CollectionStats.Summary

    private let ink = Color(red: 0.95, green: 0.91, blue: 0.86)
    private let gold = Color(red: 0.79, green: 0.59, blue: 0.23)
    private let muted = Color(red: 0.59, green: 0.53, blue: 0.44)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(summary.onShelf)")
                    .font(.system(size: 56, weight: .semibold, design: .serif))
                    .foregroundStyle(gold)
                Text(summary.onShelf == 1 ? "bottle" : "bottles")
                    .font(.system(size: 18, design: .serif))
                    .foregroundStyle(ink)
                Spacer()
            }

            HStack(spacing: 22) {
                figure("\(summary.open)", "open")
                figure("\(summary.distilleryCount)", summary.distilleryCount == 1 ? "distillery" : "distilleries")
                figure("\(summary.classCount)", summary.classCount == 1 ? "kind" : "kinds")
                if summary.picks > 0 {
                    figure("\(summary.picks)", summary.picks == 1 ? "pick" : "picks")
                }
            }

            Rectangle().fill(gold).frame(height: 2)

            list("Most of", summary.byDistillery.prefix(4))
            list("By kind", summary.byClass.prefix(4))
            if !summary.byStrength.isEmpty {
                list("Strength", summary.byStrength.prefix(4))
            }

            HStack(alignment: .firstTextBaseline) {
                if let proof = summary.highestProof {
                    Text(String(format: "Strongest %.1f proof", proof))
                }
                if let months = summary.oldestStatedAgeMonths {
                    Text("· Oldest \(AgeMath.describe(months: months))")
                }
                Spacer()
            }
            .font(.system(size: 12))
            .foregroundStyle(muted)
        }
        .padding(28)
        .frame(width: 400, alignment: .leading)
        .background(Color(red: 0.08, green: 0.06, blue: 0.04))
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ink)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(muted)
        }
    }

    private func list(_ title: String, _ slices: ArraySlice<CollectionStats.Slice>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(muted)
            ForEach(Array(slices)) { slice in
                HStack {
                    Text(slice.label)
                        .font(.system(size: 14))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Spacer()
                    Text("\(slice.count)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(gold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { StatsView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
