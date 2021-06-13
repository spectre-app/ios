//==============================================================================
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

class KeyboardMonitor {
    static let shared = KeyboardMonitor()
    var observers = Observers<KeyboardMonitorObserver>()

    fileprivate var notificationObservers     = [ Any ]()
    fileprivate var keyboardScreenFrameLatest = CGRect.null
    fileprivate var keyboardShowing = false {
        didSet {
            if self.keyboardShowing != oldValue {
                self.observers.notify {
                    $0.didChange( keyboard: self, showing: self.keyboardShowing, fromScreenFrame: self.keyboardScreenFrameLatest, toScreenFrame: self.keyboardScreenFrameLatest, curve: nil, duration: nil )
                }
            }
        }
    }

    func install() {
        self.notificationObservers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main ) { notification in
            guard (notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true,
                  let keyboardScreenFrameFrom = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue,
                  let keyboardScreenFrameTo = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                  keyboardScreenFrameFrom != keyboardScreenFrameTo
            else { return }

            self.keyboardScreenFrameLatest = keyboardScreenFrameTo

            self.observers.notify {
                $0.didChange(
                        keyboard: self, showing: self.keyboardShowing,
                        fromScreenFrame: keyboardScreenFrameFrom, toScreenFrame: keyboardScreenFrameTo,
                        curve: (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber).flatMap( { UIView.AnimationCurve( rawValue: $0.intValue ) } ),
                        duration: (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue )
            }
        } )
        self.notificationObservers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main ) {
            guard ($0.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true
            else { return }

            self.keyboardShowing = true
        } )
        self.notificationObservers.append( NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main ) {
            guard ($0.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true
            else { return }

            self.keyboardShowing = false
        } )
    }

    func uninstall() {
        self.notificationObservers.forEach { NotificationCenter.default.removeObserver( $0 ) }
        self.notificationObservers.removeAll()
    }
}

class KeyboardLayoutGuide: UILayoutGuide, KeyboardMonitorObserver {
    /// The frame that encompasses the software keyboard, in the view's coordinate space.
    public var keyboardFrame    = CGRect.null
    /// The view insets that make way for the software keyboard, in the view's coordinate space.
    public var keyboardInsets   = UIEdgeInsets.zero
    /// A layout guide that encompasses the area in the view that is not obstructed by the keyboard.
    public var inputLayoutGuide = UILayoutGuide()

    override var owningView: UIView? {
        didSet {
            if oldValue != self.owningView {
                oldValue?.removeLayoutGuide( self.inputLayoutGuide )

                if let newValue = self.owningView {
                    newValue.addLayoutGuide( self.inputLayoutGuide )

                    self.keyboardTopConstraint = self.topAnchor.constraint( equalTo: newValue.topAnchor )
                    self.keyboardLeftConstraint = self.leftAnchor.constraint( equalTo: newValue.leftAnchor )
                    self.keyboardRightConstraint = self.rightAnchor.constraint( equalTo: newValue.rightAnchor )
                    self.keyboardBottomConstraint = self.bottomAnchor.constraint( equalTo: newValue.bottomAnchor )
                    self.inputTopConstraint = self.inputLayoutGuide.topAnchor.constraint( equalTo: newValue.topAnchor )
                    self.inputLeftConstraint = self.inputLayoutGuide.leftAnchor.constraint( equalTo: newValue.leftAnchor )
                    self.inputRightConstraint = self.inputLayoutGuide.rightAnchor.constraint( equalTo: newValue.rightAnchor )
                    self.inputBottomConstraint = self.inputLayoutGuide.bottomAnchor.constraint( equalTo: newValue.bottomAnchor )
                    self.inputTopConstraint?.isActive = true
                    self.inputLeftConstraint?.isActive = true
                    self.inputRightConstraint?.isActive = true
                    self.inputBottomConstraint?.isActive = true

                    self.didChange(
                            keyboard: KeyboardMonitor.shared,
                            showing: KeyboardMonitor.shared.keyboardShowing,
                            fromScreenFrame: KeyboardMonitor.shared.keyboardScreenFrameLatest,
                            toScreenFrame: KeyboardMonitor.shared.keyboardScreenFrameLatest,
                            curve: nil, duration: nil )
                }
            }
        }
    }

    private var constraints = [ NSLayoutConstraint ]()
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
    func didAppear(constraints: ((UILayoutGuide) -> [NSLayoutConstraint]?)? = nil, observer: KeyboardMonitorObserver? = nil) {
        self.willDisappear()

        guard let view = self.owningView
        else { return }

        self.identifier = "KeyboardLayoutGuide:\(view.describe())"
        self.inputLayoutGuide.identifier = "InputLayoutGuide:\(view.describe())"

        if let constraints = constraints {
            self.add( constraints: constraints )
        }

        KeyboardMonitor.shared.observers.register( observer: self ).didChange(
                keyboard: KeyboardMonitor.shared,
                showing: KeyboardMonitor.shared.keyboardShowing,
                fromScreenFrame: KeyboardMonitor.shared.keyboardScreenFrameLatest,
                toScreenFrame: KeyboardMonitor.shared.keyboardScreenFrameLatest,
                curve: nil, duration: nil )

        if let observer = observer {
            KeyboardMonitor.shared.observers.register( observer: observer ).didChange(
                    keyboard: KeyboardMonitor.shared,
                    showing: KeyboardMonitor.shared.keyboardShowing,
                    fromScreenFrame: KeyboardMonitor.shared.keyboardScreenFrameLatest,
                    toScreenFrame: KeyboardMonitor.shared.keyboardScreenFrameLatest,
                    curve: nil, duration: nil )
        }
    }

    func willDisappear() {
        self.keyboardTopConstraint?.isActive = false
        self.keyboardLeftConstraint?.isActive = false
        self.keyboardRightConstraint?.isActive = false
        self.keyboardBottomConstraint?.isActive = false
        self.inputTopConstraint?.constant = 0
        self.inputLeftConstraint?.constant = 0
        self.inputRightConstraint?.constant = 0
        self.inputBottomConstraint?.constant = 0

        self.constraints.forEach { $0.isActive = false }
        self.constraints.removeAll()
    }

    @discardableResult
    func add(constraints: (UILayoutGuide) -> [NSLayoutConstraint]?) -> Self {
        constraints( self ).flatMap { self.constraints.append( contentsOf: $0 ) }
        return self
    }

    // MARK: --- KeyboardMonitorObserver ---

    func didChange(keyboard: KeyboardMonitor, showing: Bool, fromScreenFrame: CGRect, toScreenFrame: CGRect, curve: UIView.AnimationCurve?, duration: TimeInterval?) {
        if let curve = curve, let duration = duration, let owningView = self.owningView {
            if fromScreenFrame != toScreenFrame {
                self.updateKeyboard( frameInScreen: fromScreenFrame, transient: true )
                owningView.layoutIfNeeded()
            }
            let animator = UIViewPropertyAnimator( duration: duration, curve: curve ) {
                self.updateKeyboard( frameInScreen: toScreenFrame )
                self.constraints.forEach { $0.isActive = showing }

                owningView.layoutIfNeeded()
            }
            animator.startAnimation()
        }
        else {
            self.updateKeyboard( frameInScreen: toScreenFrame )
            self.constraints.forEach { $0.isActive = showing }
        }
    }

    // MARK: --- Private ---

    private func updateKeyboard(frameInScreen keyboardScreenFrame: CGRect, transient: Bool = false) {
        guard let view = self.owningView, let window = view.window
        else { return }

        if keyboardScreenFrame == .null {
            self.keyboardFrame = .null
            self.keyboardInsets = .zero
        }
        else {
            // Bug: iOS doesn't include window translation when converting screen coordinates.
            // Usually screen and window bounds are identical, but not always (eg. app extension windows).
            // Best we can do is guess the vertical offset in the case of iPhone (only top edge offset).
            //dbg( "window: %@, screen: %@", window.bounds, window.screen.bounds )
            var keyboardWindowFrame = keyboardScreenFrame
            if window.bounds.size.width == window.screen.bounds.size.width, window.bounds.size.height != window.screen.bounds.size.height {
                keyboardWindowFrame.origin.y -= window.screen.bounds.maxY - window.bounds.maxY
            }

            self.keyboardFrame = view.convert( keyboardWindowFrame, from: window.coordinateSpace )
            self.keyboardInsets = UIEdgeInsets( in: view.convert( view.frame, from: view.superview ), subtracting: self.keyboardFrame )
            self.keyboardTopConstraint?.constant = self.keyboardFrame.minY
            self.keyboardLeftConstraint?.constant = self.keyboardFrame.minX
            self.keyboardRightConstraint?.constant = self.keyboardFrame.maxX - view.bounds.maxX
            self.keyboardBottomConstraint?.constant = self.keyboardFrame.maxY - view.bounds.maxY
        }

        self.keyboardTopConstraint?.isActive = self.keyboardFrame != .null
        self.keyboardLeftConstraint?.isActive = self.keyboardFrame != .null
        self.keyboardRightConstraint?.isActive = self.keyboardFrame != .null
        self.keyboardBottomConstraint?.isActive = self.keyboardFrame != .null
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

protocol KeyboardMonitorObserver {
    func didChange(keyboard: KeyboardMonitor, showing: Bool, fromScreenFrame: CGRect, toScreenFrame: CGRect, curve: UIView.AnimationCurve?, duration: TimeInterval?)
}
