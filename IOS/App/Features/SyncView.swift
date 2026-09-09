import SwiftUI
import LiquorData
import LiquorEngine

/// An account, for getting a collection onto a second device.
///
/// **Framed as optional, because it is.** Every screen works without it and a
/// local-only collection is the normal state, not a degraded one. Nothing here
/// nags, there is no "finish setting up", and the copy says plainly what an
/// account is for rather than implying the app is incomplete without one.
struct SyncView: View {
    @Environment(SyncController.self) private var sync

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                switch sync.state {
                case .unavailable: unavailable
                case .signedOut: signIn
                case .working: ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                case .signedIn(let email): signedIn(email)
                }

                if let error = sync.lastError {
                    Text(error)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }

                reassurance
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - States

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Sync is not set up in this build")
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            Text("Your collection lives on this phone and works exactly as it "
                 + "does now. Nothing is missing.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(isRegistering ? "Create an account" : "Sign in")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)

            Text("Only needed to put your collection on a second device. "
                 + "Everything works without one.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modifier(FieldStyle())

            SecureField("Password", text: $password)
                .textContentType(isRegistering ? .newPassword : .password)
                .modifier(FieldStyle())

            Button {
                Task {
                    if isRegistering {
                        await sync.signUp(email: email, password: password)
                    } else {
                        await sync.signIn(email: email, password: password)
                    }
                }
            } label: {
                Text(isRegistering ? "Create account" : "Sign in")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
            .disabled(email.isEmpty || password.isEmpty)

            Button {
                isRegistering.toggle()
            } label: {
                Text(isRegistering
                     ? "I already have an account"
                     : "I need an account")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
            }
        }
    }

    private func signedIn(_ email: String?) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Account")
                    .padding(.bottom, Space.xs)
                FactRow(label: "Signed in as", value: email ?? "—")
                if let outcome = sync.lastOutcome {
                    FactRow(label: "Sent", value: "\(outcome.pushed)")
                    FactRow(label: "Received", value: "\(outcome.pulled)", isLast: true)
                }
            }

            // A non-zero count here means the sign-in stamp did not finish, and
            // those rows can never reach the server. Surfaced rather than
            // hidden: silent data loss is the thing this app is built against.
            if sync.unowned > 0 {
                Text("\(sync.unowned) rows are not linked to your account yet. "
                     + "Tap sync again.")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await sync.sync() }
            } label: {
                Text("Sync now")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }

            Button {
                Task { await sync.signOut() }
            } label: {
                Text("Sign out")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    private var reassurance: some View {
        Text("Signing out never deletes anything on this phone. Your bottles, "
             + "pours and tastings stay exactly where they are.")
            .font(TypeScale.caption())
            .textCase(nil)
            .foregroundStyle(Palette.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(TypeScale.body())
            .foregroundStyle(Palette.text)
            .padding(.horizontal, Space.m)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
    }
}
