import StoreKit
import StoreKitTest
import XCTest
@testable import MooveKit
@testable import Moove

/// End-to-end StoreKit-sandbox coverage for `SubscriptionManager`'s StoreKit 2
/// fallback backend (MOO-86). While `RevenueCatConstants.sdkKey` is the
/// committed placeholder, the manager must bypass RevenueCat entirely and run
/// the paywall/trial/restore flow directly against `Resources/Moove.storekit`.
///
/// Each test builds a fresh `SubscriptionManager` (the shared singleton is
/// never touched) after `SKTestSession` has taken ownership of StoreKit, so
/// purchases, renewals, and restore run entirely in the local sandbox.
@MainActor
final class SubscriptionManagerFallbackTests: XCTestCase {

    private var session: SKTestSession!

    override func setUp() async throws {
        try await super.setUp()
        try XCTSkipIf(
            RevenueCatConstants.isConfigured,
            "Real RevenueCat SDK key configured — StoreKit fallback is inactive"
        )
        // Same binding approach as SubscriptionStoreKitTests: the config is
        // registered with the test host via the scheme's TestAction
        // StoreKitConfigurationFileReference.
        let session = try SKTestSession(configurationFileNamed: "Moove")
        session.disableDialogs = true
        session.resetToDefaultState()
        self.session = session
    }

    override func tearDown() async throws {
        session.resetToDefaultState()
        session = nil
        try await super.tearDown()
    }

    /// Builds a fresh manager already configured against the test session.
    private func makeManager() -> SubscriptionManager {
        let manager = SubscriptionManager()
        manager.observeTransactionUpdates()
        return manager
    }

    /// Polls `condition` on the main actor until it returns true or the
    /// timeout elapses. Used for sandbox renewal events that arrive
    /// asynchronously via `Transaction.updates`.
    private func waitUntil(
        timeout: TimeInterval,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTFail("Timed out after \(timeout)s waiting for condition")
    }

    // MARK: - Paywall render path (products + prices load)

    func testFallbackLoadsProductsWithLocalizedPrices() async throws {
        let manager = makeManager()
        await manager.fetchProducts()

        XCTAssertFalse(manager.isLoadingProducts, "Loading flag must clear after fetch")
        XCTAssertEqual(manager.products.count, 2, "StoreKit config should vend monthly + yearly")

        let monthly = try XCTUnwrap(manager.monthlyProduct, "Paywall needs a monthly product")
        let yearly = try XCTUnwrap(manager.yearlyProduct, "Paywall needs a yearly product")
        XCTAssertFalse(monthly.localizedPriceString.isEmpty, "Paywall renders a monthly price")
        XCTAssertFalse(yearly.localizedPriceString.isEmpty, "Paywall renders a yearly price")
        XCTAssertTrue(manager.isEligibleForTrial, "Fresh sandbox account must be trial-eligible")
    }

    // MARK: - Trial start → premium entitlement

    func testFallbackPurchaseStartsTrialAndGrantsPremium() async throws {
        let manager = makeManager()
        await manager.fetchProducts()
        let monthly = try XCTUnwrap(manager.monthlyProduct)

        try await manager.purchase(monthly)

        XCTAssertTrue(manager.isPremium, "Entitlement must flip to premium after trial purchase")
        XCTAssertEqual(manager.subscriptionState, .trial, "Introductory-offer transaction means trial")
        XCTAssertFalse(manager.shouldShowPaywall, "Paywall must dismiss once premium")
        XCTAssertFalse(manager.isEligibleForTrial, "Trial consumption must clear eligibility (anti-bypass)")
    }

    // MARK: - Trial converts to paid on renewal

    func testFallbackTrialConvertsToActiveAfterRenewal() async throws {
        session.timeRate = .oneRenewalEveryTwoSeconds

        let manager = makeManager()
        await manager.fetchProducts()
        let monthly = try XCTUnwrap(manager.monthlyProduct)

        try await manager.purchase(monthly)
        XCTAssertEqual(manager.subscriptionState, .trial)

        // The first auto-renewal ends the introductory period; the renewed
        // transaction carries no offer type, so the state must flip to active.
        try await waitUntil(timeout: 20) {
            manager.subscriptionState == .active
        }
        XCTAssertTrue(manager.isPremium, "Premium must survive the trial → paid conversion")
        XCTAssertFalse(manager.shouldShowPaywall)
    }

    // MARK: - Restore

    func testFallbackRestoreKeepsEntitlement() async throws {
        let purchaser = makeManager()
        await purchaser.fetchProducts()
        let yearly = try XCTUnwrap(purchaser.yearlyProduct)
        try await purchaser.purchase(yearly)
        XCTAssertTrue(purchaser.isPremium)

        // Simulate relaunch/reinstall: a fresh manager restores against the
        // same sandbox account and must recover the entitlement.
        let restored = makeManager()
        await restored.fetchProducts()
        await restored.restorePurchases()

        XCTAssertTrue(restored.isPremium, "Restore must recover the active entitlement")
        XCTAssertEqual(restored.subscriptionState, .trial, "Restored introductory purchase is still in trial")
        XCTAssertFalse(restored.shouldShowPaywall)
        XCTAssertFalse(restored.isEligibleForTrial)
    }

    func testFallbackRestoreWithoutPurchaseShowsPaywall() async throws {
        let manager = makeManager()
        await manager.fetchProducts()
        await manager.restorePurchases()

        XCTAssertFalse(manager.isPremium)
        XCTAssertTrue(manager.shouldShowPaywall, "Nothing to restore → paywall stays up")
        XCTAssertEqual(manager.subscriptionState, .inactive)
    }
}
