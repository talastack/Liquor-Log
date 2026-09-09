import SwiftUI
import LiquorData
import LiquorEngine

/// What this bottle cost, and whether that was a good price.
///
/// **It never quotes a market value.** There is no free, legal, stable source
/// for what an allocated bottle trades at, and apps that publish one get
/// checked against reality and lose: *"the fair price on a ton of bottles is
/// absolute horse shit making the app useless as a guide."*
///
/// So it answers two narrower questions it can actually be right about:
///
/// 1. **What does a pour cost?** Pure arithmetic on what you paid. This is the
///    more useful number day to day — it turns an intimidating bottle price
///    into the price of a drink.
/// 2. **What have you paid before?** Your own record, which needs no outside
///    data and cannot be wrong. Somebody who buys the same bourbon twice a year
///    has a better price sense for it than any published figure; what they
///    cannot do is remember it accurately while standing in the shop.
///
/// A published shelf price is compared too when one exists, always naming its
/// source and always saying it is not a resale value.
struct PriceCard: View {
    let paidCents: Int?
    let capacityMilliliters: Double
    let pourSize: PourSize
    let history: PriceHistory.Summary?
    let reference: PriceReference?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Price")

            if let paidCents {
                paid(paidCents)
            } else {
                Text("No price recorded for this bottle.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }

            if let history {
                Divider().overlay(Palette.line)
                yourHistory(history)
            }

            if let paidCents, let reference {
                Divider().overlay(Palette.line)
                shelfComparison(paidCents: paidCents, reference: reference)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    // MARK: - What you paid

    private func paid(_ cents: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Money.short(cents))
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                Text("what you paid")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            if let perPour = PriceCheck.costPerPourCents(
                paidCents: cents,
                capacityMilliliters: capacityMilliliters,
                pourSize: pourSize) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Money.short(perPour))
                        .font(TypeScale.title())
                        .foregroundStyle(Palette.gold)
                    Text("a pour")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
    }

    // MARK: - Your own record

    private func yourHistory(_ history: PriceHistory.Summary) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(history.summary)
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recent = history.mostRecent, let store = recent.store {
                Text("Last from \(store).")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    // MARK: - Published shelf price

    private func shelfComparison(paidCents: Int, reference: PriceReference) -> some View {
        let result = PriceCheck.compare(paidCents: paidCents, reference: reference)
        return VStack(alignment: .leading, spacing: Space.xs) {
            Text(result.headline)
                .font(TypeScale.body())
                .foregroundStyle(tint(result.band))

            // Never optional. The comparison is only defensible if it says
            // which question it answered.
            Text(result.caveat)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tint(_ band: PriceCheck.Band) -> Color {
        switch band {
        case .atOrBelow: return Palette.good
        case .slightlyOver: return Palette.textSecondary
        case .wellOver: return Palette.gold
        case .farOver: return Palette.bad
        case .noReference: return Palette.textMuted
        }
    }
}

/// The live verdict while somebody types a price into Add a bottle.
///
/// Deliberately quiet. It reports a comparison and stops; it never tells
/// anybody not to buy something, and there is no version of it that says
/// "overpriced" in the app's own voice about a bottle in their hand.
struct PriceVerdictLine: View {
    let askingCents: Int
    let history: PriceHistory.Summary?

    var body: some View {
        let verdict = PriceHistory.compare(askingCents: askingCents, with: history)
        if verdict != .noHistory, let history {
            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.headline)
                    .font(TypeScale.secondary())
                    .foregroundStyle(tint(verdict))
                Text(history.summary)
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tint(_ verdict: PriceHistory.Verdict) -> Color {
        switch verdict {
        case .cheaperThanUsual: return Palette.good
        case .aboutWhatYouPay: return Palette.textSecondary
        case .moreThanUsual: return Palette.gold
        case .muchMoreThanUsual: return Palette.bad
        case .noHistory: return Palette.textMuted
        }
    }
}
