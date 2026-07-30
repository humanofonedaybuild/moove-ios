# RevenueCat Setup - Board Action Required

## Status Update
The RevenueCat integration code has been prepared. The iOS codebase now:
1. ✅ Has RevenueCat dependency added to Package.swift
2. ✅ Has RevenueCat configuration file template (RevenueCatConstants.swift)
3. ✅ Has updated SubscriptionManager.swift using RevenueCat SDK
4. ✅ Has cleaned up Constants.swift to remove duplicate product IDs

## What the Board Needs to Do

### 1. Complete RevenueCat Account Setup
Based on the screenshots you provided, RevenueCat is requesting:
- **App Bundle ID**: `com.moove.alarmclock`
- **App Name**: `Moove Alarm Clock`
- **Platform**: iOS

**Action Items:**
1. Sign up at https://app.revenuecat.com if not already done
2. Create project: `Moove Alarm Clock`
3. Add iOS app with bundle ID `com.moove.alarmclock`
4. Configure subscription products in RevenueCat dashboard:
   - `moove.monthly` (monthly subscription)
   - `moove.yearly` (yearly subscription)
5. Create entitlement: `premium`

### 2. Collect Required Keys
1. **Public SDK Key** (from RevenueCat dashboard):
   - Copy this key from RevenueCat: Project → Apps → Your App → API Keys
   - This key goes into `RevenueCatConstants.swift` line 12

2. **Secret API Key** (for GitHub CI/CD):
   - Generate in RevenueCat: Settings → API Keys
   - Add to GitHub secrets as `REVENUECAT_API_KEY`

### 3. Connect App Store Connect
1. In RevenueCat: Settings → App Store Connect
2. Upload the same `.p8` API key used for Apple Developer enrollment
3. Connect your App Store Connect account

### 4. Update Configuration File
Open `/Users/chetanchopra/Desktop/WORK/Dev/Moove/Sources/MooveKit/Utilities/RevenueCatConstants.swift` and update line 12:

```swift
public static let sdkKey = "YOUR_ACTUAL_PUBLIC_SDK_KEY_HERE"
```

Replace with your actual RevenueCat Public SDK Key.

## Files Ready for Your Review

### 1. RevenueCatConstants.swift
Location: `Sources/MooveKit/Utilities/RevenueCatConstants.swift`
Contains all RevenueCat configuration constants ready for your SDK key.

### 2. SubscriptionManager.swift (Updated)
Location: `Sources/Moove/Subscription/SubscriptionManager.swift`
Completely rewritten to use RevenueCat SDK instead of direct StoreKit.

### 3. Package.swift (Updated)
Location: `Package.swift`
Added RevenueCat dependency: `https://github.com/RevenueCat/purchases-ios`

### 4. README Document
Location: `RevenueCat-Setup-README.md`
Detailed setup instructions with verification checklist.

## Testing Instructions

Once you've added your SDK key:

1. **Build the project:**
   ```bash
   cd /Users/chetanchopra/Desktop/WORK/Dev/Moove
   swift package resolve
   ```

2. **Test in simulator:**
   - RevenueCat provides Sandbox mode for testing
   - Test subscription purchase flow
   - Test restore purchases functionality

## Next Steps After Board Completion

Once you provide the SDK key and complete the RevenueCat dashboard setup:

1. ✅ Integration complete - code is ready
2. ✅ Build verification
3. ✅ Testing in Sandbox mode
4. ✅ Ready for App Store submission

## Questions for the Board

1. Have you created the RevenueCat account?
2. Do you have the Public SDK Key ready?
3. Any issues connecting App Store Connect?

Please provide the SDK key when you have it, and I'll update the configuration file.