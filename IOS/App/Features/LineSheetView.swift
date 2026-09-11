import SwiftUI
import LiquorData
import LiquorEngine

/// One brand's line, expression by expression, against what you have.
///
/// Opened from the brand on a shelf-check card. "Which Wellers do I have"
/// is the aisle question one level up from "do I have this one", and the
/// answer is a list, not a score: no bar, no fraction, nothing that turns
/// a shelf into a checklist. Tapping a row looks that expression up.
struct LineSheetView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let product: ProductIdentity
    var onPick: ((String) -> Void)?

    @State private var line: LineView.Line?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let line {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionLabel(line.distillery)
                        Text(line.brand)
                            .font(TypeScale.largeTitle())
                            .foregroundStyle(Palette.text)
                    }

                    if line.rows.count == 1 {
                        Text("The catalogue lists only this expression of the line so far.")
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(line.rows.enumerated()), id: \.element.id) { index, row in
                            Button {
                                onPick?(row.product.displayName)
                                dismiss()
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                                    Image(systemName: symbol(row.standing))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(color(row.standing))
                                        .frame(width: 22)
                                    Text(row.product.expression.isEmpty
                                         ? row.product.brand : row.product.expression)
                                        .font(TypeScale.body())
                                        .foregroundStyle(Palette.text)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: Space.s)
                                    Text(row.standing.label)
                                        .font(TypeScale.caption())
                                        .textCase(nil)
                                        .foregroundStyle(color(row.standing))
                                }
                                .frame(minHeight: Space.tapTarget)
                            }
                            if index < line.rows.count - 1 {
                                Divider().overlay(Palette.line)
                            }
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))

                    Text("Expressions the catalogue knows. A bottle you typed in "
                         + "yourself is on your shelf whether or not it is listed here.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("The line")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
            }
        }
        .task { load() }
    }

    private func load() {
        // Resolved outside the reads; see BottleRepository.holdings.
        let holdings = (try? env.bottles.holdings { env.identity($0) }) ?? []
        let tastings = (try? env.tastings.records { env.identity($0) }) ?? []
        line = LineView.line(
            of: product,
            catalogue: env.catalog.products.map(\.identity),
            holdings: holdings,
            tastings: tastings)
    }

    private func symbol(_ standing: LineView.Standing) -> String {
        switch standing {
        case .onShelf: return "checkmark.circle.fill"
        case .hadItBefore: return "clock"
        case .tastedOnly: return "mouth"
        case .never: return "circle"
        }
    }

    private func color(_ standing: LineView.Standing) -> Color {
        switch standing {
        case .onShelf: return Palette.Verdict.onShelf
        case .hadItBefore: return Palette.Verdict.hadItBefore
        case .tastedOnly: return Palette.Verdict.tastedNotOwned
        case .never: return Palette.textMuted
        }
    }
}
