import Foundation
import WidgetKit
import Observation
import LiquorData
import LiquorEngine

/// Everything the screens read from: the database, the bundled catalog, the
/// flavour wheel, and the repositories over them.
///
/// **Nothing here touches the network.** The catalog and the wheel are files in
/// the app bundle and the data is a local SQLite file, which is what makes the
/// shelf check work in a shop with no signal.
@Observable
final class AppEnvironment {
    let database: AppDatabase
    let catalog: Catalog
    let wheel: FlavorWheel
    /// The CRT's registry of tequila producers, for the NOM on a label.
    let tequila: TequilaRegistry
    /// Bottle photos, as files in Application Support. Nil when the folder
    /// could not be made; every photo affordance then stays hidden.
    let photos: BottlePhotoStore?

    /// Set when the database could not be opened at all. The app stays up and
    /// says so rather than crashing on launch — a collection you cannot reach
    /// is bad, and a crash you cannot report is worse.
    private(set) var startupError: String?

    /// Bumped after a write made from somewhere the visible screen cannot
    /// see -- the + sheets over the tab bar, mostly. A screen that shows
    /// the shelf reloads when this changes, so a bottle added from the +
    /// appears on the Collection tab behind the sheet instead of waiting
    /// for a tab switch or a pull.
    private(set) var changeCount = 0

    /// Also the signal to everything outside the app's own screens: the
    /// widget's timeline and the phone's search index.
    func noteChange() {
        changeCount += 1
        WidgetCenter.shared.reloadAllTimelines()
        Spotlight.reindex(self)
    }

    /// A bottle asked for from outside -- a widget tap, a search result.
    /// The Collection tab opens it and clears this.
    var requestedBottleId: String?

    var bottles: BottleRepository { BottleRepository(database) }
    var tastings: TastingRepository { TastingRepository(database) }
    var shelfWalk: ReInventoryRepository { ReInventoryRepository(database) }
    var wishlist: WishlistRepository { WishlistRepository(database) }
    var export: CollectionExport { CollectionExport(database) }
    var notes: KnowledgeNoteRepository { KnowledgeNoteRepository(database) }
    var reports: ReportRepository { ReportRepository(database) }
    var sightings: SightingRepository { SightingRepository(database) }
    var visits: VisitRepository { VisitRepository(database) }

    /// Everyone's reports, reduced, from the Supabase project. Nil when
    /// the build has no project; every community line then stays hidden.
    var community: CommunityService?

    /// Sharing what this person sees -- shelf prices, wax drips -- is off
    /// until they switch it on, and switching it off withdraws everything.
    static let sharingKey = "community.share"
    static let regionKey = "community.region"

    var isSharing: Bool { UserDefaults.standard.bool(forKey: Self.sharingKey) }
    var region: String? {
        let raw = UserDefaults.standard.string(forKey: Self.regionKey)?
            .trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        return raw.isEmpty ? nil : raw
    }

    /// Records a shelf-price sighting, if sharing is on. Called wherever
    /// a price is typed against a catalogue product.
    func sawPrice(productId: String?, cents: Int?) {
        guard isSharing, let productId, let cents, cents > 0 else { return }
        _ = try? reports.recordPrice(productId: productId, cents: cents, region: region)
    }

    func measuredDrip(productId: String?, fraction: Double?) {
        guard isSharing, let productId, let fraction else { return }
        _ = try? reports.recordDrip(productId: productId, fraction: fraction)
    }

    init(
        database: AppDatabase,
        catalog: Catalog,
        wheel: FlavorWheel,
        tequila: TequilaRegistry = loadTequila(),
        photos: BottlePhotoStore? = try? BottlePhotoStore(),
        startupError: String? = nil
    ) {
        self.database = database
        self.catalog = catalog
        self.wheel = wheel
        self.tequila = tequila
        self.photos = photos
        self.startupError = startupError
    }

    // MARK: - Construction

    static func live() -> AppEnvironment {
        let catalog = loadCatalog()
        let wheel = loadWheel()
        do {
            return AppEnvironment(
                database: try AppDatabase.onDisk(), catalog: catalog, wheel: wheel)
        } catch {
            // Fall back to an in-memory database so the app runs and can
            // explain itself, rather than dying at launch.
            let memory = Self.fallbackDatabase()
            return AppEnvironment(
                database: memory, catalog: catalog, wheel: wheel,
                startupError: "Could not open your collection: \(error.localizedDescription)")
        }
    }

    /// Previews and the simulator, seeded with the same bottles the design
    /// canvas shows — so a preview and a mockup describe one app.
    static func preview() -> AppEnvironment {
        AppEnvironment(
            database: (try? AppDatabase.populatedForPreviews()) ?? fallbackDatabase(),
            catalog: loadCatalog(),
            wheel: loadWheel())
    }

    // MARK: - Bundled files

    /// A missing or corrupt catalog degrades to an empty one. The app still
    /// works: you can type a bottle in yourself, which it supports anyway.
    static func loadCatalog() -> Catalog {
        guard let data = bundled("spirits.v1"),
              let catalog = try? Catalog.decode(from: data)
        else { return .empty }
        return catalog
    }

    static func loadTequila() -> TequilaRegistry {
        guard let data = bundled("tequila-nom.v1"),
              let registry = try? TequilaRegistry.decode(from: data)
        else { return .empty }
        return registry
    }

    static func loadWheel() -> FlavorWheel {
        guard let data = bundled("flavor-wheel.v1"),
              let wheel = try? FlavorWheel.decode(from: data)
        else { return FlavorWheel(version: 0, name: "Unavailable", families: []) }
        return wheel
    }

    private static func bundled(_ name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    // MARK: - Reading

    /// The product ids the user has any history with, for the search boost.
    func historyProductIds() -> Set<String> {
        let owned = (try? bottles.summaries(includeFinished: true))?
            .compactMap(\.bottle.catalogProductId) ?? []
        return Set(owned)
    }

    /// A product id resolves against the BUNDLED catalog first and the user's
    /// own entries second. A bottle somebody typed in has to answer the shelf
    /// check exactly like a catalogue one, or half their collection is invisible
    /// to the screen the app exists for.
    func identity(_ productId: String) -> ProductIdentity? {
        if let identity = catalog.identity(productId) { return identity }
        guard let custom = try? bottles.customProduct(id: productId) else { return nil }
        return ProductIdentity(
            productId: custom.id,
            distillery: custom.distillery,
            brand: custom.brand,
            expression: custom.expression,
            classType: custom.classType,
            productionType: custom.productionType)
    }

    func name(for bottle: Bottle) -> String {
        if let id = bottle.catalogProductId, let identity = identity(id) {
            return identity.displayName
        }
        return bottle.customName ?? "Untitled bottle"
    }

    func sightingName(_ sighting: Sighting) -> String {
        if let id = sighting.catalogProductId, let identity = identity(id) {
            return identity.displayName
        }
        return sighting.customName ?? "Something"
    }

    func distillery(for bottle: Bottle) -> String? {
        bottle.catalogProductId.flatMap { identity($0)?.distillery }
    }

    /// The class of what is in the bottle, from either catalog.
    func classType(for bottle: Bottle) -> ClassType? {
        bottle.catalogProductId.flatMap { identity($0)?.classType }
    }

    func product(for bottle: Bottle) -> CatalogProduct? {
        bottle.catalogProductId.flatMap { catalog.product($0) }
    }
}

private extension AppEnvironment {
    /// Last resort. An in-memory queue has no filesystem to fail on, so if this
    /// throws the device is beyond help and crashing is more honest than
    /// pretending the app has a database.
    static func fallbackDatabase() -> AppDatabase {
        // swiftlint:disable:next force_try
        try! AppDatabase.inMemory()
    }
}
