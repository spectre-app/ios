//
//  ViewController.swift
//  Test
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import pop

class ViewController: UIViewController {

    let starsView = MPStarView()
    let usersView = MPUsersView()

    override func viewDidLoad() {
        self.view.addSubview( self.starsView )
        self.starsView.setFrameFrom( "|[]|" )

        self.view.addSubview( self.usersView )
        self.usersView.setFrameFrom( "|[]|" )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        if let anim = POPSpringAnimation( propertyNamed: kPOPViewScaleXY ) {
            anim.fromValue = CGPoint( x: 0, y: 0 )
            anim.toValue = CGPoint( x: 1, y: 1 )
            anim.springSpeed = 1
            self.usersView.pop_add( anim, forKey: "pop" )
        }
    }
}

