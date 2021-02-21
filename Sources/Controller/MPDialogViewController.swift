//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDialogViewController: MPViewController {

    private let titleLabel   = UILabel()
    private let messageLabel = UILabel()

    private let offerProgress = UIActivityIndicatorView( style: .whiteLarge )
    private let offerTitle    = UILabel()
    private let offerButton   = MPButton( track: .subject( "masterpassword", action: "subscribe" ), title: "Subscribe" )
    private let offerLabel    = UILabel()

    private lazy var cancelButton = MPButton( track: .subject( "users", action: "cancel" ),
                                              image: .icon( "" ), background: false ) { _, _ in
        self.dismiss( animated: true )
    }

    private let scrollView = UIScrollView()
    private let stackView  = UIStackView()

    // MARK: --- Life ---

//    required init?(coder aDecoder: NSCoder) {
//        fatalError( "init(coder:) is not supported for this class" )
//    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.backgroundView.mode = .panel
        self.backgroundView.image = UIImage( named: "logo" )

        self.titleLabel => \.font => Theme.current.font.title1
        self.titleLabel.numberOfLines = 0
        self.titleLabel.textAlignment = .center
        self.titleLabel.text = "Migrating From Master Password"

        self.messageLabel => \.font => Theme.current.font.body
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center
        self.messageLabel.text =
                """
                10 years ago I began development on the concept of Master Password.
                This level of privacy and security was only possible by going back to first principles.

                Spectre marks a complete overhaul and the foundation for new things to come.

                Making it possible is a new support model: our Premium subscription.
                All core functionality remains free, forever.

                You made all of this possible.
                From my heart, thank you.

                — Maarten Billemont
                """

        self.offerTitle => \.textColor => Theme.current.color.body
        self.offerTitle.textAlignment = .center
        self.offerTitle => \.font => Theme.current.font.headline
        self.offerTitle.numberOfLines = 0
        self.offerTitle.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.offerTitle.text = "From Us To You"

        self.offerLabel => \.textColor => Theme.current.color.secondary
        self.offerLabel.textAlignment = .center
        self.offerLabel => \.font => Theme.current.font.caption1
        self.offerLabel.numberOfLines = 0
        self.offerLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )

        self.offerProgress.startAnimating()
        self.offerTitle.isHidden = true
        self.offerButton.isHidden = true
        self.offerLabel.isHidden = true
        AppStore.shared.update( active: true ).finally( on: .main ) {
            self.offerProgress.isHidden = true
        }.success( on: .main ) {
            guard $0, let product = InAppProduct.premiumMasterPassword.product ?? InAppProduct.premiumAnnual.product
            else { return }

            if let introductoryPrice = product.introductoryPrice {
                self.offerButton.title = "\(introductoryPrice.localizedOffer) access to Premium for \(introductoryPrice.localizedValidity)"
                self.offerLabel.text = "Then \(product.localizedOffer()). \(product.localizedDescription)"
            }
            else {
                self.offerButton.title = product.localizedOffer()
                self.offerLabel.text = product.localizedDescription
            }

            self.offerButton.action( for: .primaryActionTriggered ) {
                AppStore.shared.purchase( product: product )
            }

            self.offerTitle.isHidden = false
            self.offerButton.isHidden = false
            self.offerLabel.isHidden = false
        }

        self.stackView.axis = .vertical
        self.stackView.spacing = 12
        self.stackView.isLayoutMarginsRelativeArrangement = true
        self.stackView.layoutMargins = UIEdgeInsets( top: 108, left: 8, bottom: 40, right: 8 )

        // - Hierarchy
        self.view.addSubview( self.scrollView )
        self.scrollView.addSubview( self.stackView )
        self.stackView.addArrangedSubview( self.titleLabel )
        self.stackView.addArrangedSubview( self.messageLabel )
        self.stackView.addArrangedSubview( self.offerProgress )
        self.stackView.addArrangedSubview( self.offerTitle )
        self.stackView.addArrangedSubview( self.offerButton )
        self.stackView.addArrangedSubview( self.offerLabel )
        self.view.addSubview( self.cancelButton )

        // - Layout
        LayoutConfiguration( view: self.scrollView ).constrain( as: .box ).activate()
        LayoutConfiguration( view: self.stackView ).constrain( as: .box )
                                                   .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                                                   .activate()
        LayoutConfiguration( view: self.cancelButton ).constrain( as: .bottomCenter, margin: true ).activate()
    }
}
