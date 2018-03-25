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

        self.loginView.translatesAutoresizingMaskIntoConstraints = false
        self.loginView.topAnchor.constraint( equalTo: self.view.topAnchor ).activate()
        self.loginView.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ).activate()
        self.loginView.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ).activate()
        self.loginView.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).updatePriority( .defaultHigh ).activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) { keyboardLayoutGuide in
            return [ self.loginView.bottomAnchor.constraint( lessThanOrEqualTo: keyboardLayoutGuide.topAnchor ) ]
        }
    }
}

