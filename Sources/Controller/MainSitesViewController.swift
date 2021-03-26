//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MainSitesViewController: BaseSitesViewController {
    private let userButton  = EffectButton( track: .subject( "sites", action: "user" ) )
    private let detailsHost = DetailHostController()

    override var user: User? {
        didSet {
            DispatchQueue.main.perform {
                self.userButton.title = self.user?.userName.name( style: .abbreviated )
                self.userButton.sizeToFit()
            }
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.userButton.isCircular = true
        self.userButton.action( for: .primaryActionTriggered ) { [unowned self] in
            if let user = self.user {
                self.detailsHost.show( DetailUserViewController( model: user ), sender: self )
            }
        }
        self.searchField.rightView = self.userButton
        self.sitesTableView.siteActions = [
            .init( tracking: .subject( "sites.site", action: "settings" ),
                   title: "Details", icon: "", appearance: [ .cell, .menu ] ) { [unowned self] site, mode, appearance in
                self.detailsHost.show( DetailSiteViewController( model: site ), sender: self )
            },
            .init( tracking: .subject( "sites.site", action: "copy" ),
                   title: "Copy", icon: "", appearance: [ .cell ] ) { [unowned self] site, mode, appearance in
                site.result( keyPurpose: mode! ).copy( fromView: self.view, trackingFrom: "site>cell" )
            },
            .init( tracking: .subject( "sites.site", action: "mode" ),
                   title: "Configure", icon: "", appearance: [ .mode ] ) { [unowned self] site, mode, appearance in
                switch mode {
                    case .authentication:
                        self.detailsHost.show( DetailSiteViewController( model: site, focus: DetailSiteViewController.PasswordTypeItem.self ), sender: self )
                    case .identification:
                        self.detailsHost.show( DetailSiteViewController( model: site, focus: DetailSiteViewController.LoginTypeItem.self ), sender: self )
                    case .recovery:
                        self.detailsHost.show( DetailSiteViewController( model: site, focus: DetailSiteViewController.SecurityAnswerItem.self ), sender: self )
                    case .none, .some( _ ):
                        self.detailsHost.show( DetailSiteViewController( model: site ), sender: self )
                }
            },
            .init( tracking: .subject( "sites.site", action: "copy" ),
                   title: "Copy Login", icon: "", appearance: [ .menu ] ) { [unowned self] site, mode, appearance in
                site.result( keyPurpose: .identification ).copy( fromView: self.view, trackingFrom: "site>cell>menu" )
            },
            .init( tracking: .subject( "sites.site", action: "copy" ),
                   title: "Copy Password", icon: "", appearance: [ .menu ] ) { [unowned self] site, mode, appearance in
                site.result( keyPurpose: .authentication ).copy( fromView: self.view, trackingFrom: "site>cell>menu" )
            },
        ]

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.insertSubview( self.detailsHost.view, belowSubview: self.topContainer )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.detailsHost.view )
                .constrain { _, _ in
                    self.detailsHost.contentView.topAnchor.constraint( greaterThanOrEqualTo: self.topContainer.bottomAnchor, constant: -8 )
                                                          .with( priority: UILayoutPriority( 520 ) )
                }
                .constrain( as: .box )
                .activate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Add space consumed by header and top container to details safe area.
        self.detailsHost.additionalSafeAreaInsets.top = self.topContainer.frame.maxY - self.view.safeAreaInsets.top
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.detailsHost.hide()
    }
}
