//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDialogViewController: MPViewController {
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

    private let scrollView   = UIScrollView()
    private let stackView    = UIStackView()
    private let titleLabel   = UILabel()
    private let messageLabel = UILabel()
    private lazy var cancelButton = MPButton( track: .subject( "users", action: "cancel" ),
                                              image: .icon( "" ), background: false ) { _, _ in
        self.dismiss( animated: true )
    }

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

        // - Hierarchy
        self.view.addSubview( self.scrollView )
        self.scrollView.addSubview( self.stackView )
        self.populate(stackView: self.stackView)
        self.view.addSubview( self.cancelButton )

        // - Layout
        LayoutConfiguration( view: self.scrollView ).constrain( as: .box ).activate()
        LayoutConfiguration( view: self.stackView ).constrain( as: .box )
                                                   .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                                                   .activate()
        LayoutConfiguration( view: self.cancelButton ).constrain( as: .bottomCenter, margin: true ).activate()
    }

    internal func populate(stackView: UIStackView) {
        self.stackView.addArrangedSubview( self.titleLabel )
        self.stackView.addArrangedSubview( self.messageLabel )
    }
}
