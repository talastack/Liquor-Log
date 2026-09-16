import SwiftUI
import LiquorEngine
import LiquorData

/// The passport: the distilleries you have stood in, as stamps against
/// your shelf, and the ones on the shelf you have not been to.
struct PassportView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var records: [Visit] = []
    @State private var summary = Passport.summarise(visits: [], shelf: [])
    @State private var isAdding = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Passport")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text(summary.headline ?? "The distilleries you have stood in. A stamp each, against what is on your shelf from there.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !summary.stamps.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("Stamps")
                        ForEach(summary.stamps) { stamp in
                            stampRow(stamp)
                        }
                    }
                }

                if !summary.notYetVisited.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("On your shelf, not yet visited")
                        ForEach(Array(summary.notYetVisited.enumerated()), id: \.offset) { _, place in
                            HStack {
                                Text(place.name)
                                    .font(TypeScale.body())
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                Text("\(place.bottles) \(place.bottles == 1 ? "bottle" : "bottles")")
                                    .font(TypeScale.caption())
                                    .textCase(nil)
                                    .foregroundStyle(Palette.textMuted)
                            }
                        }
                        Text("The distilleries whose bottles you own, minus the ones you have been to. A list to act on, not a checklist of the catalogue.")
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("Every visit")
                        ForEach(records) { visit in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visit.distillery)
                                        .font(TypeScale.body())
                                        .foregroundStyle(Palette.text)
                                    Text([Date(timeIntervalSince1970: Double(visit.visitedAt) / 1000).formatted(date: .abbreviated, time: .omitted), visit.note]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(TypeScale.caption())
                                        .textCase(nil)
                                        .foregroundStyle(Palette.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Button { remove(visit) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Palette.textMuted)
                                        .frame(width: Space.tapTarget, height: Space.tapTarget)
                                }
                                .accessibilityLabel("Remove the visit to \(visit.distillery)")
                            }
                        }
                    }
                } else {
                    Text("Log the first one: where, and when.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Passport")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Log a visit")
                    .foregroundStyle(Palette.gold)
            }
        }
        .task { reload() }
        .onChange(of: env.changeCount) { _, _ in reload() }
        .sheet(isPresented: $isAdding, onDismiss: reload) {
            NavigationStack { VisitSheet() }
        }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func stampRow(_ stamp: Passport.Stamp) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text(String(stamp.name.prefix(1)).uppercased())
                .font(TypeScale.headline())
                .foregroundStyle(Palette.gold)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Palette.gold, lineWidth: 2))
                .rotationEffect(.degrees(-8))
            VStack(alignment: .leading, spacing: 3) {
                Text(stamp.name)
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                Text(Passport.line(stamp))
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                if let shelf = Passport.shelfLine(stamp) {
                    Text(shelf)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    private func reload() {
        do {
            records = try env.visits.all()
            let shelf = try env.bottles.summaries().map { summary in
                Passport.Bottle(
                    name: env.name(for: summary.bottle),
                    distillery: env.distillery(for: summary.bottle),
                    boughtAt: summary.bottle.purchaseStore)
            }
            summary = Passport.summarise(visits: try env.visits.facts(), shelf: shelf)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove(_ visit: Visit) {
        do { try env.visits.remove(id: visit.id); reload() } catch { self.error = error.localizedDescription }
    }
}

/// Log a visit: the distillery, from the catalogue's list or typed, and
/// the day.
struct VisitSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var chosen: String?
    @State private var visitedOn = Date()
    @State private var note = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.m) {
                    SectionLabel("Where")
                    if let chosen {
                        HStack {
                            Text(chosen)
                                .font(TypeScale.title())
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Button("Change") { self.chosen = nil }
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.gold)
                                .frame(minHeight: Space.tapTarget)
                        }
                        .padding(Space.l)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
                    } else {
                        TextField("Distillery", text: $query)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 46)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                        ForEach(matches, id: \.self) { name in
                            Button { chosen = name } label: {
                                Text(name)
                                    .font(TypeScale.body())
                                    .foregroundStyle(Palette.text)
                                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget, alignment: .leading)
                            }
                            Divider().overlay(Palette.line)
                        }
                        if !query.trimmingCharacters(in: .whitespaces).isEmpty, !matches.contains(query) {
                            Text("Or keep it as typed.")
                                .font(TypeScale.caption())
                                .textCase(nil)
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                }

                DatePicker("When", selection: $visitedOn, in: ...Date(), displayedComponents: .date)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .tint(Palette.gold)

                TextField("Note (optional)", text: $note)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))

                Button(action: save) {
                    Text("Stamp it")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(canSave ? Palette.gold : Palette.surfaceRaised))
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("A visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .alert("Could not save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var place: String { chosen ?? query.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !place.isEmpty }

    /// The catalogue's distilleries that contain what was typed.
    private var matches: [String] {
        let typed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !typed.isEmpty else { return [] }
        let all = Set(env.catalog.products.map(\.distillery))
        return all.filter { $0.lowercased().contains(typed) }.sorted().prefix(8).map { $0 }
    }

    private func save() {
        do {
            try env.visits.record(
                distillery: place,
                visitedAt: Int64(visitedOn.timeIntervalSince1970 * 1000),
                note: note)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { PassportView() }
        .environment(AppEnvironment.preview())
}
