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
                        Text("Share as text")
                            .font(TypeScale.headline())
                            .foregroundStyle(Palette.onGold)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }

                    // The same menu as a picture, for a group chat, a story or
                    // a card propped on the bar. Rendered on tap, not on every
                    // keystroke of the title.
                    Button { renderImage() } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "photo")
                            Text("Share as an image")
                        }
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
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
        .sheet(item: $rendered) { card in
            ShareSheet(items: [card.image])
        }
    }

    // MARK: - Image

    /// A rendered menu, wrapped so a sheet can present it by identity.
    struct RenderedMenu: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @State private var rendered: RenderedMenu?

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: PourMenuCard(title: title, items: items))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 400, height: nil)
        if let image = renderer.uiImage {
            rendered = RenderedMenu(image: image)
        }
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


/// The menu as a card: dark, gold rule, the same words as the text version.
/// Fixed width so it renders the same on every phone; the height follows the
/// list.
struct PourMenuCard: View {
    let title: String
    let items: [PourMenu.Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title.isEmpty ? "Open tonight" : title)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.86))
            Rectangle()
                .fill(Color(red: 0.79, green: 0.59, blue: 0.23))
                .frame(height: 2)
            ForEach(items, id: \.name) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 12)
                        if let proof = item.proof {
                            Text(String(format: "%.1f", proof))
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundStyle(Color(red: 0.79, green: 0.59, blue: 0.23))
                        }
                    }
                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(red: 0.59, green: 0.53, blue: 0.44))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("Help yourself.")
                .font(.system(size: 13, design: .serif).italic())
                .foregroundStyle(Color(red: 0.59, green: 0.53, blue: 0.44))
                .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 400, alignment: .leading)
        .background(Color(red: 0.08, green: 0.06, blue: 0.04))
    }
}

/// UIKit's share sheet, for things ShareLink cannot take straight: a
/// UIImage rendered a moment ago.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { PourMenuView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
