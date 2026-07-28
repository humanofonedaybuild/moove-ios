import StoreKit
import StoreKitTest
import XCTest
@testable import MooveKit

/// Exercises the subscription path against Resources/Moove.storekit via
/// SKTestSession: product metadata, 7-day free trial intro offer, purchase,
/// entitlement, and restore behaviour.
final class SubscriptionStoreKitTests: XCTestCase {

    private var session: SKTestSession!

    override func setUp() async throws {
        try await makeSession()
    }

    func testProbeSchemeManagedSession() async throws {
        let products = try await Product.products(for: [Constants.subscriptionProductID])
        print("SKDEBUG scheme-managed count: \(products.count)")
    }

    private func makeSession() async throws {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "Moove", withExtension: "storekit") else {
            XCTFail("Moove.storekit not found in test bundle")
            throw NSError(domain: "Test", code: 1)
        }
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
    }

    override func tearDown() async throws {
        // Guarded: if setUp threw before assigning, force-unwrapping here
        // crashes the whole test process and kills subsequent tests.
        session?.resetToDefaultState()
        session = nil
    }

    func testProductLoadsWithSevenDayFreeTrial() async throws {
        let debug = try await Product.products(for: ["com.moove.alarmclock.debugconsumable"])
        print("SKDEBUG consumable count: \(debug.count)")
        let products = try await Product.products(for: [Constants.subscriptionProductID])
        print("SKDEBUG subscription count: \(products.count)")
        XCTAssertEqual(products.count, 1, "StoreKit config should vend the premium product")

        let product = try XCTUnwrap(products.first)
        let subscription = try XCTUnwrap(product.subscription, "Premium must be an auto-renewable subscription")
        XCTAssertEqual(subscription.subscriptionPeriod.unit, .month)

        let intro = try XCTUnwrap(subscription.introductoryOffer, "Missing introductory trial offer")
        XCTAssertEqual(intro.paymentMode, .freeTrial)
        XCTAssertEqual(intro.period.unit, .week)
        XCTAssertEqual(intro.period.value, 1, "Trial should be 7 days (1 week)")
    }

    func testPurchaseGrantsEntitlement() async throws {
        let products = try await Product.products(for: [Constants.subscriptionProductID])
        let product = try XCTUnwrap(products.first)

        let result = try await product.purchase()
        guard case .success(let verification) = result else {
            XCTFail("Purchase did not succeed: \(result)")
            return
        }

        guard case .verified(let transaction) = verification else {
            XCTFail("Transaction failed verification")
            return
        }
        XCTAssertEqual(transaction.productID, Constants.subscriptionProductID)
        await transaction.finish()

        var foundEntitlement = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let current) = entitlement else { continue }
            if current.productID == Constants.subscriptionProductID {
                foundEntitlement = true
            }
        }
        XCTAssertTrue(foundEntitlement, "Entitlement should be active after purchase")
    }

    func testReinstallDoesNotBypassTrialConsumption() async throws {
        // First "install": purchase consumes the introductory offer.
        let products = try await Product.products(for: [Constants.subscriptionProductID])
        let product = try XCTUnwrap(products.first)
        let result = try await product.purchase()
        guard case .success(let verification) = result,
              case .verified(let transaction) = verification else {
            XCTFail("Initial purchase failed")
            return
        }
        await transaction.finish()

        // Simulate reinstall: reset local state but keep the test Apple ID's
        // purchase history, then confirm the intro offer is no longer
        // available to this account.
        session.clearTransactions()
        let eligible = await product.subscription?.isEligibleForIntroOffer
        XCTAssertEqual(eligible, false, "Trial must not be re-offered after consumption (anti-reinstall-bypass)")
    }
}
