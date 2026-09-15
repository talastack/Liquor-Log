import SwiftUI
import WidgetKit
import AppIntents
import LiquorEngine
import LiquorData

/// What is open, on the Home Screen, with a pour button beside each bottle.
///
/// The moment a pour is skipped is the moment of pouring: bottle in one
/// hand, glass in the other, phone on the counter. A widget with one
/// button per open bottle is the only logging that survives that moment
/// -- no unlock, no search, no menu. The button is an App Intent, which
/// runs in this extension against the shared database, so the fill on the
/// app's screen and the fill here are the same rows.
///
/// Read-only otherwise: it shows what is open and how much is left, never
/// a count of anything drunk.
@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        WhatsOpenWidget()
    }
}

struct WhatsOpenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "whats-open", provider: OpenBottlesProvider()) { entry in
            WhatsOpenView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("What's open")
        .description("Your open bottles, and a pour button for each.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Data

struct OpenBottle: Identifiable, Hashable {
    let id: String
    let name: String
    let fraction: Double
    let remainingText: String
    let isEmpty: Bool
}

struct OpenEntry: TimelineEntry {
    let date: Date
    let bottles: [OpenBottle]
    let openCount: Int
}

struct OpenBottlesProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenEntry {
        OpenEntry(date: Date(), bottles: [
            OpenBottle(id: "a", name: "Elijah Craig Barrel Proof", fraction: 0.76, remainingText: "13 of 17 pours", isEmpty: false),
            OpenBottle(id: "b", name: "W. L. Weller Special Reserve", fraction: 0.31, remainingText: "5 of 17 pours", isEmpty: false),
        ], openCount: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : WidgetData.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenEntry>) -> Void) {
        let entry = WidgetData.entry()
        // The app reloads the timeline after every write; this is the
        // fallback so the widget never sits on a stale day.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

enum WidgetData {
    /// Open bottles, most recently poured first, then newest. Infinity
    /// bottles included -- they are open and pourable; samples left out,
    /// there is one pour in them and it was given to you.
    static func entry(now: Date = Date()) -> OpenEntry {
        guard let db = try? AppDatabase.onDisk() else {
            return OpenEntry(date: now, bottles: [], openCount: 0)
        }
        let bottles = BottleRepository(db)
        let catalog = loadCatalog()
        let open = ((try? bottles.summaries()) ?? [])
            .filter { $0.bottle.isOpen && !$0.bottle.isSample }
            .sorted { a, b in
                switch (a.lastPouredAt, b.lastPouredAt) {
                case let (x?, y?): return x > y
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.bottle.createdAt > b.bottle.createdAt
                }
            }
        let rows = open.map { summary -> OpenBottle in
            let capacity = summary.status.capacityMilliliters
            return OpenBottle(
                id: summary.id,
                name: name(for: summary.bottle, catalog: catalog, bottles: bottles),
                fraction: capacity > 0 ? summary.status.remainingMilliliters / capacity : 0,
                remainingText: "\(summary.status.remainingPours) of \(summary.status.totalPours) pours",
                isEmpty: summary.status.isEmpty)
        }
        return OpenEntry(date: now, bottles: rows, openCount: rows.count)
    }

    static func name(for bottle: Bottle, catalog: Catalog, bottles: BottleRepository) -> String {
        if let id = bottle.catalogProductId {
            if let product = catalog.product(id) { return product.identity.displayName }
            if let custom = try? bottles.customProduct(id: id) {
                return custom.expression.isEmpty ? custom.brand : "\(custom.brand) \(custom.expression)"
            }
        }
        return bottle.customName ?? "Untitled bottle"
    }

    /// The catalogue is bundled into this extension as well as the app,
    /// so a name resolves without the app running.
    static func loadCatalog() -> Catalog {
        guard let url = Bundle.main.url(forResource: "spirits.v1", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? Catalog.decode(from: data) else { return .empty }
        return catalog
    }
}

// MARK: - The pour button

/// One pour of the bottle's own pour size, from the widget. Runs here, in
/// the extension, against the shared database; the app sees it the next
/// time its screen reloads.
struct LogPourIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a pour"
    static let description = IntentDescription("Logs one pour of a bottle at its usual pour size.")

    @Parameter(title: "Bottle")
    var bottleId: String

    init() {}

    init(bottleId: String) {
        self.bottleId = bottleId
    }

    func perform() async throws -> some IntentResult {
        let db = try AppDatabase.onDisk()
        do {
            try BottleRepository(db).logPour(bottleId: bottleId)
        } catch DataError.bottleIsEmpty {
            // Nothing to pour; the widget already shows it empty.
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Views

/// The app's palette, compiled into this target too, so the widget is the
/// same Cellar as the app and no colour literal lives here.
enum WidgetPalette {
    static var background: Color { Palette.background }
    static var surface: Color { Palette.surfaceRaised }
    static var text: Color { Palette.text }
    static var muted: Color { Palette.textSecondary }
    static var accent: Color { Palette.gold }
}

struct WhatsOpenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OpenEntry

    private var shown: [OpenBottle] {
        switch family {
        case .systemSmall: return Array(entry.bottles.prefix(3))
        case .systemMedium: return Array(entry.bottles.prefix(3))
        default: return Array(entry.bottles.prefix(7))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("OPEN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetPalette.muted)
                Spacer()
                Text("\(entry.openCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.text)
            }
            if entry.bottles.isEmpty {
                Text("Nothing open.")
                    .font(.system(size: 13))
                    .foregroundStyle(WidgetPalette.muted)
                Spacer(minLength: 0)
            } else {
                ForEach(shown) { bottle in
                    row(bottle)
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "liquorlog://collection"))
    }

    private func row(_ bottle: OpenBottle) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(bottle.name)
                    .font(.system(size: family == .systemSmall ? 12 : 13, weight: .medium))
                    .foregroundStyle(WidgetPalette.text)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WidgetPalette.surface)
                        Capsule().fill(WidgetPalette.accent)
                            .frame(width: max(3, geo.size.width * bottle.fraction))
                    }
                }
                .frame(height: 4)
            }
            if family != .systemSmall {
                Text(bottle.remainingText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(WidgetPalette.muted)
                    .lineLimit(1)
                    .fixedSize()
                Button(intent: LogPourIntent(bottleId: bottle.id)) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WidgetPalette.background)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(bottle.isEmpty ? WidgetPalette.muted : WidgetPalette.accent))
                }
                .buttonStyle(.plain)
                .disabled(bottle.isEmpty)
            }
        }
    }
}
