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
    @Environment(ProStore.self) private var store

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                switch sync.state {
                case .unavailable: unavailable
                case .signedOut:
                    if store.allows(.cloudSync) {
                        signIn
                    } else {
                        ProLockedCard(feature: .cloudSync)
                    }
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
        }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(isRegistering ? "Create an account" : "Sign in")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)

            Text("Only for a second device.")
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

    // MARK: - A shelf shared with a partner

    @State private var householdName = ""
    @State private var isConfirmingDeletion = false
    @State private var inviteCode = ""
    @State private var isLeaving = false

    /// One shelf for two accounts. Create one and pass on the code, or
    /// enter a partner's. Everything on both shelves shows on both phones
    /// from the next sync; whoever poured is still who poured.
    private var household: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Share with a partner")

            if let home = sync.household {
                VStack(alignment: .leading, spacing: 0) {
                    FactRow(label: "Household", value: home.name)
                    FactRow(label: "Members", value: "\(home.members)")
                    FactRow(label: "Invite code", value: home.inviteCode, isLast: true)
                }
                Text(home.members == 1
                     ? "Give the code to your partner. When they enter it under Sync on their phone, both shelves show on both phones from the next sync."
                     : "Both shelves show on both phones. What each of you logs stays yours; the shelf is one.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(role: .destructive) { isLeaving = true } label: {
                    Text("Leave the household")
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.bad)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                }
                .confirmationDialog("Leave the household?", isPresented: $isLeaving, titleVisibility: .visible) {
                    Button("Leave", role: .destructive) { Task { await sync.leaveHousehold() } }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Bottles already on this phone stay. Nothing new of theirs arrives, and nothing new of yours reaches them.")
                }
            } else {
                HStack(spacing: Space.m) {
                    TextField("A name for the shelf", text: $householdName)
                        .textFieldStyle(.plain)
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                        .padding(Space.m)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                    Button {
                        Task { await sync.createHousehold(named: householdName) }
                    } label: {
                        Text("Create")
                            .font(TypeScale.secondary().weight(.semibold))
                            .foregroundStyle(Palette.onGold)
                            .padding(.horizontal, Space.l)
                            .frame(minHeight: Space.tapTarget)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.gold))
                    }
                }
                HStack(spacing: Space.m) {
                    TextField("Partner's code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .font(TypeScale.code(16))
                        .foregroundStyle(Palette.text)
                        .padding(Space.m)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 1))
                    Button {
                        Task { await sync.joinHousehold(code: inviteCode) }
                    } label: {
                        Text("Join")
                            .font(TypeScale.secondary().weight(.semibold))
                            .foregroundStyle(Palette.gold)
                            .padding(.horizontal, Space.l)
                            .frame(minHeight: Space.tapTarget)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.gold, lineWidth: 1))
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).count < 6)
                }
                Text("Two accounts, one shelf. Create a household and pass on its code, or enter your partner's.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = sync.householdError {
                Text(error)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task { await sync.refreshHousehold() }
    }

    private func signedIn(_ email: String?) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Account")
                    .padding(.bottom, Space.xs)
                FactRow(label: "Signed in as", value: email ?? "—")
                if let outcome = sync.lastOutcome {
                    FactRow(label: "Sent", value: "\(outcome.pushed)")
                    FactRow(label: "Received", value: "\(outcome.pulled)")
                    FactRow(
                        label: "Last sync",
                        value: outcome.isCompletelyClean
                            ? "Everything went"
                            : "\(outcome.failures.count) table(s) will retry",
                        isLast: true)
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

            household

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

            // Required of any app with account creation (App Store 5.1.1(v)),
            // and the right thing regardless: the account is theirs to end.
            VStack(alignment: .leading, spacing: Space.s) {
                Button(role: .destructive) { isConfirmingDeletion = true } label: {
                    Text("Delete my account")
                        .font(TypeScale.secondary().weight(.semibold))
                        .foregroundStyle(Palette.bad)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
                }
                Text("Removes your account and everything synced under it from the server. The collection on this phone stays. A Pro subscription is Apple's to cancel, in Settings › Apple ID › Subscriptions.")
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task { await sync.deleteAccount() }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Everything synced under this account is deleted from the server. This cannot be undone. Your bottles stay on this phone.")
        }
    }

    private var reassurance: some View {
        Text("Signing out deletes nothing on this phone.")
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
