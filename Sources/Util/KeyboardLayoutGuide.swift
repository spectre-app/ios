//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class KeyboardLayoutGuide: UILayoutGuide, Observable {
    var observers = Observers<KeyboardLayoutObserver>()

    /// The frame that encompasses the software keyboard, in the view's coordinate space.
    public var keyboardFrame    = CGRect.null
    /// The view insets that make way for the software keyboard, in the view's coordinate space.
    public var keyboardInsets   = UIEdgeInsets.zero
    /// A layout guide that encompasses the area in the view that is not obstructed by the keyboard.
    public var inputLayoutGuide = UILayoutGuide()
    /// Whether the software keyboard is currently active and on-screen.
    public var keyboardShowing = false {
        didSet {
            self.observers.notify { $0.keyboardDidChange( showing: self.keyboardShowing, layoutGuide: self ) }
        }
    }
    override var owningView: UIView? {
        didSet {
            if let view = self.owningView {
                view.addLayoutGuide( self.inputLayoutGuide )
            }
            else {
                self.inputLayoutGuide.owningView?.removeLayoutGuide( self.inputLayoutGuide )
            }
        }
    }

    private var notificationObservers = [ Any ]()
    private var constraints           = [ NSLayoutConstraint ]()
    private var keyboardTopConstraint:    NSLayoutConstraint?
    private var keyboardLeftConstraint:   NSLayoutConstraint?
    private var keyboardRightConstraint:  NSLayoutConstraint?
    private var keyboardBottomConstraint: NSLayoutConstraint?
    private var inputTopConstraint:       NSLayoutConstraint?
    private var inputLeftConstraint:      NSLayoutConstraint?
    private var inputRightConstraint:     NSLayoutConstraint?
    private var inputBottomConstraint:    NSLayoutConstraint?

    /**
     * Install the layout guide into the view.
     * Optionally, install constraints onto the layout guide and/or monitor the keyboard frame in the view's coordinate space.
     */
    @discardableResult
    func didAppear(in view: UIView, constraints: ((UILayoutGuide) -> [NSLayoutConstraint]?)? = nil, observer: KeyboardLayoutObserver? = nil) -> Self {
        self.willDisappear()
        self.identifier = "KeyboardLayoutGuide:\(view.describe())"
        self.inputLayoutGuide.identifier = "InputLayoutGuide:\(view.describe())"

        self.keyboardTopConstraint = self.topAnchor.constraint( equalTo: view.topAnchor )
        self.keyboardLeftConstraint = self.leftAnchor.constraint( equalTo: view.leftAnchor )
        self.keyboardRightConstraint = self.rightAnchor.constraint( equalTo: view.rightAnchor )
        self.keyboardBottomConstraint = self.bottomAnchor.constraint( equalTo: view.bottomAnchor )
        self.keyboardTopConstraint?.isActive = true
        self.keyboardLeftConstraint?.isActive = true
        self.keyboardRightConstraint?.isActive = true
        self.keyboardBottomConstraint?.isActive = true

        self.inputTopConstraint = self.inputLayoutGuide.topAnchor.constraint( equalTo: view.topAnchor )
        self.inputLeftConstraint = self.inputLayoutGuide.leftAnchor.constraint( equalTo: view.leftAnchor )
        self.inputRightConstraint = self.inputLayoutGuide.rightAnchor.constraint( equalTo: view.rightAnchor )
        self.inputBottomConstraint = self.inputLayoutGuide.bottomAnchor.constraint( equalTo: view.bottomAnchor )
        self.inputTopConstraint?.isActive = true
        self.inputLeftConstraint?.isActive = true
        self.inputRightConstraint?.isActive = true
        self.inputBottomConstraint?.isActive = true

        if let constraints = constraints {
            self.add( constraints: constraints )
        }

        if let observer = observer {
            self.observers.register( observer: observer ).keyboardDidChange( showing: self.keyboardShowing, layoutGuide: self )
        }

        self.notificationObservers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main ) {
            guard let keyboardScreenFrom = ($0.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
                  let keyboardScreenTo = ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            else { return }

            self.animate( notification: $0, prior: { self.updateKeyboardFrame( inScreen: keyboardScreenFrom, silent: true ) } ) {
                self.updateKeyboardFrame( inScreen: keyboardScreenTo )
            }
        } )
        self.notificationObservers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main ) {
            self.animate( notification: $0 ) {
                self.constraints.forEach { $0.isActive = true }
            }
            self.keyboardShowing = true
        } )
        self.notificationObservers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main ) {
            self.animate( notification: $0 ) {
                self.constraints.forEach { $0.isActive = false }
            }
            self.keyboardShowing = false
        } )

        return self
    }

    @discardableResult
    func add(constraints: (UILayoutGuide) -> [NSLayoutConstraint]?) -> Self {
        constraints( self ).flatMap { self.constraints.append( contentsOf: $0 ) }
        return self
    }

    @discardableResult
    func willDisappear() -> Self {
        self.notificationObservers.forEach { NotificationCenter.default.removeObserver( $0 ) }
        self.keyboardTopConstraint?.isActive = false
        self.keyboardLeftConstraint?.isActive = false
        self.keyboardRightConstraint?.isActive = false
        self.keyboardBottomConstraint?.isActive = false
        self.notificationObservers.removeAll()

        self.constraints.forEach { $0.isActive = false }
        self.constraints.removeAll()

        return self
    }

    private func animate(notification: Notification, prior: () -> Void = {}, execute: @escaping () -> Void) {
        if let curve = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber).flatMap( { UIView.AnimationCurve( rawValue: $0.intValue ) } ),
           let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue {
            prior()
            self.owningView?.layoutIfNeeded()
            let animator = UIViewPropertyAnimator( duration: duration, curve: curve ) { [weak self] in
                execute()
                self?.owningView?.layoutIfNeeded()
            }
            animator.startAnimation()
        }
        else {
            execute()
        }
    }

    private func updateKeyboardFrame(inScreen keyboardScreenFrame: CGRect, silent: Bool = false) {
        guard let view = self.owningView, let window = view.window
        else { return }

        defer {
            if !silent {
                self.observers.notify { $0.keyboardDidChange( showing: self.keyboardShowing, layoutGuide: self ) }
            }
        }

        self.keyboardTopConstraint?.isActive = keyboardScreenFrame != .null
        self.keyboardLeftConstraint?.isActive = keyboardScreenFrame != .null
        self.keyboardRightConstraint?.isActive = keyboardScreenFrame != .null
        self.keyboardBottomConstraint?.isActive = keyboardScreenFrame != .null
        if keyboardScreenFrame == .null {
            self.keyboardFrame = .null
            self.keyboardInsets = .zero
            return
        }

        // Bug: iOS doesn't include window translation when converting screen coordinates.
        // Usually screen and window bounds are identical, but not always (eg. app extension windows).
        // Best we can do is guess the vertical offset in the case of iPhone (only top edge offset).
        //dbg( "window: %@, screen: %@", window.bounds, window.screen.bounds )
        var keyboardWindowFrame = keyboardScreenFrame
        if window.bounds.size.width == window.screen.bounds.size.width, window.bounds.size.height != window.screen.bounds.size.height {
            keyboardWindowFrame.origin.y -= window.screen.bounds.maxY - window.bounds.maxY
        }

        view.layoutIfNeeded()
        self.keyboardFrame = view.convert( keyboardWindowFrame, from: window.coordinateSpace )
        self.keyboardInsets = UIEdgeInsets( in: view.convert( view.frame, from: view.superview ), subtracting: self.keyboardFrame )
        self.keyboardTopConstraint?.constant = self.keyboardFrame.minY
        self.keyboardLeftConstraint?.constant = self.keyboardFrame.minX
        self.keyboardRightConstraint?.constant = self.keyboardFrame.maxX - view.bounds.maxX
        self.keyboardBottomConstraint?.constant = self.keyboardFrame.maxY - view.bounds.maxY
        self.inputTopConstraint?.constant = self.keyboardInsets.top
        self.inputLeftConstraint?.constant = self.keyboardInsets.left
        self.inputRightConstraint?.constant = -self.keyboardInsets.right
        self.inputBottomConstraint?.constant = -self.keyboardInsets.bottom

        //dbg( "keyboardFrame in window: %@, view: %@", keyboardWindowFrame, self.keyboardFrame )
        //dbg( "keyboardFrame view insets: %@, constraints: t=%g, l=%g, r=%g, b=%g", self.keyboardInsets,
        //     self.keyboardTopConstraint?.constant ?? -1,
        //     self.keyboardLeftConstraint?.constant ?? -1,
        //     self.keyboardRightConstraint?.constant ?? -1,
        //     self.keyboardBottomConstraint?.constant ?? -1 )
    }
}

protocol KeyboardLayoutObserver {
    func keyboardDidChange(showing: Bool, layoutGuide: KeyboardLayoutGuide)
}
