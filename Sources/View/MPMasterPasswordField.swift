//
// Created by Maarten Billemont on 2019-06-29.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMasterPasswordField: UITextField, UITextFieldDelegate {
    var user:      MPMarshal.UserInfo?
    var nameField: UITextField?
    override var text: String? {
        didSet {
            self.setNeedsIdenticon()
        }
    }
    var actionHandler:    ((String, String) -> MPUser?)?
    var actionCompletion: ((MPUser?) -> Void)?

    private let passwordIndicator  = UIActivityIndicatorView( activityIndicatorStyle: .gray )
    private let identiconAccessory = UIInputView( frame: .zero, inputViewStyle: .default )
    private let identiconLabel     = UILabel()
    private var identiconItem: DispatchWorkItem? {
        willSet {
            self.identiconItem?.cancel()
        }
        didSet {
            if let identiconItem = self.identiconItem {
                DispatchQueue.mpw.asyncAfter( wallDeadline: .now() + .milliseconds( .random( in: 300..<500 ) ), execute: identiconItem )
            }
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser? = nil) {
        super.init( frame: .zero )

        self.delegate = self
        self.isSecureTextEntry = true
        self.placeholder = "Your master password"

        self.passwordIndicator.frame = self.passwordIndicator.frame.insetBy( dx: -8, dy: 0 )
        self.rightView = self.passwordIndicator
        self.leftView = UIView( frame: self.passwordIndicator.frame )
        self.leftViewMode = .always
        self.rightViewMode = .always

        self.identiconLabel.font = MPTheme.global.font.password.get()?.withSize( UIFont.labelFontSize )
        self.identiconLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 ) )
        self.identiconLabel.textColor = MPTheme.global.color.body.get()
        self.identiconLabel.shadowColor = MPTheme.global.color.shadow.get()
        self.identiconLabel.shadowOffset = CGSize( width: 0, height: 1 )

        self.identiconAccessory.allowsSelfSizing = true
        self.identiconAccessory.translatesAutoresizingMaskIntoConstraints = false
        self.identiconAccessory.addSubview( self.identiconLabel )
        self.inputAccessoryView = self.identiconAccessory

        LayoutConfiguration( view: self.identiconLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        NotificationCenter.default.addObserver( forName: .UITextFieldTextDidChange, object: self, queue: nil ) { notification in
            self.setNeedsIdenticon()
        }
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if newWindow == nil {
            self.identiconItem = nil
        }
    }

    // MARK: Interface

    func setNeedsIdenticon() {
        if let userName = self.user?.fullName ?? self.nameField?.text,
           let masterPassword = self.text {
            self.identiconItem = DispatchWorkItem( qos: .userInitiated ) {
                let identicon = mpw_identicon( userName, masterPassword )

                DispatchQueue.main.perform {
                    self.identiconLabel.attributedText = identicon.attributedText()
                }
            }
        }
        else {
            self.identiconItem = nil

            DispatchQueue.main.perform {
                self.identiconLabel.attributedText = nil
            }
        }
    }

    func mpw_process(handler: @escaping (String, String) -> MPUser?, completion: ((MPUser?) -> Void)? = nil) -> Bool {
        return DispatchQueue.main.await {
            if let fullName = self.user?.fullName ?? self.nameField?.text, fullName.count > 0,
               let masterPassword = self.text, masterPassword.count > 0 {
                self.isEnabled = false
                self.passwordIndicator.startAnimating()

                DispatchQueue.mpw.perform {
                    let user = handler( fullName, masterPassword )

                    DispatchQueue.main.perform {
                        self.text = nil
                        self.isEnabled = true
                        self.passwordIndicator.stopAnimating()

                        completion?( user )
                    }
                }

                return true
            }

            return false
        }
    }

    // MARK: --- UITextFieldDelegate ---

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

        if self.text?.count ?? 0 == 0 {
            self.becomeFirstResponder()
            self.shake()
            return false
        }

        return true
    }
}
