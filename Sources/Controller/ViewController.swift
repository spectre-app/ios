//
//  ViewController.swift
//  Test
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let starsView = MPStarView()
    let usersView = MPUsersView()

    override func viewDidLoad() {
        self.view.addSubview( self.starsView )
        self.starsView.setFrameFrom( "|[]|" )

        self.view.addSubview( self.usersView )
        self.usersView.setFrameFrom( "|[]|" )
    }
}

