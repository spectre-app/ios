// =============================================================================
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import StoreKit

class FeatureTapBehaviour<M>: TapBehaviour<M>, InAppFeatureObserver {
    let feature: InAppFeature

    init(feature: InAppFeature) {
        self.feature = feature
    }

    override func didInstall(into item: Item<M>) {
        super.didInstall( into: item )

        InAppFeature.observers.register( observer: self )?
                    .didChange( feature: self.feature )
    }

    override func doTapped(item: Item<M>) {
        item.viewController?.show( DetailPremiumViewController(), sender: item )

        super.doTapped( item: item )
    }

    // MARK: - InAppFeatureObserver

    func didChange(feature: InAppFeature) {
        if feature == self.feature {
            self.isEnabled = !self.feature.isEnabled
        }
    }
}

class FeatureConditionalBehaviour<M>: ConditionalBehaviour<M>, InAppFeatureObserver {

    init(feature: InAppFeature, effect: Effect) {
        super.init( effect: effect, condition: { _ in feature.isEnabled } )
    }

    override func didInstall(into item: Item<M>) {
        super.didInstall( into: item )

        InAppFeature.observers.register( observer: self )
    }

    // MARK: - InAppFeatureObserver

    func didChange(feature: InAppFeature) {
        guard case .premium = feature
        else { return }

        self.setNeedsUpdate()
    }
}

class DetailPremiumViewController: ItemsViewController<Void>, AppConfigObserver, InAppStoreObserver, InAppFeatureObserver {

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<Void>.Type? = nil) {
        super.init( model: (), focus: focus )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        AppStore.shared.observers.register( observer: self )
        AppConfig.shared.observers.register( observer: self )
        InAppFeature.observers.register( observer: self )

        // Automatic subscription restoration or renewal.
        if !InAppFeature.premium.isEnabled {
            // Start by refreshing the products, receipt and renewals; triggering App Store log-in if necessary.
            AppStore.shared.update( active: true ).finally {
                // Only try to restore premium purchases if not yet present in our receipt.
                if !InAppSubscription.premium.isActive && !InAppSubscription.premium.wasActiveButExpired {
                    AppStore.shared.restorePurchases()
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        AppStore.shared.observers.unregister( observer: self )
        AppConfig.shared.observers.unregister( observer: self )
        InAppFeature.observers.unregister( observer: self )
    }

    override func loadItems() -> [Item<Void>] {
        [ HeaderItem(), SeparatorItem(),
          SubscriptionProductsItem(),
          SubscriptionUnavailableItem(),
          SubscriptionActiveItem(),
          Item( subitems: [
              EnablePremiumItem(),
              EnableStoreItem(),
          ] ).addBehaviour( IfConfiguration( .public, effect: .hides ) ),
          SeparatorItem(),
          Item<Void>( subitems: [
              FeatureItem( name: "Biometric Lock", icon: "fingerprint",
                           caption: "A touch or smile and we can recognize you now. Skip your personal secret." ),
              FeatureItem( name: "Auto-Fill", icon: "keyboard",
                           caption: "Your passwords exactly when you need them, instantly, from any app." ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( name: "Login Name Generator", icon: "id-card-clip",
                           caption: "Upgrade your inter-site anonymity with unique login names. Who is who?" ),
              FeatureItem( name: "Security Answer Generator", icon: "comments-question-check",
                           caption: "Say « No » to those pretentiously invasive \"security\" questions." ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( name: "Password Strength", icon: "bone-break",
                           caption: "Understand what a password's complexity truly translates into." ),
              FeatureItem( name: "Application Themes", icon: "paint-roller",
                           caption: "Make it yours and dye \(productName) with a dash of personality." ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( name: "Advanced Integrations", icon: "handshake",
                           caption: "Universal Clipboard, third‑party storage apps, opening site URLs, etc." ),
              FeatureItem( name: "Support", icon: "osi",
                           caption: "Super‑charge development of \(productName)'s open source privacy‑first digital identity platform." )
                  .addBehaviour(BlockTapBehaviour { _ in
                      AppStore.shared.presentCodeRedemption()
                  }),
          ] ),
          SeparatorItem(),
          RedeemCodeItem(),
          Item<Void>( subitems: [
              FeatureItem(
                      name: "Support Ukraine", icon: "🇺🇦",
                      caption:
                      """
                      Spectre is committed to supporting emerging security concerns in Ukraine.
                      Residents can use code `SUPPORTUA`.
                      """
              ),
          ] ),
        ]
    }

    // MARK: - AppConfigObserver

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        #if !PUBLIC
        if change == \AppConfig.sandboxStore {
            self.setNeedsUpdate()
        }
        #endif
    }

    // MARK: - InAppStoreObserver

    func didChange(store: AppStore, products: [SKProduct]) {
        self.setNeedsUpdate()
    }

    // MARK: - InAppFeatureObserver

    func didChange(feature: InAppFeature) {
        guard case .premium = feature
        else { return }

        self.setNeedsUpdate()
    }

    // MARK: - Types

    class HeaderItem: ImageItem<Void> {
        init() {
            super.init( title: "\(productName) Premium", value: { _ in .icon( "user-tie", withSize: 64 ) },
                        caption: { _ in
                            """
                            Unlock enhanced comfort and security features.
                            """
                        } )
        }
    }

    class SubscriptionProductsItem: ListItem<Void, SKProduct, SubscriptionProductsItem.Cell> {
        init() {
            super.init( title: "Enroll", values: { InAppSubscription.premium.publicProducts } )

            self.addBehaviour( ConditionalBehaviour( effect: .reveals ) { _ in AppStore.shared.canBuyProducts } )
            self.addBehaviour( FeatureConditionalBehaviour( feature: .premium, effect: .hides ) )

            self.animated = false
        }

        override func populate(_ cell: SubscriptionProductsItem.Cell, indexPath: IndexPath, value: SKProduct) {
            cell.product = value
        }

        // MARK: - Types

        class Cell: UITableViewCell {
            private lazy var buyButton = EffectButton( track: .subject( "premium.subscription", action: "subscribe", [
                "product": { [weak self] in self?.product?.productIdentifier }
            ] ), title: "Subscribe" )
            private let captionLabel = UILabel()

            var product: SKProduct? {
                didSet {
                    if let product = self.product {
                        if let introductoryPrice = product.introductoryPrice {
                            self.buyButton.attributedTitle =
                            NSAttributedString( string: introductoryPrice.localizedOffer ) +
                            NSAttributedString( string: " for \(introductoryPrice.localizedValidity)", secondaryColor: .clear )
                            self.captionLabel.text = "Then \(product.localizedOffer()). \(product.localizedDescription)"
                        }
                        else {
                            self.buyButton.title = product.localizedOffer()
                            self.captionLabel.text = product.localizedDescription
                        }
                    }
                    else {
                        self.buyButton.title = nil
                        self.captionLabel.text = nil
                    }
                }
            }

            // MARK: - Life

            required init?(coder aDecoder: NSCoder) {
                fatalError( "init(coder:) is not supported for this class" )
            }

            override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
                super.init( style: style, reuseIdentifier: reuseIdentifier )

                // - View
                self.isOpaque = false
                self.backgroundColor = .clear

                self.buyButton.action( for: .primaryActionTriggered ) { [unowned self] in
                    if let product = self.product {
                        AppStore.shared.purchase( product: product )
                    }
                }

                self.captionLabel => \.textColor => Theme.current.color.secondary
                self.captionLabel.textAlignment = .center
                self.captionLabel => \.font => Theme.current.font.caption1
                self.captionLabel.numberOfLines = 0
                self.captionLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )

                // - Hierarchy
                self.contentView.addSubview( self.buyButton )
                self.contentView.addSubview( self.captionLabel )

                // - Layout
                LayoutConfiguration( view: self.buyButton )
                    .constrain( as: .topBox, margin: true ).activate()
                LayoutConfiguration( view: self.captionLabel )
                    .constrain( as: .bottomBox, margin: true )
                    .constrain { $1.topAnchor.constraint( equalTo: self.buyButton.bottomAnchor, constant: 4 ) }
                    .activate()
            }
        }
    }

    class SubscriptionUnavailableItem: ImageItem<Void> {
        init() {
            super.init( title: "Cannot Enroll", value: { _ in .icon( "store-slash", withSize: 64 ) },
                        caption: { _ in
                            """
                            Ensure you are online and try logging out and back into your Apple ID from Settings.
                            """
                        } )

            self.addBehaviour( ConditionalBehaviour( effect: .hides ) { _ in AppStore.shared.canBuyProducts } )
            self.addBehaviour( FeatureConditionalBehaviour( feature: .premium, effect: .hides ) )
        }
    }

    class SubscriptionActiveItem: ImageItem<Void> {
        init() {
            super.init( title: "Enrolled", value: { _ in .icon( "check", withSize: 64 ) },
                        caption: { _ in
                            """
                            Thank you for making \(productName) possible!
                            """
                        } )

            self.addBehaviour( FeatureConditionalBehaviour( feature: .premium, effect: .reveals ) )
        }
    }

    class FeatureItem: ImageItem<Void> {
        init(name: Text?, icon: String, caption: Text?) {
            super.init( title: name, value: { _ in .icon( icon, withSize: 48 ) }, caption: { _ in caption } )
        }
    }

    class RedeemCodeItem: ButtonItem<Void> {
        init() {
            super.init( track: .subject( "premium", action: "redeem" ),
                        value: { _ in (label: "Redeem Code", image: nil) },
                        caption: { _ in
                            """
                            If you have a support code, you can redeem it here.
                            """
                        } ) { _ in
                AppStore.shared.presentCodeRedemption()
            }
        }
    }

    #if PUBLIC
    class EnablePremiumItem: Item<Void> {
    }

    class EnableStoreItem: Item<Void> {
    }
    #else
    class EnablePremiumItem: ToggleItem<Void> {
        init() {
            super.init( track: .subject( "premium", action: "override" ),
                        title: "Subscribed 🅳", icon: { _ in .icon( "user-tie" ) },
                        value: { _ in InAppFeature.premium.isEnabled },
                        update: { AppConfig.shared.testingPremium = $1 },
                        caption: { _ in
                            """
                            Toggle access to all Premium features while testing the app.
                            """
                        } )
        }
    }

    class EnableStoreItem: ToggleItem<Void> {
        init() {
            super.init( track: .subject( "premium", action: "sandbox" ),
                        title: "Sandbox 🅳", icon: { _ in .icon( "app-store-ios" ) },
                        value: { _ in AppConfig.shared.sandboxStore }, update: { AppConfig.shared.sandboxStore = $1 },
                        caption: { _ in
                            """
                            Temporary subscription purchase testing through the App Store sandbox.
                            """
                        } )
        }
    }
    #endif
}
