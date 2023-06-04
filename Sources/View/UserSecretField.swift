// =============================================================================
// Created by Maarten Billemont on 2019-06-29.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

extension UIAlertController {
    static func authenticate(userFile: Marshal.UserFile, title: String, message: String? = nil, action: String, retryOnError: Bool = true,
                             in viewController: UIViewController, track: Tracking? = nil) async throws -> User {
        try await self.authenticate( userName: userFile.userName, identicon: userFile.identicon,
                           title: title, message: message, action: action, retryOnError: retryOnError,
                           in: viewController, track: track ) {
            try await userFile.authenticate( using: $0 )
        }
    }

    static func authenticate<U>(userName: String? = nil, identicon: SpectreIdenticon = SpectreIdenticonUnset,
                                title: String, message: String? = nil, action: String, retryOnError: Bool = true,
                                in viewController: UIViewController, track: Tracking? = nil,
                                authenticator: @escaping (SecretKeyFactory) async throws -> U) async throws -> U {
        try await withCheckedThrowingContinuation { continuation in
            let spinner         = AlertController( title: "Unlocking", message: userName,
                                                   content: UIActivityIndicatorView( style: .large ) )
            let alertController = UIAlertController( title: title, message: message, preferredStyle: .alert )
            var event = track.flatMap { Tracker.shared.begin( track: $0 ) }

            var nameField: UITextField?
            if userName == nil {
                alertController.addTextField { nameField = $0 }
            }

            let secretField = UserSecretField<U>( userName: userName, identicon: identicon, nameField: nameField )
            secretField.authenticater = { factory in
                spinner.show( in: viewController.view, dismissAutomatically: false )
                do {
                    let userKey = try await authenticator( factory )
                    event?.end(
                            [ "result": "success",
                              "type": "secret",
                              "length": factory.metadata.length,
                              "entropy": factory.metadata.entropy,
                            ] )
                    return userKey
                } catch {
                    event?.end(
                            [ "result": "!auth",
                              "type": "secret",
                              "length": factory.metadata.length,
                              "entropy": factory.metadata.entropy,
                              "error": error,
                            ] )
                    throw error
                }
            }
            secretField.authenticated = { [weak alertController] result in
                spinner.dismiss()

                guard let alertController = alertController
                else { return }

                alertController.dismiss( animated: true ) {
                    if !retryOnError {
                        continuation.resume( with: result )
                        return
                    }

                    do {
                        continuation.resume( returning: try result.get() )
                        Feedback.shared.play( .trigger )
                    }
                    catch {
                        mperror( title: "Couldn't authenticate user", error: error, in: viewController.view )
                        event = track.flatMap { Tracker.shared.begin( track: $0 ) }
                        viewController.present( alertController, animated: true )
                    }
                }
            }

            alertController.addTextField { secretField.passwordField = $0 }
            alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                event?.end(
                        [ "result": "cancelled",
                          "type": "secret",
                        ] )
                continuation.resume( throwing: CancellationError() )
            } )
            alertController.addAction( UIAlertAction( title: action, style: .default ) { [unowned alertController] _ in
                if !secretField.try() {
                    mperror( title: "Couldn't import user", message: "Personal secret cannot be left empty.", in: viewController.view )

                    event?.end(
                            [ "result": "!userSecret",
                              "type": "secret",
                            ] )
                    event = track.flatMap { Tracker.shared.begin( track: $0 ) }
                    viewController.present( alertController, animated: true )
                }
            } )
            viewController.present( alertController, animated: true )
        }
    }
}

class UserSecretField<U>: UITextField, UITextFieldDelegate, Updatable {
    var userName:  String?
    var identicon: SpectreIdenticon {
        didSet {
            self.setNeedsIdenticon()
        }
    }
    var nameField: UITextField? {
        didSet {
            if let nameField = self.nameField, nameField != oldValue {
                oldValue?.delegate = nil
                nameField.delegate = self
                nameField.placeholder = "Your full name"
                nameField.autocapitalizationType = .words
                nameField.keyboardType = .emailAddress
                nameField.textContentType = .name
                nameField.autocorrectionType = .no
                nameField.returnKeyType = .next
                nameField.textAlignment = .center
            }
        }
    }
    weak var passwordField: UITextField? {
        willSet {
            if let passwordField = self.passwordField {
                passwordField.delegate = nil
                passwordField.inputAccessoryView = nil
                passwordField.rightView = nil
                passwordField.leftView = nil
                NotificationCenter.default.removeObserver( passwordField )
            }
        }
        didSet {
            if let passwordField = self.passwordField {
                passwordField.delegate = self
                passwordField.isSecureTextEntry = true
                passwordField.placeholder = "Your personal secret"
                passwordField.keyboardType = .asciiCapable
                passwordField.textContentType = UITextContentType( rawValue: "passphrase" )
                passwordField.returnKeyType = .continue
                passwordField.leftView = self.leftItemView
                passwordField.rightView = self.rightItemView
                passwordField.leftViewMode = .always
                passwordField.rightViewMode = .always
                passwordField.textAlignment = .center

                self.leftItemView.frame.size = self.leftItemView.systemLayoutSizeFitting( UIView.layoutFittingCompressedSize )
                self.rightItemView.frame.size = self.rightItemView.systemLayoutSizeFitting( UIView.layoutFittingCompressedSize )

                NotificationCenter.default.addObserver(
                        forName: UITextField.textDidChangeNotification, object: passwordField, queue: nil ) { [weak self] _ in
                    self?.setNeedsIdenticon()
                }
            }
        }
    }
    override var text: String? {
        didSet {
            self.setNeedsIdenticon()
        }
    }
    var authenticater: ((SecretKeyFactory) async throws -> U)?
    var authenticated: ((Result<U, Error>) -> Void)?

    private let activityIndicator = UIActivityIndicatorView( style: .medium )
    private lazy var identiconLabel    = UILabel()
    private lazy var leftItemView      = UIView()
    private lazy var rightItemView     = UIView()
    private lazy var leftMinimumWidth  = self.leftItemView.widthAnchor.constraint( equalToConstant: 0 ).with( priority: .defaultLow )
    private lazy var rightMinimumWidth = self.rightItemView.widthAnchor.constraint( equalToConstant: 0 ).with( priority: .defaultLow )

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(userName: String? = nil, identicon: SpectreIdenticon = SpectreIdenticonUnset, nameField: UITextField? = nil) {
        self.userName = userName
        self.identicon = identicon
        super.init( frame: .zero )
        LeakRegistry.shared.register( self )

        self.identiconLabel => \.font => Theme.current.font.password.transform { $0?.withSize( UIFont.labelFontSize ) }
        self.identiconLabel => \.textColor => Theme.current.color.body
        self.identiconLabel => \.shadowColor => Theme.current.color.shadow
        self.identiconLabel.shadowOffset = CGSize( width: 0, height: 1 )

        self.leftItemView.addSubview( self.activityIndicator )
        self.rightItemView.addSubview( self.identiconLabel )
        self.leftMinimumWidth.isActive = true
        self.rightMinimumWidth.isActive = true

        LayoutConfiguration( view: self.activityIndicator )
            .constrain( as: .center, margin: true )
            .activate()
        LayoutConfiguration( view: self.identiconLabel )
            .constrain( as: .center, margin: true )
            .activate()

        defer {
            self.nameField = nameField
            self.passwordField = self
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if newWindow != nil {
            self.updateTask.request()
        }
        else {
            self.updateTask.cancel()
        }
    }

    // MARK: - Interface

    public func setNeedsIdenticon() {
        if (self.nameField?.text ?? self.userName) == nil || self.passwordField?.text == nil {
            self.identiconLabel.attributedText = nil
        }
        else {
            self.updateTask.request()
        }
    }

    public func `try`(_ textField: UITextField? = nil) -> Bool {
        if let field = textField ?? self.nameField ?? self.passwordField {
            return self.textFieldShouldReturn( field )
        }

        return false
    }

    public func authenticate<UU>(_ handler: ((SecretKeyFactory) async throws -> UU)?) -> Task<UU, Error>? {
        guard let handler = handler,
              let userName = self.nameField?.text ?? self.userName, userName.count > 0,
              let userSecret = self.passwordField?.text, userSecret.count > 0
        else { return nil }

        return Task {
            self.passwordField?.isEnabled = false
            self.activityIndicator.startAnimating()

            do {
                let user = try await handler( SecretKeyFactory( userName: userName, userSecret: userSecret ) )
                self.passwordField?.text = nil
                self.passwordField?.isEnabled = true
                self.passwordField?.resignFirstResponder()
                self.activityIndicator.stopAnimating()
                return user
            }
            catch {
                self.passwordField?.becomeFirstResponder()
                self.passwordField?.shake()
                self.activityIndicator.stopAnimating()
                throw error
            }
        }
    }

    // MARK: - Updatable

    lazy var updateTask = DispatchTask.update( self, deadline: .random( in: (.short)..<(.long) ) ) { [weak self] in
        guard let self = self
        else { return }

        var identicon = self.identicon
        let userName  = self.nameField?.text ?? self.userName
        if let userSecret = self.passwordField?.text?.nonEmpty {
            identicon = await Spectre.shared.identicon( userName: userName, userSecret: userSecret )
        }

        self.identiconLabel.attributedText = identicon.attributedText()
        self.leftMinimumWidth.constant = 0
        self.rightMinimumWidth.constant = 0
        let rightWidth = self.rightItemView.systemLayoutSizeFitting( UIView.layoutFittingCompressedSize ).width,
            leftWidth  = self.leftItemView.systemLayoutSizeFitting( UIView.layoutFittingCompressedSize ).width
        self.leftMinimumWidth.constant = rightWidth
        self.rightMinimumWidth.constant = leftWidth
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField, reason: DidEndEditingReason) {
        if textField == self.nameField {
            self.nameField?.text = self.nameField?.text?.trimmingCharacters( in: .whitespacesAndNewlines )
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        true
    }

    @discardableResult
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let authentication = self.authenticate( self.authenticater ) {
            textField.resignFirstResponder()
            Task.detached { await self.authenticated?( authentication.result ) }
            return true
        }

        if let nameField = self.nameField, textField == nameField {
            if nameField.text?.count ?? 0 == 0 {
                nameField.becomeFirstResponder()
                nameField.shake()
            }
            else {
                if let passwordField = self.passwordField {
                    passwordField.becomeFirstResponder()
                }
                else {
                    nameField.resignFirstResponder()
                }
            }
        }

        if let passwordField = self.passwordField, textField == passwordField {
            if passwordField.text?.count ?? 0 == 0 {
                passwordField.becomeFirstResponder()
                passwordField.shake()
            }
            else {
                if let nameField = self.nameField, nameField.text?.count ?? 0 == 0 {
                    nameField.becomeFirstResponder()
                }
                else {
                    passwordField.resignFirstResponder()
                }
            }
        }

        return false
    }
}
