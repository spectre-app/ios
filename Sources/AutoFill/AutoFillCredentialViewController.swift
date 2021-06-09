//==============================================================================
// Created by Maarten Billemont on 2018-01-21.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit
import AuthenticationServices

class AutoFillCredentialViewController: BaseUsersViewController {
    private lazy var closeButton = EffectButton( track: .subject( "users", action: "close" ),
                                                 image: .icon( "" ), border: 0, background: false, square: true ) { [unowned self] _, _ in
        self.extensionContext?.cancelRequest( withError: ASExtensionError( .userCanceled, "Close button pressed." ) )
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.insertSubview( self.closeButton, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.closeButton )
                .constrain( as: .bottomCenter, margin: true ).activate()
    }

    // MARK: --- MarshalObserver ---

    override func userFilesDidChange(_ userFiles: [Marshal.UserFile]) {
        if let userFile = AutoFillModel.shared.context.credentialIdentity.flatMap( { credentialIdentity in
            userFiles.first( where: { $0.userName == credentialIdentity.user } )
        } ) {
            self.usersSource.update( [ [ userFile ] ], selected: [ userFile ] )
        }
        else {
            self.extensionContext?.cancelRequest( withError: ASExtensionError( .failed, "Expected a credential identity." ) )
        }
    }

    // MARK: --- Types ---

    override func login(user: User) {
        super.login( user: user )

        AutoFillModel.shared.cacheUser( user )

        guard let credentialIdentity = AutoFillModel.shared.context.credentialIdentity
        else {
            self.extensionContext?.cancelRequest( withError: ASExtensionError( .failed, "Expected a credential identity." ) )
            return
        }

        guard   let site = user.sites.first( where: { $0.siteName == credentialIdentity.serviceIdentifier.identifier } )
        else {
            self.extensionContext?.cancelRequest( withError: ASExtensionError(
                    .credentialIdentityNotFound, "No site named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.userName)" ) )
            return
        }

        site.result( keyPurpose: .identification ).token.and( site.result( keyPurpose: .authentication ).token ).success {
            (self.extensionContext as? ASCredentialProviderExtensionContext)?.completeRequest(
                    withSelectedCredential: ASPasswordCredential( user: $0.0, password: $0.1 ), completionHandler: nil )
        }.failure { error in
            mperror( title: "Couldn't compute site result", error: error )
            self.extensionContext?.cancelRequest( withError: ASExtensionError( .failed, "Couldn't compute site result." ) )
        }
    }
}
