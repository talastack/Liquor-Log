import SwiftUI
import LiquorData
import LiquorEngine

/// What you own, with how much is left in each.
///
/// Counts **bottles owned, never drinks had.** Apple rejects apps that
/// encourage excessive consumption, which rules out streaks, totals and
/// anything that makes drinking more feel like progress.
struct CollectionView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var summaries: [BottleSummary] = []
    @State private var showFinished = false
    @State private var error: String?

    /// Shared with the switch in More. Off unless somebody turned it on: the
    /// figure is wanted by some people and actively avoided by others, and a
    /// total nobody asked for is the version that causes harm.
    @AppStorage("showsCollectionValue") private var showsValue = CollectionValue.shownByDefault

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.m) {
                header

                if summaries.isEmpty {
                    empty
                } else {
                    ForEach(summaries) { summary in
                        NavigationLink {
                            BottleDetailView(bottleId: summary.id)
                        } label: {
                            BottleCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .refreshable { reload() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(showFinished ? "Everything" : "On your shelf")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                Spacer()
            }

            // Bottles, not drinks. See the note on this view.
            Text(countLine)
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)

            if showsValue {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Money.short(shelfValue.cents))
                        .font(TypeScale.title())
                        .foregroundStyle(Palette.gold)
                    Text(shelfValue.caveat)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Picker("", selection: $showFinished) {
                Text("On the shelf").tag(false)
                Text("All").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: showFinished) { _, _ in reload() }
        }
        .padding(.top, Space.s)
    }

    /// What is on the shelf cost, never what it is worth. We have no market
    /// data and will not invent any.
    private var shelfValue: CollectionValue.Total {
        CollectionValue.onTheShelf(summaries.map {
            CollectionValue.Holding(
                purchasePriceCents: $0.bottle.purchasePriceCents,
                isFinished: $0.bottle.isFinished)
        })
    }

    private var countLine: String {
        let open = summaries.filter(\.bottle.isOpen).count
        let bottles = summaries.count == 1 ? "1 bottle" : "\(summaries.count) bottles"
        return open > 0 ? "\(bottles) · \(open) open" : bottles
    }

    private var empty: some View {
        VStack(spacing: Space.l) {
            BottleMark(height: 84)
            Text("Nothing here yet")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("Add a bottle and it will show up here with how much is left in it.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    private func reload() {
        do {
            summaries = try env.bottles.summaries(includeFinished: showFinished)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// One bottle in the list. Fill count and millilitres always travel together —
/// the pour count rounds to nearest, and the millilitres are what stop that
/// rounding carrying weight on its own.
struct BottleCard: View {
    @Environment(AppEnvironment.self) private var env
    let summary: BottleSummary

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            BottleMark(height: 58)

            VStack(alignment: .leading, spacing: Space.s) {
                if let distillery = env.distillery(for: summary.bottle) {
                    SectionLabel(distillery)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(env.name(for: summary.bottle))
                        .font(TypeScale.title())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Space.s)
                    if summary.bottle.isOpen {
                        Text("Open")
                            .font(TypeScale.caption())
                            .foregroundStyle(Palette.gold)
                            .padding(.horizontal, Space.s)
                            .padding(.vertical, 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Palette.gold, lineWidth: 1))
                    }
                }

                if let release = summary.bottle.releaseLabel {
                    Text(release)
                        .font(TypeScale.code(13))
                        .foregroundStyle(Palette.textMuted)
                }

                FillBar(status: summary.status)

                HStack(spacing: Space.m) {
                    if let rating = summary.latestRating {
                        RatingChip(rating: rating)
                    }
                    if let cents = summary.costPerPourCents {
                        Text(Money.short(cents) + " a pour")
                            .font(TypeScale.code(13))
                            .foregroundStyle(Palette.textMuted)
                    }
                    Spacer()
                }

                // People use this to dig out a bottle they liked and have not
                // poured from in months. It is a fact about the bottle, never a
                // nudge to drink: no streak, no "it has been too long".
                if let line = lastPourLine {
                    Text(line)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }

                if let location = summary.bottle.storageLocation {
                    Text(location)
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    /// Nil for a bottle that has never been poured from — "never poured" on a
    /// sealed bottle states the obvious, and on an open one it reads as a
    /// reproach.
    private var lastPourLine: String? {
        guard let days = summary.daysSinceLastPour() else { return nil }
        switch days {
        case 0: return "Last poured today"
        case 1: return "Last poured yesterday"
        case ..<30: return "Last poured \(days) days ago"
        case ..<60: return "Last poured about a month ago"
        case ..<365: return "Last poured \(days / 30) months ago"
        default: return "Last poured over a year ago"
        }
    }
}

// `Money` now lives in LiquorEngine. It moved because the engine renders prices
// inside sentences of its own -- "You paid $79.99 for this before" -- and two
// formatters would eventually disagree inside a single screen.

#Preview {
    NavigationStack {
        CollectionView()
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
