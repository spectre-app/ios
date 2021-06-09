//==============================================================================
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit
import StoreKit

enum InAppFeature: String, CaseIterable {
    static let observers = Observers<InAppFeatureObserver>()

    case premium = "premium"

    var isEnabled: Bool {
        UserDefaults.shared.bool( forKey: self.rawValue )
    }

    func enable(_ enabled: Bool) {
        UserDefaults.shared.set( enabled, forKey: self.rawValue )
        InAppFeature.observers.notify { $0.featureDidChange( self ) }
    }
}

enum InAppSubscription: String, CaseIterable {
    case premium = "20670397"

    var subscriptionGroupIdentifier: String {
        self.rawValue
    }
}

enum InAppProduct: String, CaseIterable {
    case premiumAnnual         = "app.spectre.premium.annual"
    case premiumMonthly        = "app.spectre.premium.monthly"
    case premiumMasterPassword = "app.spectre.premium.masterpassword"

    public static let allCases = [ InAppProduct ]( [ .premiumAnnual, .premiumMonthly ] )

    static func find(_ productIdentifier: String) -> InAppProduct? {
        self.allCases.first( where: { $0.productIdentifier == productIdentifier } )
    }

    var productIdentifier: String {
        self.rawValue
    }
    var isPublic:          Bool {
        [ InAppProduct.premiumAnnual,
          InAppProduct.premiumMonthly ].contains( self )
    }
    var features:          [InAppFeature] {
        map( self, [
            .premiumAnnual: [ .premium ],
            .premiumMonthly: [ .premium ],
            .premiumMasterPassword: [ .premium ],
        ] ) ?? []
    }
}

extension SKProduct {
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SKProduct
        else { return false }
        if #available( iOS 14.0, * ) {
            guard self.isFamilyShareable == object.isFamilyShareable
            else { return false }
        }

        return self.localizedDescription == object.localizedDescription &&
                self.localizedTitle == object.localizedTitle &&
                self.price == object.price &&
                self.priceLocale == object.priceLocale &&
                self.productIdentifier == object.productIdentifier &&
                self.isDownloadable == object.isDownloadable &&
                self.downloadContentLengths == object.downloadContentLengths &&
                self.contentVersion == object.contentVersion &&
                self.downloadContentVersion == object.downloadContentVersion &&
                self.subscriptionPeriod == object.subscriptionPeriod &&
                self.introductoryPrice == object.introductoryPrice &&
                self.subscriptionGroupIdentifier == object.subscriptionGroupIdentifier &&
                self.discounts == object.discounts
    }

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
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SKProductDiscount
        else { return false }

        return self.price == object.price &&
                self.priceLocale == object.priceLocale &&
                self.identifier == object.identifier &&
                self.subscriptionPeriod == object.subscriptionPeriod &&
                self.numberOfPeriods == object.numberOfPeriods &&
                self.paymentMode == object.paymentMode &&
                self.type == object.type
    }

    var localizedOffer: String {
        switch self.paymentMode {
            case .freeTrial:
                return "Free"
            case .payAsYouGo:
                return "\(self.localizedPrice) / \(self.subscriptionPeriod.localizedDescription( context: .frequency ))"
            case .payUpFront:
                fallthrough
            @unknown default:
                return self.localizedPrice
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
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? SKProductSubscriptionPeriod
        else { return false }

        return self.numberOfUnits == object.numberOfUnits &&
                self.unit == object.unit
    }

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

extension SKPaymentTransactionState: CustomStringConvertible {
    public var description: String {
        switch self {
            case .purchasing:
                return "purchasing"
            case .purchased:
                return "purchased"
            case .failed:
                return "failed"
            case .restored:
                return "restored"
            case .deferred:
                return "deferred"
            @unknown default:
                return "unknown"
        }
    }
}

protocol InAppFeatureObserver {
    func featureDidChange(_ feature: InAppFeature)
}

protocol InAppStoreObserver {
    func productsDidChange(_ products: [SKProduct])
}
