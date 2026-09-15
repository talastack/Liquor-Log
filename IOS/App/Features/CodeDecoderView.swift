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
    /// Buffalo Trace's laser-etched bottling code, tried last. Five digits
    /// after the letter, where a batch code has three, so it cannot be
    /// mistaken for one.
    private var laser: LaserCode? { code == nil && batch == nil ? LaserCode(typed) : nil }
    /// The federal permit on the back label. Normalised even when unknown,
    /// so the screen can say "not in the table" rather than nothing.
    private var permit: String? { DistilleryPermit.normalise(typed) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Decode a code")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("A Four Roses recipe code like OESQ, an Elijah Craig or "
                         + "Larceny batch code like B523, or the laser-etched code on "
                         + "the glass of any Buffalo Trace bottle like L19274 15:02 K, "
                         + "or the DSP permit number on the back label that says who "
                         + "really made it. Each says something specific about the "
                         + "bottle, and nothing else decodes them.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("OESQ, B523, L19274 or DSP-KY-113", text: $typed)
                    .font(TypeScale.code(28))
                    .foregroundStyle(Palette.text)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(code != nil || batch != nil || laser != nil || permit != nil ? Palette.gold : Palette.line,
                                lineWidth: 1))

                if let code {
                    decoded(code)
                } else if let batch {
                    decodedBatch(batch)
                } else if let laser {
                    decodedLaser(laser)
                } else if let permit {
                    decodedPermit(permit)
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

    private func decodedPermit(_ number: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let plant = DistilleryPermit.lookup(number) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Whose plant")
                        .padding(.bottom, Space.xs)
                    FactRow(label: number, value: plant.distillery)
                    FactRow(label: "Where", value: plant.location, isLast: plant.note == nil)
                    if let note = plant.note {
                        FactRow(label: "Note", value: note, isLast: true)
                    }
                }
                Text(plant.onTwoLists
                     ? "Checked against two independent public lists of DSP numbers."
                     : "On one public list of DSP numbers, not yet two. Treat as likely, not certain.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(number) is not in the table.")
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                Text("The table covers the plants behind most of the bourbon on a shelf, "
                     + "not every permit in the country. Not knowing is the honest answer; "
                     + "guessing would name the wrong distillery.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("The label must name the plant that distilled or bottled the whiskey, "
                 + "by its federal permit. A brand with no distillery of its own carries "
                 + "somebody else's number — which is how sourced whiskey is unmasked.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func decodedLaser(_ laser: LaserCode) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("What it means")
                    .padding(.bottom, Space.xs)
                if let prefix = laser.prefix {
                    FactRow(label: String(prefix), value: "Leading letter, always printed")
                }
                FactRow(label: String(format: "%02d", laser.year % 100), value: "\(laser.year)")
                FactRow(label: String(format: "%03d", laser.dayOfYear),
                        value: "Day \(laser.dayOfYear) of the year",
                        isLast: laser.hour == nil && laser.line == nil)
                if let hour = laser.hour, let minute = laser.minute {
                    FactRow(label: String(format: "%02d:%02d", hour, minute),
                            value: "Time of day, 24-hour", isLast: laser.line == nil)
                }
                if let line = laser.line {
                    FactRow(label: String(line), value: "Bottling line", isLast: true)
                }
            }
            Text(laser.summary())
                .font(TypeScale.body())
                .foregroundStyle(Palette.gold)
            Text("Etched near the base of the glass on every Buffalo Trace bottle — "
                 + "Blanton's, Weller, Stagg, E.H. Taylor, Eagle Rare. For most of them "
                 + "it is the only date the bottle carries. What the letters name is "
                 + "not decoded: nobody has published it.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
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
