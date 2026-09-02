import Foundation

public enum RevenueCatConstants {
    // MARK: - SDK Configuration
    // Public SDK Key from RevenueCat dashboard
    // This key should be added to the project via Xcode build settings or environment variable
    // For development: Use RevenueCat's test mode
    // For production: Use RevenueCat's production key
    
    // Public SDK Key from the RevenueCat dashboard (Project → Apps → API Keys),
    // provided by the board in MOO-77. RevenueCat public SDK keys are safe to
    // ship in the client binary.
    public static let sdkKey = "appl_PaelTIKnPvotFuoSpfxwmZXbfVP"

    /// Whether `sdkKey` holds a real RevenueCat public SDK key.
    ///
    /// RevenueCat public SDK keys carry a platform prefix (`appl_` for Apple,
    /// `goog_` for Google, `amzn_` for Amazon). Any other prefix — including
    /// the committed `test_` and `YOUR_` placeholders — is not a valid key:
    /// configuring RevenueCat with it makes every offerings/purchase call
    /// fail. While the key is a placeholder `SubscriptionManager` reads this
    /// flag to fall back to direct StoreKit 2 backed by the local
    /// `Resources/Moove.storekit` config so the paywall and 7-day trial
    /// remain fully testable in the simulator (MOO-86).
    public static var isConfigured: Bool {
        let key = sdkKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && key.hasPrefix("appl_")
    }
    
    // MARK: - Product IDs
    // These should match the product IDs configured in RevenueCat dashboard
    // Note: RevenueCat uses the same product IDs as App Store Connect
    
    public static let monthlyProductID = "moove.monthly"
    public static let yearlyProductID = "moove.yearly"
    
    public static let subscriptionProductIDs: [String] = [monthlyProductID, yearlyProductID]
    
    // MARK: - Entitlements
    // These should match the entitlements configured in RevenueCat dashboard
    
    public static let premiumEntitlement = "premium"
    
    // MARK: - Offerings
    // Offering IDs configured in RevenueCat dashboard
    
    public static let mainOfferingID = "default"
    
    // MARK: - Configuration Flags
    
    public static let enableDebugLogging = true // Set to true for development, false for production
    
    // MARK: - App Store Connect Configuration
    // These values should match App Store Connect configuration
    
    public static let appBundleID = "com.moove.alarmclock"
    public static let appName = "Moove Alarm Clock"
}