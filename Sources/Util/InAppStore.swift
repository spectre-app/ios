//
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import StoreKit

enum InAppFeature {
    static let observers = Observers<InAppFeatureObserver>()

    case premium

    func enabled() -> Bool {
        switch self {
            case .premium:
                return UserDefaults.shared.bool( forKey: "premium" )
        }
    }

    func enabled(_ enabled: Bool) {
        switch self {
            case .premium:
                UserDefaults.shared.set( enabled, forKey: "premium" )
        }

        InAppFeature.observers.notify { $0.featureDidChange( self ) }
    }
}

enum InAppSubscription {
    case premium

    var identifier: String {
        switch self {
            case .premium:
                return "20670397"
        }
    }
}

enum InAppProducts: CaseIterable {
    case premiumAnnual
    case premiumMonthly

    public static let allCases = [ InAppProducts ]( [ .premiumAnnual, .premiumMonthly ] )

    static func find(identifier: String) -> InAppProducts? {
        self.allCases.first( where: { $0.identifier == identifier } )
    }

    var identifier: String {
        switch self {
            case .premiumAnnual:
                return "app.spectre.premium.annual"
            case .premiumMonthly:
                return "app.spectre.premium.monthly"
        }
    }

    var feature: InAppFeature {
        switch self {
            case .premiumAnnual:
                return .premium
            case .premiumMonthly:
                return .premium
        }
    }
}

class InAppStore: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, Observable {
    public static let shared = InAppStore()

    private override init() {
        super.init()

        SKPaymentQueue.default().add( self )
        self.update()
    }

    var observers = Observers<InAppStoreObserver>()
    var canMakePayments: Bool {
        SKPaymentQueue.canMakePayments()
    }
    var products = [ SKProduct ]() {
        didSet {
            if self.products != oldValue {
                self.observers.notify { $0.productsDidChange( self.products ) }
            }
        }
    }

    func update() {
        let productsRequest = SKProductsRequest( productIdentifiers: Set( InAppProducts.allCases.map { $0.identifier } ) )
        productsRequest.delegate = self
        productsRequest.start()
    }

    func purchase(product: SKProduct, quantity: Int = 1) {
        let payment = SKMutablePayment( product: product )
        payment.quantity = quantity

        SKPaymentQueue.default().add( payment )
    }

    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    // MARK: --- SKProductsRequestDelegate ---

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !response.invalidProductIdentifiers.isEmpty {
            inf( "Unsupported products: %@", response.invalidProductIdentifiers )
        }

        self.products = response.products
    }

    // MARK: --- SKRequestDelegate ---

    func requestDidFinish(_ request: SKRequest) {
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        mperror( title: "App Store Request Issue", message:
        "Ensure you are online and try logging out and back into iTunes from your device's Settings.",
                 error: error )
    }

    func products(forSubscription subscription: InAppSubscription) -> [SKProduct] {
        self.products.filter { $0.subscriptionGroupIdentifier == subscription.identifier }
    }

    // MARK: --- SKPaymentTransactionObserver ---

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            dbg( "transaction updated: %@ -> %d", transaction.payment.productIdentifier, transaction.transactionState.rawValue )

            switch transaction.transactionState {
                case .purchasing, .deferred:
                    break
                case .purchased, .restored:
                    InAppProducts.find( identifier: transaction.payment.productIdentifier )?.feature.enabled( true )
                    queue.finishTransaction( transaction )
                case .failed:
                    mperror( title: "App Store Transaction Issue", message:
                    "Ensure you are online and try logging out and back into iTunes from your device's Settings.",
                             error: transaction.error )
                    queue.finishTransaction( transaction )
                @unknown default:
                    break
            }
        }
    }
}

extension SKProduct {
    func localizedPrice(quantity: Int = 1) -> String {
        let price = self.price.doubleValue * Double( quantity )
        return "\(number: price, locale: self.priceLocale, .currency)"
    }

    func localizedDuration(quantity: Int = 1) -> String? {
        self.subscriptionPeriod?.localizedDescription( periods: quantity, context: self.isAutoRenewing ? .frequency: .quantity )
    }

    func localizedOffer(quantity: Int = 1) -> String {
        if let amount = self.localizedDuration( quantity: quantity ) {
            return "\(self.localizedPrice( quantity: quantity )) \(self.isAutoRenewing ? "/": "for") \(amount)"
        }
        else {
            return self.localizedPrice( quantity: quantity )
        }
    }

    var isAutoRenewing: Bool {
        self.subscriptionGroupIdentifier != nil
    }
}

extension SKProductDiscount {
    var localizedOffer: String {
        switch self.paymentMode {
            case .freeTrial:
                return "Try freely"
            case .payAsYouGo:
                return "\(self.localizedPrice) / \(self.subscriptionPeriod.localizedDescription( context: .frequency ))"
            case .payUpFront:
                fallthrough
            @unknown default:
                return "\(self.localizedPrice)"
        }
    }

    var localizedValidity: String {
        self.subscriptionPeriod.localizedDescription( periods: self.numberOfPeriods, context: .quantity )
    }

    var localizedPrice: String {
        let pricePeriods: Int
        switch self.paymentMode {
            case .freeTrial:
                return "Free"
            case .payAsYouGo:
                pricePeriods = 1
            case .payUpFront:
                fallthrough
            @unknown default:
                pricePeriods = self.numberOfPeriods
        }

        let price = self.price.doubleValue * Double( pricePeriods )
        return "\(number: price, locale: self.priceLocale, .currency)"
    }
}

extension SKProductSubscriptionPeriod {
    func localizedDescription(periods: Int = 1, context: LocalizedContext) -> String {
        let units = Decimal( self.numberOfUnits * periods )

        return context == .frequency && units == 1 ?
                self.unit.localizedDescription( units: .nan ):
                self.unit.localizedDescription( units: units )
    }

    enum LocalizedContext {
        case frequency, quantity
    }
}

extension SKProduct.PeriodUnit {
    func localizedDescription(units: Decimal) -> String {
        switch self {
            case .day:
                return Period.days( units ).localizedDescription
            case .week:
                return Period.weeks( units ).localizedDescription
            case .month:
                return Period.months( units ).localizedDescription
            case .year:
                return Period.years( units ).localizedDescription
            @unknown default:
                return "\(units)  <\(self.rawValue)>"
        }
    }
}

protocol InAppFeatureObserver {
    func featureDidChange(_ feature: InAppFeature)
}

protocol InAppStoreObserver {
    func productsDidChange(_ products: [SKProduct])
}
