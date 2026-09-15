import SwiftUI
import LiquorEngine
import LiquorData

/// What is in an infinity bottle, and the two ways to add to it.
///
/// The strength and the make-up come from the engine's `Blend` over the
/// additions; the list underneath is the additions themselves, newest
/// first, each removable. Nothing here is a guess: an addition without a
/// known proof makes the strength read "unknown" and says how much.
struct InfinityCard: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage(VolumeDisplay.key) private var ounces = false

    let bottle: Bottle
    let additions: [BlendAddition]
    let profile: Blend.Profile
    let onChange: () -> Void

    @State private var isPickingSource = false
    @State private var isAddingByName = false
    @State private var byName = ""
    @State private var byProof = ""
    @State private var byMilliliters = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("What is in it")

            HStack(alignment: .firstTextBaseline) {
                Text(profile.strengthText)
                    .font(TypeScale.headline())
                    .foregroundStyle(profile.abv == nil ? Palette.textSecondary : Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if !profile.isEmpty {
                    Text("\(VolumeDisplay.text(profile.addedMilliliters, ounces: ounces)) added")
                        .font(TypeScale.code(13))
                        .foregroundStyle(Palette.textMuted)
                }
            }

            if !profile.shares.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    ForEach(profile.shares) { share in
                        HStack(spacing: Space.m) {
                            Text(share.name)
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.text)
                                .lineLimit(1)
                            Spacer()
                            Text(share.percentText)
                                .font(TypeScale.code(13))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Palette.gold)
                                .frame(width: max(2, geo.size.width * share.fraction), height: 4)
                        }
                        .frame(height: 4)
                    }
                }
                .padding(.top, Space.xs)
            }

            HStack(spacing: Space.m) {
                Button {
                    isPickingSource = true
                } label: {
                    Label("From a bottle", systemImage: "arrow.down.to.line")
                        .font(TypeScale.secondary().weight(.semibold))
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.gold))
                }
                Button {
                    byName = ""; byProof = ""; byMilliliters = ""
                    isAddingByName = true
                } label: {
                    Label("Something else", systemImage: "plus")
                        .font(TypeScale.secondary().weight(.semibold))
                        .foregroundStyle(Palette.gold)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.gold, lineWidth: 1))
                }
            }
            .padding(.top, Space.xs)

            if !additions.isEmpty {
                additionLog
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
        .sheet(isPresented: $isPickingSource, onDismiss: onChange) {
            NavigationStack {
                AddToBlendView(blendId: bottle.id, blendName: env.name(for: bottle))
            }
        }
        .alert("Add something else", isPresented: $isAddingByName) {
            TextField("What it is", text: $byName)
            TextField("Proof", text: $byProof).keyboardType(.decimalPad)
            TextField("ml", text: $byMilliliters).keyboardType(.decimalPad)
            Button("Add it") { addByName() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A friend's bottle, a sample. Leave the proof blank if you do not know it — the strength will say so.")
        }
        .alert("Could not add that", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    /// Every addition, newest first. Long-press to take one out; the pour
    /// it came from is undone with it.
    private var additionLog: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(additions) { addition in
                HStack {
                    Text(Date(timeIntervalSince1970: Double(addition.addedAt) / 1000)
                        .formatted(date: .abbreviated, time: .omitted))
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                    Text(name(of: addition))
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(VolumeDisplay.text(addition.volumeMl, ounces: ounces))
                        .font(TypeScale.code(12))
                        .foregroundStyle(Palette.textMuted)
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) {
                        remove(addition)
                    } label: {
                        Label("Take this out", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
        .padding(.top, Space.xs)
    }

    private func name(of addition: BlendAddition) -> String {
        if let id = addition.sourceBottleId,
           let source = try? env.bottles.summary(id: id)?.bottle {
            return env.name(for: source)
        }
        return addition.sourceName ?? "Unknown"
    }

    private func addByName() {
        guard let ml = Double(byMilliliters), ml > 0 else {
            error = "Say how many millilitres went in."
            return
        }
        let abv = Double(byProof).map { $0 / 2 }
        do {
            try env.bottles.addToBlend(blendId: bottle.id, sourceName: byName, abv: abv, volumeMl: ml)
            onChange()
        } catch DataError.bottleIsFull {
            error = "The bottle is full."
        } catch DataError.bottleNotFound {
            error = "Give it a name."
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove(_ addition: BlendAddition) {
        do {
            try env.bottles.removeAddition(id: addition.id)
            onChange()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Picks one of your open bottles and an amount to pour into an infinity
/// bottle. The strength that goes in is the bottle's own measured proof
/// first and the catalogue's second, which is the same order the bottle
/// screen shows.
struct AddToBlendView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VolumeDisplay.key) private var ounces = false

    let blendId: String
    let blendName: String

    @State private var sources: [BottleSummary] = []
    @State private var query = ""
    @State private var chosen: BottleSummary?
    @State private var milliliters = "60"
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let chosen {
                    amount(chosen)
                } else {
                    picker
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Into \(blendName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .task { load() }
        .alert("Could not add that", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var shown: [BottleSummary] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return sources }
        return sources.filter { env.name(for: $0.bottle).localizedCaseInsensitiveContains(needle) }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("From which bottle")
            TextField("Search your open bottles", text: $query)
                .textFieldStyle(.plain)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .padding(Space.m)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
            if sources.isEmpty {
                Text("Nothing open to pour from. Open a bottle first.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }
            ForEach(shown) { source in
                Button {
                    chosen = source
                } label: {
                    HStack(spacing: Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.name(for: source.bottle))
                                .font(TypeScale.body())
                                .foregroundStyle(Palette.text)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: Space.s) {
                                if let proof = proof(of: source) {
                                    Text(String(format: "%.1f proof", proof))
                                } else {
                                    Text("Proof unknown")
                                }
                                Text("·")
                                Text("\(VolumeDisplay.text(source.status.remainingMilliliters, ounces: ounces)) left")
                            }
                            .font(TypeScale.code(12))
                            .foregroundStyle(Palette.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Palette.textMuted)
                    }
                    .padding(Space.l)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func amount(_ source: BottleSummary) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(env.name(for: source.bottle))
            Text("\(VolumeDisplay.text(source.status.remainingMilliliters, ounces: ounces)) left in it")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
            HStack(spacing: Space.s) {
                ForEach([30, 60, 100, 150], id: \.self) { ml in
                    Button {
                        milliliters = String(ml)
                    } label: {
                        Text("\(ml) ml")
                            .font(TypeScale.code(13))
                            .foregroundStyle(milliliters == String(ml) ? Palette.onGold : Palette.text)
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: Space.tapTarget - 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(milliliters == String(ml) ? Palette.gold : Palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            TextField("ml", text: $milliliters)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .padding(Space.m)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
            if proof(of: source) == nil {
                Text("This bottle has no proof recorded, so the blend's strength will read unknown until you set one on it.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                add(source)
            } label: {
                Text("Pour it in")
                    .font(TypeScale.secondary().weight(.semibold))
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.gold))
            }
            Button {
                chosen = nil
            } label: {
                Text("A different bottle")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
            }
        }
    }

    private func proof(of source: BottleSummary) -> Double? {
        (source.bottle.abv ?? env.product(for: source.bottle)?.abv).map { ABV(percent: $0).proof }
    }

    private func load() {
        sources = ((try? env.bottles.summaries()) ?? [])
            .filter { $0.bottle.isOpen && !$0.status.isEmpty && $0.id != blendId && !$0.bottle.isInfinity }
            .sorted { env.name(for: $0.bottle).localizedCaseInsensitiveCompare(env.name(for: $1.bottle)) == .orderedAscending }
    }

    private func add(_ source: BottleSummary) {
        guard let ml = Double(milliliters), ml > 0 else {
            error = "Say how many millilitres."
            return
        }
        do {
            try env.bottles.addToBlend(
                blendId: blendId, fromBottleId: source.id, volumeMl: ml,
                catalogABV: env.product(for: source.bottle)?.abv)
            dismiss()
        } catch DataError.bottleIsFull {
            error = "\(blendName) is full."
        } catch DataError.bottleIsEmpty {
            error = "That bottle is empty."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
