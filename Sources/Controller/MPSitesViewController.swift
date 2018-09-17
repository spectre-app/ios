//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UISearchBarDelegate, MPSitesViewObserver {
    private let topContainer = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    private let searchField  = UISearchBar()
    private let userButton   = MPButton()
    private let sitesView    = MPSitesView()
    private let siteView     = MPSiteView()

    private let siteViewConfiguration = ViewConfiguration()

    var user: MPUser? {
        didSet {
            var userButtonTitle = ""
            self.user?.fullName.split( separator: " " ).forEach { word in userButtonTitle.append( word[word.startIndex] ) }
            self.userButton.setTitle( userButtonTitle.uppercased(), for: .normal )
            self.sitesView.user = self.user
        }
    }

    // MARK: - Life

    override func viewDidLoad() {

        self.topContainer.layer.cornerRadius = 12;
        self.topContainer.layer.masksToBounds = true;

        self.searchField.delegate = self
        self.searchField.placeholder = "Site name"
        self.searchField.searchBarStyle = .minimal
        self.searchField.keyboardAppearance = .dark

        self.userButton.setImage( UIImage( named: "icon_person" ), for: .normal )

        self.sitesView.observers.register( self )

        if #available( iOS 11.0, * ) {
            self.sitesView.contentInsetAdjustmentBehavior = .never
        }

        // - Hierarchy
        self.view.addSubview( self.siteView )
        self.view.addSubview( self.sitesView )
        self.view.addSubview( self.topContainer )
        self.view.addSubview( self.userButton )
        self.topContainer.contentView.addSubview( self.searchField )

        // - Layout
        ViewConfiguration( view: self.siteView )
                .constrainTo { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.sitesView )
                .constrainTo { self.siteView.bottomAnchor.constraint( equalTo: $1.topAnchor ) }
                .constrainTo { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .constrainTo { $0.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()

        siteViewConfiguration
                .apply( ViewConfiguration( view: self.siteView )
                                .constrainTo { $0.topAnchor.constraint( equalTo: $1.topAnchor ) }, active: true )
                .apply( ViewConfiguration( view: self.sitesView )
                                .constrainTo { $0.topAnchor.constraint( equalTo: $1.topAnchor ) }, active: false )

        ViewConfiguration( view: self.sitesView )
                .constrainTo { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .constrainTo { $0.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()

        ViewConfiguration( view: self.topContainer )
                .constrainTo { $0.layoutMarginsGuide.topAnchor.constraint( lessThanOrEqualTo: $1.topAnchor, constant: -8 ) }
                .constrainTo { self.siteView.bottomAnchor.constraint( lessThanOrEqualTo: $1.centerYAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor, constant: -8 ) }
                .constrainTo { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor, constant: 8 ) }
                .activate()

        ViewConfiguration( view: self.searchField )
                .constrainToSuperview()
                .activate()

        ViewConfiguration( view: self.userButton )
                .constrainTo { self.topContainer.bottomAnchor.constraint( equalTo: $1.centerYAnchor ) }
                .constrainTo { self.topContainer.trailingAnchor.constraint( equalTo: $1.trailingAnchor, constant: 40 ) }
                .activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.sitesView.bottomAnchor ) ]
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset site content's bottom margin to make space for the top container.
        self.siteView.layoutMargins = UIEdgeInsetsMake( 8, 8, 8 + self.topContainer.frame.size.height / 2, 8 )

        // Offset sites content's top margin to make space for the top container.
        let top = self.sitesView.convert( CGRectGetBottom( self.topContainer.bounds ), from: self.topContainer ).y
        self.sitesView.contentInset = UIEdgeInsetsMake( max( 0, top - self.sitesView.bounds.origin.y ), 0, 0, 0 )
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - MPSitesViewObserver

    func siteWasSelected(selectedSite: MPSite?) {
        if selectedSite != nil {
            self.siteView.site = selectedSite
        }
        UIView.animate( withDuration: 1, animations: {
            self.siteViewConfiguration.activated = selectedSite != nil;
        }, completion: { finished in
            if selectedSite == nil {
                self.siteView.site = selectedSite
            }
        } )
    }
}
