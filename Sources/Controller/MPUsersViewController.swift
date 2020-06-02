//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPUsersViewController: MPViewController, UICollectionViewDelegate, UICollectionViewDataSource, MPMarshalObserver {
    public lazy var fileSource = DataSource<MPMarshal.UserFile>( collectionView: self.usersSpinner )
    public var selectedFile: MPMarshal.UserFile? {
        didSet {
            if oldValue != self.selectedFile {
                trc( "Selected user: %@", self.selectedFile )

                UIView.animate( withDuration: 0.382 ) {
                    self.userToolbarConfiguration.activated = self.selectedFile != nil

                    self.userEvent?.end( [ "result": "deselected" ] )
                    if let selectedItem = self.usersSpinner.selectedItem {
                        MPFeedback.shared.play( .activate )

                        MPTracker.shared.event( named: "users >user", [
                            "value": selectedItem,
                            "items": self.usersSpinner.numberOfItems( inSection: 0 ),
                        ] )
                        self.userEvent = MPTracker.shared.begin( named: "users #user" )
                    } else {
                        self.userEvent = nil
                    }
                }
            }
        }
    }

    private let appToolbar   = UIStackView()
    private let usersSpinner = MPSpinnerView()
    private let userToolbar  = UIToolbar( frame: .infinite )
    private let detailsHost  = MPDetailsHostController()
    private var userToolbarConfiguration: LayoutConfiguration!
    private var keyboardLayoutGuide:      KeyboardLayoutGuide!
    private var userEvent:                MPTracker.TimedEvent?

    // MARK: --- Life ---

    override var next: UIResponder? {
        self.detailsHost
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init() {
        super.init()

        MPMarshal.shared.observers.register( observer: self )
    }

    override func viewDidLoad() {

        // - View
        self.view.layoutMargins = UIEdgeInsets( top: 8, left: 8, bottom: 8, right: 8 )

        self.usersSpinner.register( UserCell.self )
        self.usersSpinner.delegate = self
        self.usersSpinner.dataSource = self
        self.usersSpinner.backgroundColor = .clear
        self.usersSpinner.indicatorStyle = .white

        self.appToolbar.axis = .horizontal
        self.appToolbar.spacing = 12
        self.appToolbar.addArrangedSubview( MPButton( identifier: "users #app_settings", image: UIImage.icon( "" ), background: false ) { _, _ in
            self.detailsHost.show( MPAppDetailsViewController() )
        } )
        self.appToolbar.addArrangedSubview( MPTimedButton( identifier: "users #auth_incognito", image: UIImage.icon( "" ), background: false ) { _, incognitoButton in
            guard let incognitoButton = incognitoButton as? MPTimedButton
            else { return }
            let incognitoEvent = MPTracker.shared.begin( named: "users #user" )

            let controller = UIAlertController( title: "Incognito Login", message:
            """
            While in incognito mode, no user information is kept on the device.
            """, preferredStyle: .alert )

            let passwordField = MPMasterPasswordField()
            let spinner       = MPAlert( title: "Unlocking", message: passwordField.nameField?.text,
                                         content: UIActivityIndicatorView( style: .whiteLarge ) )
            passwordField.authenticater = { keyFactory in
                spinner.show( dismissAutomatically: false )
                return MPUser( fullName: keyFactory.fullName, file: nil ).login( keyFactory: keyFactory )
            }
            passwordField.authenticated = { result in
                trc( "Incognito authentication: %@", result )
                incognitoButton.timing?.end( [
                                                 "result": result.name,
                                                 "length": passwordField.text?.count ?? 0,
                                                 "entropy": MPAttacker.entropy( string: passwordField.text ) ?? 0,
                                             ] )

                spinner.dismiss()
                controller.dismiss( animated: true ) {
                    switch result {
                        case .success(let user):
                            MPFeedback.shared.play( .trigger )
                            incognitoEvent.end( [ "result": "incognito" ] )
                            self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )

                        case .failure(let error):
                            mperror( title: "Couldn't unlock user", error: error )
                    }
                }
            }

            controller.addTextField { passwordField.nameField = $0 }
            controller.addTextField { passwordField.passwordField = $0 }
            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                incognitoButton.timing?.end( [ "result": "cancel" ] )
            } )
            controller.addAction( UIAlertAction( title: "Log In", style: .default ) { [weak self] _ in
                guard let self = self
                else { return }

                if !passwordField.try() {
                    mperror( title: "Couldn't unlock user", message: "Missing credentials" )
                    self.present( controller, animated: true )
                }
            } )
            self.present( controller, animated: true )
        } )

        self.userToolbar.barStyle = .black
        self.userToolbar.items = [
            UIBarButtonItem( barButtonSystemItem: .trash, target: self, action: #selector( didTrashUser ) ),
            UIBarButtonItem( barButtonSystemItem: .rewind, target: self, action: #selector( didResetUser ) )
        ]

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.addSubview( self.usersSpinner )
        self.view.addSubview( self.appToolbar )
        self.view.addSubview( self.userToolbar )
        self.view.addSubview( self.detailsHost.view )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.usersSpinner )
                .constrain( anchors: .topBox )
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ).with( priority: .defaultHigh ) }
                .activate()

        LayoutConfiguration( view: self.appToolbar )
                .constrain( margins: true, anchors: .bottomCenter )
                .activate()

        LayoutConfiguration( view: self.userToolbar )
                .constrain( anchors: .horizontally )
                .activate()

        LayoutConfiguration( view: self.detailsHost.view )
                .constrain()
                .activate()

        self.userToolbarConfiguration = LayoutConfiguration( view: self.userToolbar ) { active, inactive in
            active.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ).with( priority: .defaultHigh ) }
            active.set( 1, forKey: "alpha" )
            inactive.constrainTo { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ).with( priority: .defaultHigh ) }
            inactive.set( 0, forKey: "alpha" )
        }

        self.keyboardLayoutGuide = KeyboardLayoutGuide( in: self.view ) { keyboardLayoutGuide in
            [
                self.usersSpinner.bottomAnchor.constraint( equalTo: keyboardLayoutGuide.topAnchor ),
                self.userToolbar.bottomAnchor.constraint( equalTo: keyboardLayoutGuide.topAnchor ).with( priority: .defaultHigh + 1 ),
            ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.keyboardLayoutGuide.install()

        MPMarshal.shared.setNeedsReload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.keyboardLayoutGuide.uninstall()
        self.usersSpinner.selectItem( nil )

        super.viewWillDisappear( animated )
    }

    // MARK: --- Private ---

    @objc
    private func didTrashUser() {
        if let userFile = self.selectedFile {
            let alert = UIAlertController( title: "Delete User?", message:
            """
            This will delete the user and all of its recorded state:
            \(userFile)

            Note: You can re-create the user at any time and add back your sites to fully regenerate their stateless passwords and other content.
            When re-creating the user, make sure to use the exact same name and master password.
            The user's identicon (\(userFile.identicon.text() ?? "-")) is a good manual check that you got this right.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Delete", style: .destructive ) { [weak self, weak userFile] _ in
                guard let self = self, let user = userFile
                else { return }
                trc( "Trashing user: %@", user )

                if MPMarshal.shared.delete( userFile: user ) {
                    self.fileSource.remove( user )
                }
            } )
            self.present( alert, animated: true )
        }
    }

    @objc
    private func didResetUser() {
        if let userFile = self.selectedFile {
            let alert = UIAlertController( title: "Reset Master Password?", message:
            """
            This will allow you to change the master password for:
            \(userFile)

            Note: When the user's master password changes, its site passwords and other generated content will also change accordingly.
            The master password can always be changed back to revert to the user's current site passwords and generated content.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Reset", style: .destructive ) { [weak userFile] _ in
                trc( "Resetting user: %@", userFile )

                userFile?.resetKey = true
            } )
            self.present( alert, animated: true )
        }
    }

    // MARK: --- UICollectionViewDataSource ---

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        self.fileSource.numberOfSections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.fileSource.numberOfItems( in: section )
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        UserCell.dequeue( from: collectionView, indexPath: indexPath ) { cell in
            (cell as? UserCell)?.navigationController = self.navigationController
            (cell as? UserCell)?.userFile = self.fileSource.element( at: indexPath )
        }
    }

    // MARK: --- UICollectionViewDelegate ---

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.usersSpinner.selectedItem = nil
        MPFeedback.shared.play( .flick )
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectedFile = self.fileSource.element( item: self.usersSpinner.selectedItem )
        (self.usersSpinner.cellForItem( at: indexPath ) as? UserCell)?.userEvent = self.userEvent
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        self.selectedFile = self.fileSource.element( item: self.usersSpinner.selectedItem )
    }

    // MARK: --- MPMarshalObserver ---

    func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]) {
        trc( "Users updated: %@", userFiles )

        self.fileSource.update( [ userFiles.sorted() + [ nil ] ], reloadItems: true )
        DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) ) { self.usersSpinner.flashScrollIndicators() }
    }

    // MARK: --- Types ---

    class UserCell: UICollectionViewCell, MPConfigObserver {
        public override var isSelected: Bool {
            didSet {
                if self.userFile == nil {
                    if self.isSelected {
                        self.avatar = MPUser.Avatar.userAvatars.randomElement() ?? .avatar_0
                    }
                    else {
                        self.avatar = .avatar_add
                    }
                }

                DispatchQueue.main.perform {
                    if !self.isSelected {
                        self.nameField.text = nil
                        self.passwordField.text = nil
                    }

                    self.nameLabel.font = self.nameLabel.font.withSize( UIFont.labelFontSize * (self.isSelected ? 2: 1) )
//                    self.nameLabel.font.pointSize.animate(
//                            to: UIFont.labelFontSize * (self.isSelected ? 2: 1), duration: 0.618, render: {
//                        self.nameLabel.font = self.nameLabel.font.withSize( $0 )
//                    } )

                    self.update()
                }
            }
        }

        public var new: Bool = false
        public weak var userEvent:            MPTracker.TimedEvent?
        public weak var userFile:             MPMarshal.UserFile? {
            didSet {
                self.passwordField.userFile = self.userFile
                self.avatar = self.userFile?.avatar ?? .avatar_add
                self.update()
            }
        }
        public weak var navigationController: UINavigationController?

        private var avatar          = MPUser.Avatar.avatar_add {
            didSet {
                self.update()
            }
        }
        private let nameLabel       = UILabel()
        private let nameField       = UITextField()
        private let avatarButton    = MPButton( identifier: "users.user #avatar", background: false )
        private let biometricButton = MPTimedButton( identifier: "users.user #auth_biometric", image: UIImage.icon( "" ), background: false ) // TODO: biometry-specific icon
        private var passwordEvent:               MPTracker.TimedEvent?
        private let passwordField   = MPMasterPasswordField()
        private let idBadgeView     = UIImageView( image: UIImage.icon( "" ) )
        private let authBadgeView   = UIImageView( image: UIImage.icon( "" ) )
        private var authenticationConfiguration: LayoutConfiguration!
        private var path:                        CGPath? {
            didSet {
                if oldValue != self.path {
                    self.setNeedsDisplay()
                }
            }
        }

        // MARK: --- Life ---

        override init(frame: CGRect) {
            super.init( frame: CGRect() )

            appConfig.observers.register( observer: self )

            // - View
            self.isOpaque = false
            self.contentView.layoutMargins = UIEdgeInsets( top: 20, left: 20, bottom: 20, right: 20 )

            self.nameLabel => \.font => Theme.current.font.callout
            self.nameLabel.adjustsFontSizeToFitWidth = true
            self.nameLabel.textAlignment = .center
            self.nameLabel => \.textColor => Theme.current.color.body
            self.nameLabel.numberOfLines = 0
            self.nameLabel.preferredMaxLayoutWidth = .infinity
            self.nameLabel.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 )

            self.avatarButton.setContentCompressionResistancePriority( .defaultHigh - 1, for: .vertical )
            self.avatarButton.button.action( for: .primaryActionTriggered ) { [unowned self] in
                self.avatar.next()
            }

            self.passwordField.borderStyle = .roundedRect
            self.passwordField => \.font => Theme.current.font.callout
            self.passwordField.placeholder = "Your master password"
            self.passwordField.nameField = self.nameField
            self.passwordField.rightView = self.biometricButton
            self.passwordField.rightViewMode = .always
            self.passwordField.authenticater = { keyFactory in
                self.passwordEvent = MPTracker.shared.begin( named: "users.user #auth_password" )

                return self.userFile?.authenticate( keyFactory: keyFactory ) ??
                        MPUser( fullName: keyFactory.fullName ).login( keyFactory: keyFactory )
            }
            self.passwordField.authenticated = { result in
                trc( "User password authentication: %@", result )
                self.passwordEvent?.end( [
                                             "result": result.name,
                                             "length": self.passwordField.text?.count ?? 0,
                                             "entropy": MPAttacker.entropy( string: self.passwordField.text ) ?? 0,
                                         ] )

                switch result {
                    case .success(let user):
                        MPFeedback.shared.play( .trigger )
                        self.userEvent?.end( [ "result": "password" ] )
                        self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )

                    case .failure(let error):
                        mperror( title: "Couldn't unlock user", message: "User authentication failed", error: error )
                }
            }

            self.nameField => \.font => Theme.current.font.callout.transform { $0?.withSize( UIFont.labelFontSize * 2 ) }
            self.nameField => \.textColor => Theme.current.color.body
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.borderStyle = .none
            self.nameField.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 )
            self.nameField.attributedPlaceholder = NSAttributedString( string: "Your Full Name" )
            Theme.current.color.placeholder.apply(to: self.nameField, at: \.attributedPlaceholder, attribute: .foregroundColor)
            self.nameField.alpha = 0

            self.biometricButton.button.action( for: .primaryActionTriggered ) { [unowned self] in
                guard let userFile = self.userFile
                else { return }

                let keychainKeyFactory = MPKeychainKeyFactory( fullName: userFile.fullName )
                userFile.authenticate( keyFactory: keychainKeyFactory ).then( on: .main ) { result in
                    trc( "User biometric authentication: %@", result )
                    self.biometricButton.timing?.end( [
                                                          "result": result.name,
                                                          "factor": keychainKeyFactory.factor.description,
                                                      ] )

                    switch result {
                        case .success(let user):
                            MPFeedback.shared.play( .trigger )
                            self.userEvent?.end( [ "result": "biometric" ] )
                            self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )

                        case .failure:
                            keychainKeyFactory.purgeKeys()
                            self.update()
                    }
                }
            }

            self.idBadgeView.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 0 )
            self.authBadgeView.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 0, bottom: 0, right: 8 )
            self.passwordField.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 )

            // - Hierarchy
            self.contentView.addSubview( self.idBadgeView )
            self.contentView.addSubview( self.authBadgeView )
            self.contentView.addSubview( self.avatarButton )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.nameField )
            self.contentView.addSubview( self.passwordField )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrain()
                    .activate()
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

            self.authenticationConfiguration = LayoutConfiguration( view: self.passwordField ) { active, inactive in
                active.set( 1, forKey: "alpha" )
                inactive.set( 0, forKey: "alpha" )
            }
                    .apply( LayoutConfiguration( view: self.passwordField ) { active, inactive in
                        active.set( true, forKey: "enabled" )
                        inactive.set( false, forKey: "enabled" )
                        inactive.set( nil, forKey: "text" )
                    } )
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
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            let path = CGMutablePath()
            if self.isSelected {
                path.addPath( CGPath.between( self.idBadgeView.alignmentRect, self.nameLabel.alignmentRect ) )
                if self.authenticationConfiguration.activated {
                    path.addPath( CGPath.between( self.authBadgeView.alignmentRect, self.passwordField.alignmentRect ) )
                }
            }
            self.path = path.isEmpty ? nil: path
        }

        override func draw(_ rect: CGRect) {
            super.draw( rect )

            if let path = self.path, let context = UIGraphicsGetCurrentContext() {
                Theme.current.color.mute.get()?.setStroke()
                context.addPath( path )
                context.strokePath()
            }
        }

        // MARK: --- MPConfigObserver ---

        func didChangeConfig() {
            self.update()
        }

        // MARK: --- Private ---

        private func update() {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: 0.618 ) {
                    self.nameLabel.alpha = self.isSelected && self.userFile == nil ? 0: 1
                    self.nameField.alpha = 1 - self.nameLabel.alpha

                    self.avatarButton.isUserInteractionEnabled = self.isSelected
                    self.avatarButton.image = self.avatar.image
                    self.nameLabel.text = self.userFile?.fullName ?? "Tap to create a new user"

                    let keychainKeyFactory = self.userFile.flatMap { MPKeychainKeyFactory( fullName: $0.fullName ) }
                    self.biometricButton.isHidden = !appConfig.premium ||
                            !(keychainKeyFactory?.hasKey( algorithm: self.userFile?.algorithm ?? .current ) ?? false)
                    self.biometricButton.image = keychainKeyFactory?.factor.icon
                    self.biometricButton.sizeToFit()

                    if self.isSelected {
                        self.authenticationConfiguration.activate()

                        if self.nameField.alpha != 0 {
                            self.nameField.becomeFirstResponder()
                        }
                        else if self.authenticationConfiguration.activated {
                            self.passwordField.becomeFirstResponder()
                        }
                    }
                    else {
                        self.authenticationConfiguration.deactivate()
                        self.passwordField.resignFirstResponder()
                        self.nameField.resignFirstResponder()
                    }
                }
            }
        }
    }
}
