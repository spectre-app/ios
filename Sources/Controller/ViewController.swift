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

    private let starsView = MPStarView()
    private let loginView = MPLoginView()

    // MARK: - Life

    override func viewDidLoad() {
        self.view.addSubview( self.starsView )
        self.view.addSubview( self.loginView )

        self.starsView.translatesAutoresizingMaskIntoConstraints = false
        self.starsView.topAnchor.constraint( equalTo: self.view.topAnchor ).activate()
        self.starsView.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ).activate()
        self.starsView.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ).activate()
        self.starsView.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).activate()

        self.loginView.translatesAutoresizingMaskIntoConstraints = false
        self.loginView.topAnchor.constraint( equalTo: self.view.topAnchor ).activate()
        self.loginView.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ).activate()
        self.loginView.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ).activate()
        self.loginView.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).updatePriority( .defaultHigh ).activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) { keyboardLayoutGuide in
            return [ self.loginView.bottomAnchor.constraint( lessThanOrEqualTo: keyboardLayoutGuide.topAnchor ) ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        if let anim = POPSpringAnimation( propertyNamed: kPOPViewScaleXY ) {
            anim.fromValue = CGPoint( x: 0, y: 0 )
            anim.toValue = CGPoint( x: 1, y: 1 )
            anim.springSpeed = 1
            self.loginView.pop_add( anim, forKey: "pop.scale" )
        }
    }
}

