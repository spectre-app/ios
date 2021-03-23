//
//  AutoFillUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillConfigurationViewController: BaseViewController {
    private let configurationView = AutoFillConfigurationView( fromSettings: true )
    private lazy var closeButton = EffectButton( track: .subject( "users", action: "close" ),
                                                 image: .icon( "" ), border: 0, background: false, square: true ) { _, _ in
        (self.extensionContext as? ASCredentialProviderExtensionContext)?.completeExtensionConfigurationRequest()
    }

    // MARK: --- Life ---

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
