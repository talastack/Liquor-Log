import SwiftUI
import LiquorData
import LiquorEngine

/// The shelf walk.
///
/// Every collection record decays — people buy, drink and trade faster than they
/// log, and end up not trusting their own list. The fix people arrive at on
/// their own is a periodic walk past the shelves, once or twice a year. Almost
/// no app has one.
///
/// Two decisions make it finishable. It is ordered **by where the bottles are**,
/// because you are walking past physical shelves and not scrolling a list. And
/// every answer is saved as you go, so stopping halfway is progress rather than
/// a wasted evening.
struct ReInventoryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var legs: [ReInventory.Leg] = []
    @State private var legIndex = 0
    @State private var itemIndex = 0
    @State private var decisions: [(id: String, verdict: ReInventory.Verdict)] = []
    @State private var hasStarted = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if !hasStarted {
                    intro
                } else if let leg = currentLeg, let item = currentItem {
                    walking(leg: leg, item: item)
                } else {
                    finished
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Shelf walk")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Walk your shelves")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)

            Text("Every collection list drifts. Bottles get finished and never "
                 + "marked, and bottles get bought and never added. This walks "
                 + "you past what you own, one shelf at a time, so you can "
                 + "trust the list again.")
                .font(TypeScale.body())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("This walk")
                    .padding(.bottom, Space.xs)
                FactRow(label: "Bottles", value: "\(totalItems)")
                FactRow(label: "Shelves", value: "\(legs.count)")
                FactRow(
                    label: "Never checked",
                    value: "\(neverVerifiedCount)",
                    isLast: true)
            }

            if totalItems == 0 {
                Text("Nothing on the shelf to walk yet.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            } else {
                Button { hasStarted = true } label: {
                    Text("Start")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }

                Text("Every answer saves as you go. Stop whenever you like and "
                     + "pick up where you left off.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Walking

    private func walking(leg: ReInventory.Leg, item: ReInventory.Item) -> some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionLabel(leg.title)
                ProgressView(value: Double(checkedCount), total: Double(max(totalItems, 1)))
                    .tint(Palette.gold)
                Text("\(checkedCount) of \(totalItems) checked")
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.textMuted)
            }

            VStack(spacing: Space.m) {
                BottleMark(height: 96)
                Text(item.name)
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lastSeen(item))
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xl)
            .padding(.horizontal, Space.l)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))

            VStack(spacing: Space.m) {
                Button { answer(.present, for: item) } label: {
                    Text("Still here")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }

                HStack(spacing: Space.m) {
                    Button { answer(.gone, for: item) } label: {
                        Text("Finished")
                            .font(TypeScale.headline())
                            .foregroundStyle(Palette.text)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 11)
                                .stroke(Palette.line, lineWidth: 1))
                    }

                    Button { answer(.skipped, for: item) } label: {
                        Text("Skip")
                            .font(TypeScale.headline())
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 11)
                                .stroke(Palette.line, lineWidth: 1))
                    }
                }
            }

            // "Finished" archives, it never deletes. Saying so here is what
            // makes the button safe to tap quickly, which is the whole point.
            Text("Finished bottles are archived, not deleted. They stay in your "
                 + "history and in your export.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Finished

    private var finished: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Walk done")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)

            // Plain bookkeeping. Nothing here celebrates: marking bottles
            // finished is not an achievement.
            Text(ReInventory.outcome(from: decisions).summary)
                .font(TypeScale.body())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !skippedNames.isEmpty {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("Skipped")
                    ForEach(skippedNames, id: \.self) { name in
                        Text(name)
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.textMuted)
                    }
                    Text("These stay unchecked, so they lead your next walk.")
                        .font(TypeScale.caption())
                        .textCase(nil)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button { dismiss() } label: {
                Text("Done")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
        }
    }

    // MARK: - Derivation

    private var currentLeg: ReInventory.Leg? {
        legs.indices.contains(legIndex) ? legs[legIndex] : nil
    }

    private var currentItem: ReInventory.Item? {
        guard let leg = currentLeg, leg.items.indices.contains(itemIndex) else { return nil }
        return leg.items[itemIndex]
    }

    private var totalItems: Int { legs.reduce(0) { $0 + $1.items.count } }

    private var checkedCount: Int { decisions.count }

    private var neverVerifiedCount: Int {
        legs.flatMap(\.items).filter { $0.lastVerifiedAt == nil }.count
    }

    private var skippedNames: [String] {
        let skipped = Set(ReInventory.outcome(from: decisions).skipped)
        return legs.flatMap(\.items).filter { skipped.contains($0.id) }.map(\.name)
    }

    private func lastSeen(_ item: ReInventory.Item) -> String {
        guard let last = item.lastVerifiedAt else {
            return item.isOpen ? "Open · never checked" : "Never checked"
        }
        let days = Int(Date().timeIntervalSince(last) / 86_400)
        let seen = days < 1 ? "Checked today" : "Checked \(days) \(days == 1 ? "day" : "days") ago"
        return item.isOpen ? "Open · \(seen)" : seen
    }

    // MARK: - Actions

    private func reload() {
        do {
            legs = try env.shelfWalk
                .plan(resolveName: { env.name(for: $0) })
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Saves immediately. A walk you can abandon halfway without losing the
    /// answers you already gave is a walk people finish.
    private func answer(_ verdict: ReInventory.Verdict, for item: ReInventory.Item) {
        decisions.append((id: item.id, verdict: verdict))
        do {
            try env.shelfWalk.record(verdict, for: item.id)
        } catch {
            self.error = error.localizedDescription
        }
        advance()
    }

    private func advance() {
        guard let leg = currentLeg else { return }
        if itemIndex + 1 < leg.items.count {
            itemIndex += 1
        } else {
            legIndex += 1
            itemIndex = 0
        }
    }
}

#Preview {
    NavigationStack { ReInventoryView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
