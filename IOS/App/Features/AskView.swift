import SwiftUI
import LiquorData
import LiquorEngine

/// A text box that understands you.
///
/// Type "log a pour of weller 12" or "what's open" and it does the thing or
/// answers the question, from your own data, on this phone. The grammar is
/// the engine's `Ask`; this screen runs what it understood and shows the
/// answer. A command is always shown back and confirmed before anything is
/// written, because "log a pour" against the wrong bottle is a mistake
/// somebody has to find and undo.
///
/// Where the phone has an on-device language model, `AskModel` turns looser
/// phrasing into the same commands. Older phones get the grammar alone.
/// Nothing here says AI anywhere a person can see.
struct AskView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    struct Exchange: Identifiable {
        let id = UUID()
        let asked: String
        var answer: String
        /// A command waiting for a yes.
        var pending: Ask.Command?
        var done = false
    }

    @State private var typed = ""
    @State private var exchanges: [Exchange] = []
    @FocusState private var isTyping: Bool

    private let examples = [
        "What's open", "How many bottles do I have", "Log a pour of Weller 12",
        "Rate the Stagg an 8", "Add a bottle of Eagle Rare, paid 40 at Total Wine",
        "When did I last pour the Blanton's",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.l) {
                        if exchanges.isEmpty {
                            intro
                        }
                        ForEach(exchanges) { exchange in
                            exchangeView(exchange).id(exchange.id)
                        }
                    }
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.l)
                    .padding(.bottom, Space.xl)
                }
                .onChange(of: exchanges.count) { _, _ in
                    if let last = exchanges.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
        .background(Palette.background)
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
            }
        }
    }

    // MARK: - Pieces

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Ask about your shelf, or tell it what you did.")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Answered from your own shelf, on this phone.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SectionLabel("Try")
            ForEach(examples, id: \.self) { example in
                Button { submit(example) } label: {
                    Text(example)
                        .font(TypeScale.secondary())
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, Space.l)
                        .frame(maxWidth: .infinity, minHeight: Space.tapTarget - 6, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.surfaceRaised))
                }
            }
        }
    }

    private func exchangeView(_ exchange: Exchange) -> some View {
        VStack(alignment: .trailing, spacing: Space.s) {
            Text(exchange.asked)
                .font(TypeScale.body())
                .foregroundStyle(Palette.onGold)
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.m)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.gold))
                .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .leading, spacing: Space.m) {
                Text(exchange.answer)
                    .font(TypeScale.body())
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let pending = exchange.pending, !exchange.done {
                    HStack(spacing: Space.m) {
                        Button { run(pending, for: exchange.id) } label: {
                            Text("Yes, do it")
                                .font(TypeScale.secondary().weight(.semibold))
                                .foregroundStyle(Palette.onGold)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Palette.gold))
                        }
                        Button { cancel(exchange.id) } label: {
                            Text("No")
                                .font(TypeScale.secondary())
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, Space.l)
                                .frame(minHeight: Space.tapTarget - 8)
                        }
                    }
                }
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
        }
    }

    private var composer: some View {
        HStack(spacing: Space.m) {
            TextField("Ask, or tell it what you did", text: $typed, axis: .vertical)
                .font(TypeScale.body())
                .foregroundStyle(Palette.text)
                .lineLimit(1...4)
                .focused($isTyping)
                .onSubmit { submit(typed) }
            Button { submit(typed) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .accessibilityLabel("Ask")
                    .font(.system(size: 28))
                    .foregroundStyle(typed.trimmingCharacters(in: .whitespaces).isEmpty ? Palette.textMuted : Palette.gold)
            }
            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .background(Palette.surface)
        .overlay(Rectangle().fill(Palette.line).frame(height: 1), alignment: .top)
    }

    // MARK: - Understanding

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        typed = ""
        let catalog = env.catalog.searchCandidates(history: env.historyProductIds()) + customCandidates()
        var exchange = Exchange(asked: trimmed, answer: "")
        if let understood = interpret(trimmed, catalog: catalog) {
            exchange = understood(exchange)
            exchanges.append(exchange)
            return
        }

        // The grammar did not follow. On a phone with the on-device model,
        // let it rephrase into the grammar's shape and try once more; the
        // model never touches the database, it only rewords.
        guard AskModel.isAvailable else {
            exchange.answer = didNotFollow
            exchange.done = true
            exchanges.append(exchange)
            return
        }
        exchange.answer = "…"
        exchanges.append(exchange)
        let id = exchange.id
        let names = catalog.map(\.product.displayName)
        Task {
            let rephrased = await AskModel.rephrase(trimmed, bottleNames: names)
            guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
            if let rephrased, let understood = interpret(rephrased, catalog: catalog) {
                exchanges[index] = understood(exchanges[index])
            } else {
                exchanges[index].answer = didNotFollow
                exchanges[index].done = true
            }
        }
    }

    private var didNotFollow: String {
        "I did not follow that. Try \"log a pour of …\", \"what's open\", "
            + "\"how many … do I have\", \"rate … an 8\" or \"add a bottle of …\"."
    }

    /// The grammar's reading of a sentence as a change to apply to an
    /// exchange, or nil when it did not follow.
    private func interpret(_ text: String, catalog: [SearchCandidate]) -> ((Exchange) -> Exchange)? {
        switch Ask.understand(text, catalog: catalog) {
        case .question(let question):
            let reply = answer(question)
            return { var e = $0; e.answer = reply; e.done = true; return e }
        case .command(let command):
            let (reply, ok) = describe(command)
            return { var e = $0; e.answer = reply; e.pending = ok ? command : nil; e.done = !ok; return e }
        case .unknown:
            return nil
        }
    }

    /// Typed-in products join the catalogue so "log a pour of jefferson's"
    /// finds the bottle you typed in.
    private func customCandidates() -> [SearchCandidate] {
        (try? service.customCandidates()) ?? []
    }

    // MARK: - Running

    private var service: AskService {
        AskService(env.database, identity: { env.identity($0) }, name: { env.name(for: $0) })
    }

    private func describe(_ command: Ask.Command) -> (String, Bool) {
        let described = service.describe(command)
        return (described.text, described.canRun)
    }

    private func answer(_ question: Ask.Question) -> String {
        service.answer(question)
    }

    private func run(_ command: Ask.Command, for id: UUID) {
        guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
        do {
            exchanges[index].answer = try service.execute(command)
            env.noteChange()
        } catch {
            exchanges[index].answer = "That did not work: \(error.localizedDescription)"
        }
        exchanges[index].done = true
        exchanges[index].pending = nil
    }

    private func cancel(_ id: UUID) {
        guard let index = exchanges.firstIndex(where: { $0.id == id }) else { return }
        exchanges[index].answer = "Not done."
        exchanges[index].done = true
        exchanges[index].pending = nil
    }
}
