import SwiftUI
import AuthenticationServices
import LiquorData
import LiquorEngine

/// The sign-in page: three ways in, and a fourth that is not signing in.
///
/// **"Continue without an account" is a real option, not a dismissal.** The
/// app is fully usable with no account and a local-only collection is the
/// normal state, so the way out of this page carries the same weight as the
/// ways through it. App Store guideline 5.1.1(i) says the same thing in
/// their words: an app may not require registration for features that do
/// not depend on it, and only sync does.
///
/// Apple is first and full-width. Guideline 4.8 requires Sign in with Apple
/// wherever another third-party login is offered, and requires it not be
/// the lesser option.
struct SignInView: View {
    @Environment(SyncController.self) private var sync
    @Environment(\.colorScheme) private var colorScheme

    /// What the page does when somebody chooses not to sign in. A sheet
    /// dismisses; a pushed screen goes back.
    var onContinueWithout: () -> Void

    @State private var isUsingEmail = false
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    /// Held between the request and the reply: the hash went to Apple, the
    /// raw string goes to the server.
    @State private var appleNonce: SignInNonce?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            header
            providers
            if isUsingEmail { emailForm } else { emailButton }
            if let error = sync.lastError { errorLine(error) }
            withoutAnAccount
            smallPrint
        }
    }

    // MARK: - The page

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            BottleMark(height: 64)
            Text("Your shelf on another phone")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("An account does one thing: it puts this collection on a second device, and lets a partner see the same shelf. Everything else in the app works without one.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var providers: some View {
        VStack(spacing: Space.m) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = SignInNonce()
                appleNonce = nonce
                // The address only. The app never shows a name, and asking
                // for one it would not use is data it should not hold.
                request.requestedScopes = [.email]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 11))

            Button {
                Task { await sync.signInWithGoogle() }
            } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "globe")
                        .font(.system(size: 17, weight: .medium))
                    Text("Continue with Google")
                        .font(TypeScale.headline())
                }
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    private var emailButton: some View {
        Button {
            withAnimation { isUsingEmail = true }
        } label: {
            Text("Use an email address instead")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.gold)
                .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel(isRegistering ? "A new account" : "An email address")

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
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(canSubmit ? Palette.gold : Palette.surfaceRaised))
            }
            .disabled(!canSubmit)

            Button {
                isRegistering.toggle()
            } label: {
                Text(isRegistering ? "I already have an account" : "I need an account")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
            }
        }
    }

    /// Weighted like the others, because it is as valid as the others.
    private var withoutAnAccount: some View {
        Button(action: onContinueWithout) {
            Text("Continue without an account")
                .font(TypeScale.headline())
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
        }
    }

    private var smallPrint: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            fact("Nothing leaves this phone until you sign in.")
            fact("Your bottles stay here either way. Signing out never removes them.")
            fact("Export and backup work whether you sign in or not.")
        }
    }

    private func fact(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.good)
            Text(text)
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorLine(_ error: String) -> some View {
        Text(error)
            .font(TypeScale.secondary())
            .foregroundStyle(Palette.bad)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8),
                  let nonce = appleNonce
            else { return }
            appleNonce = nil
            Task { await sync.signIn(appleIdentityToken: token, nonce: nonce.raw) }
        case .failure(let error):
            appleNonce = nil
            // Closing the sheet is not a failure worth a banner.
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            sync.report(signInError: error.localizedDescription)
        }
    }
}

#Preview {
    let env = AppEnvironment.preview()
    return ScrollView {
        SignInView(onContinueWithout: {})
            .padding(Space.xl)
    }
    .background(Palette.background)
    .environment(SyncController(database: env.database, configuration: nil))
}
