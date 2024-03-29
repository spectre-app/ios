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

class DialogMasterPasswordViewController: DialogViewController { // swiftlint:disable:this inclusive_language

    private let offerProgress = UIActivityIndicatorView( style: .large )
    private let offerTitle    = UILabel()
    private let offerButton   = EffectButton( track: .subject( "masterpassword", action: "subscribe" ), title: "Subscribe" )
    private let offerLabel    = UILabel()

    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Migrating From Master Password"
        self.message =
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
    }

    override func populate(stackView: UIStackView) {
        super.populate( stackView: stackView )

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
        AppStore.shared.update( active: true )
                .finally( on: .main ) { self.offerProgress.isHidden = true }
                .success( on: .main ) {
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
                .failure {
                    wrn( "App Store unavailable: %@ [>PII]", $0.localizedDescription )
                    pii( "[>] Error: ", $0 )
                }

        stackView.addArrangedSubview( self.offerProgress )
        stackView.addArrangedSubview( self.offerTitle )
        stackView.addArrangedSubview( self.offerButton )
        stackView.addArrangedSubview( self.offerLabel )
    }
}
