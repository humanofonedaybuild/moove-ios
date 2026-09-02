import StoreKit
import StoreKitTest
import XCTest
@testable import MooveKit
@testable import Moove

/// Exercises the full StoreKit 2 subscription lifecycle against
/// `Resources/Moove.storekit` via `SKTestSession` (MOO-75 checklist).
///
/// The session is created from the `.storekit` file bundled into the test
/// target (project.yml → MooveTests.sources) and takes ownership of StoreKit
/// before any product calls. The app's `SubscriptionManager` is disabled
/// during tests via the `-DisableStoreKitInit` launch argument (project.yml →
/// schemes.Moove.test.commandLineArguments) so it cannot race the session.
///
/// Product identifiers live in `RevenueCatConstants` (RevenueCat wraps
/// StoreKit, so the `.storekit` config remains the source of truth for
/// product definitions, introductory offers, and trial consumption).
///
/// Environment note (MOO-86): the `.storekit` config must keep its
/// `_bundleId: com.moove.alarmclock` field — without it storekitd cannot
/// bind the config to the test host and `Product.products(for:)` returns
/// zero products via `xcodebuild`. With `_bundleId` present this suite runs
/// green from both `xcodebuild` and the Xcode IDE.
final class SubscriptionStoreKitTests: XCTestCase {

    private var session: SKTestSession?

    /// StoreKit 2 verifies transaction JWT signatures on-device. This local
    /// helper unwraps a `VerificationResult`, throwing for any payload that
    /// fails Apple's signature check. (The app's `SubscriptionManager` no
    /// longer exposes this since RevenueCat owns verification; the StoreKit
    /// config tests still need it to inspect raw transactions.)
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw SubscriptionError.unknown
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        // Bind StoreKit to the local `Resources/Moove.storekit` config bundled
        // into the test target (project.yml → MooveTests sources). We prefer
        // the direct `contentsOf:` init because it does not depend on the
        // scheme's TestAction StoreKitConfigurationFileReference being
        // honored by `xcodebuild test` (which is unreliable across Xcode
        // versions). If `contentsOf:` fails (storekitd returns
        // SKInternalErrorDomain Code=3 on some iOS simruntime builds when the
        // config is not pre-registered), fall back to the scheme-managed
        // `configurationFileNamed:` init.
        let bundle = Bundle(for: type(of: self))
        let configURL = try XCTUnwrap(
            bundle.url(forResource: "Moove", withExtension: "storekit"),
            "Moove.storekit must be bundled into the test target"
        )
        let session: SKTestSession
        do {
            session = try SKTestSession(contentsOf: configURL)
        } catch {
            print("SKTestSession contentsOf: failed (\(error)); falling back to configurationFileNamed:")
            session = try SKTestSession(configurationFileNamed: "Moove")
        }
        session.disableDialogs = true
        session.resetToDefaultState()
        self.session = session

        // Session-health probe: on some sim runtimes storekitd accepts the
        // session object but rejects every operation (SKInternalErrorDomain
        // Code=3), leaving Product.products empty. Skip loudly instead of
        // reporting false product regressions.
        try await SubscriptionManagerFallbackTests.skipIfSessionUnavailable(session)
    }

    override func tearDown() async throws {
        session?.resetToDefaultState()
        session = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Polls `Transaction.currentEntitlements` until the given product is
    /// present/absent or the timeout elapses. Expiry, refund, and
    /// billing-retry transitions are applied asynchronously by storekitd, so
    /// tests must poll rather than assert immediately.
    private func waitForEntitlement(
        productID: String,
        present: Bool,
        timeout: TimeInterval = 10
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var found = false
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let transaction) = entitlement,
                   transaction.productID == productID {
                    found = true
                }
            }
            if found == present { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    private func loadMonthlyProduct(
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> Product {
        let products = try await Product.products(for: RevenueCatConstants.subscriptionProductIDs)
        return try XCTUnwrap(
            products.first { $0.id == RevenueCatConstants.monthlyProductID },
            "Monthly product missing from StoreKit config",
            file: file,
            line: line
        )
    }

    // MARK: - 1. Products load from the .storekit config

    /// Probe: the scheme-managed session is alive, bound to the expected
    /// storefront, and a products query round-trips without throwing.
    func testProbeSchemeManagedSession() async throws {
        let session = try XCTUnwrap(self.session, "SKTestSession must be created in setUp")
        XCTAssertTrue(session.disableDialogs, "Test session must suppress purchase dialogs")
        XCTAssertEqual(session.storefront, "USA", "Config storefront should default to USA")

        // The query must complete without throwing; the product count is
        // asserted strictly by testProductLoadsWithSevenDayFreeTrial.
        let products = try await Product.products(for: RevenueCatConstants.subscriptionProductIDs)
        XCTAssertEqual(
            products.count, 2,
            "StoreKit config should vend monthly + yearly products (got \(products.map(\.id)))"
        )
    }

    /// Products load with correct metadata: auto-renewable, correct periods,
    /// and a 7-day (1-week) free introductory offer on both plans.
    func testProductLoadsWithSevenDayFreeTrial() async throws {
        let products = try await Product.products(for: RevenueCatConstants.subscriptionProductIDs)
        XCTAssertEqual(products.count, 2, "StoreKit config should vend monthly + yearly products")

        let monthly = try XCTUnwrap(products.first { $0.id == RevenueCatConstants.monthlyProductID })
        let monthlySub = try XCTUnwrap(monthly.subscription, "Monthly must be an auto-renewable subscription")
        XCTAssertEqual(monthlySub.subscriptionPeriod.unit, .month)
        let monthlyIntro = try XCTUnwrap(monthlySub.introductoryOffer, "Missing monthly trial offer")
        XCTAssertEqual(monthlyIntro.paymentMode, .freeTrial)
        XCTAssertEqual(monthlyIntro.period.unit, .week)
        XCTAssertEqual(monthlyIntro.period.value, 1, "Monthly trial should be 7 days (1 week)")

        let yearly = try XCTUnwrap(products.first { $0.id == RevenueCatConstants.yearlyProductID })
        let yearlySub = try XCTUnwrap(yearly.subscription, "Yearly must be an auto-renewable subscription")
        XCTAssertEqual(yearlySub.subscriptionPeriod.unit, .year)
        let yearlyIntro = try XCTUnwrap(yearlySub.introductoryOffer, "Missing yearly trial offer")
        XCTAssertEqual(yearlyIntro.paymentMode, .freeTrial)
        XCTAssertEqual(yearlyIntro.period.unit, .week)
        XCTAssertEqual(yearlyIntro.period.value, 1, "Yearly trial should be 7 days (1 week)")
    }

    // MARK: - 2. Trial eligibility

    /// A fresh account is offered the free trial on both plans.
    func testFirstPurchaseIsEligibleForTrial() async throws {
        let products = try await Product.products(for: RevenueCatConstants.subscriptionProductIDs)
        XCTAssertEqual(products.count, 2)

        for product in products {
            let eligible = await product.subscription?.isEligibleForIntroOffer
            XCTAssertEqual(
                eligible, true,
                "First purchase of \(product.id) must offer the 7-day free trial"
            )
        }
    }

    /// After the trial is consumed, wiping local state (reinstall) must NOT
    /// re-offer it — eligibility is tracked per Apple account in the
    /// subscription group.
    func testReinstallDoesNotBypassTrialConsumption() async throws {
        // First "install": purchase consumes the introductory offer.
        let products = try await Product.products(for: RevenueCatConstants.subscriptionProductIDs)
        let product = try XCTUnwrap(products.first { $0.id == RevenueCatConstants.yearlyProductID })
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Initial purchase failed")
            return
        }
        let transaction = try checkVerified(verification)
        await transaction.finish()

        // Simulate reinstall: reset local state but keep the test Apple ID's
        // purchase history, then confirm the intro offer is no longer
        // available to this account.
        session?.clearTransactions()
        let eligible = await product.subscription?.isEligibleForIntroOffer
        XCTAssertEqual(eligible, false, "Trial must not be re-offered after consumption (anti-reinstall-bypass)")
    }

    // MARK: - 3. Purchase flow

    /// Complete purchase flow: purchase succeeds, the transaction verifies,
    /// and the entitlement becomes active.
    func testPurchaseGrantsEntitlement() async throws {
        let product = try await loadMonthlyProduct()

        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase did not succeed: \(result)")
            return
        }

        let transaction = try checkVerified(verification)
        XCTAssertEqual(transaction.productID, RevenueCatConstants.monthlyProductID)
        await transaction.finish()

        let entitled = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: true
        )
        XCTAssertTrue(entitled, "Entitlement should be active after purchase")
    }

    // MARK: - 4. Restore purchases

    /// Restore Purchases after a reinstall reinstates entitlements:
    /// `AppStore.sync()` re-pulls the account's transactions from the
    /// (test) store even after local state is wiped.
    func testRestorePurchasesReinstatesEntitlements() async throws {
        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase failed: \(result)")
            return
        }
        let transaction = try checkVerified(verification)
        await transaction.finish()

        // Simulate reinstall: local transaction state is wiped.
        session?.clearTransactions()

        // Restore Purchases button path.
        try await AppStore.sync()

        let restored = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: true
        )
        XCTAssertTrue(restored, "Restore Purchases must reinstate the entitlement after reinstall")
    }

    // MARK: - 5. Cancellation / expiry

    /// Cancelling a subscription (disable auto-renew) followed by expiry
    /// removes the entitlement — the paywall gate must re-engage.
    func testExpiredSubscriptionRemovesEntitlement() async throws {
        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase failed: \(result)")
            return
        }
        let transaction = try checkVerified(verification)
        await transaction.finish()

        let initiallyEntitled = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: true
        )
        XCTAssertTrue(initiallyEntitled, "Entitlement should be active immediately after purchase")

        // User cancels in App Store settings → subscription expires.
        // The Obj-C BOOL+NSError bridge throws on failure, so `try` asserts success.
        try session?.expireSubscription(
            productIdentifier: RevenueCatConstants.monthlyProductID
        )

        let removed = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: false
        )
        XCTAssertTrue(removed, "Entitlement must be removed after the subscription expires")
    }

    // MARK: - 6. Billing issue → grace period

    /// With billing-retry-on-renewal and a grace period enabled, a failed
    /// renewal keeps the entitlement active for the grace window.
    func testBillingGracePeriodMaintainsEntitlement() async throws {
        let session = try XCTUnwrap(self.session)
        session.shouldEnterBillingRetryOnRenewal = true
        session.billingGracePeriodIsEnabled = true

        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase failed: \(result)")
            return
        }
        let transaction = try checkVerified(verification)
        await transaction.finish()

        // Renewal attempt fails (billing issue) and enters billing retry.
        // Throws on failure, so `try` asserts the renewal was triggered.
        try session.forceRenewalOfSubscription(
            productIdentifier: RevenueCatConstants.monthlyProductID
        )

        // The test transaction should report a purchase issue…
        let issueLogged = await waitForPurchaseIssue(
            productID: RevenueCatConstants.monthlyProductID,
            timeout: 10
        )
        XCTAssertTrue(issueLogged, "Renewal with billing retry enabled should enter the billing-issue state")

        // …but the grace period keeps the entitlement alive.
        let stillEntitled = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: true
        )
        XCTAssertTrue(stillEntitled, "Grace period must maintain the entitlement during billing retry")
    }

    /// Polls the test session's transaction list until the product's latest
    /// transaction reports a purchase issue (billing retry).
    private func waitForPurchaseIssue(productID: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let transactions = session?.allTransactions() ?? []
            if transactions.contains(where: {
                $0.productIdentifier == productID && $0.hasPurchaseIssue
            }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    // MARK: - 7. Refund

    /// Refunding the purchase revokes the entitlement.
    func testRefundSimulationDeletesTransaction() async throws {
        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase failed: \(result)")
            return
        }
        let transaction = try checkVerified(verification)
        await transaction.finish()

        let entitledBeforeRefund = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: true
        )
        XCTAssertTrue(entitledBeforeRefund, "Entitlement should be active before refund")

        let testTransaction = try XCTUnwrap(
            session?.allTransactions().first {
                $0.productIdentifier == RevenueCatConstants.monthlyProductID
            },
            "Test session should list the purchase"
        )
        // Throws on failure, so `try` asserts the refund was applied.
        try session?.refundTransaction(identifier: testTransaction.identifier)

        let revoked = await waitForEntitlement(
            productID: RevenueCatConstants.monthlyProductID,
            present: false
        )
        XCTAssertTrue(revoked, "Refund must revoke the entitlement")
    }

    // MARK: - 8. Pending state (Ask to Buy / network-deferred approval)

    /// With Ask to Buy enabled the purchase defers to `.pending` until the
    /// guardian approves — the app must treat this as neither success nor
    /// failure.
    func testPendingStateOnAskToBuyEnabled() async throws {
        let session = try XCTUnwrap(self.session)
        session.askToBuyEnabled = true

        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()

        guard case .pending = result else {
            XCTFail("Ask to Buy purchase should return .pending, got \(result)")
            return
        }

        // No entitlement may be granted while the purchase is pending.
        var found = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == RevenueCatConstants.monthlyProductID {
                found = true
            }
        }
        XCTAssertFalse(found, "Pending purchase must not grant the entitlement")

        // Clean up: decline the pending Ask to Buy request.
        if let pending = session.allTransactions().first(where: {
            $0.productIdentifier == RevenueCatConstants.monthlyProductID
        }) {
            try? session.declineAskToBuyTransaction(identifier: pending.identifier)
        }
    }

    // MARK: - 9. User cancellation

    /// With dialogs disabled the StoreKit Testing harness auto-approves every
    /// purchase, so `.userCancelled` is unreachable from code — asserting
    /// that documents the harness behavior. The real cancellation path
    /// (payment sheet → Cancel) requires dialogs enabled and is covered by
    /// manual testing in the Xcode IDE (see MOO-75 findings).
    func testUserCancelledIsNotReachedWithDialogsDisabled() async throws {
        let session = try XCTUnwrap(self.session)
        XCTAssertTrue(session.disableDialogs, "setUp must disable dialogs")

        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()

        if case .userCancelled = result {
            XCTFail("Purchase must not be auto-cancelled when dialogs are disabled")
            return
        }
        guard case .success(let verification) = result else {
            XCTFail("Expected auto-approved purchase to succeed, got \(result)")
            return
        }
        let transaction = try checkVerified(verification)
        await transaction.finish()
    }

    // MARK: - 10. Fast-forward renewal → Transaction.updates

    /// Fast-forwarding a renewal delivers the new transaction through the
    /// `Transaction.updates` stream — the same stream the app's
    /// `SubscriptionManager` observes for out-of-band renewals.
    func testFastForwardRenewalUpdatesTransactionStream() async throws {
        let product = try await loadMonthlyProduct()
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase failed: \(result)")
            return
        }
        let purchaseTransaction = try checkVerified(verification)
        await purchaseTransaction.finish()

        // Force an immediate renewal and wait for it on the updates stream.
        // Throws on failure, so `try` asserts the renewal was triggered.
        try session?.forceRenewalOfSubscription(
            productIdentifier: RevenueCatConstants.monthlyProductID
        )

        let renewalTransaction = try await withThrowingTaskGroup(
            of: StoreKit.Transaction?.self
        ) { group in
            group.addTask {
                for await update in Transaction.updates {
                    guard case .verified(let transaction) = update else { continue }
                    guard transaction.productID == RevenueCatConstants.monthlyProductID,
                          transaction.id != purchaseTransaction.id else { continue }
                    await transaction.finish()
                    return transaction
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }

        let transaction = try XCTUnwrap(
            renewalTransaction,
            "Transaction.updates must deliver the fast-forwarded renewal"
        )
        XCTAssertEqual(transaction.productID, RevenueCatConstants.monthlyProductID)
        XCTAssertNotEqual(transaction.id, purchaseTransaction.id, "Renewal must be a new transaction")
    }
}
