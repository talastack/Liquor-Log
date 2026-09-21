import SwiftUI
import LiquorData

/// The first thing a new install shows: the three ways to sign in, and the
/// fourth that is not signing in.
///
/// **This is a welcome, not a gate.** App Store guideline 5.1.1(i) forbids
/// requiring registration for features that do not depend on it, and only
/// sync does — so "Continue without an account" is a full-width button
/// beside the others rather than a link in a corner, and everything behind
/// this screen works whichever one is tapped.
///
/// It appears **once**. Either path sets the flag, so a person who skipped
/// it is never asked again; the Sync screen is where an account is offered
/// after that. A screen that reappears until it gets its way is the nagging
/// the rest of this app was built to avoid.
struct WelcomeView: View {
    @Environment(SyncController.self) private var sync

    /// Called on both paths — signed in, or explicitly declined.
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            SignInView(onContinueWithout: onDone)
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xl)
                .padding(.bottom, 96)
        }
        .background(Palette.background)
        // Signing in is the other way out of this screen. Watching the
        // controller rather than passing a second closure means it fires
        // for every route in — Apple, Google and the email form alike.
        .onChange(of: sync.isSignedIn) { _, signedIn in
            if signedIn { onDone() }
        }
    }
}

#Preview {
    let env = AppEnvironment.preview()
    return WelcomeView(onDone: {})
        .environment(env)
        .environment(SyncController(database: env.database, configuration: nil))
}
