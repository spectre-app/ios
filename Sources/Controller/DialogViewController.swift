//==============================================================================
// Created by Maarten Billemont on 2019-07-05.
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

class DialogViewController: BaseViewController {
    override var title: String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }
    var message: String? {
        didSet {
            self.messageLabel.text = self.message
        }
    }

    var closeButton = EffectButton( track: .subject( "users", action: "cancel" ),
                                    image: .icon( "×", style: .regular ), border: 0, background: false, square: true )

    private let scrollView   = UIScrollView()
    private let stackView    = UIStackView()
    private let titleLabel   = UILabel()
    private let messageLabel = UILabel()

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        self.backgroundView.mode = .panel
        self.backgroundView.image = UIImage( named: "logo" )

        self.titleLabel => \.font => Theme.current.font.title1
        self.titleLabel.numberOfLines = 0
        self.titleLabel.textAlignment = .center

        self.messageLabel => \.font => Theme.current.font.body
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center

        self.stackView.axis = .vertical
        self.stackView.spacing = 12
        self.stackView.isLayoutMarginsRelativeArrangement = true
        self.stackView.layoutMargins = UIEdgeInsets( top: 108, left: 8, bottom: 40, right: 8 )

        self.closeButton.action( for: .primaryActionTriggered ) { [unowned self] in
            self.dismiss( animated: true )
        }

        // - Hierarchy
        self.view.addSubview( self.scrollView )
        self.scrollView.addSubview( self.stackView )
        self.populate( stackView: self.stackView )
        self.view.addSubview( self.closeButton )

        // - Layout
        LayoutConfiguration( view: self.scrollView )
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.stackView )
                .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                .constrain( as: .box )
                .activate()
        LayoutConfiguration( view: self.closeButton )
                .constrain( as: .bottomCenter, margin: true ).activate()
    }

    internal func populate(stackView: UIStackView) {
        self.stackView.addArrangedSubview( self.titleLabel )
        self.stackView.addArrangedSubview( self.messageLabel )
    }
}
