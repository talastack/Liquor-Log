import SwiftUI
import LiquorData
import LiquorEngine

/// What is open, written out for a guest.
///
/// Asked for unprompted in the research and never built by anybody:
/// *"I really like the menu concept! Now if there was a way to take the
/// spreadsheet and populate the menu......"*
///
/// Three decisions, all deliberate:
///
/// **Open bottles only.** That is the question a guest is actually asking. A
/// sealed bottle is not on offer, and listing the whole collection turns a menu
/// into a brag.
///
/// **No prices.** A menu with prices reads as bragging about what the evening
/// cost, and the one thing a guest cannot do with that information is enjoy the
/// whiskey.
///
/// **Plain text.** It has to survive being pasted into a message, which is how
/// it will actually be sent.
struct PourMenuView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var items: [PourMenu.Item] = []
    @State private var title = "Open tonight"

    private var text: String { PourMenu.text(title: title, items: items) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                TextField("Title", text: $title)
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Palette.line, lineWidth: 1))

                if items.isEmpty {
                    Text("Nothing is open. Open a bottle and it appears here.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .padding(.top, Space.xl)
                } else {
                    VStack(alignment: .leading, spacing: Space.m) {
                        ForEach(items, id: \.name) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.name)
                                        .font(TypeScale.body())
                                        .foregroundStyle(Palette.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: Space.s)
                                    if let proof = item.proof {
                                        Text(String(format: "%.1f", proof))
                                            .font(TypeScale.code(13))
                                            .foregroundStyle(Palette.gold)
                                    }
                                }
                                if let detail = item.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(TypeScale.caption())
                                        .textCase(nil)
                                        .foregroundStyle(Palette.textMuted)
                                }
                            }
                            Divider().overlay(Palette.line)
                        }
                    }
                    .padding(Space.l)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Palette.line, lineWidth: 1))

                    ShareLink(item: text) {
                        Text("Share the menu")
                            .font(TypeScale.headline())
                            .foregroundStyle(Palette.onGold)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }
                }

                Text("Only open bottles, and no prices. A guest wants to know "
                     + "what they can have, not what it cost.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("What's open")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private func reload() {
        let bottles = (try? env.bottles.summaries()) ?? []
        items = bottles
            .filter { $0.bottle.isOpen && !$0.status.isEmpty }
            .map { row in
                let product = env.product(for: row.bottle)
                return PourMenu.Item(
                    name: env.name(for: row.bottle),
                    // The release is what distinguishes two bottles with the
                    // same name on a shelf, which is exactly what a guest
                    // choosing between them needs.
                    detail: row.bottle.releaseLabel,
                    proof: (row.bottle.abv ?? product?.abv).map { ABV(percent: $0).proof })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

#Preview {
    NavigationStack { PourMenuView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
