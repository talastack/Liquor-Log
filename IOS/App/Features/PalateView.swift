import SwiftUI
import LiquorEngine
import LiquorData

/// What your own tastings say about you: the words you reach for, how you
/// rate by class, strength and mashbill, whether heat costs a bottle
/// points. Averages with their counts; nothing until there are enough.
struct PalateView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var profile: Palate.Profile = Palate.profile([])
    @State private var hasLooked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Your palate")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text(profile.isEmpty
                         ? "From your tastings, once there are some."
                         : "From \(profile.tastings) \(profile.tastings == 1 ? "tasting" : "tastings"), \(profile.rated) rated.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                }

                let sentences = Palate.sentences(profile) { key in env.wheel.descriptor(key)?.label ?? key }
                if !sentences.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                            Text(sentence)
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                } else if hasLooked {
                    Text(profile.isEmpty
                         ? "Record a few tastings and this fills in."
                         : "A few more rated tastings and this starts to say something. Three a side is the floor.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !profile.words.isEmpty {
                    words
                }
                if !profile.byClass.isEmpty {
                    table("By class", profile.byClass)
                }
                if !profile.byStrength.isEmpty {
                    table("By strength", profile.byStrength)
                }
                if let w = profile.wheated, let o = profile.otherBourbon {
                    table("By mashbill", [w, o])
                }
                if let hot = profile.whenHot, let easy = profile.whenEasy {
                    table("By how it drank", [easy, hot])
                }

                Text("Your ratings, averaged, with the number of tastings each rests on. Opinions, never a count of anything drunk.")
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
        .navigationTitle("Your palate")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .onChange(of: env.changeCount) { _, _ in reload() }
    }

    /// The words, sized by use. The count is printed: a word used twice
    /// is not a signature, and the number says so.
    private var words: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Words you reach for")
            FlowLayout(spacing: Space.s) {
                ForEach(profile.words.prefix(18)) { word in
                    HStack(spacing: 4) {
                        Text(env.wheel.descriptor(word.key)?.label ?? word.key)
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.text)
                        Text("\(word.count)")
                            .font(TypeScale.code(12))
                            .foregroundStyle(Palette.textMuted)
                    }
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
                }
            }
        }
    }

    private func table(_ title: String, _ lines: [Palate.Line]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title)
                .padding(.bottom, Space.xs)
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                FactRow(
                    label: line.label,
                    value: "\(line.averageText) · \(line.count) \(line.count == 1 ? "tasting" : "tastings")",
                    isLast: index == lines.count - 1)
            }
        }
    }

    private func reload() {
        let details = (try? env.tastings.allDetails()) ?? []
        let bottles = Dictionary(uniqueKeysWithValues:
            ((try? env.bottles.summaries(includeFinished: true)) ?? []).map { ($0.id, $0.bottle) })
        profile = Palate.profile(details.map { detail in
            let tasting = detail.tasting
            let productId = tasting.catalogProductId
                ?? tasting.bottleId.flatMap { bottles[$0]?.catalogProductId }
            let product = productId.flatMap { env.catalog.product($0) }
            let classType = productId.flatMap { env.identity($0)?.classType }
            let bottleABV = tasting.bottleId.flatMap { bottles[$0]?.abv }
            let isWheated: Bool? = {
                guard let classType, classType.family == .whiskey,
                      [.bourbon, .straightBourbon, .kentuckyStraightBourbon, .blendOfStraightBourbon].contains(classType)
                else { return nil }
                if product?.mashbillKey == "wheated" { return true }
                if let code = product?.recipeCode ?? tasting.bottleId.flatMap({ bottles[$0]?.recipeCode }),
                   RecipeCode(code) != nil { return false }
                return product == nil ? nil : false
            }()
            return Palate.Tasting(
                classType: classType,
                abv: bottleABV ?? product?.abv,
                isWheated: isWheated,
                rating: tasting.rating,
                perceivedHeat: tasting.perceivedHeat,
                finishSeconds: tasting.finishSeconds,
                wouldRebuy: tasting.wouldRebuy.map { $0 == .yes },
                descriptors: TastingStage.allCases.flatMap { detail.descriptors(on: $0) })
        })
        hasLooked = true
    }
}

/// Wraps its children onto as many rows as they need. SwiftUI has no
/// built-in flow layout; this is the smallest one that works.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack { PalateView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
