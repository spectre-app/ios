//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UISearchBarDelegate, MPSitesViewObserver {
    private lazy var topContainer = MPButton( subview: self.searchField )
    private let searchField = UITextField()
    private let userButton  = UIButton( type: .custom )
    private let sitesView   = MPSitesView()
    private let siteView    = MPSiteView()

    private let siteViewConfiguration = ViewConfiguration()

    var user: MPUser? {
        didSet {
            self.sitesView.user = self.user

            var userButtonTitle = ""
            self.user?.fullName.split( separator: " " ).forEach { word in userButtonTitle.append( word[word.startIndex] ) }
            self.userButton.setTitle( userButtonTitle.uppercased(), for: .normal )
            self.userButton.sizeToFit()
        }
    }

    // MARK: - Life

    override func viewDidLoad() {

        self.userButton.setImage( UIImage( named: "icon_person" ), for: .normal )
        self.userButton.sizeToFit()

        self.searchField.textColor = .white
        self.searchField.rightView = self.userButton
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.rightViewMode = .unlessEditing
        self.searchField.keyboardAppearance = .dark
        self.searchField.keyboardType = .URL
        self.searchField.autocapitalizationType = .none
        self.searchField.autocorrectionType = .no
        if #available( iOS 10.0, * ) {
            self.searchField.textContentType = .URL
        }

        self.sitesView.observers.register( self )
        self.sitesView.keyboardDismissMode = .onDrag

        if #available( iOS 11.0, * ) {
            self.sitesView.contentInsetAdjustmentBehavior = .never
        }

        // - Hierarchy
        self.view.addSubview( self.sitesView )
        self.view.addSubview( self.siteView )
        self.view.addSubview( self.topContainer )

        // - Layout
        ViewConfiguration( view: self.siteView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.sitesView )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.siteView.bottomAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        siteViewConfiguration
                .apply( ViewConfiguration( view: self.siteView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: true )
                .apply( ViewConfiguration( view: self.sitesView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: false )

        ViewConfiguration( view: self.sitesView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        ViewConfiguration( view: self.topContainer )
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ) }
                .constrainTo { $1.centerYAnchor.constraint( greaterThanOrEqualTo: self.siteView.bottomAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ) }
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 50 ) }
                .activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.sitesView.bottomAnchor ) ]
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset site content's bottom margin to make space for the top container.
        self.siteView.layoutMargins = UIEdgeInsetsMake( 0, 0, self.topContainer.frame.size.height / 2, 0 )

        // Offset sites content's top margin to make space for the top container.
        let top = self.sitesView.convert( CGRectGetBottom( self.topContainer.bounds ), from: self.topContainer ).y
        self.sitesView.contentInset = UIEdgeInsetsMake( max( 0, top - self.sitesView.bounds.origin.y ), 0, 0, 0 )
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - MPSitesViewObserver

    func siteWasSelected(selectedSite: MPSite?) {
        if let selectedSite = selectedSite {
            self.siteView.site = selectedSite
        }
        UIView.animate( withDuration: 1, animations: {
            self.siteViewConfiguration.activated = selectedSite != nil;
        }, completion: { finished in
            if selectedSite == nil {
                self.siteView.site = nil
            }
        } )
    }
}
