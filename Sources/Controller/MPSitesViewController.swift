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
                .add { $0.topAnchor.constraint( equalTo: self.view.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.searchField )
                .add { $0.topAnchor.constraint( equalTo: $0.superview!.layoutMarginsGuide.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: $0.superview!.layoutMarginsGuide.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: $0.superview!.layoutMarginsGuide.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: $0.superview!.layoutMarginsGuide.bottomAnchor ) }
                .activate()

        ViewConfiguration( view: self.sitesView )
                .add { $0.topAnchor.constraint( equalTo: self.topContainer.bottomAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.userNameLabel.topAnchor ) }
                .activate()

        ViewConfiguration( view: self.userNameLabel )
                .add { $0.leadingAnchor.constraint( equalTo: self.view.layoutMarginsGuide.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.view.layoutMarginsGuide.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.view.layoutMarginsGuide.bottomAnchor ) }
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
