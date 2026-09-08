import SwiftUI
import LiquorData
import LiquorEngine

/// Choose something to drink tonight.
///
/// A trivial feature people mention unprompted as a reason they like an app.
/// The problem is real: a shelf of forty open bottles is a decision, and most
/// nights you reach for the same three.
///
/// It leans toward bottles you have not poured from in a while, never toward
/// drinking more. There is no count of how many times you have tapped it and
/// nothing here treats a pour as progress.
struct PickMyPourView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var choice: PickMyPour.Choice?
    @State private var candidates: [PickMyPour.Candidate] = []
    @State private var hasLooked = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                if let choice {
                    result(choice)
                } else if hasLooked {
                    nothingEligible
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Pick my pour")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: - Sections

    private func result(_ choice: PickMyPour.Choice) -> some View {
        VStack(spacing: Space.xl) {
            VStack(spacing: Space.m) {
                BottleMark(height: 104)

                Text(choice.candidate.name)
                    .font(TypeScale.largeTitle())
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // A random pick with no reason feels arbitrary. The reason is
                // what makes it read as a suggestion.
                Text(choice.reason)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.gold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(remaining(choice.candidate))
                    .font(TypeScale.code(13))
                    .foregroundStyle(Palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xl)
            .padding(.horizontal, Space.l)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))

            VStack(spacing: Space.m) {
                NavigationLink {
                    BottleDetailView(bottleId: choice.candidate.id)
                } label: {
                    Text("Open this bottle")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                }

                Button { pick() } label: {
                    Text("Pick another")
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .stroke(Palette.line, lineWidth: 1))
                }
            }

            Text("Chosen from your \(eligibleCount) open \(eligibleCount == 1 ? "bottle" : "bottles"), "
                 + "leaning toward the ones you have not touched in a while.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nothingEligible: some View {
        VStack(spacing: Space.l) {
            BottleMark(height: 84)
            Text("Nothing open")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            // Opening a sealed bottle starts an oxidation clock and is often
            // the whole point of that bottle. Not the app's call.
            Text("This only suggests bottles that are already open. Opening a "
                 + "sealed one is your call, not the app's.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    // MARK: - Derivation

    private var eligibleCount: Int {
        PickMyPour.eligible(from: candidates).count
    }

    private func remaining(_ candidate: PickMyPour.Candidate) -> String {
        "\(Int(candidate.remainingMilliliters.rounded())) ml left"
    }

    // MARK: - Actions

    private func reload() {
        do {
            candidates = try env.export
                .pourCandidates(resolveName: { env.name(for: $0) })
            pick()
        } catch {
            self.error = error.localizedDescription
        }
        hasLooked = true
    }

    private func pick() {
        var generator = SystemRandomNumberGenerator()
        choice = PickMyPour.choose(from: candidates, using: &generator)
    }
}

#Preview {
    NavigationStack { PickMyPourView() }
        .environment(AppEnvironment.preview())
        .preferredColorScheme(.dark)
}
