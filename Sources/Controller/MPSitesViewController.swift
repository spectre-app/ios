//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UITextFieldDelegate, MPSiteViewObserver, MPSitesViewObserver {
    private lazy var topContainer = MPButton( content: self.searchField )
    private let searchField = UITextField()
    private let userButton  = UIButton( type: .custom )
    private let sitesView   = MPSitesView()
    private let siteView    = MPSiteView()

    private let siteViewConfiguration = ViewConfiguration()

    var         user: MPUser? {
        didSet {
            self.sitesView.user = self.user

            var userButtonTitle = ""
            self.user?.fullName.split( separator: " " ).forEach { word in userButtonTitle.append( word[word.startIndex] ) }
            self.userButton.setTitle( userButtonTitle.uppercased(), for: .normal )
            self.userButton.sizeToFit()
        }
    }

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser) {
        super.init( nibName: nil, bundle: nil )

        defer {
            self.user = user
        }
    }

    override func viewDidLoad() {

        // - View
        self.topContainer.darkBackground = true

        self.searchField.textColor = .white
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
        self.searchField.delegate = self
        self.searchField.addTarget( self, action: #selector( textFieldEditingChanged ), for: .editingChanged )

        self.userButton.setImage( UIImage( named: "icon_user" ), for: .normal )
        self.userButton.sizeToFit()

        self.siteView.observers.register( self )

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
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: self.siteView.layoutMarginsGuide.bottomAnchor ) }
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

        // Offset sites content's top margin to make space for the top container.
        let top = self.sitesView.convert( CGRectGetBottom( self.topContainer.bounds ), from: self.topContainer ).y
        self.sitesView.contentInset = UIEdgeInsetsMake( max( 0, top - self.sitesView.bounds.origin.y ), 0, 0, 0 )
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - MPSiteViewObserver

    func siteWasActivated(activatedSite: MPSite) {
        PearlMainQueue {
            self.present( MPSiteDetailsViewController( site: activatedSite ), animated: true )
        }
    }

    // MARK: - MPSitesViewObserver

    func siteWasSelected(selectedSite: MPSite?) {
        PearlMainQueue {
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

    // MARK: - UITextFieldDelegate
    @objc
    func textFieldEditingChanged(_ textField: UITextField) {
        self.sitesView.query = self.searchField.text
    }
}
