import Foundation
import LiquorEngine

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The optional second layer of Ask: an on-device language model that turns
/// looser phrasing into the grammar's own commands.
///
/// Apple's Foundation Models framework (iOS 26) runs on the phone, costs
/// nothing, needs no network and sends nothing anywhere -- which is the only
/// kind of model this app can use. The research is explicit that people here
/// do not want a database of their booze on somebody's server, and the
/// product rule is no paid API. A cloud model would break both.
///
/// It is strictly additive. `Ask.understand` is tried first on every phone;
/// only a sentence the grammar returns as `unknown` is handed to the model,
/// and what comes back is rewritten into a sentence the grammar DOES know
/// and parsed again. The model never writes to the database and never
/// answers a question by itself: it rephrases, the grammar decides, the
/// screen confirms. A wrong guess therefore costs one "No" rather than a
/// pour logged on the wrong bottle.
///
/// On a phone without the framework this whole type does nothing, and the
/// screen does not mention it either way.
enum AskModel {

    /// True only where the framework exists and the model is ready.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// The sentence, rephrased into the grammar's shape, or nil when the
    /// model is unavailable or could not make one.
    static func rephrase(_ sentence: String, bottleNames: [String]) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else { return nil }
            let names = bottleNames.prefix(60).joined(separator: "; ")
            let instructions = """
                You rewrite one sentence about a whiskey collection into ONE of these exact forms, \
                and output nothing else:
                log a pour of <bottle>
                pour <N> oz of <bottle>
                open the <bottle>
                finish the <bottle>
                set the <bottle> level to <N>%
                rate the <bottle> an <1-10>
                add a bottle of <bottle>, paid <dollars> at <store>
                add <bottle> to my wishlist under $<dollars>
                note on <bottle>: <text>
                what's open
                how many bottles do I have
                how many <brand> do I have
                do I have <bottle>
                when did I last pour the <bottle>
                what did I think of the <bottle>
                what did I pay for the <bottle>
                where is my <bottle>
                what's on my wishlist
                what's nearly gone
                Use the bottle names from this list when one fits: \(names). \
                If the sentence is not about any of these, output exactly: unknown
                """
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: sentence)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, text.lowercased() != "unknown" else { return nil }
                return text
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}
