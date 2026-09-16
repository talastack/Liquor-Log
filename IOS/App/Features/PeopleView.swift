import SwiftUI
import LiquorEngine
import LiquorData

/// Who sent you samples, who you poured for, and how that stands. Read
/// from the samples and pours already logged; nothing to keep up.
struct PeopleView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage(VolumeDisplay.key) private var ounces = false

    @State private var people: [People.Person] = []
    @State private var hasLooked = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("People")
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    Text("Who sent you samples, who you poured for, and whose turn it is. Read from what you logged: a sample says who it came from, a pour says who it went to.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if hasLooked, people.isEmpty {
                    Text("Nobody yet. Add a sample with who it came from, or mark a pour as somebody else's, and they appear here.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Space.m) {
                    ForEach(people) { person in
                        NavigationLink {
                            PersonView(person: person)
                        } label: {
                            row(person)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .onChange(of: env.changeCount) { _, _ in reload() }
        .alert("Something went wrong", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func row(_ person: People.Person) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Text(String(person.name.prefix(1)).uppercased())
                .font(TypeScale.headline())
                .foregroundStyle(Palette.onGold)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Palette.gold))
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name)
                    .font(TypeScale.title())
                    .foregroundStyle(Palette.text)
                Text(People.line(person))
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                if let balance = People.balance(person, ounces: ounces) {
                    Text(balance)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                }
                if let taste = People.taste(person) {
                    Text(taste)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.good)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    private func reload() {
        do {
            people = try Self.ledger(env)
            hasLooked = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// The ledger from the shelf: samples with a sender, pours with a
    /// recipient, and your latest rating of each sample.
    static func ledger(_ env: AppEnvironment) throws -> [People.Person] {
        let summaries = try env.bottles.summaries(includeFinished: true)
        let names = Dictionary(summaries.map { ($0.id, env.name(for: $0.bottle)) }, uniquingKeysWith: { a, _ in a })
        var ratings: [String: Int] = [:]
        for detail in try env.tastings.allDetails() {
            guard let bottleId = detail.tasting.bottleId, let rating = detail.tasting.rating,
                  ratings[bottleId] == nil else { continue }
            ratings[bottleId] = rating
        }
        func date(_ millis: Int64) -> Date { Date(timeIntervalSince1970: Double(millis) / 1000) }

        let received = summaries.compactMap { summary -> (from: String, bottle: String, milliliters: Double, how: String?, at: Date, rating: Int?)? in
            let bottle = summary.bottle
            guard bottle.isSample, let from = bottle.sampleFrom else { return nil }
            return (from: from, bottle: names[summary.id] ?? "A sample", milliliters: bottle.volumeMl,
                    how: bottle.sampleSource?.label, at: date(bottle.purchaseDate ?? bottle.createdAt),
                    rating: ratings[summary.id])
        }
        let given = try env.bottles.poursGivenAway().compactMap { pour -> (to: String, bottle: String, milliliters: Double, at: Date)? in
            guard let to = pour.givenTo else { return nil }
            return (to: to, bottle: names[pour.bottleId] ?? "A bottle", milliliters: pour.volumeMl, at: date(pour.pouredAt))
        }
        return People.ledger(received: received, given: given)
    }
}

/// One person: what came from them, what went to them.
struct PersonView: View {
    @AppStorage(VolumeDisplay.key) private var ounces = false
    let person: People.Person

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(person.name)
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                    if let balance = People.balance(person, ounces: ounces) {
                        Text(balance)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let taste = People.taste(person) {
                        Text(taste)
                            .font(TypeScale.secondary())
                            .foregroundStyle(Palette.good)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !person.received.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("From them · \(VolumeDisplay.text(person.receivedMilliliters, ounces: ounces))")
                        ForEach(Array(person.received.enumerated()), id: \.offset) { _, sample in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.bottle)
                                        .font(TypeScale.body())
                                        .foregroundStyle(Palette.text)
                                    Text([sample.how, sample.at.formatted(date: .abbreviated, time: .omitted)]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(TypeScale.caption())
                                        .textCase(nil)
                                        .foregroundStyle(Palette.textMuted)
                                }
                                Spacer()
                                if let rating = sample.rating { RatingChip(rating: rating) }
                                Text(VolumeDisplay.text(sample.milliliters, ounces: ounces))
                                    .font(TypeScale.code(13))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                }

                if !person.given.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        SectionLabel("To them · \(VolumeDisplay.text(person.givenMilliliters, ounces: ounces))")
                        ForEach(Array(person.given.enumerated()), id: \.offset) { _, pour in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pour.bottle)
                                        .font(TypeScale.body())
                                        .foregroundStyle(Palette.text)
                                    Text(pour.at.formatted(date: .abbreviated, time: .omitted))
                                        .font(TypeScale.caption())
                                        .textCase(nil)
                                        .foregroundStyle(Palette.textMuted)
                                }
                                Spacer()
                                Text(VolumeDisplay.text(pour.milliliters, ounces: ounces))
                                    .font(TypeScale.code(13))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                }

                Text("What changed hands, from your own log. A sample's size is its bottle; a pour is what you logged.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PeopleView() }
        .environment(AppEnvironment.preview())
}
