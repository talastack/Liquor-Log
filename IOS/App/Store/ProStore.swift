import Foundation
import Observation
import StoreKit
import LiquorEngine

/// Pro, bought through the App Store.
///
/// The split itself lives in the engine (`Entitlement`) and was rewritten
/// against the research: unlimited bottles, export, scanning and every
/// differentiator are free forever, and what is chargeable is the short list
/// people tolerate paying for because it is a service -- sync, the insurance
/// PDF, a hosted menu. This file only answers "is this person Pro" and sells
/// the subscription; it decides nothing about what Pro contains.
///
/// StoreKit 2. Entitlement is read from the App Store's own record of current
/// transactions on every launch and on every change, never from a flag we
/// keep, so a refund or an expiry takes effect without us doing anything.
///
/// **Price is not in this file.** It is set in App Store Connect and shown
/// from the product, so changing it needs no release. The research's one
/// rule on price -- it never scales with collection size -- is enforced by
/// there being no per-bottle product to buy.
@Observable
@MainActor
final class ProStore {

    /// The product identifiers, as they will be created in App Store Connect.
    /// Two lengths of the same thing; nothing else is for sale.
    enum ProductID: String, CaseIterable {
        case yearly = "com.talastack.liquorlog.pro.yearly"
        case monthly = "com.talastack.liquorlog.pro.monthly"
    }

    /// Links Apple requires beside an auto-renewable subscription. Nil until
    /// the pages exist; the paywall hides the lines rather than pointing at
    /// nothing.
    static let termsURL: URL? = nil
    static let privacyURL: URL? = nil

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Debug builds only: pretend to be Pro so gated screens can be tested
    /// on a simulator with no App Store account. Compiled out of release.
    #if DEBUG
    var debugOverride: Bool {
        get { UserDefaults.standard.bool(forKey: "pro.debugOverride") }
        set {
            UserDefaults.standard.set(newValue, forKey: "pro.debugOverride")
            Task { await refreshEntitlement() }
        }
    }
    #endif

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            // Every transaction the App Store delivers while the app runs:
            // a purchase finishing on another device, a renewal, a refund.
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task { await start() }
    }

    func start() async {
        await refreshEntitlement()
        await loadProducts()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            // Yearly first: it is the one to recommend and the one most
            // people pick when both are shown.
            products = fetched.sorted { a, b in
                (a.id == ProductID.yearly.rawValue) && (b.id != ProductID.yearly.rawValue)
            }
            lastError = nil
        } catch {
            lastError = "Could not reach the App Store: \(error.localizedDescription)"
        }
    }

    /// True when any current, verified transaction is one of ours.
    func refreshEntitlement() async {
        #if DEBUG
        if debugOverride {
            isPro = true
            return
        }
        #endif
        var found = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID(rawValue: transaction.productID) != nil, transaction.revocationDate == nil {
                found = true
            }
        }
        isPro = found
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Asks the App Store to re-deliver. Needed after a reinstall or on a
    /// new device, and Apple requires the button.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Whether a feature is usable right now, from the engine's split.
    func allows(_ feature: Feature) -> Bool {
        Entitlement.isAvailable(feature, in: isPro ? .pro : .free)
    }
}
