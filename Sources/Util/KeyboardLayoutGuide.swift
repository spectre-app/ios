//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class KeyboardLayoutGuide: UILayoutGuide {
    private class KeyboardObserver {
        var screenFrame = CGRect.null
        var frameObserver: Any?

        init(screen: UIScreen) {
            self.frameObserver = NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main ) {
                guard let screenFrame = ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                else { return }

                self.screenFrame = screenFrame
                trc( "keyboardFrame screen -> %@", screenFrame )
            }
        }
    }

    private static var screenObservers = [ WeakBox < UIScreen>: KeyboardObserver ]()

    private var observers   = [ Any ]()
    private var constraints = [ NSLayoutConstraint ]()
    private let view:                     UIView
    private var update:                   ((CGRect, UIEdgeInsets) -> Void)?
    private var keyboardTopConstraint:    NSLayoutConstraint!
    private var keyboardLeftConstraint:   NSLayoutConstraint!
    private var keyboardRightConstraint:  NSLayoutConstraint!
    private var keyboardBottomConstraint: NSLayoutConstraint!

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(in view: UIView) {
        self.view = view
        super.init()

        self.identifier = "KeyboardLayoutGuide"
        self.keyboardTopConstraint = self.topAnchor.constraint( equalTo: self.view.topAnchor )
        self.keyboardLeftConstraint = self.leftAnchor.constraint( equalTo: self.view.leftAnchor )
        self.keyboardRightConstraint = self.rightAnchor.constraint( equalTo: self.view.rightAnchor )
        self.keyboardBottomConstraint = self.bottomAnchor.constraint( equalTo: self.view.bottomAnchor )
    }

    /**
     * Install the layout guide into the view.
     * Optionally, install constraints onto the layout guide and/or monitor the keyboard frame in the view's coordinate space.
     */
    @discardableResult
    func install(constraints: ((UILayoutGuide) -> [NSLayoutConstraint]?)? = nil, update: ((CGRect, UIEdgeInsets) -> Void)? = nil) -> Self {
        guard let screen = self.view.window?.screen
        else { assertionFailure( "Cannot install in a view that is not attached to a screen." ); return self }

        self.uninstall()
        self.view.addLayoutGuide( self )
        self.keyboardTopConstraint.isActive = true
        self.keyboardLeftConstraint.isActive = true
        self.keyboardRightConstraint.isActive = true
        self.keyboardBottomConstraint.isActive = true

        if let constraints = constraints {
            self.add( constraints: constraints )
        }
        self.update = update
        self.notify()

        if KeyboardLayoutGuide.screenObservers[WeakBox( screen )] == nil {
            KeyboardLayoutGuide.screenObservers[WeakBox( screen )] = KeyboardObserver( screen: screen )
        }

        self.observers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main ) { _ in
            self.notify()
        } )
        self.observers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main ) {
            let duration = ($0.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3

            self.view.layoutIfNeeded()
            UIView.animate( withDuration: duration ) {
                self.constraints.forEach { $0.isActive = true }
                self.view.layoutIfNeeded()
            }
        } )
        self.observers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main ) {
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
    func add(constraints: (UILayoutGuide) -> [NSLayoutConstraint]?) -> Self {
        constraints( self ).flatMap { self.constraints.append( contentsOf: $0 ) }
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

    func notify() {
        guard let screen = self.view.window?.screen
        else { return }

        let keyboardScreenFrame = KeyboardLayoutGuide.screenObservers[WeakBox( screen )]?.screenFrame ?? .null
        self.keyboardTopConstraint.isActive = keyboardScreenFrame != .null
        self.keyboardLeftConstraint.isActive = keyboardScreenFrame != .null
        self.keyboardRightConstraint.isActive = keyboardScreenFrame != .null
        self.keyboardBottomConstraint.isActive = keyboardScreenFrame != .null
        if keyboardScreenFrame == .null {
            return
        }

        let keyboardViewFrame = self.view.convert( keyboardScreenFrame, from: screen.coordinateSpace )
        let keyboardInsets    = UIEdgeInsets( in: self.view.frame, subtracting: keyboardViewFrame )
        self.keyboardTopConstraint.constant = keyboardViewFrame.minY
        self.keyboardLeftConstraint.constant = keyboardViewFrame.minX
        self.keyboardRightConstraint.constant = keyboardViewFrame.maxX - self.view.bounds.maxX
        self.keyboardBottomConstraint.constant = keyboardViewFrame.maxY - self.view.bounds.maxY

        trc( "keyboardFrame view %@: %@ (%@)", describe( self.view ), keyboardViewFrame, keyboardInsets )
        self.update?( keyboardViewFrame, keyboardInsets )
    }
}
