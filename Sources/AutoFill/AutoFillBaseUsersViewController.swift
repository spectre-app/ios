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

class AutoFillBaseUsersViewController: BaseUsersViewController {
    lazy var closeButton = EffectButton( track: .subject( "users", action: "close" ),
                                                 image: .icon( "×", style: .regular ), border: 0, background: false, square: true ) { [unowned self] _, _ in
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

    // MARK: --- Types ---

    override func login(user: User) {
        super.login( user: user )

        AutoFillModel.shared.cacheUser( user )
    }
}
