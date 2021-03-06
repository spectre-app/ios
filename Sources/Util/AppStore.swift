// =============================================================================
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import StoreKit
import TPInAppReceipt

extension InAppSubscription {
    var isActive: Bool {
        AppStore.shared.products( forSubscription: self, onlyPublic: false ).contains {
            InAppProduct.find( $0.productIdentifier )?.isActive ?? false
        }
    }

    var wasActiveButExpired: Bool {
        AppStore.shared.products( forSubscription: self, onlyPublic: false ).contains {
            InAppProduct.find( $0.productIdentifier )?.wasActiveButExpired ?? false
        }
    }

    var latest: InAppPurchase? {
        AppStore.shared.products( forSubscription: self, onlyPublic: false )
                       .compactMap {
                           AppStore.shared.receipt?.lastAutoRenewableSubscriptionPurchase( ofProductIdentifier: $0.productIdentifier )
                       }
                       .sorted {
                           $0.subscriptionExpirationDate ?? $0.purchaseDate > $1.subscriptionExpirationDate ?? $1.purchaseDate
                       }.first
    }
}

extension InAppProduct {
    var product: SKProduct? {
        AppStore.shared.products.first { $0.productIdentifier == self.productIdentifier }
    }

    var isActive: Bool {
        AppStore.shared.receipt?.purchases( ofProductIdentifier: self.productIdentifier ).contains { purchase in
            !purchase.isRenewableSubscription || purchase.isActiveAutoRenewableSubscription( forDate: Date() )
        } ?? false
    }

    var wasActiveButExpired: Bool {
        guard let receipt = AppStore.shared.receipt
        else { return false }

        var isSubscription = false
        for purchase in receipt.purchases( ofProductIdentifier: self.productIdentifier ) {
            if !purchase.isRenewableSubscription {
                // Product purchased permanently.
                return false
            }

            isSubscription = true
            if purchase.isActiveAutoRenewableSubscription( forDate: Date() ) {
                // Product subscription is active.
                return false
            }
        }

        return isSubscription
    }
}

class AppStore: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, SKStoreProductViewControllerDelegate, Observable {
    public static let shared = AppStore()

    var observers = Observers<InAppStoreObserver>()
    var canBuyProducts: Bool {
        #if PUBLIC
        return SKPaymentQueue.canMakePayments() && !self.products.isEmpty
        #else
        return AppConfig.shared.sandboxStore && SKPaymentQueue.canMakePayments() && !self.products.isEmpty
        #endif
    }
    var products = [ SKProduct ]() {
        didSet {
            if self.products != oldValue {
                self.observers.notify { $0.didChange( store: self, products: self.products ) }
            }
        }
    }
    var receipt: InAppReceipt?

    private var updatePromise: Promise<Bool>?

    override init() {
        super.init()

        SKPaymentQueue.default().add( self )
    }

    @discardableResult
    func update(active: Bool = false) -> Promise<Bool> {
        self.updatePromise ?? using( Promise<Bool>() ) { updatePromise in
            self.updatePromise = updatePromise

            self.updateReceipt( allowRefresh: active ).then { _ in
                if active || self.products.isEmpty {
                    // Passive mode and no receipt: give up for now to avoid undesirable store errors.
                    let productsRequest = SKProductsRequest( productIdentifiers: Set( InAppProduct.allCases.map { $0.productIdentifier } ) )
                    productsRequest.delegate = self
                    productsRequest.start()
                }
            }
        }
    }

    func purchase(product: SKProduct, promotion: SKPaymentDiscount? = nil, quantity: Int = 1) {
        #if !PUBLIC
        guard AppConfig.shared.sandboxStore
        else {
            inf( "Sandbox store disabled, skipping product purchase." )
            return
        }
        #endif

        let payment = SKMutablePayment( product: product )
        payment.paymentDiscount = promotion
        payment.quantity = quantity

        SKPaymentQueue.default().add( payment )
    }

    func restorePurchases() {
        #if !PUBLIC
        guard AppConfig.shared.sandboxStore
        else {
            inf( "Sandbox store disabled, skipping purchase restoration." )
            return
        }
        #endif
        guard self.canBuyProducts
        else {
            wrn( "In-app purchases disabled, skipping purchase restoration." )
            return
        }

        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    func isUpToDate(appleID: Int? = nil, buildVersion: String? = nil)
                    -> Promise<(upToDate: Bool, buildVersion: String, storeVersion: String)> {
        guard let urlSession = URLSession.required.get()
        else { return Promise( .failure( AppError.state( title: "App is in offline mode" ) ) ) }

        var countryCode2 = "US"
        if #available( iOS 13.0, * ) {
            if let countryCode3 = SKPaymentQueue.default().storefront?.countryCode {
                countryCode2 = self.countryCode3to2[countryCode3] ?? countryCode2
            }
        }
        let searchURLString = "https://itunes.apple.com/lookup?id=\(appleID ?? productAppleID)&country=\(countryCode2)&limit=1"
        guard let searchURL = URL( string: searchURLString )
        else { return Promise( .failure( AppError.internal( cause: "Couldn't resolve store URL", details: searchURLString ) ) ) }

        return urlSession.promise( with: URLRequest( url: searchURL ) ).promise {
            let json = try JSONSerialization.jsonObject( with: $0.data ) as? [String: Any]
            if let error = json?["errorMessage"] as? String {
                throw AppError.issue( title: "iTunes store lookup issue", details: error )
            }
            guard let metadata = ((json?["results"] as? [Any])?.first as? [String: Any])
            else { throw AppError.state( title: "Missing iTunes application metadata" ) }
            guard let storeVersion = metadata["version"] as? String
            else { throw AppError.state( title: "Missing version in iTunes metadata" ) }

            let buildVersion = buildVersion ?? productVersion
            return (upToDate: !buildVersion.isVersionOutdated( by: storeVersion ),
                    buildVersion: buildVersion, storeVersion: storeVersion)
        }
    }

    func presentStore(appleID: Int? = nil, in viewController: UIViewController) {
        let storeController = SKStoreProductViewController()
        storeController.delegate = self
        storeController.loadProduct( withParameters: [
            SKStoreProductParameterITunesItemIdentifier: appleID ?? productAppleID,
        ] ) { success, error in
            if !success || error != nil {
                wrn( "Couldn't load store controller. [>PII]" )
                pii( "[>] Error: %@", error )
            }
        }
        viewController.present( storeController, animated: true )
    }

    // MARK: - Private

    private let countryCode3to2 // swiftlint:disable:next line_length
            = [ "AFG": "AF", "ALB": "AL", "DZA": "DZ", "AND": "AD", "AGO": "AO", "AIA": "AI", "ATG": "AG", "ARG": "AR", "ARM": "AM", "AUS": "AU", "AUT": "AT", "AZE": "AZ", "BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB", "BLR": "BY", "BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BMU": "BM", "BTN": "BT", "BOL": "BO", "BIH": "BA", "BWA": "BW", "BRA": "BR", "BRN": "BN", "BGR": "BG", "BFA": "BF", "KHM": "KH", "CMR": "CM", "CAN": "CA", "CPV": "CV", "CYM": "KY", "CAF": "CF", "TCD": "TD", "CHL": "CL", "CHN": "CN", "COL": "CO", "COG": "CG", "COD": "CD", "CRI": "CR", "CIV": "CI", "HRV": "HR", "CYP": "CY", "CZE": "CZ", "DNK": "DK", "DMA": "DM", "DOM": "DO", "ECU": "EC", "EGY": "EG", "SLV": "SV", "EST": "EE", "ETH": "ET", "FJI": "FJ", "FIN": "FI", "FRA": "FR", "GAB": "GA", "GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH", "GRC": "GR", "GRD": "GD", "GTM": "GT", "GIN": "GN", "GNB": "GW", "GUY": "GY", "HND": "HN", "HKG": "HK", "HUN": "HU", "ISL": "IS", "IND": "IN", "IDN": "ID", "IRQ": "IQ", "IRL": "IE", "ISR": "IL", "ITA": "IT", "JAM": "JM", "JPN": "JP", "JOR": "JO", "KAZ": "KZ", "KEN": "KE", "KOR": "KR", "KWT": "KW", "KGZ": "KG", "LAO": "LA", "LVA": "LV", "LBN": "LB", "LBR": "LR", "LBY": "LY", "LIE": "LI", "LTU": "LT", "LUX": "LU", "MAC": "MO", "MKD": "MK", "MDG": "MG", "MWI": "MW", "MYS": "MY", "MDV": "MV", "MLI": "ML", "MLT": "MT", "MRT": "MR", "MUS": "MU", "MEX": "MX", "FSM": "FM", "MDA": "MD", "MCO": "MC", "MNG": "MN", "MNE": "ME", "MSR": "MS", "MAR": "MA", "MOZ": "MZ", "MMR": "MM", "NAM": "NA", "NRU": "NR", "NPL": "NP", "NLD": "NL", "NZL": "NZ", "NIC": "NI", "NER": "NE", "NGA": "NG", "NOR": "NO", "OMN": "OM", "PAK": "PK", "PLW": "PW", "PSE": "PS", "PAN": "PA", "PNG": "PG", "PRY": "PY", "PER": "PE", "PHL": "PH", "POL": "PL", "PRT": "PT", "QAT": "QA", "ROU": "RO", "RUS": "RU", "RWA": "RW", "KNA": "KN", "LCA": "LC", "VCT": "VC", "WSM": "WS", "STP": "ST", "SAU": "SA", "SEN": "SN", "SRB": "RS", "SYC": "SC", "SLE": "SL", "SGP": "SG", "SVK": "SK", "SVN": "SI", "SLB": "SB", "ZAF": "ZA", "ESP": "ES", "LKA": "LK", "SUR": "SR", "SWZ": "SZ", "SWE": "SE", "CHE": "CH", "TWN": "TW", "TJK": "TJ", "TZA": "TZ", "THA": "TH", "TON": "TO", "TTO": "TT", "TUN": "TN", "TUR": "TR", "TKM": "TM", "TCA": "TC", "UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB", "USA": "US", "URY": "UY", "UZB": "UZ", "VUT": "VU", "VEN": "VE", "VNM": "VN", "VGB": "VG", "YEM": "YE", "ZMB": "ZM", "ZWE": "ZW" ]

    func products(forSubscription subscription: InAppSubscription, onlyPublic: Bool = true) -> [SKProduct] {
        self.products.filter { $0.subscriptionGroupIdentifier == subscription.subscriptionGroupIdentifier }
                     .filter { !onlyPublic || InAppProduct.find( $0.productIdentifier )?.isPublic ?? false }
    }

    private func refreshReceipt() -> Promise<InAppReceipt?> {
        using( Promise<InAppReceipt?>() ) { promise in
            #if !PUBLIC
            if !AppConfig.shared.sandboxStore {
                inf( "Sandbox store disabled, skipping receipt refresh." )
                self.updateReceipt( allowRefresh: false ).finishes( promise )
                return
            }
            #endif

            InAppReceipt.refresh { error in
                if let error = error {
                    promise.finish( .failure( error ) )
                    return
                }

                self.updateReceipt( allowRefresh: false ).finishes( promise )
            }
        }
    }

    @discardableResult
    private func updateReceipt(allowRefresh: Bool = true) -> Promise<InAppReceipt?> {
        using( Promise<InAppReceipt?>() ) { promise in
            // Decode and validate the application's App Store receipt.
            do {
                let receipt = try InAppReceipt.localReceipt()
                try receipt.verify()
                self.receipt = receipt
            }
            catch {
                wrn( "App Store receipt unavailable. [>PII]" )
                pii( "[>] Error: %@", error )
                self.receipt = nil
            }

            #if !PUBLIC
            if !AppConfig.shared.sandboxStore {
                inf( "Sandbox store disabled, skipping receipt parsing." )
                promise.finish( .success( self.receipt ) )
                return
            }
            #endif

            // If no (valid) App Store receipt is present, try requesting one from the store.
            if self.receipt == nil {
                if allowRefresh {
                    inf( "No receipt, requesting one." )
                    self.refreshReceipt().finishes( promise )
                    return
                }

                wrn( "Couldn't obtain a receipt." )
            }

            // Discover feature status based on which subscription products are currently active.
            var missingFeatures    = Set<InAppFeature>( InAppFeature.allCases )
            var subscribedFeatures = Set<InAppFeature>()
            for product in InAppProduct.allCases {
                if !product.isActive {
                    if allowRefresh && product.wasActiveButExpired {
                        inf( "Subscription expired, checking for renewal." )
                        self.refreshReceipt().finishes( promise )
                        return
                    }
                    continue
                }

                inf( "Active purchase: %@", product )
                missingFeatures.subtract( product.features )
                subscribedFeatures.formUnion( product.features )
            }

            // Enable features with an active subscription and disable those missing one.
            missingFeatures.forEach { $0.enable( false ) }
            subscribedFeatures.forEach { $0.enable( true ) }

            promise.finish( .success( self.receipt ) )
        }
    }

    // MARK: - SKStoreProductViewControllerDelegate

    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss( animated: true )
    }

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            inf( "Product: %@, is %@", transaction.payment.productIdentifier, transaction.transactionState )

            switch transaction.transactionState {
                case .purchasing, .deferred:
                    ()

                case .purchased, .restored:
                    self.updateReceipt().then {
                        do {
                            guard let receipt = try $0.get()
                            else { throw AppError.state( title: "Receipt missing" ) }

                            let originalIdentifier = transaction.original?.transactionIdentifier ?? transaction.transactionIdentifier
                            if !receipt.purchases.contains( where: { $0.originalTransactionIdentifier == originalIdentifier } ) {
                                mperror( title: "App Store transaction missing", message:
                                "Ensure you are online and try logging out and back into your Apple ID from Settings.",
                                         error: AppError.state( title: "Transaction is missing from receipt",
                                                                details: originalIdentifier ) )
                            }

                            queue.finishTransaction( transaction )
                        }
                        catch {
                            mperror( title: "App Store receipt unavailable", message:
                            "Ensure you are online and try logging out and back into your Apple ID from Settings.",
                                     error: error )
                        }
                    }

                case .failed:
                    mperror( title: "App Store transaction issue", message:
                    "Ensure you are online and try logging out and back into your Apple ID from Settings.",
                             error: transaction.error )
                    queue.finishTransaction( transaction )

                @unknown default:
                    ()
            }
        }
    }

    // MARK: - SKProductsRequestDelegate

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !response.invalidProductIdentifiers.isEmpty {
            inf( "Unsupported products: %@", response.invalidProductIdentifiers )
        }

        self.products = response.products
    }

    // MARK: - SKRequestDelegate

    func requestDidFinish(_ request: SKRequest) {
        self.updatePromise?.finish( .success( true ) )
        self.updatePromise = nil
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        mperror( title: "App Store request issue", message:
        "Ensure you are online and try logging out and back into your Apple ID from Settings.",
                 error: error )
        self.updatePromise?.finish( .success( false ) )
        self.updatePromise = nil
    }
}

protocol InAppStoreObserver {
    func didChange(store: AppStore, products: [SKProduct])
}
