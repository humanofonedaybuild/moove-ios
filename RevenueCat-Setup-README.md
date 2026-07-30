# RevenueCat Setup Instructions for Moove Alarm Clock

## Overview
This document provides step-by-step instructions for completing the RevenueCat setup. The iOS codebase has been updated to use RevenueCat for subscription management.

## Steps Completed So Far

### 1. Codebase Updates ✅
- Added RevenueCat dependency to Package.swift
- Created RevenueCatConstants.swift with configuration template
- Updated SubscriptionManager.swift to use RevenueCat SDK
- Removed direct StoreKit subscription code
- Updated Constants.swift to remove duplicate product ID definitions

### 2. Files Created/Updated
- `Package.swift` - Added RevenueCat dependency
- `Sources/MooveKit/Utilities/RevenueCatConstants.swift` - RevenueCat configuration
- `Sources/Moove/Subscription/SubscriptionManager.swift` - Updated to use RevenueCat
- `Sources/MooveKit/Utilities/Constants.swift` - Cleaned up product IDs

## Next Steps for Board

### 1. RevenueCat Dashboard Setup
1. **Sign up at** https://app.revenuecat.com
2. **Create project:** `Moove Alarm Clock`
3. **Add iOS app:**
   - Bundle ID: `com.moove.alarmclock`
   - App Name: `Moove Alarm Clock`
4. **Configure products** in RevenueCat to match App Store Connect:
   - Product ID: `moove.monthly` (monthly subscription)
   - Product ID: `moove.yearly` (yearly subscription)
5. **Create entitlement:** `premium`

### 2. API Keys to Collect
1. **Public SDK Key** (from RevenueCat dashboard):
   - This goes into `RevenueCatConstants.swift` as `sdkKey`
   - Located in RevenueCat: Project → Apps → Your App → API Keys
2. **Secret API Key** (for backend/CI):
   - This goes into GitHub secrets as `REVENUECAT_API_KEY`
   - Generate in RevenueCat: Settings → API Keys

### 3. App Store Connect Connection
1. In RevenueCat: Settings → App Store Connect
2. Upload the same `.p8` API key used for Apple Developer enrollment
3. Connect App Store Connect account

### 4. Update Configuration Files

#### Update RevenueCatConstants.swift
Replace the placeholder SDK key with your actual Public SDK Key:

```swift
public static let sdkKey = "YOUR_ACTUAL_PUBLIC_SDK_KEY_HERE"
```

#### Update GitHub Secrets
Add the Secret API Key to GitHub secrets:
- Secret name: `REVENUECAT_API_KEY`
- Value: Your RevenueCat Secret API Key

### 5. Test Configuration
1. Build the project to ensure RevenueCat dependency loads
2. Run the app in simulator to test subscription flow
3. Use RevenueCat's Sandbox mode for testing

## RevenueCat Configuration Notes

### Product IDs
- Must match exactly between RevenueCat, App Store Connect, and code
- Current product IDs in code: `moove.monthly`, `moove.yearly`

### Entitlements
- Configured in RevenueCat as `premium`
- Grants access to premium features when subscription is active

### Offerings
- Default offering ID: `default`
- Can customize packages and presentation in RevenueCat dashboard

### Testing
- Enable debug logging in development: Set `enableDebugLogging = true`
- Use RevenueCat Sandbox for testing purchases
- Test restore purchases functionality

## Verification Checklist
- [ ] RevenueCat account created
- [ ] Project `Moove Alarm Clock` created
- [ ] iOS app added with bundle ID `com.moove.alarmclock`
- [ ] Products configured: `moove.monthly`, `moove.yearly`
- [ ] Entitlement `premium` created
- [ ] Public SDK Key copied to `RevenueCatConstants.swift`
- [ ] Secret API Key added to GitHub secrets
- [ ] App Store Connect connected in RevenueCat
- [ ] Project builds successfully
- [ ] Subscription flow tested in Sandbox mode

## Troubleshooting

### Common Issues
1. **Product not found**: Ensure product IDs match exactly across RevenueCat, App Store Connect, and code
2. **SDK not initializing**: Check SDK key is correct and internet connection
3. **Entitlement not active**: Verify entitlement configuration in RevenueCat
4. **Sandbox purchases failing**: Ensure Sandbox tester account is set up in App Store Connect

### RevenueCat Documentation
- iOS SDK: https://docs.revenuecat.com/docs/ios
- Getting Started: https://docs.revenuecat.com/docs/getting-started
- Testing: https://docs.revenuecat.com/docs/testing

## Support
For RevenueCat issues, contact their support or check documentation. For code issues, refer to the iOS engineering team.