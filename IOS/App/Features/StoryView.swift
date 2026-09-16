import SwiftUI
import LiquorEngine
import LiquorData

/// The life of a bottle: everything recorded about it, in order, with the
/// gaps said in days -- and the same as a card to share.
struct StoryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VolumeDisplay.key) private var ounces = false

    let bottleId: String

    @State private var name = ""
    @State private var story = BottleStory.Story(events: [], summary: nil)
    @State private var rendered: RenderedStory?

    struct RenderedStory: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    SectionLabel("The story of")
                    Text(name)
                        .font(TypeScale.largeTitle())
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let summary = story.summary {
                        Text(summary)
                            .font(TypeScale.body())
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if story.events.isEmpty {
                    Text("Nothing dated yet. A purchase date, an opening, a pour or a tasting starts it.")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    StoryTimeline(events: story.events)

                    Button { render() } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share as a card")
                        }
                        .font(TypeScale.headline())
                        .foregroundStyle(Palette.onGold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
                    }
                }

                Text("From what was recorded. An event with no date is not an event.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("The story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
            }
        }
        .task { load() }
        .sheet(item: $rendered) { card in
            ShareSheet(items: [card.image])
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: StoryCard(name: name, story: story))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 420, height: nil)
        if let image = renderer.uiImage { rendered = RenderedStory(image: image) }
    }

    private func load() {
        guard let summary = try? env.bottles.summary(id: bottleId) else { return }
        let bottle = summary.bottle
        name = env.name(for: bottle)
        func date(_ millis: Int64?) -> Date? { millis.map { Date(timeIntervalSince1970: Double($0) / 1000) } }

        // Bottled: the year on the label, as its first day, said as a year.
        var bottledAt: Date?
        var bottledText: String?
        if let year = bottle.bottledYear {
            bottledAt = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))
            bottledText = "\(year), from the label"
        }

        let pours = ((try? env.bottles.pours(bottleId: bottleId)) ?? []).map { pour in
            (at: Date(timeIntervalSince1970: Double(pour.pouredAt) / 1000),
             milliliters: pour.volumeMl,
             givenTo: pour.givenTo,
             into: pour.intoBottleId.flatMap { try? env.bottles.summary(id: $0)?.bottle }.map { env.name(for: $0) })
        }
        let tastings = ((try? env.tastings.history(bottleId: bottleId)) ?? []).map { detail in
            (at: Date(timeIntervalSince1970: Double(detail.tasting.tastedAt) / 1000),
             rating: detail.tasting.rating, blind: detail.tasting.blind, liked: detail.tasting.liked)
        }
        let readings = ((try? env.bottles.fillHistory(bottleId: bottleId)) ?? []).map { reading in
            (at: Date(timeIntervalSince1970: Double(reading.readAt) / 1000),
             milliliters: reading.remainingMl, note: reading.note)
        }
        let additions = bottle.isInfinity
            ? ((try? env.bottles.additions(blendId: bottleId)) ?? []).map { addition in
                (at: Date(timeIntervalSince1970: Double(addition.addedAt) / 1000),
                 milliliters: addition.volumeMl,
                 from: addition.sourceBottleId.flatMap { try? env.bottles.summary(id: $0)?.bottle }.map { env.name(for: $0) }
                    ?? addition.sourceName ?? "elsewhere")
            }
            : []

        story = BottleStory.tell(BottleStory.Facts(
            name: name,
            bottledAt: bottledAt, bottledText: bottledText,
            boughtAt: date(bottle.purchaseDate), boughtWhere: bottle.purchaseStore,
            paidText: bottle.purchasePriceCents.map { Money.short($0) },
            openedAt: date(bottle.openedAt), finishedAt: date(bottle.finishedAt),
            pours: pours, tastings: tastings, readings: readings, additions: additions),
            ounces: ounces)
    }
}

/// The events down the page with a rule between them.
struct StoryTimeline: View {
    let events: [BottleStory.Event]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: Space.m) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(strong(event.kind) ? Palette.gold : Palette.line)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        if index < events.count - 1 {
                            Rectangle().fill(Palette.line).frame(width: 1).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                        Text(event.title)
                            .font(strong(event.kind) ? TypeScale.headline() : TypeScale.body())
                            .foregroundStyle(Palette.text)
                        if let detail = event.detail {
                            Text(detail)
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, Space.l)
                }
            }
        }
    }

    private func strong(_ kind: BottleStory.Kind) -> Bool {
        switch kind {
        case .bottled, .bought, .opened, .finished: return true
        case .pour, .gift, .tasting, .level, .addition: return false
        }
    }
}

/// The story as one image: the name, the summary, the milestones.
struct StoryCard: View {
    let name: String
    let story: BottleStory.Story

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THE STORY OF")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Palette.textSecondary)
            Text(name)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.text)
            if let summary = story.summary {
                Text(summary)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textSecondary)
            }
            Rectangle().fill(Palette.gold).frame(height: 2)
            ForEach(story.events.filter { [.bottled, .bought, .opened, .finished].contains($0.kind) }) { event in
                HStack(alignment: .firstTextBaseline) {
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 96, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.text)
                        if let detail = event.detail {
                            Text(detail).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
            }
            let pours = story.events.filter { $0.kind == .pour }.count
            let tastings = story.events.filter { $0.kind == .tasting }.count
            if pours + tastings > 0 {
                Text("\(pours) \(pours == 1 ? "pour" : "pours") · \(tastings) \(tastings == 1 ? "tasting" : "tastings")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
        .background(Palette.background)
    }
}
