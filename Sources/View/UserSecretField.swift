//
// Created by Maarten Billemont on 2019-06-29.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class UserSecretField: UITextField, UITextFieldDelegate, Updatable {
    var userFile:  Marshal.UserFile?
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
                passwordField.inputAccessoryView = self.identiconAccessory
                passwordField.rightView = self.activityIndicator
                passwordField.leftView = UIView( frame: self.activityIndicator.frame )
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
    var authenticater: ((SecretKeyFactory) throws -> Promise<User>)?
    var authenticated: ((Result<User, Error>) -> Void)?

    private let activityIndicator  = UIActivityIndicatorView( style: .gray )
    private let identiconAccessory = UIInputView( frame: .zero, inputViewStyle: .default )
    private let identiconLabel     = UILabel()
    private lazy var updateTask = DispatchTask( deadline: .now() + .milliseconds( .random( in: 300..<500 ) ), update: self )

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(userFile: Marshal.UserFile? = nil, nameField: UITextField? = nil) {
        self.userFile = userFile
        self.nameField = nameField
        super.init( frame: .zero )

        self.activityIndicator.frame = self.activityIndicator.frame.insetBy( dx: -8, dy: 0 )

        self.identiconLabel => \.font => Theme.current.font.password.transform { $0?.withSize( UIFont.labelFontSize ) }
        self.identiconLabel => \.textColor => Theme.current.color.body
        self.identiconLabel => \.shadowColor => Theme.current.color.shadow
        self.identiconLabel.shadowOffset = CGSize( width: 0, height: 1 )

        self.identiconAccessory.allowsSelfSizing = true
        self.identiconAccessory.translatesAutoresizingMaskIntoConstraints = false
        self.identiconAccessory.addSubview( self.identiconLabel )

        LayoutConfiguration( view: self.identiconLabel )
                .constrain { $1.topAnchor.constraint( equalTo: $0.topAnchor, constant: 4 ) }
                .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor, constant: 4 ) }
                .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor, constant: -4 ) }
                .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor, constant: -4 ) }
                .activate()

        defer {
            self.passwordField = self
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if newWindow == nil {
            self.updateTask.cancel()
        }
        else {
            self.updateTask.request()
        }
    }

    // MARK: --- Interface ---

    public func setNeedsIdenticon() {
        DispatchQueue.main.perform {
            if (self.userFile?.userName ?? self.nameField?.text) == nil || self.passwordField?.text == nil {
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
                  let userName = self.userFile?.userName ?? self.nameField?.text, userName.count > 0,
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

    func update() {
        DispatchQueue.main.perform {
            let userName   = self.userFile?.userName ?? self.nameField?.text
            let userSecret = self.passwordField?.text

            DispatchQueue.api.perform {
                let identicon = mpw_identicon( userName, userSecret )

                DispatchQueue.main.perform {
                    self.identiconLabel.attributedText = identicon.attributedText()
                }
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
