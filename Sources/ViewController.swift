//
//  ViewController.swift
//  Test
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let backgroundView = MPBackgroundView()

    override func viewDidLoad() {
        self.view.addSubview( self.backgroundView )
        self.backgroundView.backgroundColor = UIColor.black
        self.backgroundView.setFrameFrom( "|[]|" );
    }
}

