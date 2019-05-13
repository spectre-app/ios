//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPUsersViewController: UIViewController, MPSpinnerDelegate {
    public var users = [ MPMarshal.UserInfo ]() {
        willSet {
            DispatchQueue.main.perform {
                for user in self.users {
                    for subview in self.usersSpinner.subviews {
                        if let avatarView = subview as? UserView, user === avatarView.user {
                            avatarView.removeFromSuperview()
                        }
                    }
                }
            }
        }
        didSet {
            DispatchQueue.main.perform {
                for user in self.users {
                    self.usersSpinner.addSubview( UserView( user: user, navigateWith: self.navigationController ) )
                }

                self.usersSpinner.selectedItem = self.usersSpinner.items - 1
            }
        }
    }

    private let usersSpinner = MPSpinnerView()
    private let nameLabel    = UILabel()

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( nibName: nil, bundle: nil )

        MPMarshal.shared.loadFiles { self.users = $0 ?? [] }
    }

    override func viewDidLoad() {
        self.view.addSubview( self.usersSpinner )
        self.usersSpinner.addSubview( UserView( user: nil, navigateWith: self.navigationController ) )
        self.usersSpinner.delegate = self

        ViewConfiguration( view: self.usersSpinner ).constrainToSuperview().activate()

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.view.bottomAnchor ) ]
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.usersSpinner.activatedItem = nil
    }

    // MARK: --- MPSpinnerDelegate ---

    func spinner(_ spinner: MPSpinnerView, didScanItem scannedItem: CGFloat) {
    }

    func spinner(_ spinner: MPSpinnerView, didSelectItem selectedItem: Int?) {
    }

    func spinner(_ spinner: MPSpinnerView, didActivateItem activatedItem: Int) {
        if let userView = spinner.subviews[activatedItem] as? UserView {
            userView.active = true
        }
    }

    func spinner(_ spinner: MPSpinnerView, didDeactivateItem deactivatedItem: Int) {
        if let userView = spinner.subviews[deactivatedItem] as? UserView {
            userView.active = false
        }
    }

    // MARK: --- Types ---

    class UserView: UIView, UITextFieldDelegate {
        public var new: Bool = false
        public var active: Bool = false {
            didSet {
                DispatchQueue.main.perform {
                    let anim = POPSpringAnimation( sizeOfFontAtKeyPath: "font", on: UILabel.self )
                    anim.toValue = UIFont.labelFontSize * (self.active ? 2: 1)
                    self.nameLabel.pop_add( anim, forKey: "pop.font" )
                    self.nameField.pop_add( anim, forKey: "pop.font" )

                    UIView.animate( withDuration: 0.6 ) {
                        self.passwordField.alpha = self.active ? 1: 0
                        self.nameLabel.alpha = self.active && self.user == nil ? 0: 1
                        self.nameField.alpha = 1 - self.nameLabel.alpha

                        if self.active {
                            self.passwordConfiguration.activate()
                        }
                        else {
                            self.passwordConfiguration.deactivate()
                        }

                        self.passwordField.becomeFirstResponder()
                        self.nameField.becomeFirstResponder()
                    }
                }
                self.setNeedsDisplay()
            }
        }
        public var user: MPMarshal.UserInfo? {
            didSet {
                DispatchQueue.main.perform {
                    self.avatarView.image = (self.user?.avatar ?? MPUser.Avatar.avatar_add).image()
                    self.nameLabel.text = self.user?.fullName ?? "Tap to create a new user"
                }
            }
        }

        private let navigationController:  UINavigationController?
        private let nameLabel          = UILabel()
        private let nameField          = UITextField()
        private let avatarView         = UIImageView()
        private let passwordField      = UITextField()
        private let passwordIndicator  = UIActivityIndicatorView( activityIndicatorStyle: .gray )
        private var identiconItem:         DispatchWorkItem?
        private let identiconLabel     = UILabel()
        private let identiconAccessory = UIInputView( frame: .zero, inputViewStyle: .default )
        private let idBadgeView        = UIImageView( image: UIImage( named: "icon_user" ) )
        private let authBadgeView      = UIImageView( image: UIImage( named: "icon_key" ) )
        private var passwordConfiguration: ViewConfiguration!
        private var path               = CGMutablePath() {
            didSet {
                self.setNeedsDisplay()
            }
        }

        // MARK: --- Life ---

        init(user: MPMarshal.UserInfo?, navigateWith navigationController: UINavigationController?) {
            self.navigationController = navigationController
            super.init( frame: CGRect() )

            self.isOpaque = false
            self.layoutMargins = UIEdgeInsets( top: 20, left: 20, bottom: 20, right: 20 )

            self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = .white
            self.nameLabel.numberOfLines = 0
            self.nameLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

            self.nameField.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
            self.nameField.textAlignment = .center
            self.nameField.textColor = .white
            self.nameField.borderStyle = .none
            self.nameField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )
            self.nameField.attributedPlaceholder = stra( "Your Full Name", [
                NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent( 0.382 )
            ] )
            self.nameField.returnKeyType = .next
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.delegate = self
            self.nameField.alpha = 0

            self.avatarView.contentMode = .center

            self.identiconLabel.font = UIFont( name: "SourceCodePro-Regular", size: UIFont.labelFontSize )
            self.identiconLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 ) )
            self.identiconLabel.shadowColor = .darkGray
            self.identiconLabel.textColor = .lightText

            self.identiconAccessory.allowsSelfSizing = true
            self.identiconAccessory.translatesAutoresizingMaskIntoConstraints = false
            self.identiconAccessory.addSubview( self.identiconLabel )
            ViewConfiguration( view: self.identiconLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    .activate()

            self.passwordField.placeholder = "Your master password"
            self.passwordField.borderStyle = .roundedRect
            self.passwordField.font = UIFont( name: "SourceCodePro-Regular", size: UIFont.systemFontSize )
            self.passwordField.textAlignment = .center
            self.passwordField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )
            self.passwordField.inputAccessoryView = self.identiconAccessory
            self.passwordField.isSecureTextEntry = true
            self.passwordField.delegate = self

            self.passwordIndicator.hidesWhenStopped = true
            self.passwordIndicator.frame = self.passwordIndicator.frame.insetBy( dx: -8, dy: 0 )
            self.passwordField.rightView = self.passwordIndicator
            self.passwordField.leftView = UIView( frame: self.passwordIndicator.frame )
            self.passwordField.leftViewMode = .always
            self.passwordField.rightViewMode = .always

            self.idBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 0 ) )
            self.authBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 0, bottom: 0, right: 8 ) )

            self.addSubview( self.idBadgeView )
            self.addSubview( self.authBadgeView )
            self.addSubview( self.avatarView )
            self.addSubview( self.nameLabel )
            self.addSubview( self.nameField )
            self.addSubview( self.passwordField )

            ViewConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.avatarView.topAnchor, constant: -20 ) }
                    .activate()
            ViewConfiguration( view: self.nameField )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.avatarView.topAnchor, constant: -20 ) }
                    .activate()
            ViewConfiguration( view: self.avatarView )
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .activate()
            ViewConfiguration( view: self.passwordField )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.avatarView.bottomAnchor, constant: 20 ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            self.passwordConfiguration = ViewConfiguration( view: self.passwordField ) { active, inactive in
                active.set( 1, forKey: "alpha" )
                active.set( true, forKey: "enabled" )
                inactive.set( 0, forKey: "alpha" )
                inactive.set( false, forKey: "enabled" )
                inactive.set( nil, forKey: "text" )
            }
                    .apply( ViewConfiguration( view: self.idBadgeView ) { active, inactive in
                        active.constrainTo { $1.trailingAnchor.constraint( equalTo: self.avatarView.leadingAnchor ) }
                        active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                        active.set( 1, forKey: "alpha" )
                        inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarView.centerXAnchor ) }
                        inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                        inactive.set( 0, forKey: "alpha" )
                    } )
                    .apply( ViewConfiguration( view: self.authBadgeView ) { active, inactive in
                        active.constrainTo { $1.leadingAnchor.constraint( equalTo: self.avatarView.trailingAnchor ) }
                        active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                        active.set( 1, forKey: "alpha" )
                        inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarView.centerXAnchor ) }
                        inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarView.centerYAnchor ) }
                        inactive.set( 0, forKey: "alpha" )
                    } )
                    .needsLayout( self )

            NotificationCenter.default.addObserver( forName: .UITextFieldTextDidChange, object: self.passwordField, queue: nil ) { notification in
                self.setNeedsIdenticon()
            }

            defer {
                self.user = user
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            let path = CGMutablePath()
            if self.passwordConfiguration.activated {
                path.addPath( CGPathCreateBetween( self.idBadgeView.alignmentRect, self.nameLabel.alignmentRect ) )
                path.addPath( CGPathCreateBetween( self.authBadgeView.alignmentRect, self.passwordField.alignmentRect ) )
            }
            self.path = path
        }

        override func draw(_ rect: CGRect) {
            super.draw( rect )

            if self.active, let context = UIGraphicsGetCurrentContext() {
                UIColor.white.withAlphaComponent( 0.618 ).setStroke()
                context.addPath( self.path )
                context.strokePath()
            }
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove( toWindow: newWindow )

            if newWindow == nil {
                self.identiconItem?.cancel()
            }
        }

        // MARK: --- UITextFieldDelegate ---

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if textField == self.passwordField {
                self.identiconLabel.text = nil
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if textField == self.passwordField {
                self.identiconLabel.text = nil
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if textField == self.nameField || textField == self.passwordField {
                if let fullName = self.user?.fullName ?? self.nameField.text, fullName.count > 0 {
                    if let masterPassword = self.passwordField.text, masterPassword.count > 0 {
                        textField.resignFirstResponder()
                        self.passwordIndicator.startAnimating()

                        if let user = self.user {
                            user.authenticate( masterPassword: masterPassword ) {
                                (user: MPUser?, error: MPMarshalError) in

                                DispatchQueue.main.perform {
                                    self.passwordIndicator.stopAnimating()

                                    if let user = user, error.type == .success {
                                        self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )
                                    }
                                    else {
                                        self.passwordField.becomeFirstResponder()
                                        self.passwordField.shake()
                                    }
                                }
                            }
                        }
                        else {
                            DispatchQueue.mpw.perform {
                                let user    = MPUser( named: fullName )
                                let success = user.mpw_authenticate( masterPassword: masterPassword )

                                DispatchQueue.main.perform {
                                    self.passwordIndicator.stopAnimating()

                                    if success {
                                        self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )
                                    }
                                    else {
                                        self.passwordField.becomeFirstResponder()
                                        self.passwordField.shake()
                                    }
                                }
                            }
                        }
                    }
                    else {
                        self.passwordField.becomeFirstResponder()
                        self.passwordField.shake()
                        return false
                    }
                }
                else {
                    self.nameField.becomeFirstResponder()
                    self.nameField.shake()
                    return false
                }
            }

            return true
        }

        // MARK: --- Private ---

        func setNeedsIdenticon() {
            self.identiconItem?.cancel()
            self.identiconItem = DispatchWorkItem( qos: .userInitiated ) {
                if let userName = self.user?.fullName {
                    if let masterPassword = self.passwordField.text {
                        let identicon = mpw_identicon( userName, masterPassword )

                        DispatchQueue.main.perform {
                            self.identiconLabel.text = [
                                String( cString: identicon.leftArm ),
                                String( cString: identicon.body ),
                                String( cString: identicon.rightArm ),
                                String( cString: identicon.accessory ) ].joined()
                            switch identicon.color {
                                case .black:
                                    self.identiconLabel.textColor = .black
                                case .red:
                                    self.identiconLabel.textColor = .red
                                case .green:
                                    self.identiconLabel.textColor = .green
                                case .yellow:
                                    self.identiconLabel.textColor = .yellow
                                case .blue:
                                    self.identiconLabel.textColor = .blue
                                case .magenta:
                                    self.identiconLabel.textColor = .magenta
                                case .cyan:
                                    self.identiconLabel.textColor = .cyan
                                case .white:
                                    self.identiconLabel.textColor = .white
                            }
                        }
                    }
                }
            }

            DispatchQueue.mpw.asyncAfter( wallDeadline: .now() + .milliseconds( .random( in: 300..<500 ) ), execute: self.identiconItem! )
        }
    }
}

