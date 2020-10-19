//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import LocalAuthentication

class BasicUsersViewController: MPViewController, UICollectionViewDelegate, UICollectionViewDataSource, MPMarshalObserver {
    internal var selectedFile: MPMarshal.UserFile? {
        didSet {
            if oldValue != self.selectedFile {
                trc( "Selected user: %@", self.selectedFile )

                UIView.animate( withDuration: .short ) {
                    self.usersSpinner.selectedItem = self.fileSource.indexPath( for: self.selectedFile )?.item
                    self.userEvent?.end( [ "result": "deselected" ] )

                    if let selectedItem = self.usersSpinner.selectedItem {
                        MPFeedback.shared.play( .activate )

                        MPTracker.shared.event( named: "users >user", [
                            "value": selectedItem,
                            "items": self.usersSpinner.numberOfItems( inSection: 0 ),
                        ] )
                        self.userEvent = MPTracker.shared.begin( named: "users #user" )
                    }
                    else {
                        self.userEvent = nil
                    }
                }
            }
        }
    }
    internal lazy var fileSource = DataSource<MPMarshal.UserFile>( collectionView: self.usersSpinner )
    private var userEvent: MPTracker.TimedEvent?

    private let  usersSpinner = MPSpinnerView()
    internal let detailsHost  = MPDetailsHostController()

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
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = UIEdgeInsets( top: 8, left: 8, bottom: 8, right: 8 )

        self.usersSpinner.register( UserCell.self )
        self.usersSpinner.delegate = self
        self.usersSpinner.dataSource = self
        self.usersSpinner.backgroundColor = .clear
        self.usersSpinner.indicatorStyle = .white

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.addSubview( self.usersSpinner )
        self.view.addSubview( self.detailsHost.view )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.usersSpinner )
                .constrain( anchors: .topBox )
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ).with( priority: .defaultHigh ) }
                .activate()

        LayoutConfiguration( view: self.detailsHost.view )
                .constrain()
                .activate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        MPMarshal.shared.setNeedsUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.keyboardLayoutGuide.add( constraints: {
            [ self.usersSpinner.bottomAnchor.constraint( equalTo: $0.topAnchor ) ]
        } )
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.usersSpinner.selectItem( nil )

        super.viewWillDisappear( animated )
    }

    // MARK: --- Interface ---

    func login(user: MPUser) {
        self.usersSpinner.selectItem( nil )
    }

    // MARK: --- UICollectionViewDataSource ---

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) ) { [weak collectionView] in
            collectionView?.flashScrollIndicators()
        }

        return self.fileSource.numberOfSections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.fileSource.numberOfItems( in: section )
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        UserCell.dequeue( from: collectionView, indexPath: indexPath ) { cell in
            (cell as? UserCell)?.viewController = self
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
        self.fileSource.update( [ userFiles.sorted() ], reloadItems: true )
    }

    // MARK: --- Types ---

    class UserCell: UICollectionViewCell, ThemeObserver, InAppFeatureObserver {
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
                    else {
                        self.attemptBiometrics()
                    }

                    self.nameLabel.font = self.nameLabel.font.withSize( UIFont.labelFontSize * (self.isSelected ? 2: 1) )
//                    self.nameLabel.font.pointSize.animate(
//                            to: UIFont.labelFontSize * (self.isSelected ? 2: 1), duration: .long, render: {
//                        self.nameLabel.font = self.nameLabel.font.withSize( $0 )
//                    } )

                    self.update()
                }
            }
        }

        internal weak var userEvent:      MPTracker.TimedEvent?
        internal weak var userFile:       MPMarshal.UserFile? {
            didSet {
                self.passwordField.userFile = self.userFile
                self.avatar = self.userFile?.avatar ?? .avatar_add
                self.update()
            }
        }
        internal weak var viewController: BasicUsersViewController?

        private var avatar          = MPUser.Avatar.avatar_add {
            didSet {
                self.update()
            }
        }
        private let nameLabel       = UILabel()
        private let nameField       = UITextField()
        private let avatarButton    = MPButton( identifier: "users.user #avatar", background: false )
        private let biometricButton = MPTimedButton( identifier: "users.user #auth_biometric", image: .icon( "" ), background: false )
        private var passwordEvent:               MPTracker.TimedEvent?
        private let passwordField   = MPMasterPasswordField()
        private let idBadgeView     = UIImageView( image: .icon( "" ) )
        private let authBadgeView   = UIImageView( image: .icon( "" ) )
        private var authenticationConfiguration: LayoutConfiguration<MPMasterPasswordField>!
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

            InAppFeature.observers.register( observer: self )

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
            self.avatarButton.action( for: .primaryActionTriggered ) { [unowned self] in
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

                return self.userFile?.authenticate( using: keyFactory ) ??
                        MPUser( fullName: keyFactory.fullName ).login( using: keyFactory )
            }
            self.passwordField.authenticated = { result in
                trc( "User password authentication: %@", result )
                self.passwordEvent?.end(
                        [ "result": result.name,
                          "length": self.passwordField.text?.count ?? 0,
                          "entropy": MPAttacker.entropy( string: self.passwordField.text ) ?? 0,
                        ] )

                do {
                    let user = try result.get()
                    MPFeedback.shared.play( .trigger )
                    self.userEvent?.end( [ "result": "password" ] )
                    self.viewController?.login( user: user )
                }
                catch {
                    mperror( title: "Couldn't unlock user", message: "User authentication failed", error: error )
                }
            }

            self.nameField.alpha = .off
            self.nameField.borderStyle = .none
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.alignmentRectOutsets = UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 )
            self.nameField.attributedPlaceholder = NSAttributedString( string: "Your Full Name" )
            self.nameField => \.attributedPlaceholder => .foregroundColor => Theme.current.color.placeholder
            self.nameField => \.font => Theme.current.font.callout.transform { $0?.withSize( UIFont.labelFontSize * 2 ) }
            self.nameField => \.textColor => Theme.current.color.body

            self.biometricButton.action( for: .primaryActionTriggered ) { [unowned self] in
                self.attemptBiometrics()
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
                active.set( 1, keyPath: \.alpha )
                inactive.set( 0, keyPath: \.alpha )
            }
                    .apply( LayoutConfiguration( view: self.passwordField ) { active, inactive in
                        active.set( true, keyPath: \.isEnabled )
                        inactive.set( false, keyPath: \.isEnabled )
                        inactive.set( nil, keyPath: \.text )
                    } )
                    .apply( LayoutConfiguration( view: self.idBadgeView ) { active, inactive in
                        active.constrainTo { $1.trailingAnchor.constraint( equalTo: self.avatarButton.leadingAnchor ) }
                        active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        active.set( 1, keyPath: \.alpha )
                        inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarButton.centerXAnchor ) }
                        inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        inactive.set( 0, keyPath: \.alpha )
                    } )
                    .apply( LayoutConfiguration( view: self.authBadgeView ) { active, inactive in
                        active.constrainTo { $1.leadingAnchor.constraint( equalTo: self.avatarButton.trailingAnchor ) }
                        active.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        active.set( 1, keyPath: \.alpha )
                        inactive.constrainTo { $1.centerXAnchor.constraint( equalTo: self.avatarButton.centerXAnchor ) }
                        inactive.constrainTo { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        inactive.set( 0, keyPath: \.alpha )
                    } )
                    .needs( .layout( view: WeakBox( self ) ) )
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func willMove(toSuperview newSuperview: UIView?) {
            super.willMove( toSuperview: newSuperview )

            if newSuperview != nil {
                Theme.current.observers.register( observer: self )
            }
            else {
                Theme.current.observers.unregister( observer: self )
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            let path = CGMutablePath()
            if self.isSelected {
                path.addPath( CGPath.between( self.idBadgeView.alignmentRect, self.nameLabel.alignmentRect ) )
                if self.authenticationConfiguration.isActive {
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

        // MARK: --- ThemeObserver ---

        func didChangeTheme() {
            self.setNeedsDisplay()
        }

        // MARK: --- InAppFeatureObserver ---

        func featureDidChange(_ feature: InAppFeature) {
            if case .premium = feature {
                self.update()
            }
        }

        // MARK: --- Private ---

        private func attemptBiometrics() {
            guard InAppFeature.premium.enabled(), let userFile = self.userFile, userFile.biometricLock
            else { return }

            let keychainKeyFactory = MPKeychainKeyFactory( fullName: userFile.fullName )
            guard keychainKeyFactory.hasKey( for: userFile.algorithm )
            else { return }

            keychainKeyFactory.unlock().promising {
                userFile.authenticate( using: $0 )
            }.then( on: .main ) { [unowned self] result in
                trc( "User biometric authentication: %@", result )
                self.biometricButton.timing?.end(
                        [ "result": result.name,
                          "factor": MPKeychainKeyFactory.factor.description,
                        ] )

                do {
                    let user = try result.get()
                    MPFeedback.shared.play( .trigger )
                    self.userEvent?.end( [ "result": "biometric" ] )
                    self.viewController?.login( user: user )
                }
                catch {
                    switch error {
                        case LAError.userCancel, LAError.userCancel, LAError.systemCancel, LAError.appCancel, LAError.notInteractive:
                            wrn( "Biometrics cancelled: %@", error )
                        default:
                            mperror( title: "Biometrics Rejected", error: error )
                    }
                }
            }
        }

        private func update() {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: .long ) {
                    self.nameLabel.alpha = self.isSelected && self.userFile == nil ? .off: .on
                    self.nameField.alpha = .on - self.nameLabel.alpha

                    self.avatarButton.isUserInteractionEnabled = self.isSelected
                    self.avatarButton.image = self.avatar.image
                    self.nameLabel.text = self.userFile?.fullName ?? "Tap to create a new user"

                    self.biometricButton.isHidden = !InAppFeature.premium.enabled() || !(self.userFile?.biometricLock ?? false) ||
                            !(self.userFile?.keychainKeyFactory.hasKey( for: self.userFile?.algorithm ?? .current ) ?? false)
                    self.biometricButton.image = MPKeychainKeyFactory.factor.icon
                    self.biometricButton.sizeToFit()

                    if self.isSelected {
                        self.authenticationConfiguration.activate()

                        if self.nameField.alpha != .off {
                            self.nameField.becomeFirstResponder()
                        }
                        else if self.authenticationConfiguration.isActive {
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
