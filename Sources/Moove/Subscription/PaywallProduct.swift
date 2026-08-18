import RevenueCat
import StoreKit

/// A purchasable subscription product, independent of the active backend.
///
/// Wraps either a RevenueCat `StoreProduct` (production, real SDK key) or a
/// StoreKit 2 `Product` (dev fallback using the local `Moove.storekit`
/// configuration), so the paywall renders and purchases identically in both
/// modes.
struct PaywallProduct {
    enum Backing {
        case revenueCat(StoreProduct)
        case storeKit(StoreKit.Product)
        case development(mockPrice: String, productID: String)
    }

    let backing: Backing

    var productIdentifier: String {
        switch backing {
        case .revenueCat(let product): return product.productIdentifier
        case .storeKit(let product): return product.id
        case .development(_, let productID): return productID
        }
    }

    var localizedPriceString: String {
        switch backing {
        case .revenueCat(let product): return product.localizedPriceString
        case .storeKit(let product): return product.displayPrice
        case .development(let mockPrice, _): return mockPrice
        }
    }
}
