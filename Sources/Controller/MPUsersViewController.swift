//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPUsersViewController: UIViewController {

    private let loginView = MPLoginView()

    // MARK: - Life

    override func viewDidLoad() {
        self.view.addSubview( self.loginView )

        ViewConfiguration( view: self.loginView )
                .add { $0.topAnchor.constraint( equalTo: self.view.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).updatePriority( .defaultHigh ) }
                .activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.loginView.bottomAnchor ) ]
        }
    }
}

