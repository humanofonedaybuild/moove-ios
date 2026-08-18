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
    @State private var hasCompletedInitialFetch = false

    var body: some View {
        ScrollView {
            VStack(spacing: MooveSpacing.xxl) {
                headerSection
                howItWorksSection
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
            await subscriptionManager.fetchProducts()
            await subscriptionManager.refreshSubscriptionState()
            hasCompletedInitialFetch = true
        }
    }

    // MARK: - Header (MOO-138 copy: validity-first, no feature lists)

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
                    Text("All of Moove.")
                        .font(MooveFont.title())
                        .foregroundStyle(Color.espresso)

                    Text("Free for 7 days.")
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
                 : "Your trial includes every feature. Subscribe to keep it all — for as long as you're subscribed.")
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

    // MARK: - How it works (MOO-138: validity timeline replaces feature list)

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: MooveSpacing.lg) {
            Text("How it works")
                .mooveEyebrow()

            VStack(spacing: 0) {
                HStack(spacing: MooveSpacing.lg) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.terracotta)

                    VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                        Text("Days 1–7")
                            .font(MooveFont.subheadline(weight: .semibold))
                            .foregroundStyle(Color.espresso)
                        Text("Everything free. Every feature included.")
                            .font(MooveFont.subheadline())
                            .foregroundStyle(Color.taupe)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, MooveSpacing.md)

                Rectangle()
                    .fill(Color.hairline)
                    .frame(height: 1)

                HStack(spacing: MooveSpacing.lg) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.terracotta)

                    VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                        Text("Day 8+")
                            .font(MooveFont.subheadline(weight: .semibold))
                            .foregroundStyle(Color.espresso)
                        Text("Keep everything while subscribed. Cancel anytime.")
                            .font(MooveFont.subheadline())
                            .foregroundStyle(Color.taupe)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, MooveSpacing.md)
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
            } else if !subscriptionManager.products.isEmpty {
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
                        isSelected: selectedPlan == .monthly,
                        action: { selectedPlan = .monthly }
                    )
                }

                if let yearly = subscriptionManager.yearlyProduct {
                    PlanCard(
                        title: "Yearly · Best Value",
                        price: "\(yearly.localizedPriceString) / year",
                        trialDuration: "7-day free trial",
                        savingsNote: "Save over 30% vs monthly",
                        isSelected: selectedPlan == .yearly,
                        action: { selectedPlan = .yearly }
                    )
                }
            } else if hasCompletedInitialFetch {
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
                ProgressView()
                    .tint(.espresso)
                    .padding(.vertical, MooveSpacing.lg)
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


