//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillUsersViewController: BasicUsersViewController {
    private lazy var cancelButton = MPButton( identifier: "autofill #cancel", image: .icon( "" ), background: false ) { _, _ in
        self.extensionContext?.cancelRequest( withError: ASExtensionError( .userCanceled, "Cancel button pressed." ) )
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(userFiles: [MPMarshal.UserFile]) {
        super.init()

        self.userFilesDidChange( userFiles )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.insertSubview( self.cancelButton, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.cancelButton )
                .constrain( margins: true, anchors: .bottomCenter )
                .activate()
    }

    // MARK: --- Types ---

    override func login(user: MPUser) {
        super.login( user: user )

        self.detailsHost.show( AutoFillSitesViewController( user: user ), sender: self )
    }
}
