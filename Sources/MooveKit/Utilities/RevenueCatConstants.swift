import Foundation

public enum RevenueCatConstants {
    // MARK: - SDK Configuration
    // Public SDK Key from RevenueCat dashboard
    // This key should be added to the project via Xcode build settings or environment variable
    // For development: Use RevenueCat's test mode
    // For production: Use RevenueCat's production key
    
    // Placeholder — the board must replace this with the real RevenueCat
    // Public SDK Key from the dashboard (Project → Apps → API Keys).
    // RevenueCat public SDK keys are safe to ship in the client, but the
    // real value is not committed until the dashboard/app are configured.
    public static let sdkKey = "YOUR_REVENUECAT_PUBLIC_SDK_KEY_HERE"
    
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
    
    public static let appBundleID = "com.moove.alarm"
    public static let appName = "Moove Alarm Clock"
}