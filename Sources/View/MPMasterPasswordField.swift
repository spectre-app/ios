//
// Created by Maarten Billemont on 2019-06-29.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMasterPasswordField: UITextField, UITextFieldDelegate {
    var userFile:  MPMarshal.UserFile?
    var nameField: UITextField?
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

                passwordField.inputAccessoryView = self.identiconAccessory
                passwordField.rightView = self.passwordIndicator
                passwordField.leftView = UIView( frame: self.passwordIndicator.frame )
                passwordField.leftViewMode = .always
                passwordField.rightViewMode = .always

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
    var actionHandler:    ((String, String) -> MPUser?)?
    var actionCompletion: ((MPUser?) -> Void)?

    private let passwordIndicator  = UIActivityIndicatorView( style: .gray )
    private let identiconAccessory = UIInputView( frame: .zero, inputViewStyle: .default )
    private let identiconLabel     = UILabel()
    private lazy var identiconTask = DispatchTask( queue: DispatchQueue.main, qos: .userInitiated,
                                                   deadline: .now() + .milliseconds( .random( in: 300..<500 ) ) ) {
        let userName       = self.userFile?.fullName ?? self.nameField?.text
        let masterPassword = self.passwordField?.text

        DispatchQueue.mpw.perform {
            let identicon = mpw_identicon( userName, masterPassword )

            DispatchQueue.main.perform {
                self.identiconLabel.attributedText = identicon.attributedText()
            }
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(userFile: MPMarshal.UserFile? = nil, nameField: UITextField? = nil) {
        self.userFile = userFile
        self.nameField = nameField
        super.init( frame: .zero )

        self.passwordIndicator.frame = self.passwordIndicator.frame.insetBy( dx: -8, dy: 0 )

        self.identiconLabel.font = MPTheme.global.font.password.get()?.withSize( UIFont.labelFontSize )
        self.identiconLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 ) )
        self.identiconLabel.textColor = MPTheme.global.color.body.get()
        self.identiconLabel.shadowColor = MPTheme.global.color.shadow.get()
        self.identiconLabel.shadowOffset = CGSize( width: 0, height: 1 )

        self.identiconAccessory.allowsSelfSizing = true
        self.identiconAccessory.translatesAutoresizingMaskIntoConstraints = false
        self.identiconAccessory.addSubview( self.identiconLabel )

        LayoutConfiguration( view: self.identiconLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
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

    // MARK: Interface

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

    func mpw_process<U>(handler: @escaping (String, String) -> U, completion: ((U) -> Void)? = nil) -> Bool {
        DispatchQueue.main.await { [weak self] in
            guard let self = self,
                  let fullName = self.userFile?.fullName ?? self.nameField?.text, fullName.count > 0,
                  let masterPassword = self.passwordField?.text, masterPassword.count > 0
            else { return false }

            self.passwordField?.isEnabled = false
            self.passwordIndicator.startAnimating()

            DispatchQueue.mpw.perform { [weak self] in
                guard let self = self
                else { return }

                let user = handler( fullName, masterPassword )

                DispatchQueue.main.perform { [weak self] in
                    guard let self = self
                    else { return }

                    self.passwordField?.text = nil
                    self.passwordField?.isEnabled = true
                    self.passwordIndicator.stopAnimating()

                    completion?( user )
                }
            }

            return true
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let actionHandler = self.actionHandler,
           self.mpw_process( handler: actionHandler, completion: { user in
               if user == nil {
                   self.becomeFirstResponder()
                   self.shake()
               }
               self.actionCompletion?( user )
           } ) {
            return true
        }

        if let nameField = self.nameField, nameField.text?.count ?? 0 == 0 {
            nameField.becomeFirstResponder()
            nameField.shake()
            return false
        }

        if let passwordField = self.passwordField, passwordField.text?.count ?? 0 == 0 {
            passwordField.becomeFirstResponder()
            passwordField.shake()
            return false
        }

        return true
    }
}
