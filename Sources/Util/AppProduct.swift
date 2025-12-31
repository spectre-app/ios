//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import StoreKit

enum AppFeature: String, CaseIterable {
    case notifications, diagnostics, offline, handoff, style, icons, incognito, sharing
    case biometrics, autofill, logins, answers, strength

    /// Can the user access this feature's capabilities?
    var isEnabled: Bool {
        if self.isPurchaseNeeded {
            return false
        }

        switch self {
            case .notifications: return AppConfig.shared.notifications
            case .diagnostics: return AppConfig.shared.diagnostics && !Self.offline.isEnabled
            case .offline: return AppConfig.shared.offline
            case .handoff: return AppConfig.shared.allowHandoff && !Self.offline.isEnabled
            case .style: return true
            case .icons: return true
            case .incognito: return true
            case .sharing: return true
            case .biometrics: return true
            case .autofill: return true
            case .logins: return true
            case .answers: return true
            case .strength: return true
        }
    }

    /// Does the user need to make a purchase in order to unlock this feature's capabilities?
    var isPurchaseNeeded: Bool {
        switch self {
            case .notifications: false
            case .diagnostics: false
            case .offline: false
            case .handoff: !StoreFeature.integrations.isEnabled
            case .style: !StoreFeature.themes.isEnabled
            case .icons: !StoreFeature.themes.isEnabled
            case .incognito: false
            case .sharing: !StoreFeature.integrations.isEnabled
            case .biometrics: !StoreFeature.biometrics.isEnabled
            case .autofill: !StoreFeature.autofill.isEnabled
            case .logins: !StoreFeature.logins.isEnabled
            case .answers: !StoreFeature.answers.isEnabled
            case .strength: !StoreFeature.strength.isEnabled
        }
    }
}

enum StoreFeature: String, CaseIterable {
    case biometrics, autofill, logins, answers, strength, themes, integrations, support

    var enabled: UserDefault<Bool> {
        AppConfig.for(self.rawValue)
    }

    var isEnabled: Bool {
        self.enabled.wrappedValue
    }

    func enable(_ enabled: Bool) {
        if enabled != self.isEnabled {
            dbg("Feature \(self.rawValue) -> \(enabled)")
            self.enabled.wrappedValue = enabled
        }
    }
}

enum StoreSubscription: String, CaseIterable {
    case premium

    var enabled: UserDefault<Bool> {
        AppConfig.for(self.rawValue)
    }

    var isEnabled: Bool {
        self.enabled.wrappedValue
    }

    func enable(_ enabled: Bool) {
        if enabled != self.isEnabled {
            dbg("Subscription \(self.rawValue) -> \(enabled)")
            self.enabled.wrappedValue = enabled
        }
    }

    var subscriptionGroupIdentifier: String {
        [
            .premium: "20670397",
        ][self] ?? ""
    }
}

enum StoreProduct: String, CaseIterable {
    case premiumAnnual = "app.spectre.premium.annual"
    case premiumMonthly = "app.spectre.premium.monthly"
    case premiumMasterPassword = "app.spectre.premium.masterpassword"  // swiftlint:disable:this inclusive_language
    case legacyMasterPassword = "app.spectre.legacy.masterpassword"  // swiftlint:disable:this inclusive_language

    static func find(_ productIdentifier: String) -> StoreProduct? {
        self.allCases.first(where: { $0.productIdentifier == productIdentifier })
    }

    var productIdentifier: String {
        self.rawValue
    }

    var isPublic: Bool {
        [
            StoreProduct.premiumAnnual,
            StoreProduct.premiumMonthly,
        ].contains(self)
    }

    var isInStore: Bool {
        ![
            StoreProduct.legacyMasterPassword,
        ].contains(self)
    }

    var features: [StoreFeature] {
        [
            .premiumAnnual: [.biometrics, .autofill, .logins, .answers, .strength, .themes, .integrations, .support],
            .premiumMonthly: [.biometrics, .autofill, .logins, .answers, .strength, .themes, .integrations, .support],
            .premiumMasterPassword: [.biometrics, .autofill, .logins, .answers, .strength, .themes, .integrations, .support],
            .legacyMasterPassword: [.biometrics, .logins, .answers],
        ][self] ?? []
    }

    var subscription: StoreSubscription? {
        [
            .premiumAnnual: .premium,
            .premiumMonthly: .premium,
            .premiumMasterPassword: .premium,
        ][self]
    }
}

@MainActor
func updateStoreFeatures(deliver delivered: VerificationResult<StoreKit.Transaction>? = nil) async {
    var enabledProducts: [StoreProduct] = []

    // Master Password customers automatically get all legacy in-app purchases for free.
    if AppConfig.shared.masterPasswordCustomer {
        trc("Product is active: \(StoreProduct.legacyMasterPassword.productIdentifier)")
        enabledProducts += [.legacyMasterPassword]
    }
    #if !PUBLIC
    // Enable testing of the premium subscription capabilities without actually purchasing.
    if AppConfig.shared.testingPremium {
        trc("Product is active: \(StoreProduct.legacyMasterPassword.productIdentifier)")
        enabledProducts += [.premiumMonthly]
    }
    #endif

    // Handle all currently active subscriptions and non-consumables.
    for await current in Transaction.currentEntitlements {
        switch current {
            case let .unverified(transaction, error):
                // Illegal transaction.
                err("Couldn't verify: \(transaction.productID)", data: transaction, error)

            case let .verified(transaction):
                if let expirationDate = transaction.expirationDate, expirationDate < .now {
                    // Expired subscription.
                    dbg("Skipping expired product: \(transaction.productID) (\(expirationDate))")
                }
                else if let revocationDate = transaction.revocationDate, revocationDate < .now {
                    // Expired subscription.
                    dbg(
                        "Skipping revoked product: \(transaction.productID) (\(revocationDate), reason: \(String(describing: transaction.revocationReason)))",
                    )
                }
                else if let product = StoreProduct.find(transaction.productID) {
                    // Active product subscription.
                    trc("Product is active: \(product.productIdentifier)")
                    enabledProducts += [product]
                }
                else {
                    // Active subscription for an unknown product.
                    wrn("No product for: \(transaction.productID)")
                }
        }
    }
    switch delivered {
        case .none: ()

        case let .unverified(transaction, error):
            err("Couldn't verify: \(transaction.productID)", data: transaction, error)

        case let .verified(transaction):
            // Handle the delivered consumable.
            if transaction.productType == .consumable {
                if transaction.revocationDate == nil {
                    // Purchased consumable.
                    // inf( "Consumable delivered: \(transaction.productID )
                    // await transaction.finish()
                }
                else {
                    // Refunded consumable.
                    // inf( "Consumable refunded: \(transaction.productID )
                    // await transaction.finish()
                }
            }
            // Handle the delivered non-consumable.
            else if enabledProducts.map(\.productIdentifier).contains(transaction.productID) {
                // Non-consumable enabled.
                inf("Non-consumable delivery is enabled: \(transaction.productID)")
                await transaction.finish()
            }
            else {
                err("Non-consumable delivery is unsupported: \(transaction.productID)")
            }
    }

    // Enable only those features and subscriptions supported by an enabled product.
    let enabledFeatures = enabledProducts.reduce(Set<StoreFeature>()) { $0.union($1.features) }
    for item in StoreFeature.allCases {
        item.enable(enabledFeatures.contains(item))
    }
    let enabledSubscriptions = Set(enabledProducts.compactMap(\.subscription))
    for item in StoreSubscription.allCases {
        item.enable(enabledSubscriptions.contains(item))
    }

    //            let originalPremiumPurchase =
    //                    StoreProduct.allCases.filter { $0.features.contains( .premium ) }
    //                        .compactMap { self.receipt?.lastAutoRenewableSubscriptionPurchase( ofProductIdentifier: $0.productIdentifier ) }
    //                        .sorted( by: { $0.originalPurchaseDate < $1.originalPurchaseDate } ).first
    //            let currentPremiumPurchase =
    //                    StoreProduct.allCases.filter { $0.features.contains( .premium ) }
    //                        .compactMap { self.receipt?.lastAutoRenewableSubscriptionPurchase( ofProductIdentifier: $0.productIdentifier ) }
    //                        .sorted( by: {
    //                            $0.subscriptionExpirationDate ?? $0.cancellationDate ?? $0.purchaseDate <
    //                            $1.subscriptionExpirationDate ?? $1.cancellationDate ?? $1.purchaseDate
    //                        } ).last
    //            let months = { Calendar.current.dateComponents( [ .month ], from: $0, to: $1 as Date ).month }
    //            Tracker.shared.event( track: .subject( "appstore", action: "receipt", [
    //                "answers_active": StoreFeature.answers.isEnabled,
    //                "logins_active": StoreFeature.logins.isEnabled,
    //                "biometrics_active": StoreFeature.biometrics.isEnabled,
    //                "premium_active": StoreFeature.premium.isEnabled,
    //                "premium_in_trial": currentPremiumPurchase?.subscriptionTrialPeriod ?? false,
    //                "premium_in_intro": currentPremiumPurchase?.subscriptionIntroductoryPricePeriod ?? false,
    //                "premium_months_age": originalPremiumPurchase?.originalPurchaseDate.flatMap { months( $0, Date() ) } ?? -1,
    //                "premium_months_left": currentPremiumPurchase?.subscriptionExpirationDate.flatMap { months( Date(), $0 ) } ?? -1,
    //            ] ) )
}
