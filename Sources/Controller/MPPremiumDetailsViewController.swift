//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import StoreKit

class MPPremiumDetailsViewController: MPDetailsViewController<Void>, InAppStoreObserver {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( model: () )

        InAppStore.shared.observers.register( observer: self )
    }

    override func loadItems() -> [Item<Void>] {
        [ HeaderItem(), SeparatorItem(),
          SubscribeItem(),
          SubscribedItem(),
          Item<Void>( subitems: [
              FeatureItem( name: "Biometric Lock", icon: "",
                           caption: "A touch or smile and we can recognize you now. Skip the master password." ),
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
                           caption: "Make it yours and dye Spectre with a dash of personality." ),
          ] ),
          SeparatorItem( subitems: [
              OverrideItem(),
          ] ).addBehaviour( RequiresDebug( mode: .reveals ) ),
        ]
    }

    // MARK: --- InAppStoreObserver ---

    func productsDidChange(_ products: [SKProduct]) {
        self.setNeedsUpdate()
    }

    // MARK: --- Types ---

    class HeaderItem: ImageItem<Void> {
        init() {
            super.init( title: "\(productName) Premium",
                        value: { _ in UIImage.icon( "", withSize: 64 ) },
                        caption: { _ in "Unlock enhanced comfort and security features." } )
        }
    }

    class SubscribeItem: ListItem<Void, SKProduct> {
        init() {
            super.init( title: "Enroll", values: { InAppStore.shared.products( forSubscription: .premium ) } )

            self.addBehaviour( PremiumConditionalBehaviour( mode: .hides ) )
        }

        override func didLoad(tableView: UITableView) {
            super.didLoad( tableView: tableView )

            tableView.register( Cell.self )
        }

        override func cell(tableView: UITableView, indexPath: IndexPath, model: (), value: SKProduct) -> UITableViewCell? {
            Cell.dequeue( from: tableView, indexPath: indexPath ) {
                ($0 as? Cell)?.product = value
            }
        }

        class Cell: UITableViewCell {
            private let buyButton    = MPButton( identifier: "premium.subscription #subscribe", title: "Subscribe" )
            private let captionLabel = UILabel()

            var product: SKProduct? {
                didSet {
                    if let product = self.product {
                        self.buyButton.title = "\(product.localizedTitle) for \(product.localizedPrice) per \(product.localizedAmount)"
                        self.captionLabel.text = product.localizedDescription
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

                self.buyButton.button.action( for: .primaryActionTriggered ) { //[unowned self] in
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

    class SubscribedItem: ImageItem<Void> {
        init() {
            super.init( title: "Enrolled",
                        value: { _ in UIImage.icon( "", withSize: 64 ) },
                        caption: { _ in "Thank you for making Spectre possible!" } )
            self.addBehaviour( PremiumConditionalBehaviour( mode: .reveals ) )
        }
    }

    class FeatureItem: ImageItem<Void> {
        init(name: String?, icon: String, caption: String?) {
            super.init( title: name, value: { _ in UIImage.icon( icon, withSize: 48 ) }, caption: { _ in caption } )
        }
    }

    class OverrideItem: ToggleItem<Void>, MPConfigObserver {
        init() {
            super.init(
                    identifier: "premium >override",
                    title: """
                           Subscribed 🅳
                           """,
                    value: {
                        (icon: UIImage.icon( "" ),
                         selected: appConfig.premium,
                         enabled: true)
                    },
                    update: { appConfig.premium = $1 },
                    caption: { _ in
                        """
                        Developer override for premium features.
                        """
                    } )

            appConfig.observers.register( observer: self )
        }

        // MARK: --- MPConfigObserver ---

        func didChangeConfig() {
            self.setNeedsUpdate()
        }
    }
}
