import SwiftUI
import LiquorData
import LiquorEngine

/// Type a Four Roses code, get the recipe.
///
/// The research brief looked for this and found nothing: *"Interactive
/// barrel-code decoders don't exist. No tool takes a Buffalo Trace laser code
/// or Four Roses recipe and returns an answer. Everything found is a static
/// explainer — gobourbon.com (last updated Feb 2021), ModernThirst (ends
/// 2019)."* The knowledge lives in blog posts that stopped updating years ago.
///
/// Ours has existed since the first commit, and was only reachable from the
/// screen of a bottle that already had a code on it. This makes it a tool in
/// its own right — the thing to open when a store pick is on the shelf in
/// front of you and the label says OBSK.
///
/// The decoder is the engine's, so the ten codes are the ten real ones and an
/// unrecognised string says so rather than inventing three letters out of four.
struct CodeDecoderView: View {
    @State private var typed = ""

    private var code: RecipeCode? { RecipeCode(typed) }
    /// Heaven Hill's scheme, tried when the Four Roses one does not fit. The
    /// two cannot collide: one is four letters, the other a letter and digits.
    private var batch: BatchCode? { code == nil ? BatchCode(typed) : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Decode a code")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("A Four Roses recipe code like OESQ, or an Elijah Craig "
                         + "or Larceny batch code like B523. Both say something "
                         + "specific about the bottle, and nothing else decodes them.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("OESQ or B523", text: $typed)
                    .font(TypeScale.code(28))
                    .foregroundStyle(Palette.text)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(code != nil || batch != nil ? Palette.gold : Palette.line,
                                lineWidth: 1))

                if let code {
                    decoded(code)
                } else if let batch {
                    decodedBatch(batch)
                } else if typed.trimmingCharacters(in: .whitespaces).count >= 4 {
                    Text("Not a code this knows. Four Roses is O, then B or E, then "
                         + "S, then one of V K O Q F. Heaven Hill batches are A, B or "
                         + "C, then the month, then a two-digit year.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                allTen
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Decode a code")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func decoded(_ code: RecipeCode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("What it means")
                .padding(.bottom, Space.xs)
            FactRow(label: "O", value: "Four Roses")
            FactRow(label: code.mashbill.rawValue, value: "Mashbill · " + code.mashbill.summary)
            FactRow(label: "S", value: "Straight whiskey")
            FactRow(label: code.yeast.rawValue, value: "Yeast · " + code.yeast.character, isLast: true)
        }
    }

    private func decodedBatch(_ batch: BatchCode) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("What it means")
                    .padding(.bottom, Space.xs)
                FactRow(label: String(batch.release.rawValue),
                        value: "\(batch.release.ordinal) release of the year")
                FactRow(label: "\(batch.month)", value: BatchCode.monthName(batch.month))
                FactRow(label: String(format: "%02d", batch.year % 100),
                        value: "\(batch.year)", isLast: true)
            }
            Text(batch.summary + ".")
                .font(TypeScale.body())
                .foregroundStyle(Palette.gold)

            // Not refused -- a real bottle can depart from the schedule -- but
            // said out loud, because a misread digit is the likelier story.
            if !batch.followsTheUsualSchedule {
                Text("Releases usually ship in January, May and September. A "
                     + "\(batch.release.ordinal.lowercased()) release in "
                     + "\(BatchCode.monthName(batch.month)) is unusual — worth "
                     + "checking the label again.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Elijah Craig Barrel Proof and Larceny Barrel Proof share this "
                 + "scheme.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
        }
    }

    /// Every code, so the screen is useful before anything is typed and so a
    /// half-remembered one can be found by its character.
    private var allTen: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("All ten")
            ForEach(RecipeCode.all, id: \.code) { entry in
                Button { typed = entry.code } label: {
                    HStack(spacing: Space.m) {
                        Text(entry.code)
                            .font(TypeScale.code(15))
                            .foregroundStyle(entry.code == code?.code ? Palette.gold : Palette.text)
                            .frame(width: 60, alignment: .leading)
                        Text("\(entry.mashbill.ryePercent)% rye · \(entry.yeast.character)")
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                    }
                    .frame(minHeight: Space.tapTarget)
                }
            }
            Text("The distillery's own descriptors for each yeast. The mashbills "
                 + "are Four Roses' published figures.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack { CodeDecoderView() }
        .preferredColorScheme(.dark)
}
