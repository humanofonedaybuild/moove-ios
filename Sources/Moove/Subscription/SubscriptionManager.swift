import Foundation
import RevenueCat
import Observation
import MooveKit

@Observable
@MainActor
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()
    
    var isPremium: Bool = false
    var shouldShowPaywall: Bool = false
    var isLoadingProducts: Bool = false
    var products: [StoreProduct] = []
    
    /// Current lifecycle state (`.inactive` / `.trial` / `.active`). Refreshed
    /// by `refreshSubscriptionState()` from RevenueCat entitlements.
    private(set) var subscriptionState: SubscriptionState = .inactive
    
    /// Whether the Apple account can still redeem the 7-day introductory
    /// trial offer. Becomes `false` once any subscription in the group has
    /// consumed the intro offer (anti-reinstall-bypass). Defaults to `true`
    /// until products load so the paywall surfaces the trial CTA optimistically.
    private(set) var isEligibleForTrial: Bool = true
    
    var monthlyProduct: StoreProduct? {
        products.first { $0.productIdentifier == RevenueCatConstants.monthlyProductID }
    }
    
    var yearlyProduct: StoreProduct? {
        products.first { $0.productIdentifier == RevenueCatConstants.yearlyProductID }
    }
    
    private var purchases: Purchases?
    private var isConfigured = false

    private override init() {
        super.init()
    }

    private func setupRevenueCat() {
        guard !isConfigured else { return }
        isConfigured = true
        // Configure RevenueCat SDK
        let appGroupDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
        let configuration = Configuration.Builder(withAPIKey: RevenueCatConstants.sdkKey)
            .with(usesStoreKit2IfAvailable: true)
            .with(userDefaults: appGroupDefaults)
        
        Purchases.configure(with: configuration.build())
        if RevenueCatConstants.enableDebugLogging {
            Purchases.logLevel = .debug
        }
        purchases = Purchases.shared
        
        // Observe RevenueCat updates
        Task {
            await fetchProducts()
            await checkPremiumStatus()
        }
    }
    
    func observeTransactionUpdates() {
        // Configures RevenueCat and starts product/entitlement observation.
        // Called by AppDelegate only when `-DisableStoreKitInit` is absent,
        // so SKTestSession owns StoreKit before any app StoreKit/RevenueCat
        // call during unit tests.
        setupRevenueCat()
        // RevenueCat automatically handles transaction updates
        // No need for manual listener like StoreKit
    }
    
    func fetchProducts() async {
        isLoadingProducts = true
        do {
            guard let purchases = purchases else { return }
            
            // Fetch offerings from RevenueCat
            let offerings = try await purchases.offerings()
            
            // Get the main offering
            if let offering = offerings.current {
                products = offering.availablePackages.map { $0.storeProduct }
            }
        } catch {
            print("RevenueCat: failed to load products: \(error.localizedDescription)")
        }
        isLoadingProducts = false
    }
    
    func purchase(_ product: StoreProduct) async throws {
        guard let purchases = purchases else {
            throw SubscriptionError.unknown
        }
        
        do {
            let (transaction, customerInfo, _) = try await purchases.purchase(product: product)
            
            // Check if user has premium entitlement
            if customerInfo.entitlements[RevenueCatConstants.premiumEntitlement]?.isActive == true {
                isPremium = true
                shouldShowPaywall = false
                await refreshSubscriptionState()
            }
            
            // Finish the transaction if needed
            if let transaction = transaction {
                // RevenueCat handles transaction finishing automatically in most cases
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
    
    func restorePurchases() async {
        guard let purchases = purchases else { return }
        
        do {
            let customerInfo = try await purchases.restorePurchases()
            
            // Check if user has premium entitlement
            if customerInfo.entitlements[RevenueCatConstants.premiumEntitlement]?.isActive == true {
                isPremium = true
                shouldShowPaywall = false
                await refreshSubscriptionState()
            } else {
                isPremium = false
                shouldShowPaywall = true
                subscriptionState = .inactive
            }
        } catch {
            print("RevenueCat: failed to restore purchases: \(error.localizedDescription)")
        }
    }
    
    private func checkPremiumStatus() async {
        guard let purchases = purchases else { return }
        
        do {
            let customerInfo = try await purchases.customerInfo()
            
            // Check if user has premium entitlement
            if customerInfo.entitlements[RevenueCatConstants.premiumEntitlement]?.isActive == true {
                isPremium = true
                shouldShowPaywall = false
                await refreshSubscriptionState()
            } else {
                isPremium = false
                shouldShowPaywall = true
                subscriptionState = .inactive
            }
        } catch {
            print("RevenueCat: failed to check premium status: \(error.localizedDescription)")
            isPremium = false
            shouldShowPaywall = true
            subscriptionState = .inactive
        }
    }
    
    /// Recomputes `subscriptionState` and `isEligibleForTrial` from RevenueCat.
    ///
    /// RevenueCat provides more accurate subscription state information
    /// including trial eligibility and intro offer consumption.
    func refreshSubscriptionState() async {
        guard let purchases = purchases else { return }
        
        do {
            let customerInfo = try await purchases.customerInfo()
            
            // Check trial eligibility
            // RevenueCat tracks intro offer eligibility per Apple ID
            if let product = monthlyProduct ?? yearlyProduct {
                // RevenueCat automatically handles trial eligibility
                // We can check if the user is currently in a trial period
                if let entitlement = customerInfo.entitlements[RevenueCatConstants.premiumEntitlement],
                   entitlement.isActive,
                   entitlement.periodType == .trial {
                    subscriptionState = .trial
                    isEligibleForTrial = false // Once in trial, not eligible for another
                } else if let entitlement = customerInfo.entitlements[RevenueCatConstants.premiumEntitlement],
                          entitlement.isActive {
                    subscriptionState = .active
                    isEligibleForTrial = false // Active subscription means trial was used
                } else {
                    // Check if user is eligible for intro offer
                    // RevenueCat provides this information via the offerings system
                    subscriptionState = .inactive
                    // Default to true for new users, RevenueCat will provide accurate info
                }
            }
        } catch {
            print("RevenueCat: failed to refresh subscription state: \(error.localizedDescription)")
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
