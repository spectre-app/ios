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

class AppStore: NSObject, SKStoreProductViewControllerDelegate {
    public static let shared = AppStore()

    private let countryCode3to2
            = [ "AFG": "AF", "ALB": "AL", "DZA": "DZ", "AND": "AD", "AGO": "AO", "AIA": "AI", "ATG": "AG", "ARG": "AR", "ARM": "AM", "AUS": "AU", "AUT": "AT", "AZE": "AZ", "BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB", "BLR": "BY", "BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BMU": "BM", "BTN": "BT", "BOL": "BO", "BIH": "BA", "BWA": "BW", "BRA": "BR", "BRN": "BN", "BGR": "BG", "BFA": "BF", "KHM": "KH", "CMR": "CM", "CAN": "CA", "CPV": "CV", "CYM": "KY", "CAF": "CF", "TCD": "TD", "CHL": "CL", "CHN": "CN", "COL": "CO", "COG": "CG", "COD": "CD", "CRI": "CR", "CIV": "CI", "HRV": "HR", "CYP": "CY", "CZE": "CZ", "DNK": "DK", "DMA": "DM", "DOM": "DO", "ECU": "EC", "EGY": "EG", "SLV": "SV", "EST": "EE", "ETH": "ET", "FJI": "FJ", "FIN": "FI", "FRA": "FR", "GAB": "GA", "GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH", "GRC": "GR", "GRD": "GD", "GTM": "GT", "GIN": "GN", "GNB": "GW", "GUY": "GY", "HND": "HN", "HKG": "HK", "HUN": "HU", "ISL": "IS", "IND": "IN", "IDN": "ID", "IRQ": "IQ", "IRL": "IE", "ISR": "IL", "ITA": "IT", "JAM": "JM", "JPN": "JP", "JOR": "JO", "KAZ": "KZ", "KEN": "KE", "KOR": "KR", "KWT": "KW", "KGZ": "KG", "LAO": "LA", "LVA": "LV", "LBN": "LB", "LBR": "LR", "LBY": "LY", "LIE": "LI", "LTU": "LT", "LUX": "LU", "MAC": "MO", "MKD": "MK", "MDG": "MG", "MWI": "MW", "MYS": "MY", "MDV": "MV", "MLI": "ML", "MLT": "MT", "MRT": "MR", "MUS": "MU", "MEX": "MX", "FSM": "FM", "MDA": "MD", "MCO": "MC", "MNG": "MN", "MNE": "ME", "MSR": "MS", "MAR": "MA", "MOZ": "MZ", "MMR": "MM", "NAM": "NA", "NRU": "NR", "NPL": "NP", "NLD": "NL", "NZL": "NZ", "NIC": "NI", "NER": "NE", "NGA": "NG", "NOR": "NO", "OMN": "OM", "PAK": "PK", "PLW": "PW", "PSE": "PS", "PAN": "PA", "PNG": "PG", "PRY": "PY", "PER": "PE", "PHL": "PH", "POL": "PL", "PRT": "PT", "QAT": "QA", "ROU": "RO", "RUS": "RU", "RWA": "RW", "KNA": "KN", "LCA": "LC", "VCT": "VC", "WSM": "WS", "STP": "ST", "SAU": "SA", "SEN": "SN", "SRB": "RS", "SYC": "SC", "SLE": "SL", "SGP": "SG", "SVK": "SK", "SVN": "SI", "SLB": "SB", "ZAF": "ZA", "ESP": "ES", "LKA": "LK", "SUR": "SR", "SWZ": "SZ", "SWE": "SE", "CHE": "CH", "TWN": "TW", "TJK": "TJ", "TZA": "TZ", "THA": "TH", "TON": "TO", "TTO": "TT", "TUN": "TN", "TUR": "TR", "TKM": "TM", "TCA": "TC", "UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB", "USA": "US", "URY": "UY", "UZB": "UZ", "VUT": "VU", "VEN": "VE", "VNM": "VN", "VGB": "VG", "YEM": "YE", "ZMB": "ZM", "ZWE": "ZW" ]

    func isUpToDate(appleID: Int? = nil, buildVersion: String? = nil) -> Promise<(upToDate: Bool, buildVersion: String, storeVersion: String)> {
        var countryCode2 = "US"
        if #available( iOS 13.0, * ) {
            if let countryCode3 = SKPaymentQueue.default().storefront?.countryCode {
                countryCode2 = self.countryCode3to2[countryCode3] ?? countryCode2
            }
        }

        let searchURLString = "https://itunes.apple.com/lookup?id=\(appleID ?? productAppleID)&country=\(countryCode2)&limit=1"
        guard let searchURL = URL( string: searchURLString )
        else { return Promise( .failure( MPError.internal( cause: "Couldn't resolve store URL", details: searchURLString ) ) ) }

        return URLSession.required.promise( with: URLRequest( url: searchURL ) ).promise {
            if let error = (try JSONSerialization.jsonObject( with: $0.data ) as? [String: Any])?["errorMessage"] as? String {
                throw MPError.issue( title: "iTunes store lookup issue.", details: error )
            }
            guard let metadata = (((try JSONSerialization.jsonObject( with: $0.data ) as? [String: Any])?["results"] as? [Any])?.first as? [String: Any])
            else { throw MPError.state( title: "Missing iTunes application metadata." ) }
            guard let storeVersion = metadata["version"] as? String
            else { throw MPError.state( title: "Missing version in iTunes metadata." ) }

            let buildVersion = buildVersion ?? productVersion
            let buildComponents = buildVersion.components( separatedBy: "." )
            let storeComponents = storeVersion.components( separatedBy: "." )
            for c in 0..<max( storeComponents.count, buildComponents.count ) {
                if c < storeComponents.count && c < buildComponents.count {
                    let storeComponent = (storeComponents[c] as NSString).integerValue
                    let buildComponent = (buildComponents[c] as NSString).integerValue
                    if storeComponent > buildComponent {
                        // Store version component higher than build, build is outdated.
                        return (upToDate: false, buildVersion: buildVersion, storeVersion: storeVersion)
                    }
                    else if storeComponent < buildComponent {
                        // Store version component lower than build, build is more recent.
                        return (upToDate: true, buildVersion: buildVersion, storeVersion: storeVersion)
                    }
                }
                else if storeComponents.count > buildComponents.count {
                    // Store version has more components than build and prior components were identical, build outdated.
                    return (upToDate: false, buildVersion: buildVersion, storeVersion: storeVersion)
                }
                else {
                    return (upToDate: true, buildVersion: buildVersion, storeVersion: storeVersion)
                }
            }

            return (upToDate: true, buildVersion: buildVersion, storeVersion: storeVersion)
        }
    }

    func present(appleID: Int? = nil, in viewController: UIViewController) {
        let controller = SKStoreProductViewController()
        controller.delegate = self
        controller.loadProduct( withParameters: [ SKStoreProductParameterITunesItemIdentifier: appleID ?? productAppleID ] ) { success, error in
            if !success || error != nil {
                wrn( "Couldn't load store controller: %@", error )
            }
        }
        viewController.present( controller, animated: true )
    }

    // MARK: --- SKStoreProductViewControllerDelegate ---

    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss( animated: true )
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
