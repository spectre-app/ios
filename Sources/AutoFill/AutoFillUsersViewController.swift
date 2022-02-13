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
    private var configurationView: AutoFillConfigurationView? {
        didSet {
            if self.configurationView != oldValue, let oldValue = oldValue {
                oldValue.removeFromSuperview()
            }

            if let configurationView = self.configurationView, configurationView.superview == nil {
                self.view.insertSubview( configurationView, belowSubview: self.closeButton )
                LayoutConfiguration( view: configurationView )
                    .constrain { $1.view!.contentLayoutGuide.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor ) }
                    .constrain( as: .box ).activate()
            }
        }
    }

    // MARK: - MarshalObserver

    override func didUpdateUsers(isEmpty: Bool) {
        super.didUpdateUsers( isEmpty: isEmpty )

        if isEmpty {
            self.configurationView = self.configurationView ?? AutoFillConfigurationView( fromSettings: false )
        }
        else {
            self.configurationView = nil
        }
    }

    // MARK: - Types

    override func login(user: User) {
        super.login( user: user )

        self.detailsHost.show( AutoFillSitesViewController( user: user ), sender: self )
    }
}
