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

class AutoFillConfigurationViewController: BaseViewController {
    private let configurationView = AutoFillConfigurationView( fromSettings: true )
    private lazy var closeButton = EffectButton( track: .subject( "users", action: "close" ), image: .icon( "×", style: .regular ),
                                                 border: 0, background: false, square: true ) { [unowned self] _, _ in
        (self.extensionContext as? ASCredentialProviderExtensionContext)?.completeExtensionConfigurationRequest()
    }

    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        // - Hierarchy
        self.view.addSubview( self.configurationView )
        self.view.addSubview( self.closeButton )

        // - Layout
        LayoutConfiguration( view: self.configurationView )
                .constrain { $1.view!.contentLayoutGuide.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor ) }
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.closeButton )
                .constrain( as: .bottomCenter, margin: true ).activate()
    }
}
