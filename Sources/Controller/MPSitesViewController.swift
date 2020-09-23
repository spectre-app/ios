//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesViewController: MPUserViewController, UITextFieldDelegate, MPSitesViewObserver {
    private lazy var topContainer = MPEffectView( content: self.searchField )
    private let searchField    = UITextField()
    private let userButton     = MPButton( identifier: "sites #user_settings" )
    private let sitesTableView = MPSitesTableView()
    private let detailsHost    = MPDetailsHostController()

    override var user: MPUser {
        didSet {
            DispatchQueue.main.perform {
                self.userButton.title = self.user.fullName.name( style: .abbreviated )
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
        self.detailsHost.isShowing ? self.detailsHost: nil
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
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.searchField.attributedPlaceholder = NSAttributedString( string: "Site Name" )
        self.searchField => \.attributedPlaceholder => .font => Theme.current.font.body
        self.searchField => \.attributedPlaceholder => .foregroundColor => Theme.current.color.placeholder
        self.searchField => \.textColor => Theme.current.color.body
        self.searchField.rightView = self.userButton
        self.searchField.rightViewMode = .unlessEditing
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.clearsOnBeginEditing = true
        self.searchField.keyboardAppearance = .dark
        self.searchField.keyboardType = .URL
        self.searchField.textContentType = .URL
        self.searchField.autocapitalizationType = .none
        self.searchField.autocorrectionType = .no
        self.searchField.returnKeyType = .done
        self.searchField.delegate = self
        self.searchField.action( for: .editingChanged ) { [unowned self] in
            self.sitesTableView.query = self.searchField.text
        }

        self.userButton.isRound = true
        self.userButton.button.action( for: .primaryActionTriggered ) { [unowned self] in
            self.detailsHost.show( MPUserDetailsViewController( model: self.user ) )
            self.setNeedsStatusBarAppearanceUpdate()
        }

        self.sitesTableView.observers.register( observer: self )
        self.sitesTableView.keyboardDismissMode = .onDrag
        self.sitesTableView.contentInsetAdjustmentBehavior = .always

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.detailsHost.view )
        self.view.addSubview( self.topContainer )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.sitesTableView )
                .constrain()
                .activate()

        LayoutConfiguration( view: self.detailsHost.view )
                .constrain()
                .activate()

        LayoutConfiguration( view: self.topContainer )
                .constrainToAll {
                    [
                        $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ),
                        $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor, constant: 8 )
                                    .with( priority: UILayoutPriority( 500 ) ),
                        $1.bottomAnchor.constraint( lessThanOrEqualTo: self.detailsHost.contentView.topAnchor, constant: 8 )
                                       .with( priority: UILayoutPriority( 520 ) ),
                        $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ),
                        $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ),
                        $1.heightAnchor.constraint( equalToConstant: 50 ),
                    ]
                }
                .activate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset sites content's top inset to make space for the top container.
        let top = self.sitesTableView.convert( self.topContainer.bounds.bottom, from: self.topContainer ).y - 8
        self.sitesTableView.contentInset.top = max( 0, top - self.sitesTableView.bounds.origin.y - self.sitesTableView.safeAreaInsets.top )

        // Add space consumed by header and top container to details safe area.
        self.detailsHost.additionalSafeAreaInsets.top = self.topContainer.frame.maxY - self.view.safeAreaInsets.top
    }

    // MARK: --- MPSitesViewObserver ---

    func siteWasSelected(site selectedSite: MPSite?) {
        DispatchQueue.main.perform {
            UIView.animate( withDuration: .long, animations: {
                if selectedSite == nil {
                    self.detailsHost.hide()
                }

                self.setNeedsStatusBarAppearanceUpdate()
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
