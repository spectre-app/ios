//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesViewController: MPUserViewController, UITextFieldDelegate, MPSiteHeaderObserver, MPSitesViewObserver {
    private lazy var topContainer = MPButton( content: self.searchField )
    private let searchField             = UITextField()
    private let userButton              = UIButton( type: .custom )
    private let sitesTableView          = MPSitesTableView()
    private let siteHeaderView          = MPSiteHeaderView()
    private let siteHeaderConfiguration = LayoutConfiguration()
    private let detailsHost             = MPDetailsHostController()

    override var user: MPUser {
        didSet {
            DispatchQueue.main.perform {
                var userButtonTitle = ""
                self.user.fullName.split( separator: " " ).forEach { word in userButtonTitle.append( word[word.startIndex] ) }
                self.userButton.setTitle( userButtonTitle.uppercased(), for: .normal )
                self.userButton.sizeToFit()

                self.sitesTableView.user = self.user
            }
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {

        // - View
        self.topContainer.darkBackground = true

        self.searchField.attributedPlaceholder = stra( "Site Name", [
            NSAttributedString.Key.foregroundColor: MPTheme.global.color.secondary.get()!.withAlphaComponent( 0.382 )
        ] )
        self.searchField.textColor = MPTheme.global.color.body.get()
        self.searchField.rightView = self.userButton
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.rightViewMode = .unlessEditing
        self.searchField.keyboardAppearance = .dark
        self.searchField.keyboardType = .URL
        if #available( iOS 10.0, * ) {
            self.searchField.textContentType = .URL
        }
        self.searchField.autocapitalizationType = .none
        self.searchField.autocorrectionType = .no
        self.searchField.returnKeyType = .done
        self.searchField.delegate = self
        self.searchField.addAction( for: .editingChanged ) { _, _ in
            self.sitesTableView.query = self.searchField.text
        }

        self.userButton.addAction( for: .touchUpInside ) { _, _ in
            if !self.detailsHost.hideDetails() {
                self.detailsHost.showDetails( MPUserDetailsViewController( model: self.user ) )
            }
        }
        //self.userButton.setImage( self.user.avatar.image(), for: .normal )
        self.userButton.sizeToFit()

        self.siteHeaderView.observers.register( observer: self )

        self.sitesTableView.observers.register( observer: self )
        self.sitesTableView.keyboardDismissMode = .onDrag

        if #available( iOS 11.0, * ) {
            self.sitesTableView.contentInsetAdjustmentBehavior = .never
        }

        // - Hierarchy
        self.addChild( self.detailsHost )
        defer {
            self.detailsHost.didMove( toParent: self )
        }
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.siteHeaderView )
        self.view.addSubview( self.detailsHost.view )
        self.view.addSubview( self.topContainer )

        // - Layout
        LayoutConfiguration( view: self.siteHeaderView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor, multiplier: 0.382 ) }
                .activate()

        LayoutConfiguration( view: self.sitesTableView )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.siteHeaderView.bottomAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        LayoutConfiguration( view: self.detailsHost.view )
                .constrainToOwner()
                .activate()

        LayoutConfiguration( view: self.topContainer )
                .constrainToAll {
                    [
                        $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ),
                        $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor, constant: 8 )
                                    .withPriority( UILayoutPriority( 500 ) ),
                        $1.topAnchor.constraint( greaterThanOrEqualTo: self.siteHeaderView.layoutMarginsGuide.bottomAnchor )
                                    .withPriority( UILayoutPriority( 510 ) ),
                        $1.bottomAnchor.constraint( lessThanOrEqualTo: self.detailsHost.contentView.topAnchor, constant: 8 )
                                       .withPriority( UILayoutPriority( 520 ) ),
                        $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ),
                        $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ),
                        $1.heightAnchor.constraint( equalToConstant: 50 ),
                    ]
                }
                .activate()

        self.siteHeaderConfiguration
                .apply( LayoutConfiguration( view: self.siteHeaderView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: true )
                .apply( LayoutConfiguration( view: self.sitesTableView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: false )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset sites content's top inset to make space for the top container.
        let top = self.sitesTableView.convert( CGRectGetBottom( self.topContainer.bounds ), from: self.topContainer ).y - 8
        self.sitesTableView.contentInset = UIEdgeInsets(
                top: max( 0, top - self.sitesTableView.bounds.origin.y ), left: 0, bottom: 0, right: 0 )

        // Add space consumed by header and top container to details safe area.
        if #available( iOS 11, * ) {
            if self.siteHeaderView.frame.maxY <= 0 {
                self.detailsHost.additionalSafeAreaInsets = UIEdgeInsets(
                        top: self.topContainer.frame.maxY
                                - self.view.safeAreaInsets.top, left: 0, bottom: 0, right: 0 )
            }
            else {
                self.detailsHost.additionalSafeAreaInsets = UIEdgeInsets(
                        top: self.siteHeaderView.frame.maxY + (self.topContainer.frame.size.height + 8) / 2
                                - self.view.safeAreaInsets.top, left: 0, bottom: 0, right: 0 )
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    // MARK: --- MPSiteHeaderObserver ---

    func shouldOpenDetails(forSite site: MPSite) {
        if !self.detailsHost.hideDetails() {
            self.detailsHost.showDetails( MPSiteDetailsViewController( model: site ) )
        }
    }

    // MARK: --- MPSitesViewObserver ---

    func siteWasSelected(selectedSite: MPSite?) {
        DispatchQueue.main.perform {
            UIView.animate( withDuration: 1, animations: {
                if let selectedSite = selectedSite {
                    self.siteHeaderView.site = selectedSite
                }
                else {
                    self.detailsHost.hideDetails()
                    self.searchField.text = nil
                    self.sitesTableView.query = nil
                }

                self.siteHeaderConfiguration.activated = selectedSite != nil;
            }, completion: { finished in
                if selectedSite == nil {
                    self.siteHeaderView.site = nil
                }
            } )
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.detailsHost.hideDetails()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
