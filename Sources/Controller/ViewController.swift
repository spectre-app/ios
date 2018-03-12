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

    private let starsView           = MPStarView()
    private let loginView           = MPLoginView()
    private let keyboardLayoutGuide = UILayoutGuide()
    private var keyboardTopConstraint:   NSLayoutConstraint!, keyboardLeftConstraint: NSLayoutConstraint!,
                keyboardRightConstraint: NSLayoutConstraint!, keyboardBottomConstraint: NSLayoutConstraint!
    private var keyboardLoginConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        self.view.addSubview( self.starsView )
        self.view.addSubview( self.loginView )
        self.view.addLayoutGuide( self.keyboardLayoutGuide )

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
        self.keyboardLoginConstraint = self.loginView.bottomAnchor.constraint( lessThanOrEqualTo: self.keyboardLayoutGuide.topAnchor )

        self.keyboardTopConstraint = self.keyboardLayoutGuide.topAnchor.constraint( equalTo: self.view.topAnchor ).activate()
        self.keyboardLeftConstraint = self.keyboardLayoutGuide.leftAnchor.constraint( equalTo: self.view.leftAnchor ).activate()
        self.keyboardRightConstraint = self.keyboardLayoutGuide.rightAnchor.constraint( equalTo: self.view.rightAnchor ).activate()
        self.keyboardBottomConstraint = self.keyboardLayoutGuide.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).activate()

        NotificationCenter.default.addObserver( forName: .UIKeyboardWillChangeFrame, object: nil, queue: .main ) { notification in
            if let keyboardScreenFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                let keyboardFrame = self.view.convert( keyboardScreenFrame, from: UIScreen.main.coordinateSpace )
                self.keyboardTopConstraint.constant = keyboardFrame.minY
                self.keyboardLeftConstraint.constant = keyboardFrame.minX
                self.keyboardRightConstraint.constant = keyboardFrame.maxX - self.view.bounds.maxX
                self.keyboardBottomConstraint.constant = keyboardFrame.maxY - self.view.bounds.maxY
            }
        }
        NotificationCenter.default.addObserver( forName: .UIKeyboardWillShow, object: nil, queue: .main ) { notification in
            let duration = ((notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber) ?? 0.3).doubleValue
            UIView.animate( withDuration: duration ) {
                self.keyboardLoginConstraint.activate()
                self.view.layoutIfNeeded()
            }
        }
        NotificationCenter.default.addObserver( forName: .UIKeyboardWillHide, object: nil, queue: .main ) { notification in
            let duration = ((notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber) ?? 0.3).doubleValue
            UIView.animate( withDuration: duration ) {
                self.keyboardLoginConstraint.deactivate()
                self.view.layoutIfNeeded()
            }
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

