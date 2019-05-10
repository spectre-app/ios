//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPUsersViewController: UIViewController, MPUserObserver {
    private let loginView = MPLoginView()

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(users: [MPUser]) {
        super.init( nibName: nil, bundle: nil )

        users.forEach { $0.observers.register( self ) }
        self.loginView.users = users
    }

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

    // MARK: --- MPUserObserver ---

    func userDidLogin(_ user: MPUser) {
        DispatchQueue.main.async {
            self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )
        }
    }

    func userDidLogout(_ user: MPUser) {
        DispatchQueue.main.async {
            // Remove any SitesVC's from the stack that are for this user.
            if let navigationController = self.navigationController {
                navigationController.setViewControllers(
                        navigationController.viewControllers.filter {
                            ($0 as? MPSitesViewController)?.user != user
                        }, animated: true )
            }
        }
    }

    func userDidChange(_ user: MPUser) {
    }

    func userDidUpdateSites(_ user: MPUser) {
    }
}

