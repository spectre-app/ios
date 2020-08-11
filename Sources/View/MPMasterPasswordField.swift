//
// Created by Maarten Billemont on 2019-06-29.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPMasterPasswordField: UITextField, UITextFieldDelegate, Updatable {
    var userFile:  MPMarshal.UserFile?
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
                passwordField.placeholder = "Your master password"
                passwordField.returnKeyType = .continue
                passwordField.inputAccessoryView = self.identiconAccessory
                passwordField.rightView = self.passwordIndicator
                passwordField.leftView = UIView( frame: self.passwordIndicator.frame )
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
    var authenticater: ((MPPasswordKeyFactory) throws -> Promise<MPUser>)?
    var authenticated: ((Result<MPUser, Error>) -> Void)?

    private let passwordIndicator  = UIActivityIndicatorView( style: .gray )
    private let identiconAccessory = UIInputView( frame: .zero, inputViewStyle: .default )
    private let identiconLabel     = UILabel()
    private lazy var identiconTask = DispatchTask( queue: .main, deadline: .now() + .milliseconds( .random( in: 300..<500 ) ),
                                                   qos: .userInitiated, update: self )

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(userFile: MPMarshal.UserFile? = nil, nameField: UITextField? = nil) {
        self.userFile = userFile
        self.nameField = nameField
        super.init( frame: .zero )

        self.passwordIndicator.frame = self.passwordIndicator.frame.insetBy( dx: -8, dy: 0 )

        self.identiconLabel => \.font => Theme.current.font.password.transform { $0?.withSize( UIFont.labelFontSize ) }
        self.identiconLabel => \.textColor => Theme.current.color.body
        self.identiconLabel => \.shadowColor => Theme.current.color.shadow
        self.identiconLabel.shadowOffset = CGSize( width: 0, height: 1 )

        self.identiconAccessory.allowsSelfSizing = true
        self.identiconAccessory.translatesAutoresizingMaskIntoConstraints = false
        self.identiconAccessory.addSubview( self.identiconLabel )

        LayoutConfiguration( view: self.identiconLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor, constant: 4 ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor, constant: 4 ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor, constant: -4 ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor, constant: -4 ) }
                .activate()

        defer {
            self.passwordField = self
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if newWindow == nil {
            self.identiconTask.cancel()
        }
        else {
            self.identiconTask.request()
        }
    }

    // MARK: --- Interface ---

    public func setNeedsIdenticon() {
        DispatchQueue.main.perform {
            if (self.userFile?.fullName ?? self.nameField?.text) == nil || self.passwordField?.text == nil {
                self.identiconTask.cancel()
                self.identiconLabel.attributedText = nil
            }
            else {
                self.identiconTask.request()
            }
        }
    }

    public func `try`(_ textField: UITextField? = nil) -> Bool {
        if let field = textField ?? self.nameField ?? self.passwordField {
            return self.textFieldShouldReturn( field )
        }

        return false
    }

    public func authenticate<U>(_ handler: ((MPPasswordKeyFactory) throws -> Promise<U>)?) -> Promise<U>? {
        DispatchQueue.main.await {
            guard let handler = handler,
                  let fullName = self.userFile?.fullName ?? self.nameField?.text, fullName.count > 0,
                  let masterPassword = self.passwordField?.text, masterPassword.count > 0
            else { return nil }

            self.passwordField?.isEnabled = false
            self.passwordIndicator.startAnimating()

            return DispatchQueue.mpw.promised {
                try handler( MPPasswordKeyFactory( fullName: fullName, masterPassword: masterPassword ) )
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
                self.passwordIndicator.stopAnimating()
            }
        }
    }

    // MARK: --- Updatable ---

    func update() {
        DispatchQueue.main.perform {
            let userName       = self.userFile?.fullName ?? self.nameField?.text
            let masterPassword = self.passwordField?.text

            DispatchQueue.mpw.perform {
                let identicon = mpw_identicon( userName, masterPassword )

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
