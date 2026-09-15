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
    @Environment(AppEnvironment.self) private var env
    @State private var typed = ""
    @State private var dustyChosen: Set<String> = []

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
    /// Wild Turkey's, tried after the others: its shapes share nothing
    /// with them.
    private var turkey: WildTurkeyCode? {
        code == nil && batch == nil && laser == nil && permit == nil ? WildTurkeyCode(typed) : nil
    }
    /// A four-digit NOM, or a tequila brand name, against the CRT registry.
    private var nomProducer: TequilaRegistry.Producer? {
        permit == nil ? env.tequila.producer(nom: typed) : nil
    }
    private var brandHits: [(producer: TequilaRegistry.Producer, brand: String)] {
        guard code == nil, batch == nil, laser == nil, permit == nil, turkey == nil, nomProducer == nil
        else { return [] }
        return env.tequila.find(brand: typed, limit: 6)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Decode a code")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("Four Roses recipe codes, Heaven Hill batch codes, Buffalo Trace and Wild Turkey bottling codes, DSP permits, tequila NOMs and brands.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("OESQ, B523, L19274, LL/DF021000, DSP-KY-113, NOM 1139", text: $typed)
                    .font(TypeScale.code(28))
                    .foregroundStyle(Palette.text)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(code != nil || batch != nil || laser != nil || permit != nil
                                || turkey != nil || nomProducer != nil || !brandHits.isEmpty
                                ? Palette.gold : Palette.line,
                                lineWidth: 1))

                if let code {
                    decoded(code)
                } else if let batch {
                    decodedBatch(batch)
                } else if let laser {
                    decodedLaser(laser)
                } else if let permit {
                    decodedPermit(permit)
                } else if let turkey {
                    decodedTurkey(turkey)
                } else if let nomProducer {
                    decodedNOM(nomProducer)
                } else if !brandHits.isEmpty {
                    decodedBrands(brandHits)
                } else if typed.trimmingCharacters(in: .whitespaces).count >= 4 {
                    Text("Not a code this knows.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                allTen
                dusty
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
                Text("Unknown is the honest answer.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func decodedTurkey(_ code: WildTurkeyCode) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("What it means")
            Text(code.summary)
                .font(TypeScale.body())
                .foregroundStyle(Palette.gold)
            Text("Wild Turkey's bottling code, read by the formats Rare Bird 101 has documented from bottles in hand. "
                 + "The brand does not publish the scheme; what the other letters mean is not known.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func decodedNOM(_ producer: TequilaRegistry.Producer) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("NOM \(producer.nom)")
                    .padding(.bottom, Space.xs)
                FactRow(label: "Producer", value: producer.company, isLast: true)
            }
            Text(brandsLine(producer))
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("From the Consejo Regulador del Tequila's registry of authorised producers, names as the CRT lists them.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func decodedBrands(_ hits: [(producer: TequilaRegistry.Producer, brand: String)]) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Who makes it")
                    .padding(.bottom, Space.xs)
                ForEach(Array(hits.enumerated()), id: \.offset) { index, hit in
                    FactRow(
                        label: hit.brand.capitalized,
                        value: "NOM \(hit.producer.nom) · \(hit.producer.company)",
                        isLast: index == hits.count - 1)
                }
            }
            if hits.count == 1, let only = hits.first {
                Text(brandsLine(only.producer))
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("From the CRT's registry. A brand's NOM can change when it moves distillery; the registry is what it is today.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Also from this plant: Corona, Jarana, Kirkland Signature and 4 more."
    private func brandsLine(_ producer: TequilaRegistry.Producer) -> String {
        let names = producer.brands.map { $0.capitalized }
        guard !names.isEmpty else { return "No brands registered against it." }
        let shown = names.prefix(6)
        let rest = names.count - shown.count
        var line = (names.count == 1 ? "Registered brand: " : "Registered brands: ") + shown.joined(separator: ", ")
        if rest > 0 { line += " and \(rest) more" }
        return line + "."
    }

    /// Dating an old bottle: tick what it shows, read the window. Every
    /// clue carries its reason; two that cannot both hold are said so.
    private var dusty: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Dating an old bottle")
            Text("Tick what the bottle shows.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
            VStack(spacing: 0) {
                ForEach(DustyClues.Clue.allCases) { clue in
                    Button {
                        if dustyChosen.contains(clue.id) { dustyChosen.remove(clue.id) } else { dustyChosen.insert(clue.id) }
                    } label: {
                        HStack(alignment: .top, spacing: Space.m) {
                            Image(systemName: dustyChosen.contains(clue.id) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(dustyChosen.contains(clue.id) ? Palette.gold : Palette.textMuted)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clue.text)
                                    .font(TypeScale.body())
                                    .foregroundStyle(Palette.text)
                                    .multilineTextAlignment(.leading)
                                Text(clue.why)
                                    .font(TypeScale.caption())
                                    .textCase(nil)
                                    .foregroundStyle(Palette.textMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Space.s)
                        .frame(minHeight: Space.tapTarget)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Palette.line)
                }
            }
            let window = DustyClues.window(for: DustyClues.Clue.allCases.filter { dustyChosen.contains($0.id) })
            Text(window.text)
                .font(TypeScale.body())
                .foregroundStyle(window.conflict == nil ? Palette.gold : Palette.bad)
                .fixedSize(horizontal: false, vertical: true)
            Text("Windows from federal dates and the collectors' references (whiskeyid.com, whiskeyprof.com); the bottle is where they overlap.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
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
            Text("Etched near the base of the glass. What the letters name is not published.")
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
        }
    }
}

#Preview {
    NavigationStack { CodeDecoderView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
