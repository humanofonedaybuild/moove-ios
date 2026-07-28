import StoreKit
import StoreKitTest
import XCTest
@testable import MooveKit
@testable import Moove

/// Exercises the subscription path against Resources/Moove.storekit via
/// `SKTestSession`. The session is created from the `.storekit` file bundled
/// into the test target (project.yml → MooveTests.sources) and takes
/// ownership of StoreKit before any product calls. The app's
/// `SubscriptionManager` is disabled during tests via the
/// `-DisableStoreKitInit` launch argument (project.yml →
/// schemes.Moove.test.commandLineArguments) so it cannot race the session.
final class SubscriptionStoreKitTests: XCTestCase {

    private var session: SKTestSession?

    override func setUp() async throws {
        try await super.setUp()
        let testBundle = Bundle(for: Self.self)
        guard let url = testBundle.url(forResource: "Moove", withExtension: "storekit") else {
            XCTFail("Moove.storekit not found in test bundle")
            throw NSError(domain: "Test", code: 1)
        }
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.resetToDefaultState()
        self.session = session
    }

    override func tearDown() async throws {
        session?.resetToDefaultState()
        session = nil
        try await super.tearDown()
    }

    func testProductsLoadWithSevenDayFreeTrial() async throws {
        let products = try await Product.products(for: Constants.subscriptionProductIDs)
        XCTAssertEqual(products.count, 2, "StoreKit config should vend monthly + yearly products")

        let monthly = try XCTUnwrap(products.first { $0.id == Constants.monthlyProductID })
        let monthlySub = try XCTUnwrap(monthly.subscription, "Monthly must be an auto-renewable subscription")
        XCTAssertEqual(monthlySub.subscriptionPeriod.unit, .month)
        let monthlyIntro = try XCTUnwrap(monthlySub.introductoryOffer, "Missing monthly trial offer")
        XCTAssertEqual(monthlyIntro.paymentMode, .freeTrial)
        XCTAssertEqual(monthlyIntro.period.unit, .week)
        XCTAssertEqual(monthlyIntro.period.value, 1, "Monthly trial should be 7 days (1 week)")

        let yearly = try XCTUnwrap(products.first { $0.id == Constants.yearlyProductID })
        let yearlySub = try XCTUnwrap(yearly.subscription, "Yearly must be an auto-renewable subscription")
        XCTAssertEqual(yearlySub.subscriptionPeriod.unit, .year)
        let yearlyIntro = try XCTUnwrap(yearlySub.introductoryOffer, "Missing yearly trial offer")
        XCTAssertEqual(yearlyIntro.paymentMode, .freeTrial)
        XCTAssertEqual(yearlyIntro.period.unit, .week)
        XCTAssertEqual(yearlyIntro.period.value, 1, "Yearly trial should be 7 days (1 week)")
    }

    func testPurchaseGrantsEntitlement() async throws {
        let products = try await Product.products(for: Constants.subscriptionProductIDs)
        let product = try XCTUnwrap(products.first { $0.id == Constants.monthlyProductID })

        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase did not succeed: \(result)")
            return
        }

        let transaction = try SubscriptionManager.checkVerified(verification)
        XCTAssertEqual(transaction.productID, Constants.monthlyProductID)
        await transaction.finish()

        var foundEntitlement = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let current) = entitlement else { continue }
            if current.productID == Constants.monthlyProductID {
                foundEntitlement = true
            }
        }
        XCTAssertTrue(foundEntitlement, "Entitlement should be active after purchase")
    }

    func testCheckVerifiedUnwrapsVerifiedTransactions() async throws {
        // The verified path is exercised through a real purchase; the unverified
        // branch cannot be synthesised in-process because Transaction has no
        // public initializer. We assert here that checkVerified accepts the
        // verified payload without throwing.
        let products = try await Product.products(for: Constants.subscriptionProductIDs)
        let product = try XCTUnwrap(products.first { $0.id == Constants.monthlyProductID })
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase did not succeed")
            return
        }
        let transaction = try SubscriptionManager.checkVerified(verification)
        XCTAssertEqual(transaction.productID, Constants.monthlyProductID)
        await transaction.finish()
    }

    func testReinstallDoesNotBypassTrialConsumption() async throws {
        // First "install": purchase consumes the introductory offer.
        let products = try await Product.products(for: Constants.subscriptionProductIDs)
        let product = try XCTUnwrap(products.first { $0.id == Constants.yearlyProductID })
        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Initial purchase failed")
            return
        }
        let transaction = try SubscriptionManager.checkVerified(verification)
        await transaction.finish()

        // Simulate reinstall: reset local state but keep the test Apple ID's
        // purchase history, then confirm the intro offer is no longer
        // available to this account.
        session?.clearTransactions()
        let eligible = await product.subscription?.isEligibleForIntroOffer
        XCTAssertEqual(eligible, false, "Trial must not be re-offered after consumption (anti-reinstall-bypass)")
    }
}
