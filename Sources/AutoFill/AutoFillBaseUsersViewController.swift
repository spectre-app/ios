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
    lazy var closeButton = EffectButton( track: .subject( "users", action: "close" ), image: .icon( "xmark", style: .regular ),
                                         border: 0, background: false, square: true ) { [unowned self] _ in
        self.extensionContext?.cancelRequest( withError: ASExtensionError( .userCanceled, "Close button pressed." ) )
    }

    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.insertSubview( self.closeButton, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.closeButton )
            .constrain( as: .bottomCenter, margin: true ).activate()
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
