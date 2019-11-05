//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesViewController: MPUserViewController, UITextFieldDelegate, MPSitesViewObserver {
    private lazy var topContainer = MPButton( content: self.searchField )
    private let searchField              = UITextField()
    private let userButton               = UIButton( type: .custom )
    private let sitesTableView           = MPSitesTableView()
    private let sitePreviewController    = MPSitePreviewController()
    private let sitePreviewConfiguration = LayoutConfiguration()
    private let detailsHost              = MPDetailsHostController()

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

    override var next:                                       UIResponder? {
        self.detailsHost
    }
    private var  activeChild:                                UIViewController? {
        self.sitePreviewConfiguration.activated ? self.sitePreviewController: self.detailsHost.isShowing ? self.detailsHost: nil
    }
    override var childForStatusBarStyle:                     UIViewController? {
        self.activeChild
    }
    override var childForStatusBarHidden:                    UIViewController? {
        self.activeChild
    }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        self.activeChild
    }
    override var childForHomeIndicatorAutoHidden:            UIViewController? {
        self.activeChild
    }
    override var preferredStatusBarStyle:                    UIStatusBarStyle {
        // TODO: depend on theme
        .lightContent
    }

    override func viewDidLoad() {

        // - View
        self.topContainer.isBackgroundDark = true

        self.searchField.attributedPlaceholder = stra( "Site Name", [
            NSAttributedString.Key.foregroundColor: appConfig.theme.color.secondary.get()!.withAlphaComponent( 0.382 )
        ] )
        self.searchField.textColor = appConfig.theme.color.body.get()
        self.searchField.rightView = self.userButton
        self.searchField.rightViewMode = .unlessEditing
        self.searchField.clearButtonMode = .whileEditing
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
            self.detailsHost.show( MPUserDetailsViewController( model: self.user ) )
            self.setNeedsStatusBarAppearanceUpdate()
        }
        //self.userButton.setImage( self.user.avatar.image(), for: .normal )
        self.userButton.sizeToFit()

        self.sitesTableView.observers.register( observer: self )
        self.sitesTableView.keyboardDismissMode = .onDrag

        if #available( iOS 11.0, * ) {
            self.sitesTableView.contentInsetAdjustmentBehavior = .never
        }

        // - Hierarchy
        self.addChild( self.sitePreviewController )
        self.addChild( self.detailsHost )
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.sitePreviewController.view )
        self.view.addSubview( self.detailsHost.view )
        self.view.addSubview( self.topContainer )
        self.sitePreviewController.didMove( toParent: self )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.sitePreviewController.view )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalTo: $1.widthAnchor, multiplier: 0.382 ) }
                .activate()

        LayoutConfiguration( view: self.sitesTableView )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.sitePreviewController.view.bottomAnchor ) }
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
                        $1.topAnchor.constraint( greaterThanOrEqualTo: self.sitePreviewController.view.layoutMarginsGuide.bottomAnchor )
                                    .withPriority( UILayoutPriority( 510 ) ),
                        $1.bottomAnchor.constraint( lessThanOrEqualTo: self.detailsHost.contentView.topAnchor, constant: 8 )
                                       .withPriority( UILayoutPriority( 520 ) ),
                        $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ),
                        $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ),
                        $1.heightAnchor.constraint( equalToConstant: 50 ),
                    ]
                }
                .activate()

        self.sitePreviewConfiguration
                .apply( LayoutConfiguration( view: self.sitePreviewController.view )
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
            if self.sitePreviewController.view.frame.maxY <= 0 {
                self.detailsHost.additionalSafeAreaInsets = UIEdgeInsets(
                        top: self.topContainer.frame.maxY
                                - self.view.safeAreaInsets.top, left: 0, bottom: 0, right: 0 )
            }
            else {
                self.detailsHost.additionalSafeAreaInsets = UIEdgeInsets(
                        top: self.sitePreviewController.view.frame.maxY + (self.topContainer.frame.size.height + 8) / 2
                                - self.view.safeAreaInsets.top, left: 0, bottom: 0, right: 0 )
            }
        }
    }

    // MARK: --- MPSitesViewObserver ---

    func siteWasSelected(site selectedSite: MPSite?) {
        DispatchQueue.main.perform {
            UIView.animate( withDuration: 0.618, animations: {
                if let selectedSite = selectedSite {
                    self.sitePreviewController.site = selectedSite
                }
                else {
                    self.detailsHost.hide()
                }

                self.sitePreviewConfiguration.activated = selectedSite != nil
                self.setNeedsStatusBarAppearanceUpdate()
            }, completion: { finished in
                if selectedSite == nil {
                    self.sitePreviewController.site = nil
                }
            } )
        }

        MPFeedback.shared.play( .activate )
    }

    func siteDetailsAction(site: MPSite) {
        DispatchQueue.main.perform {
            self.detailsHost.show( MPSiteDetailsViewController( model: site ) )
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.detailsHost.hide()
        self.setNeedsStatusBarAppearanceUpdate()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
