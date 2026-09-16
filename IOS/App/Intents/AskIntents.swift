import AppIntents
import WidgetKit
import LiquorEngine
import LiquorData

/// The Ask box, reachable from Siri and Shortcuts.
///
/// "Ask Liquor Log" takes any sentence the grammar knows; a question is
/// answered, a command is read back and confirmed before anything is
/// written, exactly as in the app. Two more shortcuts carry the two
/// questions worth a phrase of their own: what's open, and what's nearly
/// gone. Everything runs in the app's own process against its own
/// database; nothing is sent anywhere.
struct AskIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask my shelf"
    // One literal: the description is a localisable resource, not a String.
    static let description = IntentDescription("Ask a question about your bottles, or tell it something to log: \"what's open\", \"how many Wellers do I have\", \"log a pour of Weller 12\", \"saw Blanton's at Total Wine for $75\".")
    static let openAppWhenRun = false

    @Parameter(title: "Sentence", requestValueDialog: "What would you like to ask?")
    var sentence: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask \(\.$sentence)")
    }

    init() {}
    init(sentence: String) { self.sentence = sentence }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let shelf = AskShelf.open()
        switch Ask.understand(sentence, catalog: shelf.candidates) {
        case .question(let question):
            let answer = shelf.service.answer(question)
            return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))

        case .command(let command):
            let described = shelf.service.describe(command)
            guard described.canRun else {
                return .result(value: described.text, dialog: IntentDialog(stringLiteral: described.text))
            }
            // Shown back before it is written, like the app's own Ask. The
            // confirmation call is iOS 18's; on iOS 17 the only one left is
            // deprecated, so there the sentence is read back and the app is
            // where it gets done. Nothing is ever written unconfirmed.
            guard #available(iOS 18, *) else {
                let text = described.text + " Open the app and say it there to do it."
                return .result(value: text, dialog: IntentDialog(stringLiteral: text))
            }
            try await requestConfirmation(
                conditions: [], actionName: .go, dialog: IntentDialog(stringLiteral: described.text))
            let done = try shelf.service.execute(command)
            WidgetCenter.shared.reloadAllTimelines()
            return .result(value: done, dialog: IntentDialog(stringLiteral: done))

        case .unknown:
            let text = "I did not follow that. Try \"what's open\", \"how many Wellers do I have\", "
                + "\"log a pour of Weller 12\" or \"what did I think of the Stagg\"."
            return .result(value: text, dialog: IntentDialog(stringLiteral: text))
        }
    }
}

/// "What's open in Liquor Log?"
struct WhatsOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "What's open"
    static let description = IntentDescription("Your open bottles, with the pours left in each.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let answer = AskShelf.open().service.answer(.whatIsOpen)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// "What's nearly gone in Liquor Log?"
struct NearlyGoneIntent: AppIntent {
    static let title: LocalizedStringResource = "What's nearly gone"
    static let description = IntentDescription("The open bottles down to their last pours.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let answer = AskShelf.open().service.answer(.nearlyGone)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

/// The phrases Siri listens for. `applicationName` is whatever the app is
/// called on the device, so the name decision does not touch this file.
struct LiquorLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatsOpenIntent(),
            phrases: [
                "What's open in \(.applicationName)",
                "What is open in \(.applicationName)",
                "Which bottles are open in \(.applicationName)",
            ],
            shortTitle: "What's open",
            systemImageName: "list.bullet.rectangle")
        AppShortcut(
            intent: NearlyGoneIntent(),
            phrases: [
                "What's nearly gone in \(.applicationName)",
                "What's running low in \(.applicationName)",
            ],
            shortTitle: "Nearly gone",
            systemImageName: "drop")
        AppShortcut(
            intent: AskIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) about my shelf",
            ],
            shortTitle: "Ask my shelf",
            systemImageName: "text.bubble")
    }
}

/// The database, the catalogue and the service, opened for one intent.
/// A second connection beside the app's own is fine: the file is in WAL
/// mode with a busy timeout, which is how the widget shares it already.
@MainActor
enum AskShelf {
    struct Opened {
        let env: AppEnvironment
        let service: AskService
        let candidates: [SearchCandidate]
    }

    static func open() -> Opened {
        let env = AppEnvironment.live()
        let service = AskService(env.database, identity: { env.identity($0) }, name: { env.name(for: $0) })
        let bundled = env.catalog.products.map {
            SearchCandidate(product: $0.identity, recipeCode: $0.code, mashbillKey: $0.mashbillKey)
        }
        let custom = (try? service.customCandidates()) ?? []
        return Opened(env: env, service: service, candidates: bundled + custom)
    }
}
