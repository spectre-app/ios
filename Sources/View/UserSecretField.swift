//
// Created by Maarten Billemont on 2019-06-29.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension UIAlertController {
    static func authenticate(userFile: Marshal.UserFile, title: String, message: String? = nil, in viewController: UIViewController,
                             track: Tracking? = nil, action: String, retryOnError: Bool = true) -> Promise<User> {
        self.authenticate( userName: userFile.userName, title: title, message: message, in: viewController,
                           track: track, action: action, retryOnError: retryOnError ) {
            userFile.authenticate( using: $0 )
        }
    }

    static func authenticate<U>(userName: String? = nil, title: String, message: String? = nil, in viewController: UIViewController,
                                track: Tracking? = nil, action: String, retryOnError: Bool = true,
                                authenticator: @escaping (SecretKeyFactory) throws -> Promise<U>) -> Promise<U> {
        let promise         = Promise<U>()
        let spinner         = AlertController( title: "Unlocking", message: userName, content: UIActivityIndicatorView( style: .whiteLarge ) )
        let alertController = UIAlertController( title: title, message: message, preferredStyle: .alert )
        var event = track.flatMap { Tracker.shared.begin( track: $0 ) }

        var nameField: UITextField?
        if userName == nil {
            alertController.addTextField { nameField = $0 }
        }

        let secretField = UserSecretField<U>( userName: userName, nameField: nameField )
        secretField.authenticater = { factory in
            spinner.show( in: viewController.view, dismissAutomatically: false )
            return try authenticator( factory )
        }
        secretField.authenticated = { result in
            spinner.dismiss()
            alertController.dismiss( animated: true ) {
                if !retryOnError {
                    promise.finish( result )
                    return
                }

                do {
                    promise.finish( .success( try result.get() ) )
                    Feedback.shared.play( .trigger )
                }
                catch {
                    mperror( title: "Couldn't authenticate user", error: error, in: viewController.view )

                    event?.end(
                            [ "result": result.name,
                              "type": "secret",
                              "length": secretField.text?.count ?? 0,
                              "entropy": Attacker.entropy( string: secretField.text ) ?? 0,
                              "error": error,
                            ] )
                    event = track.flatMap { Tracker.shared.begin( track: $0 ) }
                    viewController.present( alertController, animated: true )
                }
            }
        }

        alertController.addTextField { secretField.passwordField = $0 }
        alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
            promise.finish( .failure( AppError.cancelled ) )
        } )
        alertController.addAction( UIAlertAction( title: action, style: .default ) { _ in
            if !secretField.try() {
                mperror( title: "Couldn't import user", message: "Missing personal secret", in: viewController.view )

                event?.end(
                        [ "result": "!userSecret",
                          "type": "secret",
                          "length": secretField.text?.count ?? 0,
                          "entropy": Attacker.entropy( string: secretField.text ) ?? 0,
                        ] )
                event = track.flatMap { Tracker.shared.begin( track: $0 ) }
                viewController.present( alertController, animated: true )
            }
        } )
        viewController.present( alertController, animated: true )

        return promise.then {
            event?.end(
                    [ "result": $0.name,
                      "type": "secret",
                      "length": secretField.text?.count ?? 0,
                      "entropy": Attacker.entropy( string: secretField.text ) ?? 0,
                      "error": $0.error ?? "-",
                    ] )
        }
    }
}

class UserSecretField<U>: UITextField, UITextFieldDelegate, Updatable {
    var userName:  String?
    var nameField: UITextField? {
        willSet {
            self.nameField?.delegate = nil
        }
        didSet {
            if let nameField = self.nameField {
                nameField.delegate = self
                nameField.placeholder = "Your full name"
                nameField.autocapitalizationType = .words
                nameField.returnKeyType = .next
                nameField.textAlignment = .center
            }
        }
    }
    var passwordField: UITextField? {
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
                passwordField.returnKeyType = .continue
                passwordField.leftView = self.leftItemView
                passwordField.rightView = self.rightItemView
                passwordField.leftViewMode = .always
                passwordField.rightViewMode = .always
                passwordField.textAlignment = .center

                NotificationCenter.default.addObserver( forName: UITextField.textDidChangeNotification, object: passwordField, queue: nil ) { notification in
                    self.setNeedsIdenticon()
                }
            }
        }
    }
    override var text: String? {
        didSet {
            self.setNeedsIdenticon()
        }
    }
    var authenticater: ((SecretKeyFactory) throws -> Promise<U>)?
    var authenticated: ((Result<U, Error>) -> Void)?

    private let activityIndicator = UIActivityIndicatorView( style: .gray )
    private lazy var identiconLabel    = UILabel()
    private lazy var leftItemView      = UIView()
    private lazy var rightItemView     = UIView()
    private lazy var leftMinimumWidth  = self.leftItemView.widthAnchor.constraint( equalToConstant: 0 ).with( priority: .defaultLow )
    private lazy var rightMinimumWidth = self.rightItemView.widthAnchor.constraint( equalToConstant: 0 ).with( priority: .defaultLow )

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(userName: String? = nil, nameField: UITextField? = nil) {
        self.userName = userName
        super.init( frame: .zero )

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

    // MARK: --- Interface ---

    public func setNeedsIdenticon() {
        DispatchQueue.main.perform {
            if (self.nameField?.text ?? self.userName) == nil || self.passwordField?.text == nil {
                self.updateTask.cancel()
                self.identiconLabel.attributedText = nil
            }
            else {
                self.updateTask.request()
            }
        }
    }

    public func `try`(_ textField: UITextField? = nil) -> Bool {
        if let field = textField ?? self.nameField ?? self.passwordField {
            return self.textFieldShouldReturn( field )
        }

        return false
    }

    public func authenticate<U>(_ handler: ((SecretKeyFactory) throws -> Promise<U>)?) -> Promise<U>? {
        DispatchQueue.main.await {
            guard let handler = handler,
                  let userName = self.nameField?.text ?? self.userName, userName.count > 0,
                  let userSecret = self.passwordField?.text, userSecret.count > 0
            else { return nil }

            self.passwordField?.isEnabled = false
            self.activityIndicator.startAnimating()

            return DispatchQueue.api.promising {
                try handler( SecretKeyFactory( userName: userName, userSecret: userSecret ) )
            }.then( on: .main ) { result in
                self.passwordField?.text = nil
                self.passwordField?.isEnabled = true
                switch result {
                    case .success:
                        self.passwordField?.resignFirstResponder()

                    case .failure:
                        self.passwordField?.becomeFirstResponder()
                        self.passwordField?.shake()
                }
                self.activityIndicator.stopAnimating()
            }
        }
    }

    // MARK: --- Updatable ---

    lazy var updateTask = DispatchTask.update( self, deadline: .now() + .milliseconds( .random( in: 300..<500 ) ) ) { [weak self] in
        guard let self = self
        else { return }

        let userName   = self.nameField?.text ?? self.userName
        let userSecret = self.passwordField?.text

        DispatchQueue.api.perform {
            let identicon = spectre_identicon( userName, userSecret )

            DispatchQueue.main.perform {
                self.identiconLabel.attributedText = identicon.attributedText()
                self.leftMinimumWidth.constant = 0
                self.rightMinimumWidth.constant = 0
                let rightWidth = self.rightItemView.systemLayoutSizeFitting( UIView.layoutFittingCompressedSize ).width,
                    leftWidth  = self.leftItemView.systemLayoutSizeFitting( UIView.layoutFittingCompressedSize ).width
                self.leftMinimumWidth.constant = rightWidth
                self.rightMinimumWidth.constant = leftWidth
            }
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        true
    }

    @discardableResult
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let authentication = self.authenticate( self.authenticater ) {
            authentication.then( on: .main ) { result in
                textField.resignFirstResponder()
                self.authenticated?( result )
            }
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
