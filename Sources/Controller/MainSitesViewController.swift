// =============================================================================
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import SafariServices

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

    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.userButton.isCircular = true
        self.userButton.action( for: .primaryActionTriggered ) { [unowned self] in
            if let user = self.user {
                self.detailsHost.show( DetailUserViewController( model: user ), sender: self )
            }
        }
        self.userButton.addGestureRecognizer( UILongPressGestureRecognizer {
            [unowned self] in
            guard case .began = $0.state
            else { return }

            self.user?.logout()
        } )
        self.searchField.rightView = self.userButton
        self.sitesTableView.siteActions = [
            .init( tracking: .subject( "sites.site", action: "settings" ),
                   title: "Details", icon: .icon( "circle-info", invert: true ), appearance: [ .cell, .menu ] ) {
                [unowned self] site, _, _ in
                self.detailsHost.show( DetailSiteViewController( model: site ), sender: self )
            },
            .init( tracking: .subject( "sites.site", action: "copy" ),
                   title: "Copy", icon: .icon( "copy" ), appearance: [ .cell, .primary ] ) {
                [unowned self] site, purpose, _ in
                site.result( keyPurpose: purpose ?? .authentication )?.copy( fromView: self.view, trackingFrom: "site>cell" )
            },
            .init( tracking: .subject( "sites.site", action: "mode" ),
                   title: "Configure", icon: .icon( "gear" ), appearance: [ .mode ] ) {
                [unowned self] site, purpose, _ in
                let focus: Item<Site>.Type?
                switch purpose {
                    case .authentication:
                        focus = DetailSiteViewController.PasswordTypeItem.self
                    case .identification:
                        focus = DetailSiteViewController.LoginTypeItem.self
                    case .recovery:
                        focus = DetailSiteViewController.SecurityAnswerItem.self
                    case .none, .some( _ ):
                        focus = nil
                }
                self.detailsHost.show( DetailSiteViewController( model: site, focus: focus ), sender: self )
            },
            .init( tracking: .subject( "sites.site", action: "copy", [ "purpose": "\(SpectreKeyPurpose.authentication)" ] ),
                   title: "Copy Password", icon: .icon( "copy" ), appearance: [ .menu ] ) {
                [unowned self] site, purpose, _ in
                site.result( keyPurpose: purpose ?? .authentication )?.copy( fromView: self.view, trackingFrom: "site>cell>menu" )
            },
            .init( tracking: .subject( "sites.site", action: "copy", [ "purpose": "\(SpectreKeyPurpose.identification)" ] ),
                   title: "Copy Login", icon: .icon( "copy" ), appearance: [ .menu, .feature(.logins) ] ) {
                [unowned self] site, purpose, _ in
                site.result( keyPurpose: purpose ?? .identification )?.copy( fromView: self.view, trackingFrom: "site>cell>menu" )
            },
            .init( tracking: .subject( "sites.site", action: "copy", [ "purpose": "\(SpectreKeyPurpose.recovery)" ] ),
                   title: "Copy Security Answer", icon: .icon( "copy" ), appearance: [ .menu, .feature(.answers) ] ) {
                [unowned self] site, purpose, _ in
                site.result( keyPurpose: purpose ?? .recovery )?.copy( fromView: self.view, trackingFrom: "site>cell>menu" )
            },
            .init( tracking: .subject( "sites.site", action: "open" ),
                   title: "Open Site", icon: .icon( "globe" ), appearance: [ .menu, .feature(.premium) ] ) {
                site, _, _ in
                if let url = URL( string: site.url ?? "https://\(site.siteName)" ) {
                    UIApplication.shared.open( url )
                    //self.present( SFSafariViewController( url: url ), animated: true )
                }
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
        self.detailsHost.additionalSafeAreaInsets.top = max( 0, self.topContainer.frame.maxY - self.view.safeAreaInsets.top )
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.detailsHost.hide()
    }
}
