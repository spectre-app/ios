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

    override init() {
        super.init()

        self.userFilesDidChange( AutoFillModel.shared.userFiles )
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        if let userName = AutoFillModel.shared.context.credentialIdentity?.user {
            self.selectedFile = self.fileSource.firstElement( where: { $0?.fullName == userName } )
        }
    }

    // MARK: --- Types ---

    override func login(user: MPUser) {
        super.login( user: user )

        self.detailsHost.show( AutoFillServicesViewController( user: user ), sender: self )
    }
}
