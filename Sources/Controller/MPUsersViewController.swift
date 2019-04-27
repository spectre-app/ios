//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPUsersViewController: UIViewController {
    private let users = [ MPUser( named: "Maarten Billemont", avatar: .avatar_3 ),
                          MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 ) ]

    private let loginView = MPLoginView()

    // MARK: - Life

    override func viewDidLoad() {
        self.view.addSubview( self.loginView )

        ViewConfiguration( view: self.loginView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ).withPriority( .defaultHigh ) }
                .activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.loginView.bottomAnchor ) ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.loginView.users = self.users
    }
}

