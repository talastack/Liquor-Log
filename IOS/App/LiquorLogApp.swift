import SwiftUI

@main
struct LiquorLogApp: App {
    /// Built once at launch. Opening the database and decoding the bundled
    /// catalog are the only startup work, and neither touches the network.
    @State private var environment: AppEnvironment

    /// Built from the same database. Reads its project from the bundle and is
    /// `.unavailable` when there is none -- a fresh clone runs with sync simply
    /// absent rather than broken.
    @State private var sync: SyncController

    /// Pro, from the App Store's own record. Reads entitlement at launch and
    /// on every transaction; sells nothing until asked.
    @State private var store = ProStore()

    init() {
        let env = AppEnvironment.live()
        _environment = State(initialValue: env)
        _sync = State(initialValue: SyncController(
            database: env.database,
            configuration: SyncConfiguration.fromBundle()))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(environment)
                .environment(sync)
                .environment(store)
                // Both palettes ship and the system setting decides. Nothing
                // here pins a mode -- see the note in project.yml about the
                // deliberately absent UIUserInterfaceStyle key.
                .tint(Palette.gold)
        }
    }
}
