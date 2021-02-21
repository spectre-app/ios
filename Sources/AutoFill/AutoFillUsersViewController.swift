//
//  MPUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillUsersViewController: BasicUsersViewController {
    private lazy var cancelButton = MPButton( track: .subject( "users", action: "cancel"),
                                              image: .icon( "" ), background: false ) { _, _ in
        self.extensionContext?.cancelRequest( withError: ASExtensionError( .userCanceled, "Cancel button pressed." ) )
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init() {
        super.init()

        self.userFilesDidChange( AutoFillModel.shared.userFiles )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.insertSubview( self.cancelButton, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.cancelButton ).constrain( as: .bottomCenter, margin: true )
                                                      .activate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        if let userName = AutoFillModel.shared.context.credentialIdentity?.user {
            self.usersSpinner.requestSelection( at: self.fileSource.indexPath( where: { $0?.userName == userName } ) )
        }
        else if self.fileSource.count() == 1, let only = self.fileSource.elements().first( where: { _ in true } )?.indexPath {
            self.usersSpinner.requestSelection( at: only )
        }
    }

    // MARK: --- MPMarshalObserver ---

    override func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]) {
        self.fileSource.update( [ userFiles.filter( { $0.autofill } ).sorted() ] )
    }

    // MARK: --- Types ---

    override func login(user: MPUser) {
        super.login( user: user )

        self.detailsHost.show( AutoFillSitesViewController( user: user ), sender: self )
    }
}
