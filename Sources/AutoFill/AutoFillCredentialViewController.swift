// =============================================================================
// Created by Maarten Billemont on 2018-01-21.
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
import AuthenticationServices

class AutoFillCredentialViewController: AutoFillBaseUsersViewController {

    // MARK: - MarshalObserver

    override func items(for userFiles: [Marshal.UserFile]) -> [UserItem] {
        guard let credentialUser = userFiles.first( where: {
            $0.autofill && $0.userName == AutoFillModel.shared.context.credentialIdentity?.user
        } )
        else { return super.items( for: userFiles ) }

        return [ .knownUser( userFile: credentialUser ) ]
    }

    // MARK: - Types

    override func login(user: User) {
        super.login( user: user )

        Task {
            do {
                guard let credentialIdentity = AutoFillModel.shared.context.credentialIdentity
                else {
                    throw ASExtensionError(
                            .failed, "Expected a credential identity." )
                }

                guard let siteName = user.credential( for: credentialIdentity.serviceIdentifier )?.siteName,
                      let site = user.sites.first( where: { $0.siteName == siteName } )
                else {
                    throw ASExtensionError(
                            .credentialIdentityNotFound,
                            "No site named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.userName)" )
                }

                guard let login = try await site.result( keyPurpose: .identification )?.task.value,
                      let password = try await site.result( keyPurpose: .authentication )?.task.value
                else {
                    throw ASExtensionError(
                            .userInteractionRequired, "Unauthenticated user: \(user.userName)" )
                }

                 inf( "Autofilling interactively: %@, for site: %@", login, site.siteName )
                 Feedback.shared.play( .activate )

                 (self.extensionContext as? ASCredentialProviderExtensionContext)?.completeRequest(
                         withSelectedCredential: ASPasswordCredential( user: login, password: password ), completionHandler: nil )
             }
             catch {
                 wrn( "Autofill unsuccessful: %@ [>PII]", error.localizedDescription )
                 pii( "[>] Error: %@", error )
                 Feedback.shared.play( .error )

                 self.extensionContext?.cancelRequest( withError: ASExtensionError(for: error ) )
             }
        }
    }
}
