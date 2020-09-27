//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesViewController: BasicSitesViewController {
    private let userButton  = MPButton( identifier: "sites #user_settings" )
    private let detailsHost = MPDetailsHostController()

    override var user: MPUser {
        didSet {
            DispatchQueue.main.perform {
                self.userButton.title = self.user.fullName.name( style: .abbreviated )
                self.userButton.sizeToFit()
            }
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.userButton.isRound = true
        self.userButton.button.action( for: .primaryActionTriggered ) { [unowned self] in
            self.detailsHost.show( MPUserDetailsViewController( model: self.user ), sender: self )
        }
        self.searchField.rightView = self.userButton

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.insertSubview( self.detailsHost.view, belowSubview: self.topContainer )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.detailsHost.view )
                .constrain()
                .constrainTo { _, _ in
                    self.detailsHost.contentView.topAnchor.constraint( greaterThanOrEqualTo: self.topContainer.bottomAnchor, constant: -8 )
                                                          .with( priority: UILayoutPriority( 520 ) )
                }
                .activate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Add space consumed by header and top container to details safe area.
        self.detailsHost.additionalSafeAreaInsets.top = self.topContainer.frame.maxY - self.view.safeAreaInsets.top
    }

    // MARK: --- MPSitesViewObserver ---

    override func siteWasSelected(site selectedSite: MPSite?) {
        super.siteWasSelected( site: selectedSite )

        if selectedSite == nil {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: .long, animations: {
                    self.detailsHost.hide()
                } )
            }
        }
    }

    override func siteDetailsAction(site: MPSite) {
        DispatchQueue.main.perform {
            self.detailsHost.show( MPSiteDetailsViewController( model: site ), sender: self )
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.detailsHost.hide()
    }
}
