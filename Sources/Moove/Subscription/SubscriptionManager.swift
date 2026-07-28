import Foundation
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
    var products: [Product] = []

    /// Current lifecycle state (`.inactive` / `.trial` / `.active`). Refreshed
    /// by `refreshSubscriptionState()` from `Transaction.currentEntitlements`.
    private(set) var subscriptionState: SubscriptionState = .inactive

    /// Whether the Apple account can still redeem the 7-day introductory
    /// trial offer. Becomes `false` once any subscription in the group has
    /// consumed the intro offer (anti-reinstall-bypass). Defaults to `true`
    /// until products load so the paywall surfaces the trial CTA optimistically.
    private(set) var isEligibleForTrial: Bool = true

    var monthlyProduct: Product? {
        products.first { $0.id == Constants.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Constants.yearlyProductID }
    }

    private var transactionListener: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func observeTransactionUpdates() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self?.handleVerifiedTransaction(transaction)
                } catch {
                    continue
                }
            }
        }

        Task {
            await fetchProducts()
            await checkPremiumStatus()
        }
    }

    func fetchProducts() async {
        isLoadingProducts = true
        do {
            products = try await Product.products(for: Constants.subscriptionProductIDs)
        } catch {
            print("StoreKit: failed to load products: \(error.localizedDescription)")
        }
        isLoadingProducts = false
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await handleVerifiedTransaction(transaction)
            await transaction.finish()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unknown
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkPremiumStatus()
    }

    private func checkPremiumStatus() async {
        var foundActive = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if Constants.subscriptionProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                foundActive = true
            }
        }
        isPremium = foundActive
        shouldShowPaywall = !foundActive
        await refreshSubscriptionState()
    }

    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        guard Constants.subscriptionProductIDs.contains(transaction.productID),
              transaction.revocationDate == nil else {
            return
        }
        isPremium = true
        shouldShowPaywall = false
        await refreshSubscriptionState()
    }

    /// Recomputes `subscriptionState` and `isEligibleForTrial` from StoreKit.
    ///
    /// `isEligibleForTrial` comes from `Product.SubscriptionInfo.isEligibleForIntroOffer`
    /// — Apple tracks intro-offer consumption per Apple ID, so a reinstall
    /// cannot re-trigger the trial.
    ///
    /// `.trial` is detected when an active, non-revoked entitlement's billing
    /// period matches the 7-day introductory offer length
    /// (`expirationDate - purchaseDate ≈ 7 days`). A normal monthly/yearly
    /// renewal produces a billing period an order of magnitude longer, so the
    /// heuristic cleanly separates trial from paid periods without a custom
    /// backend or offer metadata.
    func refreshSubscriptionState() async {
        let eligibility = await (monthlyProduct ?? yearlyProduct)?.subscription?.isEligibleForIntroOffer
        if let eligibility {
            isEligibleForTrial = eligibility
        }

        var detected: SubscriptionState = .inactive
        let trialWindow = Constants.subscriptionTrialDuration
        let tolerance: TimeInterval = 24 * 3600
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            guard Constants.subscriptionProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate {
                let period = expiration.timeIntervalSince(transaction.purchaseDate)
                if abs(period - trialWindow) <= tolerance {
                    detected = .trial
                } else {
                    detected = .active
                }
            } else {
                detected = .active
            }
            break
        }
        subscriptionState = isPremium ? detected : .inactive
    }

    /// StoreKit 2 verifies transaction JWT signatures on-device. This helper
    /// unwraps a `VerificationResult`, throwing `.unverified` for any payload
    /// that fails Apple's signature check so callers cannot act on forged data.
    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw SubscriptionError.unverified
        }
    }

}

enum SubscriptionError: LocalizedError {
    case productNotFound
    case verificationFailed
    case unverified
    case userCancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound: "Subscription product not found in App Store Connect."
        case .verificationFailed: "Receipt verification failed. Please try again."
        case .unverified: "Apple could not verify this transaction. Please try again."
        case .userCancelled: "Purchase was cancelled."
        case .pending: "Purchase is pending and awaiting approval."
        case .unknown: "An unknown purchase error occurred."
        }
    }
}
