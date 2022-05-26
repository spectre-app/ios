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

class AutoFillBaseUsersViewController: BaseUsersViewController {
    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        self.showCloseButton( track: .subject( "users", action: "close" ) ) { [weak self] in
            (self?.extensionContext as? ASCredentialProviderExtensionContext)?.cancelRequest(
                    withError: ASExtensionError( .userCanceled, "Close button pressed." )
            )
        } longPressAction: {
            if AppConfig.shared.memoryProfiler {
                AutoFillProviderController.shared?.reportLeaks()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        // Necessary to ensure usersCarousel is fully laid-out; selection in empty collection view leads to a hang in -selectItemAtIndexPath.
        self.view.layoutIfNeeded()

        if let userName = AutoFillModel.shared.context.credentialIdentity?.user,
           let item = self.usersSource?.snapshot()?.itemIdentifiers.enumerated().first( where: { $0.element.file?.userName == userName } ) {
            self.usersCarousel.requestSelection( item: item.offset )
        }
        else if self.usersSource?.snapshot()?.numberOfItems == 1 {
            self.usersCarousel.requestSelection( item: 0 )
        }
    }

    // MARK: - Interface

    override func items(for userFiles: [Marshal.UserFile]) -> [UserItem] {
        super.items( for: userFiles ).filter( { $0.file?.autofill ?? false } )
    }

    // MARK: - Types

    override func login(user: User) {
        super.login( user: user )

        AutoFillModel.shared.cacheUser( user )
    }
}
