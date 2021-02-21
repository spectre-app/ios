//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import StoreKit

class PremiumTapBehaviour<M>: TapBehaviour<M>, InAppFeatureObserver {
    init() {
        super.init()

        InAppFeature.observers.register( observer: self )
    }

    override func didInstall(into item: Item<M>) {
        super.didInstall( into: item )

        self.featureDidChange( .premium )
    }

    override func doTapped(item: Item<M>) {
        item.viewController?.show( MPPremiumDetailsViewController(), sender: item )

        super.doTapped( item: item )
    }

    // MARK: --- InAppFeatureObserver ---

    func featureDidChange(_ feature: InAppFeature) {
        guard case .premium = feature
        else { return }

        self.isEnabled = !InAppFeature.premium.isEnabled
    }
}

class PremiumConditionalBehaviour<M>: ConditionalBehaviour<M>, InAppFeatureObserver {

    init(mode: Effect) {
        super.init( mode: mode, condition: { _ in InAppFeature.premium.isEnabled } )

        InAppFeature.observers.register( observer: self )
    }

    // MARK: --- InAppFeatureObserver ---

    func featureDidChange(_ feature: InAppFeature) {
        self.setNeedsUpdate()
    }
}

class MPPremiumDetailsViewController: MPItemsViewController<Void> {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(focus: Item<Void>.Type? = nil) {
        super.init( model: (), focus: focus )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Automatic subscription restoration or renewal.
        if !InAppFeature.premium.isEnabled && !InAppSubscription.premium.isActive && !InAppSubscription.premium.wasActiveButExpired {
            // Only restore premium if not yet in our receipt.
            AppStore.shared.restorePurchases()
        }
        else {
            // Otherwise refresh receipt and products, triggering App Store log-in if necessary.
            AppStore.shared.update( active: true )
        }
    }

    override func loadItems() -> [Item<Void>] {
        [ HeaderItem(), SeparatorItem(),
          SubscriptionProductsItem(),
          SubscriptionUnavailableItem(),
          SubscriptionActiveItem(),
          Item<Void>( subitems: [
              FeatureItem( name: "Biometric Lock", icon: "",
                           caption: "A touch or smile and we can recognize you now. Skip your personal secret." ),
              FeatureItem( name: "Password Auto-Fill", icon: "",
                           caption: "Your passwords exactly when you need them, instantly, from any app." ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( name: "Login Name Generator", icon: "",
                           caption: "Upgrade your inter-site anonymity with unique login names. Who is who?" ),
              FeatureItem( name: "Security Answer Generator", icon: "",
                           caption: "Say « No » to those pretentiously invasive \"security\" questions." ),
          ] ),
          Item<Void>( subitems: [
              FeatureItem( name: "Password Strength", icon: "",
                           caption: "Understand what a password's complexity truly translates into." ),
              FeatureItem( name: "Application Themes", icon: "",
                           caption: "Make it yours and dye \(productName) with a dash of personality." ),
          ] ),
          SeparatorItem( subitems: [
              OverrideItem(),
          ] ).addBehaviour( RequiresPrivate( mode: .reveals ) ),
        ]
    }

    // MARK: --- Types ---

    class HeaderItem: ImageItem<Void> {
        init() {
            super.init( title: "\(productName) Premium", value: { _ in .icon( "", withSize: 64 ) },
                        caption: { _ in
                            """
                            Unlock enhanced comfort and security features.
                            """
                        } )
        }
    }

    class SubscriptionProductsItem: ListItem<Void, SKProduct, SubscriptionProductsItem.Cell>, InAppStoreObserver {
        init() {
            super.init( title: "Enroll", values: { AppStore.shared.products( forSubscription: .premium ) } )

            self.addBehaviour( ConditionalBehaviour( mode: .reveals ) { _ in AppStore.shared.canBuyProducts } )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .hides ) )
            AppStore.shared.observers.register( observer: self )
        }

        override func populate(_ cell: SubscriptionProductsItem.Cell, indexPath: IndexPath, value: SKProduct) {
            cell.product = value
        }

        // MARK: --- InAppStoreObserver ---

        func productsDidChange(_ products: [SKProduct]) {
            self.setNeedsUpdate()
        }

        // MARK: --- Types ---

        class Cell: UITableViewCell {
            private lazy var buyButton = MPButton( track: .subject( "premium.subscription", action: "subscribe",
                                                                    [ "product": self.product?.productIdentifier ?? "n/a" ] ),
                                                   title: "Subscribe" )
            private let captionLabel = UILabel()

            var product: SKProduct? {
                didSet {
                    if let product = self.product {
                        if let introductoryPrice = product.introductoryPrice {
                            self.buyButton.attributedTitle =
                                    .str( introductoryPrice.localizedOffer ) +
                                    .str( " for \(introductoryPrice.localizedValidity)", secondaryColor: .clear )
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

            // MARK: --- Life ---

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
                        .constrain( margins: true, anchors: .topBox )
                        .activate()
                LayoutConfiguration( view: self.captionLabel )
                        .constrain( margins: true, anchors: .bottomBox )
                        .constrainTo { $1.topAnchor.constraint( equalTo: self.buyButton.bottomAnchor, constant: 4 ) }
                        .activate()
            }
        }
    }

    class SubscriptionUnavailableItem: ImageItem<Void> {
        init() {
            super.init( title: "Cannot Enroll", value: { _ in .icon( "", withSize: 64 ) },
                        caption: { _ in
                            """
                            Ensure you are online and try logging out and back into your Apple ID from Settings.
                            """
                        } )

            self.addBehaviour( ConditionalBehaviour( mode: .hides ) { _ in AppStore.shared.canBuyProducts } )
        }
    }

    class SubscriptionActiveItem: ImageItem<Void> {
        init() {
            super.init( title: "Enrolled", value: { _ in .icon( "", withSize: 64 ) },
                        caption: { _ in
                            """
                            Thank you for making \(productName) possible!
                            """
                        } )

            self.addBehaviour( PremiumConditionalBehaviour( mode: .reveals ) )
        }
    }

    class FeatureItem: ImageItem<Void> {
        init(name: String?, icon: String, caption: String?) {
            super.init( title: name, value: { _ in .icon( icon, withSize: 48 ) }, caption: { _ in caption } )
        }
    }

    class OverrideItem: ToggleItem<Void>, InAppFeatureObserver {
        init() {
            super.init( track: .subject( "premium", action: "override" ),
                        title: "Subscribed 🅳", icon: { _ in .icon( "" ) },
                        value: { _ in InAppFeature.premium.isEnabled }, update: { InAppFeature.premium.enable( $1 ) },
                        caption: { _ in
                            """
                            Developer override for premium features.
                            """
                        } )

            InAppFeature.observers.register( observer: self )
        }

        // MARK: --- InAppFeatureObserver ---

        func featureDidChange(_ feature: InAppFeature) {
            self.setNeedsUpdate()
        }
    }
}
