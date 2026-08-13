import SwiftUI
import MooveKit

struct PaywallView: View {
    var mode: PaywallMode = .optional

    @Environment(SubscriptionManager.self)
    private var subscriptionManager

    @Environment(\.dismiss)
    private var dismiss

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var selectedPlan: Plan = .yearly

    var body: some View {
        ScrollView {
            VStack(spacing: MooveSpacing.xxl) {
                headerSection
                proofPointsSection
                pricingSection
                bottomSection
            }
            .padding(.horizontal, MooveSpacing.xxl)
            .padding(.top, MooveSpacing.huge)
            .padding(.bottom, MooveSpacing.huge)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .mooveScreenBackground()
        .task {
            // Products must be loaded for the paywall to show pricing and for
            // the purchase button to be actionable. `refreshSubscriptionState`
            // alone only reads entitlements — it does not fetch products — so
            // fetching here guarantees the paywall is never stuck on
            // "Pricing unavailable" with a disabled, unresponsive CTA (MOO-112).
            await subscriptionManager.fetchProducts()
            await subscriptionManager.refreshSubscriptionState()
        }
    }

    // MARK: - Header (MOO-113 copy: validity/permanence)

    private var headerSection: some View {
        VStack(spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text(mode == .required ? "Subscribe to continue" : "Moove Premium")
                .mooveEyebrow()
                .padding(.top, MooveSpacing.xxl)

            VStack(spacing: 0) {
                if mode == .required {
                    Text("To continue using Moove,")
                        .font(MooveFont.title())
                        .foregroundStyle(Color.espresso)

                    Text("please subscribe.")
                        .font(MooveFont.displayItalic(size: 34))
                        .foregroundStyle(Color.terracotta)
                } else {
                    Text("Everything.")
                        .font(MooveFont.title())
                        .foregroundStyle(Color.espresso)

                    Text("Forever.")
                        .font(MooveFont.displayItalic(size: 38))
                        .foregroundStyle(Color.terracotta)
                }
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, MooveSpacing.md)

            Text(mode == .required
                 ? "Your free trial has ended. Choose a plan to keep your alarms working."
                 : "Start a 7-day free trial to unlock all of Moove. Subscribe to keep everything — permanently.")
                .font(MooveFont.subheadline())
                .foregroundStyle(Color.taupe)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MooveSpacing.lg)
        }
        .background(softHeroGradient, alignment: .center)
    }

    private var softHeroGradient: some View {
        RadialGradient(
            colors: [Color.terracotta.opacity(0.18), Color.cream.opacity(0)],
            center: .center,
            startRadius: 8,
            endRadius: 160
        )
        .frame(width: 320, height: 320)
        .allowsHitTesting(false)
    }

    // MARK: - Proof points (MOO-113: "Keep forever" lead-in + 4 items)

    private var proofPointsSection: some View {
        VStack(alignment: .leading, spacing: MooveSpacing.lg) {
            Text("Keep forever")
                .mooveEyebrow()

            VStack(spacing: 0) {
                ForEach(Array(proofPoints.enumerated()), id: \.offset) { index, point in
                    HStack(spacing: MooveSpacing.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.terracotta)

                        Text(point)
                            .font(MooveFont.subheadline(weight: .medium))
                            .foregroundStyle(Color.espresso)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, MooveSpacing.md)

                    if index < proofPoints.count - 1 {
                        Rectangle()
                            .fill(Color.hairline)
                            .frame(height: 1)
                    }
                }
            }
        }
        .mooveCard(padding: MooveSpacing.lg)
    }

    // MARK: - Pricing (MOO-112: real StoreKit 2 product pricing)

    private var pricingSection: some View {
        VStack(spacing: MooveSpacing.md) {
            if subscriptionManager.isLoadingProducts {
                ProgressView()
                    .tint(.espresso)
                    .padding(.vertical, MooveSpacing.lg)
            } else if subscriptionManager.products.isEmpty {
                VStack(spacing: MooveSpacing.md) {
                    Text("Pricing unavailable")
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)

                    Text(subscriptionManager.productsLoadFailed
                         ? "We couldn't load subscription options. Check your connection and try again."
                         : "We couldn't load subscription options right now.")
                        .font(MooveFont.caption())
                        .foregroundStyle(Color.taupe.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 260)

                    Button {
                        Task { await subscriptionManager.fetchProducts() }
                    } label: {
                        Text("Retry")
                            .font(MooveFont.caption())
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 200, height: 44)
                    }
                    .accessibilityIdentifier("paywall.retryButton")
                }
            } else {
                Text("Start your 7-day free trial")
                    .font(MooveFont.headline())
                    .foregroundStyle(Color.espresso)

                Text("Cancel anytime")
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe.opacity(0.7))

                if let monthly = subscriptionManager.monthlyProduct {
                    PlanCard(
                        title: "Monthly",
                        price: "\(monthly.localizedPriceString) / month",
                        trialDuration: "7-day free trial",
                        features: monthlyFeatures,
                        isSelected: selectedPlan == .monthly,
                        action: { selectedPlan = .monthly }
                    )
                }

                if let yearly = subscriptionManager.yearlyProduct {
                    PlanCard(
                        title: "Yearly · Best Value",
                        price: "\(yearly.localizedPriceString) / year",
                        trialDuration: "7-day free trial",
                        features: yearlyFeatures,
                        isSelected: selectedPlan == .yearly,
                        action: { selectedPlan = .yearly }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom (CTA + trial note + secondary + restore + legal)

    private var bottomSection: some View {
        VStack(spacing: MooveSpacing.md) {
            if let error = purchaseError {
                Text(error)
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.terracotta)
                    .multilineTextAlignment(.center)
            }

            // Only render the purchase CTA when a product is actually
            // selectable. When products failed to load the pricing section
            // already surfaces a Retry; rendering a permanently-disabled
            // "Start 7-Day Free Trial" button here traps the user on the
            // screen ("button does nothing / app hangs" — MOO-112).
            if selectedProduct != nil {
                Button(action: purchase) {
                    HStack(spacing: MooveSpacing.sm) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.cream)
                        }

                        Text(isPurchasing ? "Please wait..." : ctaLabel)
                    }
                }
                .mooveButton(.primary)
                .disabled(isPurchasing || subscriptionManager.isLoadingProducts)
                .accessibilityIdentifier("paywall.startTrialButton")

                trialNote
            }

            if mode == .optional {
                Button {
                    dismiss()
                } label: {
                    Text("Maybe later")
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)
                        .frame(width: 200, height: 44)
                }
                .accessibilityIdentifier("paywall.maybeLaterButton")
            }

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
            }
            .mooveButton(.secondary)

            legalLinks
        }
        .padding(.top, MooveSpacing.md)
    }

    /// Trial transparency note (MOO-113): small print directly under the CTA —
    /// "Free for 7 days. Then [price] / [period]. Cancel anytime." Only shown
    /// while the introductory offer is still available and a plan is selected.
    private var trialNote: some View {
        Group {
            if subscriptionManager.isEligibleForTrial, let product = selectedProduct {
                Text("Free for 7 days. Then \(product.localizedPriceString) / \(selectedPeriod). Cancel anytime.")
            }
        }
        .font(MooveFont.caption())
        .foregroundStyle(Color.taupe.opacity(0.8))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var legalLinks: some View {
        HStack(spacing: MooveSpacing.md) {
            Link("Terms of Service", destination: Constants.Links.termsOfService)
            Text("·")
            Link("Privacy Policy", destination: Constants.Links.privacyPolicy)
        }
        .font(MooveFont.caption())
        .foregroundStyle(Color.taupe)
        .padding(.top, MooveSpacing.sm)
    }

    private var ctaLabel: String {
        if subscriptionManager.isEligibleForTrial {
            return "Start 7-Day Free Trial"
        }
        if let product = selectedProduct {
            return "Subscribe — \(product.localizedPriceString)"
        }
        return "Subscribe"
    }

    private var selectedProduct: PaywallProduct? {
        switch selectedPlan {
        case .monthly: subscriptionManager.monthlyProduct
        case .yearly: subscriptionManager.yearlyProduct
        }
    }

    private var selectedPeriod: String {
        switch selectedPlan {
        case .monthly: "month"
        case .yearly: "year"
        }
    }

    private func purchase() {
        purchaseError = nil
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            do {
                try await subscriptionManager.purchase(product)
                isPurchasing = false
                if subscriptionManager.isPremium {
                    dismiss()
                }
            } catch SubscriptionError.userCancelled, SubscriptionError.pending {
                isPurchasing = false
                if mode == .required { return }
            } catch {
                purchaseError = error.localizedDescription
                isPurchasing = false
            }
        }
    }
}

private enum Plan {
    case monthly
    case yearly
}

enum PaywallMode {
    case optional
    case required
}

/// Proof points (MOO-113): the four features are identical during the free
/// trial, so the copy centers on permanence — "Keep forever" — rather than
/// listing them as premium-only differentiators.
private let proofPoints: [String] = [
    "Unlimited alarms",
    "Full sound library",
    "Watch companion",
    "No ads"
]

private let monthlyFeatures: [String] = [
    "Unlimited alarms",
    "Full sound library",
    "Apple Watch companion"
]

private let yearlyFeatures: [String] = [
    "Everything in Monthly",
    "Save over 30% vs monthly",
    "Priority support"
]
