import SwiftUI
import LiquorData
import LiquorEngine

/// Enum tabs rather than string paths: every destination is exhaustively
/// switched, so a typo is a compile error instead of a blank screen.
enum Tab: Hashable, CaseIterable {
    case shelfCheck
    case collection
    case tasting
    case more

    var title: String {
        switch self {
        case .shelfCheck: return "Shelf Check"
        case .collection: return "Collection"
        case .tasting: return "Tasting"
        case .more: return "More"
        }
    }

    var symbol: String {
        switch self {
        case .shelfCheck: return "magnifyingglass"
        case .collection: return "square.stack.3d.up"
        case .tasting: return "wineglass"
        case .more: return "ellipsis"
        }
    }
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tab: Tab = .shelfCheck
    @State private var isAddingBottle = false
    @State private var isAddingTasting = false
    @State private var isChoosingWhatToAdd = false

    var body: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { item in
                NavigationStack { screen(for: item) }
                    .tabItem { Label(item.title, systemImage: item.symbol) }
                    .tag(item)
            }
        }
        .overlay(alignment: .bottom) {
            // The canvas puts a gold "+" in the middle of the bar. A true centre
            // tab button needs a custom bar, which has real safe-area and
            // accessibility pitfalls; this floats above the system one so the
            // action exists from day one without faking the chrome.
            Button { isChoosingWhatToAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.onGold)
                    .frame(width: Space.tapTarget, height: Space.tapTarget)
                    .background(Circle().fill(Palette.gold))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            }
            .accessibilityLabel("Add a bottle or a tasting")
            .padding(.bottom, 52)
        }
        .confirmationDialog("Add", isPresented: $isChoosingWhatToAdd) {
            Button("Add a bottle") { isAddingBottle = true }
            Button("Record a tasting") { isAddingTasting = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $isAddingBottle) {
            NavigationStack { AddBottleView() }
        }
        .sheet(isPresented: $isAddingTasting) {
            NavigationStack { TastingSheetView() }
        }
        .overlay(alignment: .top) {
            if let message = env.startupError {
                StartupBanner(message: message)
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: Tab) -> some View {
        switch tab {
        case .shelfCheck: ShelfCheckView()
        case .collection: CollectionView()
        case .tasting: TastingHistoryView()
        case .more: MoreView()
        }
    }
}

/// Shown when the database could not be opened. The app stays usable and says
/// so, rather than dying at launch with nothing to report.
struct StartupBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(TypeScale.secondary())
            .foregroundStyle(Palette.text)
            .padding(Space.m)
            .frame(maxWidth: .infinity)
            .background(Palette.bad.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Every tasting you have recorded, newest first.
struct TastingHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var details: [TastingDetailRow] = []

    struct TastingDetailRow: Identifiable {
        let id: String
        let title: String
        let rating: Int?
        let liked: String?
        /// Was being recorded and never shown. The research rates would-buy-
        /// again as MORE useful than a numeric score -- most people's ratings
        /// cluster in one narrow band, and this one does not.
        let rebuy: Rebuy?
        let disliked: String?
        let descriptors: String
        let date: Date
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Tastings")
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                    .padding(.top, Space.s)

                if details.isEmpty {
                    VStack(spacing: Space.m) {
                        Text("No tastings yet")
                            .font(TypeScale.title())
                            .foregroundStyle(Palette.text)
                        Text("Tap the + to record one. A rating on its own is enough.")
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 64)
                } else {
                    ForEach(details) { row in
                        VStack(alignment: .leading, spacing: Space.s) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.title)
                                    .font(TypeScale.title())
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                if let rating = row.rating { RatingChip(rating: rating) }
                            }
                            Text(row.date.formatted(date: .abbreviated, time: .omitted))
                                .font(TypeScale.code(13))
                                .foregroundStyle(Palette.textMuted)
                            if let rebuy = row.rebuy {
                                Text(rebuyLabel(rebuy))
                                    .font(TypeScale.secondary())
                                    .foregroundStyle(
                                        rebuy == .no ? Palette.bad : Palette.gold)
                            }
                            if let liked = row.liked, !liked.isEmpty {
                                Text(liked)
                                    .font(TypeScale.secondary())
                                    .foregroundStyle(Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let disliked = row.disliked, !disliked.isEmpty {
                                Text(disliked)
                                    .font(TypeScale.secondary())
                                    .foregroundStyle(Palette.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if !row.descriptors.isEmpty {
                                Text(row.descriptors)
                                    .font(TypeScale.caption())
                                    .textCase(nil)
                                    .foregroundStyle(Palette.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(Space.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Palette.line, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private func reload() {
        let summaries = (try? env.bottles.summaries(includeFinished: true)) ?? []
        var rows: [TastingDetailRow] = []
        for summary in summaries {
            let history = (try? env.tastings.history(bottleId: summary.id)) ?? []
            for detail in history {
                rows.append(TastingDetailRow(
                    id: detail.id,
                    title: env.name(for: summary.bottle),
                    rating: detail.tasting.rating,
                    liked: detail.tasting.liked,
                    rebuy: detail.tasting.wouldRebuy,
                    disliked: detail.tasting.disliked,
                    descriptors: describe(detail),
                    date: Date(timeIntervalSince1970: Double(detail.tasting.tastedAt) / 1000)))
            }
        }
        details = rows.sorted { $0.date > $1.date }
    }

    private func rebuyLabel(_ rebuy: Rebuy) -> String {
        switch rebuy {
        case .yes: return "Would buy again"
        case .maybe: return "Might buy again"
        case .no: return "Would not buy again"
        }
    }

    private func describe(_ detail: TastingDetail) -> String {
        TastingStage.allCases.compactMap { stage -> String? in
            let keys = detail.descriptors(on: stage)
            guard !keys.isEmpty else { return nil }
            let labels = keys.compactMap { env.wheel.descriptor($0)?.label ?? $0 }
            return "\(stage.rawValue.capitalized): \(labels.joined(separator: ", "))"
        }
        .joined(separator: "  ·  ")
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
