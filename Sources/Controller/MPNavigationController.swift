//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPNavigationController: UINavigationController {
    private let starsView = MPStarView()

    // MARK: - Life

    override init(rootViewController: UIViewController) {
        super.init( rootViewController: rootViewController )
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init( nibName: nibNameOrNil, bundle: nibBundleOrNil )

        self.isNavigationBarHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        self.view.insertSubview(self.starsView, at: 0)

        self.starsView.translatesAutoresizingMaskIntoConstraints = false
        self.starsView.topAnchor.constraint( equalTo: self.view.topAnchor ).activate()
        self.starsView.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ).activate()
        self.starsView.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ).activate()
        self.starsView.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).activate()
    }
}
