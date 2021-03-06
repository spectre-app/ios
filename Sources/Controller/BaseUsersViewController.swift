// =============================================================================
// Created by Maarten Billemont on 2018-01-21.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import LocalAuthentication

extension Optional: Identifiable where Wrapped == Marshal.UserFile {
    var id: String {
        self.flatMap { $0.id } ?? ""
    }
}

class BaseUsersViewController: BaseViewController, UICollectionViewDelegate, MarshalObserver {
    internal lazy var usersSource = UsersSource( viewController: self )
    private var userEvent: Tracker.TimedEvent?

    internal let usersCarousel = CarouselView()
    internal let detailsHost   = DetailHostController()
    internal var userActions   = [ UserAction ]()

    // MARK: - Life

    override var next: UIResponder? {
        self.detailsHost
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = .border( 8 )

        self.usersCarousel.register( UserCell.self )
        self.usersCarousel.delegate = self
        self.usersCarousel.dataSource = self.usersSource
        self.usersCarousel.backgroundColor = .clear
        self.usersCarousel.indicatorStyle = .white
        self.usersCarousel.addGestureRecognizer( UILongPressGestureRecognizer { [unowned self] recognizer in
            guard case .began = recognizer.state
            else { return }

            self.usersCarousel.selectItem( at: IndexPath( item: self.usersCarousel.scrolledItem, section: 0 ),
                                           animated: true, scrollPosition: .centeredHorizontally )
            self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = true }
        } )

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

        Marshal.shared.observers.register( observer: self ).didChange( userFiles: Marshal.shared.userFiles )
    }

    override func viewWillDisappear(_ animated: Bool) {
        Marshal.shared.observers.unregister( observer: self )
        self.usersCarousel.selectedItem = nil

        super.viewWillDisappear( animated )
    }

    // MARK: - KeyboardLayoutObserver

    override func didChange(keyboard: KeyboardMonitor, showing: Bool, changing: Bool, fromScreenFrame: CGRect, toScreenFrame: CGRect,
                            curve: UIView.AnimationCurve?, duration: TimeInterval?) {
        // Don't adjust the safe area. Keyboard is handled explicitly.
    }

    // MARK: - Interface

    func sections(for userFiles: [Marshal.UserFile]) -> [[Marshal.UserFile?]] {
        [ userFiles.sorted() ]
    }

    func login(user: User) {
        self.usersCarousel.selectedItem = nil
    }

    // MARK: - UICollectionViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.usersCarousel.selectedItem = nil
        Feedback.shared.play( .flick )
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Feedback.shared.play( .activate )
        Tracker.shared.event( track: .subject( "users", action: "user", [
            "value": indexPath.item,
            "items": self.usersCarousel.numberOfItems( inSection: indexPath.section ),
        ] ) )

        self.userEvent?.end( [ "result": "deselected" ] )
        self.userEvent = Tracker.shared.begin( track: .subject( "users", action: "user" ) )

        if let selectedCell = self.usersCarousel.cellForItem( at: indexPath ) as? UserCell {
            selectedCell.userEvent = self.userEvent
            selectedCell.attemptBiometrics().failure { error in
                inf( "Skipping biometrics. [>PII]" )
                pii( "[>] Error: %@", error )
            }
        }
        self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = true }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        self.userEvent?.end( [ "result": "deselected" ] )
        self.userEvent = nil

        (self.usersCarousel.cellForItem( at: indexPath ) as? UserCell)?.userEvent = nil
        self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = false }
    }

    // MARK: - MarshalObserver

    func didChange(userFiles: [Marshal.UserFile]) {
        let sections = self.sections( for: userFiles )

        DispatchQueue.main.perform {
            let scrolledUser = self.usersSource.element( item: self.usersCarousel.scrolledItem )
            self.usersSource.update( sections ) { _ in
                self.usersCarousel.scrolledItem = self.usersSource.indexPath( where: { $0?.id == scrolledUser?.id } )?.item ?? 0
                self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = self.usersCarousel.selectedItem != nil }
            }
        }
    }

    // MARK: - Types

    class UsersSource: DataSource<Marshal.UserFile?> {
        unowned let viewController: BaseUsersViewController

        init(viewController: BaseUsersViewController) {
            self.viewController = viewController
            super.init( collectionView: viewController.usersCarousel )
        }

        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            using( UserCell.dequeue( from: collectionView, indexPath: indexPath ) ) { cell in
                UIView.performWithoutAnimation {
                    cell.state = (userFile: self.element( at: indexPath ) ?? nil,
                                  userActions: self.viewController.userActions,
                                  viewController: self.viewController)
                }
            }
        }
    }

    class UserCell: UICollectionViewCell, InAppFeatureObserver, Updatable {
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
                }
                else {
                    if self.userFile == nil {
                        self.avatar = nil
                    }
                    self.nameField.text = nil
                    self.secretField.text = nil
                }

                self.updateTask.request()
            }
        }
        override var alpha: CGFloat {
            didSet {
                self.nameLabel.alpha = self.alpha
            }
        }
        internal weak var userEvent: Tracker.TimedEvent?
        internal var state: (userFile: Marshal.UserFile?, userActions: [UserAction], viewController: BaseUsersViewController)! {
            didSet {
                self.userFile = self.state.userFile
                self.userActions = self.state.userActions
                self.viewController = self.state.viewController
                self.updateTask.request( now: true )
            }
        }

        private var userFile: Marshal.UserFile? {
            didSet {
                if self.userFile != oldValue {
                    self.secretField.userName = self.userFile?.userName
                    self.secretField.identicon = self.userFile?.identicon ?? SpectreIdenticonUnset
                    self.avatar = self.userFile?.avatar
                }
            }
        }
        private var userActions = [ UserAction ]() {
            didSet {
                self.actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                self.userActions.forEach { action in
                    self.actionsStack.addArrangedSubview(
                            EffectButton( track: action.tracking, image: .icon( action.icon ), border: 0, background: false ) {
                                [unowned self] _, _ in
                                if let userFile = self.userFile {
                                    action.action( userFile )
                                }
                            } )
                    self.actionsStack.addArrangedSubview( self.biometricButton )
                }
            }
        }
        private weak var viewController: BaseUsersViewController? {
            didSet {
                self.hasSelected = self.viewController?.usersCarousel.selectedItem != nil
            }
        }

        private var avatar:                      User.Avatar? {
            didSet {
                if self.avatar != oldValue {
                    self.updateTask.request()
                }
            }
        }
        private let nameLabel     = UILabel()
        private let nameField     = UITextField()
        private let floorView     = BackgroundView( mode: .tint )
        private let avatarTip     = UILabel()
        private var secretEvent:                 Tracker.TimedEvent?
        private let userNameField = UITextField()
        private let secretField   = UserSecretField<User>()
        private let actionsStack  = UIStackView()
        private let strengthMeter = UIProgressView()
        private let strengthLabel = UILabel()
        private var authenticationConfiguration: LayoutConfiguration<UserCell>!

        private lazy var avatarButton    = EffectButton( track: .subject( "users.user", action: "avatar" ),
                                                         border: 0, background: false, circular: false )
        private lazy var biometricButton = TimedButton( track: .subject( "users.user", action: "auth" ),
                                                        image: .icon( "???" ), border: 0, background: false )

        // MARK: - Life

        // swiftlint:disable:next function_body_length
        override init(frame: CGRect) {
            super.init( frame: CGRect() )

            // - View
            self.isOpaque = false
            self.contentView.layoutMargins = .border( 20 )

            self.userNameField.textContentType = .username
            self.userNameField.isUserInteractionEnabled = false

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
            self.avatarButton.button.setContentCompressionResistancePriority( .defaultHigh - 1, for: .vertical )
            self.avatarButton.action( for: .primaryActionTriggered ) { [unowned self] in
                self.avatar?.next()
            }

            self.biometricButton.action( for: .primaryActionTriggered ) { [unowned self] in
                self.attemptBiometrics().failure { error in
                    err( "Failed biometrics. [>PII]" )
                    pii( "[>] Error: %@", error )
                }
            }

            self.secretField.alignmentRectOutsets = .horizontal()
            self.secretField.borderStyle = .roundedRect
            self.secretField => \.font => Theme.current.font.callout
            self.secretField.placeholder = "Your personal secret"
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
                    mperror( title: "Couldn't unlock user", error: error )
                }
            }
            self.secretField.action( for: .editingChanged ) { [unowned self] in
                let secretText = self.secretField.text

                DispatchQueue.api.perform {
                    var strengthText: Text?, strengthProgress: Double = 0
                    if let timeToCrack = Attacker.single.timeToCrack( string: secretText, hash: .spectre ) {
                        strengthProgress = ((timeToCrack.period.seconds / age_of_the_universe) as NSDecimalNumber).doubleValue
                        strengthProgress = pow( 1 - pow( strengthProgress - 1, 30 ), 1 / 30.0 )
                        strengthText = "\(.icon( "???" )) \(timeToCrack.period.normalize.brief)???"
                    }

                    DispatchQueue.main.perform {
                        self.strengthMeter.progress = Float( strengthProgress )
                        self.strengthMeter.progressTintColor = .systemGreen
                        self.strengthMeter.trackTintColor = strengthProgress < 0.5 ? .systemRed: .systemOrange
                        self.strengthLabel.attributedText = strengthText?.attributedString( for: self.strengthLabel )
                    }
                }
            }

            self.nameField.isHidden = true
            self.nameField.borderStyle = .none
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.attributedPlaceholder = NSAttributedString( string: "Your full name" )
            self.nameField => \.font => Theme.current.font.title1
            self.nameField => \.textColor => Theme.current.color.body
            self.nameField => \.attributedPlaceholder => .foregroundColor => Theme.current.color.placeholder

            self.strengthLabel => \.font => Theme.current.font.caption1
            self.strengthLabel.textAlignment = .center
            self.strengthLabel => \.textColor => Theme.current.color.secondary

            // - Hierarchy
            self.contentView.addSubview( self.avatarButton )
            self.contentView.addSubview( self.floorView )
            self.contentView.addSubview( self.avatarTip )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.nameField )
            self.contentView.addSubview( self.userNameField )
            self.contentView.addSubview( self.secretField )
            self.contentView.addSubview( self.actionsStack )
            self.contentView.addSubview( self.strengthMeter )
            self.contentView.addSubview( self.strengthLabel )

            // - Layout
            LayoutConfiguration( view: self.contentView )
                    .constrain( as: .box ).activate()
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
            LayoutConfiguration( view: userNameField )
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .constrain { $1.heightAnchor.constraint( equalToConstant: 1 ) }
                    .constrain { $1.bottomAnchor.constraint( equalTo: self.secretField.topAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.secretField )
                    .constrain { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.actionsStack )
                    .constrain { $1.topAnchor.constraint( equalTo: self.secretField.bottomAnchor, constant: 12 ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.strengthMeter )
                    .constrain { $1.topAnchor.constraint( equalTo: self.secretField.bottomAnchor, constant: 12 ) }
                    .constrain { $1.leadingAnchor.constraint( equalTo: self.secretField.leadingAnchor ) }
                    .constrain { $1.trailingAnchor.constraint( equalTo: self.secretField.trailingAnchor ) }
                    .activate()
            LayoutConfiguration( view: self.strengthLabel )
                    .constrain { $1.topAnchor.constraint( equalTo: self.strengthMeter.bottomAnchor, constant: 4 ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                    .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                    .activate()

            self.authenticationConfiguration = LayoutConfiguration( view: self )
                    .apply( LayoutConfiguration( view: self.avatarButton ) { active, inactive in
                        active.constrain { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ).with( priority: .defaultLow ) }
                        inactive.constrain { $1.bottomAnchor.constraint( equalTo: $0.centerYAnchor ).with( priority: .defaultLow ) }
                    } )
                    .apply( LayoutConfiguration( view: self.nameLabel ) { active, inactive in
                        active.constrain { $1.bottomAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: -20 ) }
                        inactive.constrain { $1.topAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: 20 ) }
                    } )
                    .apply( LayoutConfiguration( view: self.secretField ) { active, inactive in
                        active.set( .on, keyPath: \.alpha )
                        active.set( true, keyPath: \.isEnabled )
                        active.constrain { $1.topAnchor.constraint( equalTo: self.avatarButton.bottomAnchor, constant: 28 ) }
                        inactive.set( .off, keyPath: \.alpha )
                        inactive.set( false, keyPath: \.isEnabled )
                        inactive.set( nil, keyPath: \.text )
                        inactive.constrain { $1.topAnchor.constraint( equalTo: self.nameLabel.bottomAnchor ) }
                    } )
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove( toWindow: newWindow )

            if newWindow != nil {
                InAppFeature.observers.register( observer: self )
            }
            else {
                InAppFeature.observers.unregister( observer: self )
            }
        }

        // MARK: - InAppFeatureObserver

        func didChange(feature: InAppFeature) {
            guard case .premium = feature
            else { return }

            self.updateTask.request()
        }

        // MARK: - Private

        func attemptBiometrics() -> Promise<User> {
            guard InAppFeature.premium.isEnabled
            else { return Promise( .failure( AppError.state( title: "Biometrics not available" ) ) ) }
            guard let userFile = self.userFile, userFile.biometricLock
            else { return Promise( .failure( AppError.state( title: "Biometrics not enabled", details: self.userFile ) ) ) }
            let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
            guard keychainKeyFactory.isKeyPresent( for: userFile.algorithm )
            else { return Promise( .failure( AppError.state( title: "Biometrics key not present" ) ) ) }

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
                            wrn( "Biometrics cancelled. [>PII]" )
                            pii( "[>] Error: %@", error )
                        default:
                            mperror( title: "Couldn't unlock user", error: error )
                    }
                }
            }
        }

        // MARK: - Updatable

        lazy var updateTask = DispatchTask.update( self, animated: true ) { [weak self] in
            guard let self = self
            else { return }

            self.authenticationConfiguration.isActive = self.isSelected

            self.nameLabel.text = self.userFile?.userName ?? "Add a new user"
            self.nameLabel.isHidden = self.isSelected && self.userFile == nil
            self.nameField.isHidden = !self.nameLabel.isHidden
            self.avatarTip.isHidden = self.nameField.isHidden
            self.secretField.nameField = !self.nameField.isHidden ? self.nameField: nil
            self.avatarButton.isUserInteractionEnabled = self.isSelected && self.userFile == nil
            self.avatarButton.image = self.avatar?.image ?? .icon( "???", withSize: 96, invert: true )
            self.actionsStack.isHidden = !self.isSelected || self.userFile == nil
            self.strengthMeter.isHidden = !self.isSelected || self.userFile != nil
            self.strengthLabel.isHidden = !self.isSelected || self.userFile != nil
            self.biometricButton.isHidden = !InAppFeature.premium.isEnabled || !(self.userFile?.biometricLock ?? false) ||
                    !(self.userFile?.keychainKeyFactory.isKeyPresent( for: self.userFile?.algorithm ?? .current ) ?? false)
            self.biometricButton.image = .icon( KeychainKeyFactory.factor.icon )

            if self.secretField.text?.isEmpty ?? true {
                self.strengthMeter.progress = 0
                self.strengthMeter.progressTintColor = .systemGreen
                self.strengthMeter.trackTintColor = nil
            }

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

    struct UserAction {
        let tracking: Tracking?
        let title:    String
        let icon:     String
        let action:   (Marshal.UserFile) -> Void
    }
}
