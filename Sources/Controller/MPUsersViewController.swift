//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import Crashlytics

class MPUsersViewController: UIViewController, MPSpinnerDelegate, MPMarshalObserver {
    public var users = [ MPMarshal.UserInfo ]() {
        didSet {
            DispatchQueue.main.perform {
                for user in oldValue {
                    for subview in self.usersSpinner.subviews {
                        if let avatarView = subview as? UserView, user === avatarView.user {
                            avatarView.removeFromSuperview()
                        }
                    }
                }
                for user in self.users {
                    self.usersSpinner.addSubview( UserView( user: user, navigateWith: self.navigationController ) )
                }

                self.usersSpinner.selectedItem = self.usersSpinner.items - 1
            }
        }
    }

    private let settingsButton = MPButton( image: UIImage( named: "icon_gears" ) )
    private let usersSpinner   = MPSpinnerView()
    private let userToolbar    = UIToolbar()
    private var userToolbarConfiguration: LayoutConfiguration!

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( nibName: nil, bundle: nil )

        MPMarshal.shared.observers.register( observer: self )
    }

    override func viewDidLoad() {
        self.view.layoutMargins = UIEdgeInsets( top: 8, left: 8, bottom: 8, right: 8 )

        self.usersSpinner.addSubview( UserView( user: nil, navigateWith: self.navigationController ) )
        self.usersSpinner.delegate = self

        self.settingsButton.darkBackground = true

        self.userToolbar.barStyle = .black
        self.userToolbar.items = [
            UIBarButtonItem( barButtonSystemItem: .trash, target: self, action: #selector( didTrashUser ) ),
            UIBarButtonItem( barButtonSystemItem: .rewind, target: self, action: #selector( didResetUser ) )
        ]

        self.view.addSubview( self.usersSpinner )
        self.view.addSubview( self.settingsButton )
        self.view.addSubview( self.userToolbar )

        LayoutConfiguration( view: self.usersSpinner )
                .constrainToOwner( withMargins: false, anchor: .topBox )
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .activate()
        LayoutConfiguration( view: self.settingsButton )
                .constrainToOwner( withMargins: true, anchor: .bottomCenter )
                .activate()
        LayoutConfiguration( view: self.userToolbar )
                .constrainToOwner( withMargins: false, anchor: .horizontally ).activate()

        self.userToolbarConfiguration = LayoutConfiguration( view: self.userToolbar ) { active, inactive in
            active.constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
            active.set( 1, forKey: "alpha" )
            inactive.constrainTo { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ) }
            inactive.set( 0, forKey: "alpha" )
        }

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) { keyboardLayoutGuide in
            [
                self.usersSpinner.bottomAnchor.constraint( equalTo: keyboardLayoutGuide.topAnchor ),
                self.userToolbar.bottomAnchor.constraint( equalTo: keyboardLayoutGuide.topAnchor ).withPriority( .defaultHigh )
            ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        MPMarshal.shared.setNeedsReload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear( animated )

        self.usersSpinner.activatedItem = nil
    }

    // MARK: --- Private ---

    @objc
    private func didTrashUser() {
        if let activatedItem = self.usersSpinner.activatedItem,
           let user = (self.usersSpinner.subviews[activatedItem] as? UserView)?.user {
            let alert = UIAlertController( title: "Delete User?", message:
            """
            This will delete the user and all of its recorded state:
            \(user)

            Note: You can re-create the user at any time and add back your sites to fully regenerate their stateless passwords and other content.
            When re-creating the user, make sure to use the exact same name and master password.
            The user's identicon (\(user.identicon.text() ?? "-")) is a good manual check that you got this right.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Delete", style: .destructive ) { _ in
                if MPMarshal.shared.delete( userInfo: user ) {
                    self.users.removeAll { $0 == user }
                }
            } )
            self.present( alert, animated: true )
        }
    }

    @objc
    private func didResetUser() {
        if let activatedItem = self.usersSpinner.activatedItem,
           let user = (self.usersSpinner.subviews[activatedItem] as? UserView)?.user {
            let alert = UIAlertController( title: "Reset Master Password?", message:
            """
            This will allow you to change the master password for:
            \(user)

            Note: When the user's master password changes, its site passwords and other generated content will also change accordingly.
            The master password can always be changed back to revert to the user's current site passwords and generated content.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Reset", style: .destructive ) { _ in
                user.resetKey = true
            } )
            self.present( alert, animated: true )
        }
    }

    // MARK: --- MPSpinnerDelegate ---

    func spinner(_ spinner: MPSpinnerView, didScanItem scannedItem: CGFloat) {
    }

    func spinner(_ spinner: MPSpinnerView, didSelectItem selectedItem: Int?) {
    }

    func spinner(_ spinner: MPSpinnerView, didActivateItem activatedItem: Int) {
        if spinner.subviews.indices.contains( activatedItem ),
           let userView = spinner.subviews[activatedItem] as? UserView {
            userView.active = true
        }

        UIView.animate( withDuration: 0.382 ) {
            self.userToolbarConfiguration.updateActivated( spinner.activatedItem != nil )
        }
    }

    func spinner(_ spinner: MPSpinnerView, didDeactivateItem deactivatedItem: Int) {
        if spinner.subviews.indices.contains( deactivatedItem ),
           let userView = spinner.subviews[deactivatedItem] as? UserView {
            userView.active = false
        }

        UIView.animate( withDuration: 0.382 ) {
            self.userToolbarConfiguration.updateActivated( spinner.activatedItem != nil )
        }
    }

    // MARK: --- MPMarshalObserver ---

    func usersDidChange(_ users: [MPMarshal.UserInfo]?) {
        self.users = users ?? []
    }

    // MARK: --- Types ---

    class UserView: UIView {
        public var  new:    Bool = false
        public var  active: Bool = false {
            didSet {
                if self.user == nil {
                    if self.active {
                        self.avatar = MPUser.Avatar.userAvatars.randomElement() ?? .avatar_0
                    }
                    else {
                        self.avatar = .avatar_add
                    }
                }

                if !self.active {
                    self.nameField.text = nil
                    self.passwordField.text = nil
                }

                self.update()
                self.setNeedsDisplay()
            }
        }
        public var  user:   MPMarshal.UserInfo? {
            didSet {
                self.passwordField.user = self.user
                self.avatar = self.user?.avatar ?? .avatar_add
                self.update()
            }
        }
        private var avatar       = MPUser.Avatar.avatar_add {
            didSet {
                self.update()
            }
        }

        private let navigationController:  UINavigationController?
        private let nameLabel     = UILabel()
        private let nameField     = UITextField()
        private let avatarButton  = UIButton()
        private let passwordField = MPMasterPasswordField()
        private let idBadgeView   = UIImageView( image: UIImage( named: "icon_user" ) )
        private let authBadgeView = UIImageView( image: UIImage( named: "icon_key" ) )
        private var passwordConfiguration: LayoutConfiguration!
        private var path          = CGMutablePath() {
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

            self.nameLabel.font = MPTheme.global.font.callout.get()
            self.nameLabel.adjustsFontSizeToFitWidth = true
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = MPTheme.global.color.body.get()
            self.nameLabel.numberOfLines = 0
            self.nameLabel.preferredMaxLayoutWidth = .infinity
            self.nameLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

            self.nameField.font = MPTheme.global.font.callout.get()
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.textAlignment = .center
            self.nameField.textColor = MPTheme.global.color.body.get()
            self.nameField.borderStyle = .none
            self.nameField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )
            self.nameField.attributedPlaceholder = stra( "Your Full Name", [
                NSAttributedString.Key.foregroundColor: MPTheme.global.color.body.get()!.withAlphaComponent( 0.382 )
            ] )
            self.nameField.autocapitalizationType = .words
            self.nameField.returnKeyType = .next
            self.nameField.delegate = self.passwordField
            self.nameField.alpha = 0

            self.avatarButton.contentMode = .center
            self.avatarButton.addAction( for: .touchUpInside ) { _, _ in self.avatar.next() }

            self.passwordField.borderStyle = .roundedRect
            self.passwordField.font = MPTheme.global.font.callout.get()
            self.passwordField.textAlignment = .center
            self.passwordField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )
            self.passwordField.nameField = self.nameField
            self.passwordField.actionHandler = { fullName, masterPassword -> MPUser? in
                if let user = self.user {
                    let (user, error) = user.mpw_authenticate( masterPassword: masterPassword )
                    return error.type != .success ? nil: user
                }
                else {
                    let user    = MPUser( fullName: fullName )
                    let success = user.mpw_authenticate( masterPassword: masterPassword )
                    return success ? user: nil
                }
            }
            self.passwordField.actionCompletion = { user in
                if let user = user {
                    self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )
                }
            }

            self.idBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 0 ) )
            self.authBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 0, bottom: 0, right: 8 ) )

            self.addSubview( self.idBadgeView )
            self.addSubview( self.authBadgeView )
            self.addSubview( self.avatarButton )
            self.addSubview( self.nameLabel )
            self.addSubview( self.nameField )
            self.addSubview( self.passwordField )

            LayoutConfiguration( view: self.nameLabel )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.avatarButton.topAnchor, constant: -20 ) }
                    .activate()
            LayoutConfiguration( view: self.nameField )
                    .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: self.avatarButton.topAnchor, constant: -20 ) }
                    .activate()
            LayoutConfiguration( view: self.avatarButton )
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.passwordField )
                    .constrainTo { $1.topAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: 20 ) }
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            self.passwordConfiguration = LayoutConfiguration( view: self.passwordField ) { active, inactive in
                active.set( 1, forKey: "alpha" )
                active.set( true, forKey: "enabled" )
                inactive.set( 0, forKey: "alpha" )
                inactive.set( false, forKey: "enabled" )
                inactive.set( nil, forKey: "text" )
            }
                    .apply( LayoutConfiguration( view: self.idBadgeView ) { active, inactive in
                        active.constrainTo { $1.trailingAnchor.constraint( equalTo: self.avatarButton.leadingAnchor ) }
                        active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        active.set( 1, forKey: "alpha" )
                        inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarButton.centerXAnchor ) }
                        inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        inactive.set( 0, forKey: "alpha" )
                    } )
                    .apply( LayoutConfiguration( view: self.authBadgeView ) { active, inactive in
                        active.constrainTo { $1.leadingAnchor.constraint( equalTo: self.avatarButton.trailingAnchor ) }
                        active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        active.set( 1, forKey: "alpha" )
                        inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarButton.centerXAnchor ) }
                        inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        inactive.set( 0, forKey: "alpha" )
                    } )
                    .needsLayout( self )

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

        // MARK: --- Private ---

        private func update() {
            DispatchQueue.main.perform {
                let anim = POPSpringAnimation( sizeOfFontAtKeyPath: "font", on: UILabel.self )
                anim.toValue = UIFont.labelFontSize * (self.active ? 2: 1)
                self.nameLabel.pop_add( anim, forKey: "pop.font" )
                self.nameField.pop_add( anim, forKey: "pop.font" )

                UIView.animate( withDuration: 0.618 ) {
                    self.passwordField.alpha = self.active ? 1: 0
                    self.nameLabel.alpha = self.active && self.user == nil ? 0: 1
                    self.nameField.alpha = 1 - self.nameLabel.alpha

                    self.avatarButton.isUserInteractionEnabled = self.active
                    self.avatarButton.setImage( self.avatar.image(), for: .normal )
                    self.nameLabel.text = self.user?.fullName ?? "Tap to create a new user"

                    if self.active {
                        self.passwordConfiguration.activate()

                        if self.nameField.alpha != 0 {
                            self.nameField.becomeFirstResponder()
                        }
                        else {
                            self.passwordField.becomeFirstResponder()
                        }
                    }
                    else {
                        self.passwordConfiguration.deactivate()
                        self.passwordField.resignFirstResponder()
                        self.nameField.resignFirstResponder()
                    }
                }
            }
        }
    }
}

