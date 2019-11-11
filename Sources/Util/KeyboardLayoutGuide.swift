//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class KeyboardLayoutGuide: UILayoutGuide {
    var observers   = [ Any ]()
    var constraints = [ NSLayoutConstraint ]()
    let view:                     UIView
    let initializer:              ((UILayoutGuide) -> ([NSLayoutConstraint]?))?
    var keyboardTopConstraint:    NSLayoutConstraint!
    var keyboardLeftConstraint:   NSLayoutConstraint!
    var keyboardRightConstraint:  NSLayoutConstraint!
    var keyboardBottomConstraint: NSLayoutConstraint!

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(in view: UIView, _ initializer: ((UILayoutGuide) -> ([NSLayoutConstraint]?))? = nil) {
        self.view = view
        self.initializer = initializer
        super.init()

        self.identifier = "KeyboardLayoutGuide"
        self.keyboardTopConstraint = self.topAnchor.constraint( equalTo: self.view.topAnchor )
        self.keyboardLeftConstraint = self.leftAnchor.constraint( equalTo: self.view.leftAnchor )
        self.keyboardRightConstraint = self.rightAnchor.constraint( equalTo: self.view.rightAnchor )
        self.keyboardBottomConstraint = self.bottomAnchor.constraint( equalTo: self.view.bottomAnchor )
    }

    @discardableResult
    func install() -> Self {
        self.uninstall()
        self.view.addLayoutGuide( self )
        self.keyboardTopConstraint.isActive = true
        self.keyboardLeftConstraint.isActive = true
        self.keyboardRightConstraint.isActive = true
        self.keyboardBottomConstraint.isActive = true
        self.initializer?( self ).flatMap { self.constraints.append( contentsOf: $0 ) }

        self.observers.append( NotificationCenter.default.addObserver( forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main ) {
            guard let keyboardScreenFrame = ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return }

            let keyboardFrame = self.view.convert( keyboardScreenFrame, from: UIScreen.main.coordinateSpace )
            self.keyboardTopConstraint.constant = keyboardFrame.minY
            self.keyboardLeftConstraint.constant = keyboardFrame.minX
            self.keyboardRightConstraint.constant = keyboardFrame.maxX - self.view.bounds.maxX
            self.keyboardBottomConstraint.constant = keyboardFrame.maxY - self.view.bounds.maxY
        } )
        self.observers.append( NotificationCenter.default.addObserver( forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main ) {
            let duration = ($0.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3

            self.view.layoutIfNeeded()
            UIView.animate( withDuration: duration ) {
                self.constraints.forEach { $0.isActive = true }
                self.view.layoutIfNeeded()
            }
        } )
        self.observers.append( NotificationCenter.default.addObserver( forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main ) {
            let duration = ($0.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3

            self.view.layoutIfNeeded()
            UIView.animate( withDuration: duration ) {
                self.constraints.forEach { $0.isActive = false }
                self.view.layoutIfNeeded()
            }
        } )

        return self
    }

    @discardableResult
    func uninstall() -> Self {
        self.observers.forEach { NotificationCenter.default.removeObserver( $0 ) }
        self.keyboardTopConstraint.isActive = false
        self.keyboardLeftConstraint.isActive = false
        self.keyboardRightConstraint.isActive = false
        self.keyboardBottomConstraint.isActive = false
        self.observers.removeAll()

        self.constraints.forEach { $0.isActive = false }
        self.constraints.removeAll()

        self.owningView?.removeLayoutGuide( self )
        self.view.layoutIfNeeded()

        return self
    }
}
