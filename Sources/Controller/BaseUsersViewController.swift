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

                    if let selectedItem = self.usersCarousel.selectedItem {
                        Feedback.shared.play( .activate )

                        Tracker.shared.event( track: .subject( "users", action: "user", [
                            "value": selectedItem,
                            "items": self.usersCarousel.numberOfItems( inSection: 0 ),
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

    internal let usersCarousel = CarouselView()
    internal let detailsHost   = DetailHostController()

    // MARK: --- Life ---

    override var next: UIResponder? {
        self.detailsHost
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = .border( 8 )

        self.usersCarousel.register( UserCell.self )
        self.usersCarousel.delegate = self
        self.usersCarousel.dataSource = self.fileSource
        self.usersCarousel.backgroundColor = .clear
        self.usersCarousel.indicatorStyle = .white

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.addSubview( self.usersCarousel )
        self.view.addSubview( self.detailsHost.view )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.usersCarousel )
                .constrain( as: .box, to: self.keyboardLayoutGuide.inputLayoutGuide ).activate()
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
        self.usersCarousel.selectedItem = nil

        super.viewWillDisappear( animated )
    }

    // MARK: --- KeyboardLayoutObserver ---

    override func keyboardDidChange(showing: Bool, layoutGuide: KeyboardLayoutGuide) {
    }

    // MARK: --- Interface ---

    func login(user: User) {
        self.usersCarousel.selectedItem = nil
    }

    // MARK: --- UICollectionViewDelegate ---

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.usersCarousel.selectedItem = nil
        Feedback.shared.play( .flick )
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectedFile = self.fileSource.element( item: self.usersCarousel.selectedItem ) ?? nil
        (self.usersCarousel.cellForItem( at: indexPath ) as? UserCell)?.userEvent = self.userEvent
        self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = true }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        (self.usersCarousel.cellForItem( at: indexPath ) as? UserCell)?.userEvent = nil
        self.selectedFile = self.fileSource.element( item: self.usersCarousel.selectedItem ) ?? nil
        self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = false }
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
            super.init( collectionView: viewController.usersCarousel )
        }

        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            using( UserCell.dequeue( from: collectionView, indexPath: indexPath ) ) { cell in
                UIView.performWithoutAnimation {
                    cell.viewController = self.viewController
                    cell.userFile = self.element( at: indexPath ) ?? nil
                    cell.updateTask.request( immediate: true )
                }
            }
        }
    }

    class UserCell: UICollectionViewCell, ThemeObserver, InAppFeatureObserver, Updatable {
        public var hasSelected = false {
            didSet {
                self.contentView.alpha = self.hasSelected ? (self.isSelected ? .on: .off): .on
            }
        }
        public override var isSelected: Bool {
            didSet {
                if self.isSelected {
                    if self.userFile == nil {
                        self.avatar = User.Avatar.allCases.randomElement()
                    }
                    else {
                        self.attemptBiometrics()
                    }
                }
                else {
                    if self.userFile == nil {
                        self.avatar = nil
                    }
                    self.nameField.text = nil
                    self.secretField.text = nil
                }

//                self.nameLabel.font = self.nameLabel.font.withSize( UIFont.labelFontSize * (self.isSelected ? 2: 1) )
//                self.nameLabel.font.pointSize.animate(
//                        to: UIFont.labelFontSize * (self.isSelected ? 2: 1), duration: .long, render: {
//                    self.nameLabel.font = self.nameLabel.font.withSize( $0 )
//                } )

                self.updateTask.request()
            }
        }
        override var alpha: CGFloat {
            didSet {
                self.nameLabel.alpha = self.alpha
            }
        }
        internal weak var userEvent: Tracker.TimedEvent?
        internal var userFile: Marshal.UserFile? {
            didSet {
                if self.userFile != oldValue {
                    self.secretField.userName = self.userFile?.userName
                    self.avatar = self.userFile?.avatar
                    self.updateTask.request()
                }
            }
        }
        internal weak var viewController: BaseUsersViewController?

        private var avatar: User.Avatar? {
            didSet {
                if self.avatar != oldValue {
                    self.updateTask.request()
                }
            }
        }
        private let nameLabel = UILabel()
        private let nameField = UITextField()
        private let floorView = BackgroundView( mode: .tint )
        private let avatarTip = UILabel()
        private lazy var avatarButton = EffectButton( track: .subject( "users.user", action: "avatar" ),
                                                      border: 0, background: false, circular: false ) { _, _ in self.avatar?.next() }
        private lazy var biometricButton = TimedButton( track: .subject( "users.user", action: "auth" ),
                                                        image: .icon( "" ), border: 0, background: false, square: true )
        private var secretEvent:                 Tracker.TimedEvent?
        private let secretField   = UserSecretField<User>()
        private let idBadgeView   = UIImageView( image: .icon( "" ) )
        private let authBadgeView = UIImageView( image: .icon( "" ) )
        private var authenticationConfiguration: LayoutConfiguration<UserCell>!
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

            self.nameLabel.alignmentRectOutsets = .horizontal()
            self.nameLabel => \.font => Theme.current.font.title1
            self.nameLabel.adjustsFontSizeToFitWidth = true
            self.nameLabel.textAlignment = .center
            self.nameLabel => \.textColor => Theme.current.color.body
            self.nameLabel.numberOfLines = 0
            self.nameLabel.preferredMaxLayoutWidth = .infinity

            self.avatarTip.text = "Tap your avatar to change it"
            self.avatarTip.textAlignment = .center
            self.avatarTip => \.font => Theme.current.font.caption1
            self.avatarTip => \.textColor => Theme.current.color.secondary

            self.avatarButton.padded = false
            self.avatarButton.setContentCompressionResistancePriority( .defaultHigh - 1, for: .vertical )

            self.biometricButton.action( for: .primaryActionTriggered ) {
                self.attemptBiometrics()
            }

            self.secretField.alignmentRectOutsets = .horizontal()
            self.secretField.borderStyle = .roundedRect
            self.secretField => \.font => Theme.current.font.callout
            self.secretField.placeholder = "Your personal secret"
            self.secretField.rightView = self.biometricButton
            self.secretField.rightViewMode = .always
            self.secretField.authenticater = { keyFactory in
                self.secretEvent = Tracker.shared.begin( track: .subject( "users.user", action: "auth" ) )

                return self.userFile?.authenticate( using: keyFactory ) ??
                        User( userName: keyFactory.userName ).login( using: keyFactory )
            }
            self.secretField.authenticated = { result in
                do {
                    let user = try result.get()
                    if let avatar = self.avatar {
                        user.avatar = avatar
                    }

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

            self.nameField.isHidden = true
            self.nameField.borderStyle = .none
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.attributedPlaceholder = NSAttributedString( string: "Your full name" )
            self.nameField => \.font => Theme.current.font.title1
            self.nameField => \.textColor => Theme.current.color.body
            self.nameField => \.attributedPlaceholder => .foregroundColor => Theme.current.color.placeholder

            // - Hierarchy
            self.contentView.addSubview( self.idBadgeView )
            self.contentView.addSubview( self.authBadgeView )
            self.contentView.addSubview( self.avatarButton )
            self.contentView.addSubview( self.floorView )
            self.contentView.addSubview( self.avatarTip )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.nameField )
            self.contentView.addSubview( self.secretField )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrain( as: .horizontalCenterV ).activate()
            LayoutConfiguration( view: self.avatarButton )
                    .constrain { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.floorView )
                    .constrain { $1.bottomAnchor.constraint( equalTo: self.avatarButton.bottomAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .constrain { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                    .activate()
            LayoutConfiguration( view: self.avatarTip )
                    .constrain { $1.topAnchor.constraint( equalTo: self.floorView.bottomAnchor ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.nameLabel )
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.nameField )
                    .constrain( as: .box, to: self.nameLabel ).activate()
            LayoutConfiguration( view: self.secretField )
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            self.authenticationConfiguration = LayoutConfiguration( view: self )
                    .apply( LayoutConfiguration( view: self.avatarButton ) { active, inactive in
                        inactive.constrain { $1.bottomAnchor.constraint( equalTo: $0.centerYAnchor ) }
                    } )
                    .apply( LayoutConfiguration( view: self.nameLabel ) { active, inactive in
                        active.constrain { $1.bottomAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: -20 ) }
                        inactive.constrain { $1.topAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: 20 ) }
                    } )
                    .apply( LayoutConfiguration( view: self.secretField ) { active, inactive in
                        active.set( .on, keyPath: \.alpha )
                        active.set( true, keyPath: \.isEnabled )
                        active.constrain { $1.topAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: 32 ) }
                        inactive.set( .off, keyPath: \.alpha )
                        inactive.set( false, keyPath: \.isEnabled )
                        inactive.set( nil, keyPath: \.text )
                        inactive.constrain { $1.topAnchor.constraint( equalTo: self.nameLabel.bottomAnchor, constant: 8 ) }
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
                    .needs( .layout )
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
                self.updateTask.request()
            }
        }

        // MARK: --- Private ---

        @discardableResult
        private func attemptBiometrics() -> Promise<User> {
            guard InAppFeature.premium.isEnabled
            else { return Promise( .failure( AppError.state( title: "Biometrics not available." ) ) ) }
            guard let userFile = self.userFile, userFile.biometricLock
            else { return Promise( .failure( AppError.state( title: "Biometrics not enabled.", details: self.userFile ) ) ) }
            let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
            guard keychainKeyFactory.hasKey( for: userFile.algorithm )
            else { return Promise( .failure( AppError.state( title: "Biometrics key not present." ) ) ) }

            return keychainKeyFactory.unlock().promising {
                userFile.authenticate( using: $0 )
            }.then( on: .main ) { [unowned self] result in
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

        // MARK: --- Updatable ---

        lazy var updateTask = DispatchTask.update( self, animated: true ) { [weak self] in
            guard let self = self
            else { return }

            self.authenticationConfiguration.isActive = self.isSelected

            self.nameLabel.text = self.userFile?.userName ?? "Add a new user"
            self.nameLabel.isHidden = self.isSelected && self.userFile == nil
            self.nameField.isHidden = !self.nameLabel.isHidden
            self.avatarTip.isHidden = self.nameField.isHidden
            self.secretField.nameField = !self.nameField.isHidden ? self.nameField: nil
            self.avatarButton.isUserInteractionEnabled = self.isSelected
            self.avatarButton.image = self.avatar?.image ?? .icon( "", withSize: 96, invert: true )

            self.biometricButton.isHidden = !InAppFeature.premium.isEnabled || !(self.userFile?.biometricLock ?? false) ||
                    !(self.userFile?.keychainKeyFactory.hasKey( for: self.userFile?.algorithm ?? .current ) ?? false)
            self.biometricButton.image = .icon( KeychainKeyFactory.factor.icon )
            self.biometricButton.sizeToFit()

            if self.isSelected {
                if !self.nameField.isHidden {
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
