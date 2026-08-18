import Foundation
import RevenueCat
import StoreKit
import Observation
import MooveKit

@Observable
@MainActor
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    var isPremium: Bool = false
    var shouldShowPaywall: Bool = false
    var isLoadingProducts: Bool = false
    var products: [PaywallProduct] = []

    /// `true` when the most recent `fetchProducts()` threw or returned no
    /// products. The paywall uses this (with `products.isEmpty`) to render a
    /// graceful "pricing unavailable" fallback with a Retry instead of a dead
    /// primary CTA, so the user is never trapped on the screen (MOO-112).
    private(set) var productsLoadFailed: Bool = false

    /// Current lifecycle state. Refreshed by `refreshSubscriptionState()`.
    private(set) var subscriptionState: SubscriptionState = .inactive

    /// Post-trial access gate (full / 24h grace / hard lock).
    private(set) var subscriptionAccess: SubscriptionAccess = .full

    var canUseAlarms: Bool { subscriptionAccess.canUseAlarms }
    var requiresHardPaywall: Bool { subscriptionAccess.requiresHardPaywall }
    var shouldShowGraceBanner: Bool { subscriptionAccess.graceEndsAt != nil }

    /// Injected clock for grace/expiry tests. Production always uses `Date()`.
    var nowProvider: () -> Date = Date.init

    /// Persistence for the last known intro-trial expiration. Isolated managers
    /// in tests can swap this to a throwaway suite.
    var persistence: UserDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard

    private static let trialExpirationDefaultsKey = "moove.subscription.lastTrialExpiration"
    private var wasHardLocked = false

    /// Whether the Apple account can still redeem the 7-day introductory
    /// trial offer. Becomes `false` once any subscription in the group has
    /// consumed the intro offer (anti-reinstall-bypass). Defaults to `true`
    /// until products load so the paywall surfaces the trial CTA optimistically.
    private(set) var isEligibleForTrial: Bool = true

    /// The purchase backend in use.
    enum Backend {
        /// Real RevenueCat SDK key present — full RevenueCat pipeline.
        case revenueCat
        /// Placeholder SDK key — direct StoreKit 2 backed by the local
        /// `Resources/Moove.storekit` configuration (dev/simulator mode).
        case storeKit
    }

    private(set) var backend: Backend = .storeKit

    var monthlyProduct: PaywallProduct? {
        products.first { $0.productIdentifier == RevenueCatConstants.monthlyProductID }
    }

    var yearlyProduct: PaywallProduct? {
        products.first { $0.productIdentifier == RevenueCatConstants.yearlyProductID }
    }

    private var purchases: Purchases?
    private var isConfigured = false
    private var transactionUpdatesTask: Task<Void, Never>?

    // Internal (not private) so tests can build isolated instances instead of
    // touching the shared singleton.
    override init() {
        super.init()
    }

    private func ensureConfigured() {
        guard !isConfigured else { return }
        isConfigured = true

        guard RevenueCatConstants.isConfigured else {
            backend = .storeKit
            print("SubscriptionManager: RevenueCat SDK key is a placeholder — using direct StoreKit 2 backend with the local Moove.storekit configuration.")
            startStoreKitTransactionListener()
            Task { await finishUnfinishedStoreKitTransactions() }
            return
        }

        backend = .revenueCat
        let appGroupDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
        let configuration = Configuration.Builder(withAPIKey: RevenueCatConstants.sdkKey)
            .with(usesStoreKit2IfAvailable: true)
            .with(userDefaults: appGroupDefaults)

        Purchases.configure(with: configuration.build())
        if RevenueCatConstants.enableDebugLogging {
            Purchases.logLevel = .debug
        }
        purchases = Purchases.shared
    }

    func observeTransactionUpdates() {
        // Configures the active backend and starts product/entitlement
        // observation. Called by AppDelegate only when `-DisableStoreKitInit`
        // is absent, so SKTestSession owns StoreKit before any app
        // StoreKit/RevenueCat call during unit tests.
        ensureConfigured()
        // RevenueCat automatically handles transaction updates; the StoreKit
        // fallback listens via `Transaction.updates` (see ensureConfigured).
        Task {
            await fetchProducts()
            await refreshPurchaseState()
        }
    }

    func fetchProducts() async {
        ensureConfigured()
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        switch backend {
        case .revenueCat:
            guard let purchases else {
                productsLoadFailed = true
                return
            }
            do {
                // Fetch offerings from RevenueCat
                let offerings = try await purchases.offerings()

                // Get the main offering
                if let offering = offerings.current {
                    products = offering.availablePackages.map { PaywallProduct(backing: .revenueCat($0.storeProduct)) }
                }
                productsLoadFailed = products.isEmpty
            } catch {
                print("RevenueCat: failed to load products: \(error.localizedDescription)")
                productsLoadFailed = true
            }
        case .storeKit:
            do {
                let storeProducts = try await StoreKit.Product.products(for: RevenueCatConstants.subscriptionProductIDs)
                products = storeProducts.map { PaywallProduct(backing: .storeKit($0)) }
                productsLoadFailed = products.isEmpty
                if !products.isEmpty {
                    await refreshStoreKitTrialEligibility()
                }
            } catch {
                print("StoreKit: failed to load products: \(error.localizedDescription)")
                productsLoadFailed = true
            }
        }
    }

    func purchase(_ product: PaywallProduct) async throws {
        ensureConfigured()
        switch product.backing {
        case .revenueCat(let storeProduct):
            try await purchaseViaRevenueCat(storeProduct)
        case .storeKit(let storeProduct):
            try await purchaseViaStoreKit(storeProduct)
        }
    }

    private func purchaseViaRevenueCat(_ product: StoreProduct) async throws {
        guard let purchases = purchases else {
            throw SubscriptionError.unknown
        }

        do {
            let (_, customerInfo, _) = try await purchases.purchase(product: product)

            // Check if user has premium entitlement
            if customerInfo.entitlements[RevenueCatConstants.premiumEntitlement]?.isActive == true {
                isPremium = true
                shouldShowPaywall = false
                await refreshSubscriptionState()
            } else {
                await refreshSubscriptionState()
            }
        } catch {
            if let revenueCatError = error as? RevenueCat.ErrorCode {
                switch revenueCatError {
                case .purchaseCancelledError:
                    throw SubscriptionError.userCancelled
                case .paymentPendingError:
                    throw SubscriptionError.pending
                default:
                    throw SubscriptionError.unknown
                }
            } else {
                throw SubscriptionError.unknown
            }
        }
    }

    private func purchaseViaStoreKit(_ product: StoreKit.Product) async throws {
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            print("StoreKit: purchase failed: \(error.localizedDescription)")
            throw SubscriptionError.unknown
        }

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.receiptValidationFailed
            }
            await transaction.finish()
            await refreshFromStoreKit()
            // Successful purchase dismisses the paywall (mirrors RevenueCat path).
            if isPremium { shouldShowPaywall = false }
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    func restorePurchases() async {
        ensureConfigured()

        switch backend {
        case .revenueCat:
            guard let purchases else { return }

            do {
                let customerInfo = try await purchases.restorePurchases()

                // Check if user has premium entitlement
                await applyRevenueCatCustomerInfo(customerInfo)
                if !isPremium { shouldShowPaywall = true }
            } catch {
                print("RevenueCat: failed to restore purchases: \(error.localizedDescription)")
            }
        case .storeKit:
            // StoreKit 2 has no separate restore call: `AppStore.sync()` forces
            // a transaction refresh against the store (prompting sign-in when
            // needed), then entitlements are re-read from on-device receipts.
            do {
                try await AppStore.sync()
            } catch {
                print("StoreKit: AppStore.sync failed during restore: \(error.localizedDescription)")
            }
            await refreshFromStoreKit()
            // User-initiated restore with nothing to restore surfaces the paywall.
            shouldShowPaywall = !isPremium
        }
    }

    private func refreshPurchaseState() async {
        switch backend {
        case .revenueCat:
            await checkPremiumStatus()
        case .storeKit:
            await refreshFromStoreKit()
        }
    }

    private func checkPremiumStatus() async {
        guard let purchases = purchases else { return }

        do {
            let customerInfo = try await purchases.customerInfo()

            // Check if user has premium entitlement.
            // Passive refresh must NOT force-present the paywall — the paywall
            // is shown only on user intent (Settings → Upgrade, post-onboarding,
            // failed restore). Auto-presenting on every cold launch blocks the
            // main UI for free users (QA MOO-87).
            await applyRevenueCatCustomerInfo(customerInfo)
        } catch {
            print("RevenueCat: failed to check premium status: \(error.localizedDescription)")
            isPremium = false
            applyResolvedAccess(
                hasCurrentEntitlement: false,
                isInIntroductoryOffer: false,
                lastTrialExpiration: persistedTrialExpiration(),
                hasExpiredSubscriptionStatus: persistedTrialExpiration() != nil
            )
        }
    }

    /// Recomputes `subscriptionState` and `isEligibleForTrial` from the active
    /// backend. Called by the paywall on appear.
    func refreshSubscriptionState() async {
        ensureConfigured()
        switch backend {
        case .revenueCat:
            await refreshSubscriptionStateFromRevenueCat()
        case .storeKit:
            await refreshFromStoreKit()
        }
    }

    private func refreshSubscriptionStateFromRevenueCat() async {
        guard let purchases = purchases else { return }

        do {
            let customerInfo = try await purchases.customerInfo()
            await applyRevenueCatCustomerInfo(customerInfo)
        } catch {
            print("RevenueCat: failed to refresh subscription state: \(error.localizedDescription)")
        }
    }

    private func applyRevenueCatCustomerInfo(_ customerInfo: CustomerInfo) async {
        let entitlement = customerInfo.entitlements[RevenueCatConstants.premiumEntitlement]
        let isActive = entitlement?.isActive == true
        let isTrial = isActive && entitlement?.periodType == .trial
        if isActive, let expiration = entitlement?.expirationDate ?? customerInfo.latestExpirationDate {
            persistTrialExpiration(expiration)
        }
        let expiredStatus = !isActive && (
            customerInfo.latestExpirationDate != nil || persistedTrialExpiration() != nil
        )
        applyResolvedAccess(
            hasCurrentEntitlement: isActive,
            isInIntroductoryOffer: isTrial,
            lastTrialExpiration: persistedTrialExpiration() ?? customerInfo.latestExpirationDate,
            hasExpiredSubscriptionStatus: expiredStatus
        )
        if isActive {
            isEligibleForTrial = false
        }
    }

    // MARK: - StoreKit 2 fallback backend

    private func startStoreKitTransactionListener() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task.detached(priority: .utility) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshFromStoreKit()
            }
        }
    }

    /// Finishes any transactions left unfinished by a previous launch, e.g.
    /// a purchase interrupted before `finish()` ran.
    private func finishUnfinishedStoreKitTransactions() async {
        for await unfinished in Transaction.unfinished {
            guard case .verified(let transaction) = unfinished else { continue }
            await transaction.finish()
        }
    }

    /// Recomputes premium/state/trial-eligibility from StoreKit 2
    /// `Transaction.currentEntitlements`. A current entitlement carrying
    /// `offerType == .introductory` means the 7-day trial is still running;
    /// once the trial converts, the renewed transaction has no offer type and
    /// the state flips to `.active`.
    private func refreshFromStoreKit() async {
        var hasActiveSubscription = false
        var isInTrialPeriod = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard RevenueCatConstants.subscriptionProductIDs.contains(transaction.productID) else { continue }
            hasActiveSubscription = true
            if transaction.offerType == .introductory {
                isInTrialPeriod = true
            }
        }

        let trialExpiration = await storeKitTrialExpiration()
        var expiredStatus = false
        for product in products {
            guard case .storeKit(let storeProduct) = product.backing,
                  let subscription = storeProduct.subscription else { continue }
            if let statuses = try? await subscription.status {
                expiredStatus = statuses.contains { $0.state == .expired }
            }
            break
        }
        if !hasActiveSubscription,
           let persisted = persistedTrialExpiration(),
           persisted <= nowProvider() {
            expiredStatus = true
        }

        applyResolvedAccess(
            hasCurrentEntitlement: hasActiveSubscription,
            isInIntroductoryOffer: isInTrialPeriod,
            lastTrialExpiration: trialExpiration,
            hasExpiredSubscriptionStatus: expiredStatus
        )
        await refreshStoreKitTrialEligibility()
    }

    func presentRequiredPaywall() {
        shouldShowPaywall = true
    }

    func applyResolvedAccessForTesting(
        hasCurrentEntitlement: Bool,
        isInIntroductoryOffer: Bool,
        lastTrialExpiration: Date?,
        hasExpiredSubscriptionStatus: Bool
    ) {
        applyResolvedAccess(
            hasCurrentEntitlement: hasCurrentEntitlement,
            isInIntroductoryOffer: isInIntroductoryOffer,
            lastTrialExpiration: lastTrialExpiration,
            hasExpiredSubscriptionStatus: hasExpiredSubscriptionStatus
        )
    }

    private func applyResolvedAccess(
        hasCurrentEntitlement: Bool,
        isInIntroductoryOffer: Bool,
        lastTrialExpiration: Date?,
        hasExpiredSubscriptionStatus: Bool
    ) {
        let now = nowProvider()
        var trialEnd = lastTrialExpiration
        if hasExpiredSubscriptionStatus, !hasCurrentEntitlement {
            if trialEnd == nil || (trialEnd ?? now) > now {
                persistTrialExpiration(now)
                trialEnd = now
            }
        }

        let access = SubscriptionAccessPolicy.resolve(
            hasCurrentEntitlement: hasCurrentEntitlement,
            lastTrialExpiration: trialEnd,
            hasExpiredSubscriptionStatus: hasExpiredSubscriptionStatus,
            now: now
        )

        isPremium = hasCurrentEntitlement
        subscriptionAccess = access
        if hasCurrentEntitlement {
            subscriptionState = isInIntroductoryOffer ? .trial : .active
            if isPremium { shouldShowPaywall = false }
        } else {
            switch access {
            case .trialGrace:
                subscriptionState = .trialGrace
            case .blocked:
                subscriptionState = .expired
                shouldShowPaywall = true
            case .full:
                subscriptionState = .inactive
            @unknown default:
                subscriptionState = .inactive
            }
        }
        enforceAlarmAccess()
    }

    private func enforceAlarmAccess() {
        guard self === SubscriptionManager.shared else { return }
        if subscriptionAccess.requiresHardPaywall {
            wasHardLocked = true
            AppAlarmManager.shared.suspendAllScheduledAlarms()
            return
        }
        if wasHardLocked {
            wasHardLocked = false
            Task { await AppAlarmManager.shared.rescheduleEnabledAlarms() }
        }
    }

    private func persistTrialExpiration(_ date: Date) {
        let existing = persistence.object(forKey: Self.trialExpirationDefaultsKey) as? Date
        let now = nowProvider()
        if let existing, existing <= now, date > now { return }
        if existing == date { return }
        persistence.set(date, forKey: Self.trialExpirationDefaultsKey)
    }

    func persistedTrialExpiration() -> Date? {
        persistence.object(forKey: Self.trialExpirationDefaultsKey) as? Date
    }

    private func storeKitTrialExpiration() async -> Date? {
        var latest = persistedTrialExpiration()

        func consider(_ date: Date?) {
            guard let date else { return }
            if latest == nil || date > latest! { latest = date }
        }

        for product in products {
            guard case .storeKit(let storeProduct) = product.backing,
                  let subscription = storeProduct.subscription else { continue }
            guard let statuses = try? await subscription.status else { continue }
            for status in statuses {
                guard case .verified(let transaction) = status.transaction else { continue }
                if transaction.offerType == .introductory || status.state == .expired {
                    consider(transaction.expirationDate)
                }
            }
        }

        if latest == nil {
            for await result in Transaction.all {
                guard case .verified(let transaction) = result else { continue }
                guard RevenueCatConstants.subscriptionProductIDs.contains(transaction.productID) else { continue }
                if transaction.offerType == .introductory {
                    consider(transaction.expirationDate)
                }
            }
        }

        if let latest { persistTrialExpiration(latest) }
        return latest
    }

    private func refreshStoreKitTrialEligibility() async {
        for product in products {
            if case .storeKit(let storeProduct) = product.backing,
               let subscription = storeProduct.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
                return
            }
        }
    }
}

enum SubscriptionError: LocalizedError {
    case productNotFound
    case configurationFailed
    case userCancelled
    case pending
    case unknown
    case networkError
    case receiptValidationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound: "Subscription product not found in RevenueCat."
        case .configurationFailed: "RevenueCat configuration failed. Please check your SDK key."
        case .userCancelled: "Purchase was cancelled."
        case .pending: "Purchase is pending and awaiting approval."
        case .unknown: "An unknown purchase error occurred."
        case .networkError: "Network connection failed. Please check your internet connection."
        case .receiptValidationFailed: "Receipt validation failed. Please try again."
        }
    }
}
