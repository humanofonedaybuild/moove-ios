import SwiftUI
import MooveKit

struct PaywallView: View {
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
                pricingSection
                featuresSection
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
            await subscriptionManager.refreshSubscriptionState()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text("Moove Premium")
                .mooveEyebrow()
                .padding(.top, MooveSpacing.xxl)

            VStack(spacing: 0) {
                Text("Wake up to your")
                    .font(MooveFont.title())
                    .foregroundStyle(Color.espresso)

                Text("full potential")
                    .font(MooveFont.displayItalic(size: 38))
                    .foregroundStyle(Color.terracotta)
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, MooveSpacing.md)
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

                    Button {
                        Task { await subscriptionManager.fetchProducts() }
                    } label: {
                        Text("Retry")
                            .font(MooveFont.caption())
                            .foregroundStyle(Color.terracotta)
                    }
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

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: MooveSpacing.lg) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.terracotta)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.terracotta.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(MooveFont.subheadline(weight: .medium))
                            .foregroundStyle(Color.espresso)

                        Text(feature.description)
                            .font(MooveFont.caption())
                            .foregroundStyle(Color.taupe)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, MooveSpacing.md)

                if index < features.count - 1 {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 1)
                        .padding(.leading, 52)
                }
            }
        }
        .mooveCard(padding: MooveSpacing.lg)
    }

    private var bottomSection: some View {
        VStack(spacing: MooveSpacing.md) {
            if let error = purchaseError {
                Text(error)
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.terracotta)
                    .multilineTextAlignment(.center)
            }

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
            .disabled(isPurchasing || subscriptionManager.isLoadingProducts || selectedProduct == nil)

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
            }
            .mooveButton(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Maybe Later")
                    .font(MooveFont.subheadline())
                    .foregroundStyle(Color.taupe)
                    .frame(width: 200, height: 44)
            }

            legalLinks
        }
        .padding(.top, MooveSpacing.md)
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

private struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

private let features: [Feature] = [
    Feature(
        icon: "alarm.fill",
        title: "Unlimited Alarms",
        description: "Set as many alarms as you need, each with custom step goals."
    ),
    Feature(
        icon: "music.note.list",
        title: "Full Sound Library",
        description: "Access all premium alarm sounds and import your own."
    ),
    Feature(
        icon: "applewatch",
        title: "Apple Watch Companion",
        description: "Track steps from your wrist and control alarms hands-free."
    ),
    Feature(
        icon: "sparkles",
        title: "No Ads, Ever",
        description: "A clean, focused experience. No interruptions."
    ),
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
