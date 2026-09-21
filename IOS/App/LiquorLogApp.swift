import SwiftUI
import LiquorData
import WidgetKit

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

    /// The chosen look. Changing it rebuilds the root view, which is how
    /// every `Palette` read picks up the new values.
    @AppStorage(Palette.Look.key, store: Palette.Look.defaults) private var look = Palette.Look.standard.rawValue

    /// Whether the welcome has had its one turn. Set by either path out
    /// of it, so it is asked once and never again.
    @AppStorage("welcome.seen") private var hasSeenWelcome = false
    @State private var isShowingWelcome = false

    init() {
        let env = AppEnvironment.live()
        _environment = State(initialValue: env)
        let sync = SyncController(
            database: env.database,
            configuration: SyncConfiguration.fromBundle())
        sync.onPulled = { env.noteChange() }
        env.community = sync.communityTransport.map { CommunityService(transport: $0) }
        _sync = State(initialValue: sync)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .id(look)
                // The widget is the same look; it is told when that changes.
                .onChange(of: look) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
                // Search index and widget are brought up to date once at
                // launch, so an updated install has its shelf in search
                // before any sheet is used.
                .task { environment.noteChange() }
                .environment(environment)
                .environment(sync)
                .environment(store)
                // Both palettes ship and the system setting decides. Nothing
                // here pins a mode -- see the note in project.yml about the
                // deliberately absent UIUserInterfaceStyle key.
                .tint(Palette.gold)
                // After the environment modifiers, so the cover inherits
                // them rather than being handed a second copy.
                .fullScreenCover(isPresented: $isShowingWelcome) {
                    WelcomeView(onDone: {
                        hasSeenWelcome = true
                        isShowingWelcome = false
                    })
                }
                .task { decideOnTheWelcome() }
        }
    }

    /// Shown only where it could do something. A build with no Supabase
    /// project has nothing to offer; somebody already signed in has
    /// already answered; and anyone who has seen it once is not asked
    /// twice.
    @MainActor
    private func decideOnTheWelcome() {
        guard !hasSeenWelcome else { return }
        if case .unavailable = sync.state {
            hasSeenWelcome = true
            return
        }
        if sync.isSignedIn {
            hasSeenWelcome = true
            return
        }
        isShowingWelcome = true
    }
}
