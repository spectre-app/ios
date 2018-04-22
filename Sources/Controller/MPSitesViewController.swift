//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

@available(iOS 10.0, *)
class MPSitesViewController: UIViewController, UISearchBarDelegate {
    private let user = MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 )

    private let topContainer  = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    private let searchField   = UISearchBar()
    private let userNameLabel = UILabel()
    private let sitesView     = MPSitesView()

    // MARK: - Life

    override func viewDidLoad() {
        self.searchField.delegate = self
        self.searchField.placeholder = "Site name"
        self.searchField.searchBarStyle = .minimal
        self.searchField.keyboardAppearance = .dark

        self.userNameLabel.font = UIFont( name: "Exo2.0-Regular", size: 34 )
        self.userNameLabel.textAlignment = .center
        self.userNameLabel.textColor = .white
        self.userNameLabel.numberOfLines = 0

        self.view.addSubview( self.topContainer )
        self.topContainer.contentView.addSubview( self.searchField )
        self.view.addSubview( self.userNameLabel )
        self.view.addSubview( self.sitesView )

        ViewConfiguration( view: self.topContainer )
                .add { $0.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.searchField )
                .addConstrainedInSuperviewMargins()
                .activate()

        ViewConfiguration( view: self.sitesView )
                .add { self.topContainer.bottomAnchor.constraint( equalTo: $1.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .add { self.userNameLabel.topAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()

        ViewConfiguration( view: self.userNameLabel )
                .add { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .add { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.sitesView.bottomAnchor ) ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.userNameLabel.text = self.user.fullName
        self.sitesView.user = self.user
    }
}
