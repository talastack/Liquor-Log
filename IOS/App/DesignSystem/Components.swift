import SwiftUI
import LiquorEngine

// MARK: - Verdict badge

/// The shelf-check answer, as a label.
///
/// It takes `ShelfCheckResult.Headline` directly rather than a string, so the
/// switch below is exhaustive: adding a verdict to the engine is a compile
/// error here until somebody decides how it looks. A badge that silently falls
/// through to a default is a verdict the user never sees.
///
/// **Colour never carries the meaning alone.** Every badge shows its text, for
/// a dim shop aisle and for anyone colour-blind.
struct VerdictBadge: View {
    let headline: ShelfCheckResult.Headline

    var body: some View {
        Text(title)
            .font(TypeScale.caption())
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(isFilled ? Palette.onGold : tint)
            .padding(.horizontal, Space.m)
            .padding(.vertical, 5)
            .frame(minHeight: 26)
            .background {
                if isFilled {
                    RoundedRectangle(cornerRadius: 6).fill(tint)
                } else {
                    RoundedRectangle(cornerRadius: 6).stroke(tint, lineWidth: 1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Filled when you have some claim on the bottle, outlined when you do not.
    /// The fill is what carries at arm's length.
    private var isFilled: Bool {
        switch headline {
        case .onYourShelf, .haveTheLineNotThisRelease: return true
        case .hadItBefore, .tastedNeverOwned, .neverHadIt: return false
        }
    }

    private var tint: Color {
        switch headline {
        case .onYourShelf: return Palette.Verdict.onShelf
        case .haveTheLineNotThisRelease: return Palette.Verdict.haveTheLine
        case .tastedNeverOwned: return Palette.Verdict.tastedNotOwned
        case .hadItBefore: return Palette.Verdict.hadItBefore
        case .neverHadIt: return Palette.Verdict.neverHadIt
        }
    }

    private var title: String {
        switch headline {
        case .onYourShelf: return "On your shelf"
        case .haveTheLineNotThisRelease: return "Have the line"
        case .tastedNeverOwned: return "Tasted, not owned"
        case .hadItBefore: return "Had it before"
        case .neverHadIt: return "Never had it"
        }
    }
}

// MARK: - Fill bar

/// How much is left, from the engine's own `PourStatus`.
///
/// The count and the millilitres are rendered together and cannot be separated,
/// because the pour count rounds to nearest: a bottle holding 16.6 pours reads
/// "17". The millilitres are what stop that rounding from carrying weight on
/// its own.
/// Millilitres or US fluid ounces, by a per-device preference.
///
/// Bottles are labelled in millilitres and the database stores millilitres;
/// American pours are thought about in ounces. The preference changes only
/// what is SHOWN -- every stored number and every export stays metric, so
/// two devices with different settings hold the same data.
enum VolumeDisplay {
    static let key = "units.ounces"

    /// "573 ml" or "19.4 oz".
    static func text(_ milliliters: Double, ounces: Bool) -> String {
        if ounces {
            let oz = milliliters / Volume.usFluidOunceInMilliliters
            return String(format: oz < 10 ? "%.1f oz" : "%.0f oz", oz)
        }
        return "\(Int(milliliters.rounded())) ml"
    }

    /// Both, when ounces are on: "573 ml · 19.4 oz". Where the millilitres
    /// are the thing being edited they stay visible, so the number typed and
    /// the number shown never disagree.
    static func both(_ milliliters: Double, ounces: Bool) -> String {
        ounces
            ? "\(Int(milliliters.rounded())) ml · " + text(milliliters, ounces: true)
            : text(milliliters, ounces: false)
    }
}

struct FillBar: View {
    let status: PourStatus
    @AppStorage(VolumeDisplay.key) private var ounces = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text("\(status.remainingPours) of \(status.totalPours) pours left")
                    .font(TypeScale.code(16))
                    .foregroundStyle(Palette.text)
                Spacer(minLength: Space.s)
                Text(millilitres)
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceRaised)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Palette.gold, Palette.goldSoft],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 9)

            if status.hasPartialPourOnly {
                // Never render this state as "0 pours", which reads as empty.
                Text("Less than a pour left")
                    .font(TypeScale.caption())
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var fraction: Double {
        guard status.capacityMilliliters > 0 else { return 0 }
        return min(1, max(0, status.remainingMilliliters / status.capacityMilliliters))
    }

    private var millilitres: String {
        VolumeDisplay.text(status.remainingMilliliters, ounces: ounces) + " left"
    }
}

// MARK: - Rating

struct RatingChip: View {
    let rating: Int
    var outOf: Int = 10

    var body: some View {
        HStack(spacing: Space.xs + 1) {
            Image(systemName: "star.fill").font(.system(size: 12))
            Text("\(rating)/\(outOf)").font(TypeScale.secondary().weight(.semibold))
        }
        .foregroundStyle(Palette.gold)
        .padding(.horizontal, Space.m - 2)
        .padding(.vertical, 4)
        .frame(minHeight: 28)
        .background(RoundedRectangle(cornerRadius: 7).fill(Palette.surfaceRaised))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line, lineWidth: 1))
        .fixedSize(horizontal: true, vertical: true)
    }
}

// MARK: - Bottle mark

/// A drawn bottle silhouette, used wherever the canvas shows a thumbnail.
///
/// Deliberately a placeholder: real label artwork belongs to the distillery and
/// is not ours to reproduce. When a user photographs their own bottle, that
/// photo replaces this.
struct BottleMark: View {
    var tint: Color = Palette.gold
    var height: CGFloat = 58

    var body: some View {
        BottleShape()
            .fill(Palette.glass.opacity(0.55))
            .overlay(BottleShape().stroke(Palette.glass, lineWidth: 1.4))
            .overlay(alignment: .center) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint.opacity(0.85))
                    .frame(width: height * 0.29, height: height * 0.26)
                    .offset(y: height * 0.05)
            }
            .frame(width: height * 0.62, height: height)
            .accessibilityHidden(true)
    }
}

private struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Neck
        p.move(to: CGPoint(x: w * 0.39, y: h * 0.03))
        p.addLine(to: CGPoint(x: w * 0.61, y: h * 0.03))
        p.addLine(to: CGPoint(x: w * 0.61, y: h * 0.20))
        // Shoulder into the body
        p.addQuadCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.40),
            control: CGPoint(x: w * 0.90, y: h * 0.26))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.90))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.80, y: h * 0.97),
            control: CGPoint(x: w * 0.94, y: h * 0.97))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.97))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.06, y: h * 0.90),
            control: CGPoint(x: w * 0.06, y: h * 0.97))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.40))
        p.addQuadCurve(
            to: CGPoint(x: w * 0.39, y: h * 0.20),
            control: CGPoint(x: w * 0.10, y: h * 0.26))
        p.closeSubpath()
        return p
    }
}

// MARK: - Small parts

/// Uppercase section label. 12pt is the floor for anything in this app.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(TypeScale.caption())
            .kerning(1.1)
            .textCase(.uppercase)
            .foregroundStyle(Palette.textSecondary)
    }
}

/// A fact row: label on the left, value on the right, hairline underneath.
///
/// Class type and production type are always two of these, never one. They are
/// independent axes -- Elijah Craig Barrel Proof is Kentucky Straight *and*
/// small batch *and* barrel proof -- and merging them is what makes an app
/// unable to answer "do I have this bourbon, or do I have *this type*?"
struct FactRow: View {
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Space.l) {
                Text(label)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: Space.s)
                Text(value)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 13)

            if !isLast {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }
}

#Preview("Components") {
    ScrollView {
        VStack(alignment: .leading, spacing: Space.xl) {
            ForEach([
                ShelfCheckResult.Headline.onYourShelf,
                .haveTheLineNotThisRelease,
                .tastedNeverOwned,
                .hadItBefore,
                .neverHadIt
            ], id: \.self) { VerdictBadge(headline: $0) }

            FillBar(status: PourMath.status(
                capacityMilliliters: 750,
                pouredMilliliters: 4 * PourSize.standard.milliliters))

            HStack(spacing: Space.m) {
                RatingChip(rating: 8)
                BottleMark()
            }

            FactRow(label: "Class type", value: "Kentucky Straight Bourbon Whiskey")
            FactRow(label: "Production type", value: "Small batch · barrel proof", isLast: true)
        }
        .padding(Space.xl)
    }
    .background(Palette.background)
}
