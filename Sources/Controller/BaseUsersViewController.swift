//
//  BaseUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import LocalAuthentication

extension Optional: Identifiable where Wrapped == Marshal.UserFile {
    var id: String {
        self.flatMap { $0.id } ?? ""
    }
}

class BaseUsersViewController: BaseViewController, UICollectionViewDelegate, MarshalObserver {
    internal var selectedFile: Marshal.UserFile? {
        didSet {
            if oldValue != self.selectedFile {
                trc( "Selected user: %@", self.selectedFile )

                UIView.animate( withDuration: .short ) {
                    self.userEvent?.end( [ "result": "deselected" ] )

                    if let selectedItem = self.usersSpinner.selectedItem {
                        Feedback.shared.play( .activate )

                        Tracker.shared.event( track: .subject( "users", action: "user", [
                            "value": selectedItem,
                            "items": self.usersSpinner.numberOfItems( inSection: 0 ),
                        ] ) )
                        self.userEvent = Tracker.shared.begin( track: .subject( "users", action: "user" ) )
                    }
                    else {
                        self.userEvent = nil
                    }
                }
            }
        }
    }
    internal lazy var fileSource = UsersSource( viewController: self )
    private var userEvent: Tracker.TimedEvent?

    internal let usersSpinner = SpinnerView()
    internal let detailsHost  = DetailHostController()

    // MARK: --- Life ---

    override var next: UIResponder? {
        self.detailsHost
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = .border( 8 )

        self.usersSpinner.register( UserCell.self )
        self.usersSpinner.delegate = self
        self.usersSpinner.dataSource = self.fileSource
        self.usersSpinner.backgroundColor = .clear
        self.usersSpinner.indicatorStyle = .white

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.addSubview( self.usersSpinner )
        self.view.addSubview( self.detailsHost.view )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.usersSpinner )
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.detailsHost.view )
                .constrain( as: .box ).activate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        Marshal.shared.observers.register( observer: self )
        do { let _ = try Marshal.shared.setNeedsUpdate().await() }
        catch { err( "Cannot read user documents: %@", error ) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        Marshal.shared.observers.unregister( observer: self )
        self.usersSpinner.requestSelection( item: nil )

        super.viewWillDisappear( animated )
    }

    // MARK: --- Interface ---

    func login(user: User) {
        self.usersSpinner.requestSelection( item: nil )
    }

    // MARK: --- UICollectionViewDelegate ---

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.usersSpinner.selectedItem = nil
        Feedback.shared.play( .flick )
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectedFile = self.fileSource.element( item: self.usersSpinner.selectedItem ) ?? nil
        (self.usersSpinner.cellForItem( at: indexPath ) as? UserCell)?.userEvent = self.userEvent
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        self.selectedFile = self.fileSource.element( item: self.usersSpinner.selectedItem ) ?? nil
    }

    // MARK: --- MarshalObserver ---

    func userFilesDidChange(_ userFiles: [Marshal.UserFile]) {
        self.fileSource.update( [ userFiles.sorted() ] )
    }

    // MARK: --- Types ---

    class UsersSource: DataSource<Marshal.UserFile?> {
        let viewController: BaseUsersViewController

        init(viewController: BaseUsersViewController) {
            self.viewController = viewController
            super.init( collectionView: viewController.usersSpinner )
        }

        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            using( UserCell.dequeue( from: collectionView, indexPath: indexPath ) ) {
                $0.viewController = self.viewController
                $0.userFile = self.element( at: indexPath ) ?? nil
            }
        }
    }

    class UserCell: UICollectionViewCell, ThemeObserver, InAppFeatureObserver {
        public override var isSelected: Bool {
            didSet {
                if self.userFile == nil {
                    if self.isSelected {
                        self.avatar = User.Avatar.userAvatars.randomElement() ?? .avatar_0
                    }
                    else {
                        self.avatar = .avatar_add
                    }
                }

                DispatchQueue.main.perform {
                    if !self.isSelected {
                        self.nameField.text = nil
                        self.secretField.text = nil
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

        internal weak var userEvent:      Tracker.TimedEvent?
        internal weak var userFile:       Marshal.UserFile? {
            didSet {
                self.secretField.userName = self.userFile?.userName
                self.avatar = self.userFile?.avatar ?? .avatar_add
                self.update()
            }
        }
        internal weak var viewController: BaseUsersViewController?

        private var avatar    = User.Avatar.avatar_add {
            didSet {
                self.update()
            }
        }
        private let nameLabel = UILabel()
        private let nameField = UITextField()
        private lazy var avatarButton = EffectButton( track: .subject( "users.user", action: "avatar" ),
                                                      border: 0, background: false ) { _, _ in self.avatar.next() }
        private lazy var biometricButton = TimedButton( track: .subject( "users.user", action: "auth" ),
                                                        image: .icon( "" ), border: 0, background: false, square: true )
        private var secretEvent:                 Tracker.TimedEvent?
        private let secretField   = UserSecretField<User>()
        private let idBadgeView   = UIImageView( image: .icon( "" ) )
        private let authBadgeView = UIImageView( image: .icon( "" ) )
        private var authenticationConfiguration: LayoutConfiguration<UserSecretField<User>>!
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

            // - View
            self.isOpaque = false
            self.contentView.layoutMargins = .border( 20 )

            self.nameLabel => \.font => Theme.current.font.callout
            self.nameLabel.adjustsFontSizeToFitWidth = true
            self.nameLabel.textAlignment = .center
            self.nameLabel => \.textColor => Theme.current.color.body
            self.nameLabel.numberOfLines = 0
            self.nameLabel.preferredMaxLayoutWidth = .infinity
            self.nameLabel.alignmentRectOutsets = .horizontal()

            self.avatarButton.setContentCompressionResistancePriority( .defaultHigh - 1, for: .vertical )

            self.biometricButton.action( for: .primaryActionTriggered ) {
                self.attemptBiometrics()
            }

            self.secretField.borderStyle = .roundedRect
            self.secretField => \.font => Theme.current.font.callout
            self.secretField.placeholder = "Your personal secret"
            self.secretField.nameField = self.nameField
            self.secretField.rightView = self.biometricButton
            self.secretField.rightViewMode = .always
            self.secretField.authenticater = { keyFactory in
                self.secretEvent = Tracker.shared.begin( track: .subject( "users.user", action: "auth" ) )

                return self.userFile?.authenticate( using: keyFactory ) ??
                        User( userName: keyFactory.userName ).login( using: keyFactory )
            }
            self.secretField.authenticated = { result in
                trc( "User secret authentication: %@", result )

                do {
                    let user = try result.get()
                    Feedback.shared.play( .trigger )
                    self.secretEvent?.end(
                            [ "result": result.name,
                              "type": "secret",
                              "length": self.secretField.text?.count ?? 0,
                              "entropy": Attacker.entropy( string: self.secretField.text ) ?? 0,
                            ] )
                    self.userEvent?.end( [ "result": result.name, "type": "secret" ] )
                    self.viewController?.login( user: user )
                }
                catch {
                    self.secretEvent?.end(
                            [ "result": result.name,
                              "type": "secret",
                              "length": self.secretField.text?.count ?? 0,
                              "entropy": Attacker.entropy( string: self.secretField.text ) ?? 0,
                              "error": error,
                            ] )
                    mperror( title: "Couldn't unlock user", message: "User authentication failed", error: error )
                }
            }

            self.nameField.alpha = .off
            self.nameField.borderStyle = .none
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.alignmentRectOutsets = .horizontal()
            self.nameField.attributedPlaceholder = NSAttributedString( string: "Your full name" )
            self.nameField => \.attributedPlaceholder => .foregroundColor => Theme.current.color.placeholder
            self.nameField => \.font => Theme.current.font.callout.transform { $0?.withSize( UIFont.labelFontSize * 2 ) }
            self.nameField => \.textColor => Theme.current.color.body

            self.idBadgeView.alignmentRectOutsets = .border()
            self.authBadgeView.alignmentRectOutsets = .border()
            self.secretField.alignmentRectOutsets = .horizontal()

            // - Hierarchy
            self.contentView.addSubview( self.idBadgeView )
            self.contentView.addSubview( self.authBadgeView )
            self.contentView.addSubview( self.avatarButton )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.nameField )
            self.contentView.addSubview( self.secretField )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrain( as: .horizontalCenter, margin: true ).activate()
            LayoutConfiguration( view: self.nameLabel )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: self.avatarButton.topAnchor, constant: -20 ) }
                    .activate()
            LayoutConfiguration( view: self.nameField )
                    .constrain { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: self.avatarButton.topAnchor, constant: -20 ) }
                    .activate()
            LayoutConfiguration( view: self.avatarButton )
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.secretField )
                    .constrain { $1.topAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: 20 ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            self.authenticationConfiguration = LayoutConfiguration( view: self.secretField ) { active, inactive in
                active.set( .on, keyPath: \.alpha )
                inactive.set( .off, keyPath: \.alpha )
            }
                    .apply( LayoutConfiguration( view: self.secretField ) { active, inactive in
                        active.set( true, keyPath: \.isEnabled )
                        inactive.set( false, keyPath: \.isEnabled )
                        inactive.set( nil, keyPath: \.text )
                    } )
                    .apply( LayoutConfiguration( view: self.idBadgeView ) { active, inactive in
                        active.constrain { $1.trailingAnchor.constraint( equalTo: self.avatarButton.leadingAnchor ) }
                        active.constrain { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        active.set( .on, keyPath: \.alpha )
                        inactive.constrain { $1.centerXAnchor.constraint( equalTo: self.avatarButton.centerXAnchor ) }
                        inactive.constrain { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        inactive.set( .off, keyPath: \.alpha )
                    } )
                    .apply( LayoutConfiguration( view: self.authBadgeView ) { active, inactive in
                        active.constrain { $1.leadingAnchor.constraint( equalTo: self.avatarButton.trailingAnchor ) }
                        active.constrain { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        active.set( .on, keyPath: \.alpha )
                        inactive.constrain { $1.centerXAnchor.constraint( equalTo: self.avatarButton.centerXAnchor ) }
                        inactive.constrain { $1.centerYAnchor.constraint( equalTo: self.avatarButton.centerYAnchor ) }
                        inactive.set( .off, keyPath: \.alpha )
                    } )
                    .needs( .layout( view: WeakBox( self ) ) )
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove( toWindow: newWindow )

            if newWindow != nil {
                InAppFeature.observers.register( observer: self )
                Theme.current.observers.register( observer: self )
            }
            else {
                InAppFeature.observers.unregister( observer: self )
                Theme.current.observers.unregister( observer: self )
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            let path          = CGMutablePath()
            let idBadgeRect   = self.convert( self.idBadgeView.alignmentRect, from: self.contentView )
            let nameRect      = self.convert( self.nameLabel.alignmentRect, from: self.contentView )
            let authBadgeRect = self.convert( self.authBadgeView.alignmentRect, from: self.contentView )
            let secretRect    = self.convert( self.secretField.alignmentRect, from: self.contentView )

            if self.isSelected {
                path.addPath( CGPath.between( idBadgeRect, nameRect ) )
                if self.authenticationConfiguration.isActive {
                    path.addPath( CGPath.between( authBadgeRect, secretRect ) )
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
            guard InAppFeature.premium.isEnabled, let userFile = self.userFile, userFile.biometricLock
            else { return }

            let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
            guard keychainKeyFactory.hasKey( for: userFile.algorithm )
            else { return }

            keychainKeyFactory.unlock().promising {
                userFile.authenticate( using: $0 )
            }.then( on: .main ) { [unowned self] result in
                trc( "User biometric authentication: %@", result )

                do {
                    let user = try result.get()
                    Feedback.shared.play( .trigger )
                    self.biometricButton.timing?.end(
                            [ "result": result.name,
                              "type": "biometric",
                              "factor": KeychainKeyFactory.factor.description,
                            ] )
                    self.userEvent?.end( [ "result": result.name, "type": "biometric" ] )
                    self.viewController?.login( user: user )
                }
                catch {
                    self.biometricButton.timing?.end(
                            [ "result": result.name,
                              "type": "biometric",
                              "factor": KeychainKeyFactory.factor.description,
                              "error": error,
                            ] )

                    switch error {
                        case LAError.userCancel, LAError.userCancel, LAError.systemCancel, LAError.appCancel, LAError.notInteractive:
                            wrn( "Biometrics cancelled: %@", error )
                        default:
                            mperror( title: "Couldn't unlock user", error: error )
                    }
                }
            }
        }

        private func update() {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: .long ) {
                    self.authenticationConfiguration.isActive = self.isSelected

                    self.nameLabel.alpha = self.isSelected && self.userFile == nil ? .off: .on
                    self.nameField.alpha = .on - self.nameLabel.alpha
                    self.secretField.nameField = self.nameField.alpha == .on ? self.nameField : nil

                    self.avatarButton.isUserInteractionEnabled = self.isSelected
                    self.avatarButton.image = self.avatar.image
                    self.nameLabel.text = self.userFile?.userName ?? "Tap to create a new user"

                    self.biometricButton.isHidden = !InAppFeature.premium.isEnabled || !(self.userFile?.biometricLock ?? false) ||
                            !(self.userFile?.keychainKeyFactory.hasKey( for: self.userFile?.algorithm ?? .current ) ?? false)
                    self.biometricButton.image = KeychainKeyFactory.factor.icon
                    self.biometricButton.sizeToFit()

                    if self.isSelected {
                        if self.nameField.alpha != .off {
                            self.nameField.becomeFirstResponder()
                        }
                        else if self.authenticationConfiguration.isActive {
                            self.secretField.becomeFirstResponder()
                        }
                    }
                    else {
                        self.secretField.resignFirstResponder()
                        self.nameField.resignFirstResponder()
                    }
                }
            }
        }
    }
}
