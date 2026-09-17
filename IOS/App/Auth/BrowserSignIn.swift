import AuthenticationServices
import UIKit

/// The system's own sign-in browser, for providers with no native sheet.
///
/// `ASWebAuthenticationSession` and not a `WKWebView`: the session runs in
/// Safari's process, so the password is typed into a page this app cannot
/// read, an existing Google session is reused, and the system asks the
/// person before any of it starts. Google also refuses embedded web views
/// outright, which is the other reason there is no choice to make here.
///
/// The redirect never reaches `onOpenURL`; the session claims it and hands
/// it back, which is why the callback carries a code rather than tokens.
@MainActor
enum BrowserSignIn {

    enum Failure: Error {
        /// The person closed the sheet. Not an error worth a banner.
        case cancelled
        /// The redirect came back without the code, or with an error from
        /// the provider in its place.
        case noCode(String?)
    }

    /// Opens `url`, waits for a redirect on `scheme`, and returns the
    /// authorisation code from it.
    static func authorizationCode(at url: URL, scheme: String) async throws -> String {
        let anchor = PresentationAnchor()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: scheme
            ) { callback, error in
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: cancelled ? Failure.cancelled : error)
                    return
                }
                guard let callback,
                      let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems
                else {
                    continuation.resume(throwing: Failure.noCode(nil))
                    return
                }
                func value(_ name: String) -> String? {
                    items.first { $0.name == name }?.value
                }
                if let code = value("code") {
                    continuation.resume(returning: code)
                } else {
                    // GoTrue puts the provider's refusal here: access_denied
                    // when the person said no, or a message worth showing.
                    continuation.resume(throwing: Failure.noCode(
                        value("error_description") ?? value("error")))
                }
            }
            session.presentationContextProvider = anchor
            // Deliberately not ephemeral: a person already signed in to
            // Google on this phone should not have to type a password again.
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: Failure.noCode("The sign-in page could not be opened."))
            }
            // The session holds the anchor alive until it finishes.
            anchor.session = session
        }
    }

    /// `ASWebAuthenticationSession` needs a window to hang the sheet on.
    private final class PresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
        var session: ASWebAuthenticationSession?

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }
}
