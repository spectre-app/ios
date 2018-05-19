//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UISearchBarDelegate {
    private let topContainer    = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    private let bottomContainer = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    private let searchField     = UISearchBar()
    private let sitesView       = MPSitesView()
    private let userNameLabel   = UILabel()

    var user: MPUser? {
        didSet {
            self.userNameLabel.text = self.user?.fullName
            self.sitesView.user = self.user
        }
    }

    // MARK: - Life

    override func viewDidLoad() {

        self.searchField.delegate = self
        self.searchField.placeholder = "Site name"
        self.searchField.searchBarStyle = .minimal
        self.searchField.keyboardAppearance = .dark

        if #available( iOS 11.0, * ) {
            self.sitesView.contentInsetAdjustmentBehavior = .never
        }

        self.userNameLabel.font = UIFont( name: "Exo2.0-Regular", size: 34 )
        self.userNameLabel.textAlignment = .center
        self.userNameLabel.textColor = .white
        self.userNameLabel.numberOfLines = 0

        self.view.addSubview( self.sitesView )
        self.view.addSubview( self.topContainer )
        self.topContainer.contentView.addSubview( self.searchField )
        self.view.addSubview( self.bottomContainer )
        self.bottomContainer.contentView.addSubview( self.userNameLabel )

        ViewConfiguration( view: self.sitesView )
                .addConstrainedInSuperview()
                .activate()

        ViewConfiguration( view: self.topContainer )
                .add { $0.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.bottomContainer )
                .add { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()

        ViewConfiguration( view: self.searchField )
                .addConstrainedInSuperviewMargins()
                .activate()

        ViewConfiguration( view: self.userNameLabel )
                .addConstrainedInSuperviewMargins()
                .activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.sitesView.bottomAnchor ) ]
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Inset sites scroll content from overlaying top and bottom container.
        self.sitesView.contentInset = UIEdgeInsetsUnionEdgeInsets(
                UIEdgeInsetsForRectSubtractingRect( self.sitesView.frame, self.topContainer.frame ),
                UIEdgeInsetsForRectSubtractingRect( self.sitesView.frame, self.bottomContainer.frame ) )
    }
}
