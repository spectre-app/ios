//
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import StoreKit

enum InAppFeature: String, CaseIterable {
    static let observers = Observers<InAppFeatureObserver>()

    case premium = "premium"

    var isEnabled: Bool {
        switch self {
            case .premium:
                return UserDefaults.shared.bool( forKey: "premium" )
        }
    }

    func enable(_ enabled: Bool) {
        switch self {
            case .premium:
                UserDefaults.shared.set( enabled, forKey: "premium" )
        }

        InAppFeature.observers.notify { $0.featureDidChange( self ) }
    }
}

enum InAppSubscription: String, CaseIterable {
    case premium = "20670397"

    var subscriptionGroupIdentifier: String {
        self.rawValue
    }
}

enum InAppProducts: String, CaseIterable {
    case premiumAnnual  = "app.spectre.premium.annual"
    case premiumMonthly = "app.spectre.premium.monthly"

    public static let allCases = [ InAppProducts ]( [ .premiumAnnual, .premiumMonthly ] )

    static func find(_ productIdentifier: String) -> InAppProducts? {
        self.allCases.first( where: { $0.productIdentifier == productIdentifier } )
    }

    var productIdentifier: String {
        self.rawValue
    }

    var features: [InAppFeature] {
        switch self {
            case .premiumAnnual:
                return [ .premium ]
            case .premiumMonthly:
                return [ .premium ]
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
