//
//  AutoFillUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillUsersViewController: BaseUsersViewController {
    private let configurationView = AutoFillConfigurationView( fromSettings: false )
    private lazy var closeButton = EffectButton( track: .subject( "users", action: "close" ),
                                                 image: .icon( "" ), border: 0, background: false, square: true ) { [unowned self] _, _ in
        self.extensionContext?.cancelRequest( withError: ASExtensionError( .userCanceled, "Close button pressed." ) )
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.insertSubview( self.configurationView, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.closeButton, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.configurationView )
                .constrain { $1.view!.contentLayoutGuide.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor ) }
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.closeButton )
                .constrain( as: .bottomCenter, margin: true ).activate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        // Necessary to ensure usersCarousel is fully laid-out; selection in empty collection view leads to a hang in -selectItemAtIndexPath.
        self.view.layoutIfNeeded()

        if let userName = AutoFillModel.shared.context.credentialIdentity?.user {
            self.usersCarousel.requestSelection( at: self.usersSource.indexPath( where: { $0?.userName == userName } ) )
        }
        else if self.usersSource.count() == 1, let only = self.usersSource.elements().first( where: { _ in true } )?.indexPath {
            self.usersCarousel.requestSelection( at: only )
        }
    }

    // MARK: --- Interface ---

    override func sections(for userFiles: [Marshal.UserFile]) -> [[Marshal.UserFile?]] {
        [ userFiles.filter( { $0.autofill } ).sorted() ]
    }

    // MARK: --- MarshalObserver ---

    override func userFilesDidChange(_ userFiles: [Marshal.UserFile]) {
        super.userFilesDidChange( userFiles )

        DispatchQueue.main.perform {
            self.configurationView.isHidden = !self.usersSource.isEmpty
        }
    }

    // MARK: --- Types ---

    override func login(user: User) {
        super.login( user: user )

        self.detailsHost.show( AutoFillSitesViewController( user: user ), sender: self )
    }
}
