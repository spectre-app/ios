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

class AutoFillUsersViewController: AutoFillBaseUsersViewController {
    private let configurationView = AutoFillConfigurationView( fromSettings: false )

    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.insertSubview( self.configurationView, belowSubview: self.closeButton )

        // - Layout
        LayoutConfiguration( view: self.configurationView )
                .constrain { $1.view!.contentLayoutGuide.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor ) }
                .constrain( as: .box ).activate()
    }

    // MARK: - MarshalObserver

    override func didChange(userFiles: [Marshal.UserFile]) {
        super.didChange( userFiles: userFiles )

        DispatchQueue.main.perform {
            self.configurationView.isHidden = !(self.usersSource?.isEmpty ?? true)
        }
    }

    // MARK: - Types

    override func login(user: User) {
        super.login( user: user )

        self.detailsHost.show( AutoFillSitesViewController( user: user ), sender: self )
    }
}
