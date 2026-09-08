import SwiftUI

/// Enum routes rather than string paths: every destination is exhaustively
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
    @State private var tab: Tab = .shelfCheck
    @State private var isAdding = false

    var body: some View {
        TabView(selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { item in
                NavigationStack {
                    Placeholder(title: item.title)
                }
                .tabItem { Label(item.title, systemImage: item.symbol) }
                .tag(item)
            }
        }
        .overlay(alignment: .bottom) {
            // The canvas puts a gold "+" in the middle of the bar. A real
            // centre tab button needs a custom bar; this floats above the
            // system one until that lands, so the action exists from day one.
            Button { isAdding = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.onGold)
                    .frame(width: Space.tapTarget, height: Space.tapTarget)
                    .background(Circle().fill(Palette.gold))
            }
            .accessibilityLabel("Add a bottle")
            .padding(.bottom, 52)
        }
        .sheet(isPresented: $isAdding) {
            Placeholder(title: "Add a bottle")
        }
    }
}

/// Stands in until each screen lands, in canvas order: shelf check first.
private struct Placeholder: View {
    let title: String

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: Space.l) {
                BottleMark(height: 76)
                Text(title).font(TypeScale.largeTitle()).foregroundStyle(Palette.text)
                Text("Not built yet.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }
}
