import SwiftUI
import StoreKit
import LiquorEngine

/// What Pro is, what it costs, and -- first -- what stays free.
///
/// Leading with the free list is deliberate. The research's sharpest finding
/// on pricing is that people in this category have been burned: bottle caps,
/// paywalled export, prices that scale with the collection. The paywall says
/// none of that happens here before it asks for anything, because the trust
/// is the product.
struct PaywallView: View {
    @Environment(ProStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The feature that brought the person here, named at the top so the
    /// screen answers the question they actually had.
    var reason: Feature?

    private var proFeatures: [Feature] {
        Entitlement.displayOrder.filter { !Entitlement.isAvailable($0, in: .free) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                stillFree
                whatProAdds
                if store.isPro {
                    youArePro
                } else {
                    plans
                }
                legal
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 96)
        }
        .background(Palette.background)
        .navigationTitle("Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }.foregroundStyle(Palette.textSecondary)
            }
        }
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let reason {
                SectionLabel(Entitlement.title(for: reason))
            }
            Text("Pay for services. Never for your own data.")
                .font(TypeScale.largeTitle())
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stillFree: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Free, and staying free")
            Text("Unlimited bottles. Every barrel, batch and pick field. The shelf "
                 + "check, the fill level, the oxidation clock, the flavour wheel, "
                 + "label scanning. Export of everything, always. The price never "
                 + "goes up because your collection did.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }

    private var whatProAdds: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("What Pro adds")
                .padding(.bottom, Space.xs)
            ForEach(Array(proFeatures.enumerated()), id: \.element) { index, feature in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Entitlement.title(for: feature))
                        .font(TypeScale.body())
                        .foregroundStyle(Palette.text)
                    if let why = Entitlement.reason(for: feature) {
                        Text(why)
                            .font(TypeScale.caption())
                            .textCase(nil)
                            .foregroundStyle(Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, Space.s)
                if index < proFeatures.count - 1 {
                    Divider().overlay(Palette.line)
                }
            }
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Plans")
            if store.products.isEmpty {
                Text(store.isLoading
                     ? "Loading prices…"
                     : (store.lastError ?? "Prices are not available right now."))
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textMuted)
            }
            ForEach(store.products, id: \.id) { product in
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.displayName)
                                .font(TypeScale.headline())
                            if let period = product.subscription?.subscriptionPeriod {
                                Text(periodLabel(period))
                                    .font(TypeScale.caption())
                                    .textCase(nil)
                                    .opacity(0.8)
                            }
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .font(TypeScale.headline())
                    }
                    .foregroundStyle(product.id == ProStore.ProductID.yearly.rawValue
                                     ? Palette.onGold : Palette.text)
                    .padding(Space.l)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(product.id == ProStore.ProductID.yearly.rawValue
                              ? Palette.gold : Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
                }
            }
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restore purchases")
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity, minHeight: Space.tapTarget)
            }
            if let error = store.lastError, !store.products.isEmpty {
                Text(error)
                    .font(TypeScale.caption())
                    .textCase(nil)
                    .foregroundStyle(Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var youArePro: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("You have Pro")
            Text("Thank you. Manage or cancel the subscription in Settings › Apple ID › "
                 + "Subscriptions; everything you have entered stays yours either way.")
                .font(TypeScale.secondary())
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Payment is charged to your Apple ID at confirmation. The subscription "
                 + "renews automatically unless cancelled at least 24 hours before the "
                 + "end of the period. Cancelling never removes anything you entered.")
                .font(TypeScale.caption())
                .textCase(nil)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.l) {
                if let terms = ProStore.termsURL {
                    Link("Terms of use", destination: terms)
                }
                if let privacy = ProStore.privacyURL {
                    Link("Privacy policy", destination: privacy)
                }
            }
            .font(TypeScale.caption())
            .foregroundStyle(Palette.gold)
        }
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .year: return period.value == 1 ? "Billed yearly" : "Every \(period.value) years"
        case .month: return period.value == 1 ? "Billed monthly" : "Every \(period.value) months"
        case .week: return period.value == 1 ? "Billed weekly" : "Every \(period.value) weeks"
        case .day: return "Every \(period.value) days"
        @unknown default: return ""
        }
    }
}

/// A Pro feature, seen without Pro: what it is, why it costs, and the way
/// in. Never a blurred screenshot and never a countdown.
struct ProLockedCard: View {
    let feature: Feature
    @State private var isShowingPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionLabel("Pro")
            Text(Entitlement.title(for: feature))
                .font(TypeScale.title())
                .foregroundStyle(Palette.text)
            if let why = Entitlement.reason(for: feature) {
                Text(why)
                    .font(TypeScale.secondary())
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { isShowingPaywall = true } label: {
                Text("See what Pro includes")
                    .font(TypeScale.headline())
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.gold))
            }
        }
        .padding(Space.l)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 1))
        .sheet(isPresented: $isShowingPaywall) {
            NavigationStack { PaywallView(reason: feature) }
        }
    }
}
