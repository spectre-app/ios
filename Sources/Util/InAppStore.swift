//
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import StoreKit

enum InAppFeature {
    static var observers = Observers<InAppFeatureObserver>()

    case premium

    func enabled() -> Bool {
        switch self {
            case .premium:
                return UserDefaults.standard.bool( forKey: "premium" )
        }
    }

    func enabled(_ enabled: Bool) {
        switch self {
            case .premium:
                UserDefaults.standard.set( enabled, forKey: "premium" )
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

    public private(set) static var allCases = [ InAppProducts ]( [ .premiumAnnual, .premiumMonthly ] )

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
        self.products.filter {
            dbg( "product: %@, sub: %@", $0, $0.subscriptionGroupIdentifier )
            return $0.subscriptionGroupIdentifier == subscription.identifier
        }
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
    var localizedPrice: String {
        self.localizedPrice( quantity: 1 )
    }

    func localizedPrice(quantity: Int) -> String {
        let price = self.price.doubleValue * Double( self.subscriptionPeriod?.numberOfUnits ?? 1 * quantity )

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = self.priceLocale
        return currencyFormatter.string( from: NSNumber( value: price ) ) ?? "\(price)"
    }

    var localizedAmount: String {
        self.localizedAmount( quantity: 1 ) ?? ""
    }

    func localizedAmount(quantity: Int) -> String? {
        (self.subscriptionPeriod?.localizedDescription).map { period in
            quantity == 1 ? period: quantify( period, quantity: quantity )
        }
    }

    func quantify(_ string: String?, quantity: Int) -> String {
        var quantum: String
        if quantity == 0 {
            quantum = "no"
        }
        else if quantity == 1 {
            quantum = "1 time"
        }
        else {
            quantum = "\(quantity) times"
        }

        if let string = string {
            return "\(quantum) \(string)"
        }
        else {
            return quantum
        }
    }
}

extension SKProductSubscriptionPeriod {
    var localizedDescription: String {
        let plural = self.numberOfUnits != 1

        var unitName: String
        switch self.unit {
            case .day:
                unitName = plural ? "Days": "Day"
            case .week:
                unitName = plural ? "Weeks": "Week"
            case .month:
                unitName = plural ? "Months": "Month"
            case .year:
                unitName = plural ? "Years": "Year"
            @unknown default:
                unitName = "<\(self.unit.rawValue)>"
        }

        return plural ? "\(self.numberOfUnits) \(unitName)": unitName
    }
}

protocol InAppFeatureObserver {
    func featureDidChange(_ feature: InAppFeature)
}

protocol InAppStoreObserver {
    func productsDidChange(_ products: [SKProduct])
}
