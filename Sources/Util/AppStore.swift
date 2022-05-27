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
    var allProducts: [SKProduct] {
        AppStore.shared.products.filter { $0.subscriptionGroupIdentifier == self.subscriptionGroupIdentifier }
    }

    var publicProducts: [SKProduct] {
        self.allProducts.filter { InAppProduct.find( $0.productIdentifier )?.isPublic ?? false }

    }

    var isActive: Bool {
        self.allProducts.contains {
            InAppProduct.find( $0.productIdentifier )?.isActive ?? false
        }
    }

    var wasActiveButExpired: Bool {
        self.allProducts.contains {
            InAppProduct.find( $0.productIdentifier )?.wasActiveButExpired ?? false
        }
    }

    var latest: InAppPurchase? {
        self.allProducts
                .compactMap {
                    AppStore.shared.receipt?.lastAutoRenewableSubscriptionPurchase( ofProductIdentifier: $0.productIdentifier )
                }
                .sorted {
                    $0.subscriptionExpirationDate ?? $0.purchaseDate > $1.subscriptionExpirationDate ?? $1.purchaseDate
                }
                .first
    }
}

extension InAppProduct {
    var product: SKProduct? {
        AppStore.shared.products.first { $0.productIdentifier == self.productIdentifier }
    }

    var isActive: Bool {
        if case .legacyMasterPassword = self, AppConfig.shared.masterPasswordCustomer { // swiftlint:disable:this inclusive_language
            return true
        }
        #if !PUBLIC
        if case .premiumMonthly = self, AppConfig.shared.testingPremium {
            return true
        }
        else if !AppConfig.shared.sandboxStore {
            return false
        }
        #endif

        return AppStore.shared.receipt?.purchases( ofProductIdentifier: self.productIdentifier ).contains { purchase in
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

class AppStore: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, SKStoreProductViewControllerDelegate, Observable, AppConfigObserver {
    public static let shared = AppStore()

    let observers = Observers<InAppStoreObserver>()
    var canBuyProducts: Bool {
        #if PUBLIC
        return SKPaymentQueue.canMakePayments() && !self.products.isEmpty
        #else
        return AppConfig.shared.sandboxStore && SKPaymentQueue.canMakePayments() && !self.products.isEmpty
        #endif
    }
    var country: Promise<String?> {
        if let countryCode = SKPaymentQueue.default().storefront?.countryCode {
            return Promise( .success( countryCode3to2?[countryCode] ) )
        }

        if #available(iOS 15, *) {
            return Promise { await Storefront.current?.countryCode }
        }

        return Promise(.success(nil))
    }
    var products = [ SKProduct ]() {
        didSet {
            if self.products != oldValue {
                self.observers.notify { $0.didChange( store: self, products: self.products ) }
            }

            Tracker.shared.event( track: .subject( "appstore", action: "status", [
                "payments": SKPaymentQueue.canMakePayments(),
                "products": self.products.count,
            ] ) )
        }
    }
    var receipt: InAppReceipt?

    private var updatePromise: Promise<Bool>?
    private var purchaseEvent: Tracker.TimedEvent?
    private var restoreEvent:  Tracker.TimedEvent?

    override init() {
        super.init()

        SKPaymentQueue.default().add( self )
        AppConfig.shared.observers.register( observer: self )
    }

    @discardableResult
    func update(active: Bool = false) -> Promise<Bool> {
        self.updatePromise ?? using( Promise<Bool>() ) { updatePromise in
            self.updatePromise = updatePromise

            self.updateReceipt( allowRefresh: active ).then { _ in
                if active || self.products.isEmpty {
                    let productsRequest = SKProductsRequest( productIdentifiers: Set( InAppProduct.allCases.map { $0.productIdentifier } ) )
                    productsRequest.delegate = self
                    productsRequest.start()
                }
                else {
                    self.updatePromise?.finish( .success( true ) )
                }
            }
        }
            .finally {
                self.updatePromise = nil
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

        self.purchaseEvent = Tracker.shared.begin( track: .subject( "appstore", action: "purchase", [
            "product": product.productIdentifier,
            "promotion": promotion?.identifier,
            "quantity": quantity,
        ] ) )

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

        self.restoreEvent = Tracker.shared.begin( track: .subject( "appstore", action: "restore" ) )

        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    func isUpToDate(appleID: Int? = nil, buildVersion: String? = nil)
            -> Promise<(upToDate: Bool, buildVersion: String, storeVersion: String)> {
        guard let urlSession = URLSession.required.get()
        else { return Promise( .failure( AppError.state( title: "App is in offline mode" ) ) ) }

        return self.country
            .promise { "https://itunes.apple.com/lookup?id=\(appleID ?? productAppleID)&country=\($0 ?? "US")&limit=1" }
            .promising { (url: String?) -> Promise<(data: Data, response: URLResponse)> in
                guard let url = url, let searchURL = URL( string: url ) else {
                    throw AppError.internal( cause: "Couldn't resolve store URL", details: url )
                }

                return urlSession.promise( with: URLRequest( url: searchURL ) )
            }
            .promise {
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
                wrn( "Couldn't load store controller: %@ [>PII]", error?.localizedDescription )
                pii( "[>] Error: %@", error )
            }
        }
        viewController.present( storeController, animated: true )
    }

    func presentCodeRedemption() {
        if #available( iOS 14.0, * ) {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
    }

    // MARK: - Private

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
                try receipt.validate()
                self.receipt = receipt
            }
            catch {
                wrn( "App Store receipt unavailable: %@ [>PII]", error.localizedDescription )
                pii( "[>] Error: %@", error )
                self.receipt = nil
            }

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
                if !product.isActive, product.isInStore {
                    if allowRefresh && product.wasActiveButExpired {
                        inf( "Subscription expired, checking for renewal." )
                        self.refreshReceipt().finishes( promise )
                        return
                    }
                    continue
                }

                inf( "Active product: %@", product )
                missingFeatures.subtract( product.features )
                subscribedFeatures.formUnion( product.features )
            }

            // Enable features with an active subscription and disable those missing one.
            missingFeatures.forEach { $0.enable( false ) }
            subscribedFeatures.forEach { $0.enable( true ) }

            let originalPremiumPurchase =
                    InAppProduct.allCases.filter { $0.features.contains( .premium ) }
                        .compactMap { self.receipt?.lastAutoRenewableSubscriptionPurchase( ofProductIdentifier: $0.productIdentifier ) }
                        .sorted( by: { $0.originalPurchaseDate < $1.originalPurchaseDate } ).first
            let currentPremiumPurchase =
                    InAppProduct.allCases.filter { $0.features.contains( .premium ) }
                        .compactMap { self.receipt?.lastAutoRenewableSubscriptionPurchase( ofProductIdentifier: $0.productIdentifier ) }
                        .sorted( by: {
                            $0.subscriptionExpirationDate ?? $0.cancellationDate ?? $0.purchaseDate <
                            $1.subscriptionExpirationDate ?? $1.cancellationDate ?? $1.purchaseDate
                        } ).last
            let months = { Calendar.current.dateComponents( [ .month ], from: $0, to: $1 as Date ).month }
            Tracker.shared.event( track: .subject( "appstore", action: "receipt", [
                "answers_active": InAppFeature.answers.isEnabled,
                "logins_active": InAppFeature.logins.isEnabled,
                "biometrics_active": InAppFeature.biometrics.isEnabled,
                "premium_active": InAppFeature.premium.isEnabled,
                "premium_in_trial": currentPremiumPurchase?.subscriptionTrialPeriod ?? false,
                "premium_in_intro": currentPremiumPurchase?.subscriptionIntroductoryPricePeriod ?? false,
                "premium_months_age": originalPremiumPurchase?.originalPurchaseDate.flatMap { months( $0, Date() ) } ?? -1,
                "premium_months_left": currentPremiumPurchase?.subscriptionExpirationDate.flatMap { months( Date(), $0 ) } ?? -1,
            ] ) )

            promise.finish( .success( self.receipt ) )
        }
    }

    // MARK: - AppConfigObserver

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        if change == \AppConfig.masterPasswordCustomer {
            self.update()
        }
        #if !PUBLIC
        if change == \AppConfig.testingPremium {
            self.update()
        }
        #endif
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
                default:
                    self.purchaseEvent?.end( [ "result": transaction.transactionState, "error": transaction.error ] )
                    self.restoreEvent?.end( [ "result": transaction.transactionState, "error": transaction.error ] )
            }

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
        if !response.invalidProductIdentifiers.filter( { InAppProduct.find( $0 )?.isInStore ?? true } ).isEmpty {
            wrn( "Unsupported products: %@", response.invalidProductIdentifiers )
        }

        self.products = response.products
    }

    // MARK: - SKRequestDelegate

    func requestDidFinish(_ request: SKRequest) {
        self.updatePromise?.finish( .success( true ) )
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        mperror( title: "App Store request issue", message:
        "Ensure you are online and try logging out and back into your Apple ID from Settings.",
                 error: error )
        self.updatePromise?.finish( .success( false ) )
    }
}

protocol InAppStoreObserver {
    func didChange(store: AppStore, products: [SKProduct])
}
