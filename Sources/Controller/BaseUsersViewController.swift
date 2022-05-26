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

class BaseUsersViewController: BaseViewController, UICollectionViewDelegate, MarshalObserver {
    private var userEvent:    Tracker.TimedEvent?
    private var scrolledUser: UserItem?

    internal var usersSource: DataSource<NoSections, UserItem>?
    internal let usersCarousel = CarouselView()
    internal let detailsHost   = DetailHostController()
    internal var userActions   = [ UserAction ]()

    // MARK: - Life

    override var next: UIResponder? {
        self.detailsHost
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.usersSource = .init( collectionView: self.usersCarousel ) { collectionView, indexPath, item in
            using( UserCell.dequeue( from: collectionView, indexPath: indexPath ) ) { cell in
                UIView.performWithoutAnimation {
                    cell.state = (userItem: item, userActions: self.userActions, viewController: self)
                }
            }
        }

        // - View
        self.view.layoutMargins = .border( 8 )

        self.usersCarousel.register( UserCell.self )
        self.usersCarousel.delegate = self
        self.usersCarousel.backgroundColor = .clear
        self.usersCarousel.indicatorStyle = .white
        self.usersCarousel.addGestureRecognizer( UILongPressGestureRecognizer { [unowned self] in
            guard case .began = $0.state
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

        Marshal.shared.observers.register( observer: self )?
               .didChange( userFiles: Marshal.shared.userFiles )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        Marshal.shared.updateTask.request( now: true, await: true )
    }

    override func viewWillDisappear(_ animated: Bool) {
        Marshal.shared.observers.unregister( observer: self )
        self.usersCarousel.selectedItem = nil

        super.viewWillDisappear( animated )
    }

    // MARK: - KeyboardLayoutObserver

    override func didChange(keyboard: KeyboardMonitor, showing: Bool, changing: Bool,
                            fromScreenFrame: CGRect, toScreenFrame: CGRect, animated: Bool) {
        // Don't adjust the safe area. Keyboard is handled explicitly.
    }

    // MARK: - Interface

    func items(for userFiles: [Marshal.UserFile]) -> [UserItem] {
        userFiles.sorted().map { .knownUser( userFile: $0 ) }
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
                inf( "Skipping biometrics: %@ [>PII]", error.localizedDescription )
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

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate, scrollView == self.usersCarousel {
            self.didEndScrolling()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == self.usersCarousel {
            self.didEndScrolling()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView == self.usersCarousel {
            self.didEndScrolling()
        }
    }

    // MARK: - MarshalObserver

    func didChange(userFiles: [Marshal.UserFile]) {
        let sections = self.items( for: userFiles )
        self.usersSource?.apply( [ .items: sections ] ) {
            if !(self.scrolledUser.flatMap( { self.usersSource?.snapshot()?.itemIdentifiers.contains( $0 ) } ) ?? false) {
                self.scrolledUser = self.usersSource?.snapshot()?.itemIdentifiers.first
            }
            self.usersCarousel.scrolledItem = self.scrolledUser.flatMap { self.usersSource?.snapshot()?.indexOfItem( $0 ) } ?? 0
            self.usersCarousel.visibleCells.forEach { ($0 as? UserCell)?.hasSelected = self.usersCarousel.selectedItem != nil }

            self.didUpdateUsers( isEmpty: self.usersSource?.isEmpty ?? true )
        }
    }

    func didUpdateUsers(isEmpty: Bool) {
    }

    // MARK: - Private

    private func didEndScrolling() {
        self.scrolledUser = self.usersSource?.snapshot()?.itemIdentifiers[maybe: self.usersCarousel.scrolledItem]
    }

    // MARK: - Types

    enum UserItem: Hashable {
        case knownUser(userFile: Marshal.UserFile)
        case newUser

        var file: Marshal.UserFile? {
            switch self {
                case .knownUser(userFile: let userFile):
                    return userFile
                case .newUser:
                    return nil
            }
        }

        // Hashable

        static func == (lhs: UserItem, rhs: UserItem) -> Bool {
            lhs.file?.origin == rhs.file?.origin && lhs.file?.userName == rhs.file?.userName
        }

        func hash(into hasher: inout Hasher) {
            self.file.flatMap {
                hasher.combine( $0.origin )
                hasher.combine( $0.userName )
            }
        }
    }

    class UserCell: UICollectionViewCell, InAppFeatureObserver, Updatable {
        public var hasSelected = false {
            didSet {
                self.contentView.alpha = self.hasSelected ? (self.isSelected ? .on : .off) : .on
            }
        }
        public override var isSelected: Bool {
            didSet {
                if self.isSelected {
                    if case .newUser = self.userItem {
                        self.avatar = User.Avatar.allCases.randomElement()
                    }
                }
                else {
                    if case .newUser = self.userItem {
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
        internal var state: (userItem: UserItem, userActions: [UserAction], viewController: BaseUsersViewController)! {
            didSet {
                self.userItem = self.state.userItem
                self.userActions = self.state.userActions
                self.viewController = self.state.viewController
                self.updateTask.request( now: true )
            }
        }

        private var userItem: UserItem = .newUser {
            didSet {
                if self.userItem != oldValue {
                    self.secretField.userName = self.userItem.file?.userName
                    self.secretField.identicon = self.userItem.file?.identicon ?? SpectreIdenticonUnset
                    self.avatar = self.userItem.file?.avatar
                }
            }
        }
        private var userActions = [ UserAction ]() {
            didSet {
                self.actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                self.userActions.forEach { action in
                    self.actionsStack.addArrangedSubview(
                            EffectButton( track: action.tracking, image: .icon( action.icon ), border: 0, background: false ) {
                                [unowned self] _ in
                                if case .knownUser(let userFile) = self.userItem {
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
        private let nameView      = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        private let nameLabel     = UILabel()
        private let nameField     = UITextField()
        private let floorView     = BackgroundView( mode: .tint )
        private let avatarTip     = UILabel()
        private let userNameField = UITextField()
        private let secretField   = UserSecretField<User>()
        private let actionsStack  = UIStackView()
        private let strengthTips  = UILabel()
        private let strengthMeter = UIProgressView()
        private let strengthLabel = UILabel()
        private var authenticationConfiguration: LayoutConfiguration<UserCell>!

        private lazy var avatarButton    = EffectButton( track: .subject( "users.user", action: "avatar" ),
                                                         border: 0, background: false, circular: false )
        private lazy var biometricButton = TimedButton( track: .subject( "users.user", action: "auth" ),
                                                        image: .icon( "fingerprint" ), border: 0, background: false )

        // MARK: - Life

        // swiftlint:disable:next function_body_length
        override init(frame: CGRect) {
            super.init( frame: CGRect() )
            LeakRegistry.shared.register( self )

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
                    err( "Failed biometrics: %@ [>PII]", error.localizedDescription )
                    pii( "[>] Error: %@", error )
                }
            }

            self.secretField.alignmentRectOutsets = .horizontal()
            self.secretField.borderStyle = .roundedRect
            self.secretField => \.font => Theme.current.font.callout
            self.secretField.placeholder = "Your personal secret"
            self.secretField.authenticater = { keyFactory in
                let secretEvent = Tracker.shared.begin( track: .subject( "users.user", action: "auth" ) )
                return (self.userItem.file?.authenticate( using: keyFactory )
                        ?? User( userName: keyFactory.userName ).login( using: keyFactory ))
                    .then {
                        secretEvent.end(
                                [ "result": $0.name,
                                  "type": "secret",
                                  "length": keyFactory.metadata.length,
                                  "entropy": keyFactory.metadata.entropy,
                                  "error": $0.error
                                ] )
                    }
            }
            self.secretField.authenticated = { result in
                do {
                    let user = try result.get()
                    if let avatar = self.avatar {
                        user.avatar = avatar
                    }

                    Feedback.shared.play( .trigger )
                    self.userEvent?.end( [ "result": result.name, "type": "secret" ] )
                    self.viewController?.login( user: user )
                }
                catch {
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
                        strengthText = "\(.icon( "shield-slash" )) \(timeToCrack.period.normalize.brief)︎"
                    }

                    DispatchQueue.main.perform {
                        self.strengthMeter.progress = Float( strengthProgress )
                        self.strengthMeter.progressTintColor = .systemGreen
                        self.strengthMeter.trackTintColor = strengthProgress < 0.5 ? .systemRed : .systemOrange
                        self.strengthLabel.applyText( strengthText )
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
            self.nameField => \.layer.shadowColor => Theme.current.color.backdrop
            self.nameField.layer.shadowOpacity = .on
            self.nameField.layer.shadowOffset = .zero
            self.nameField.layer.shadowRadius = 10

            self.strengthTips => \.font => Theme.current.font.caption1
            self.strengthTips => \.textColor => Theme.current.color.secondary
            self.strengthTips.numberOfLines = 0
            self.strengthTips.textAlignment = .center
            self.strengthTips.text =
            """
            A good personal secret is long, unpredictable and easy to remember.
            Try a random nonsense sentence, eg. tall piano strawberry blonde
            """

            self.strengthLabel => \.font => Theme.current.font.caption1
            self.strengthLabel => \.textColor => Theme.current.color.secondary
            self.strengthLabel.textAlignment = .center

            // - Hierarchy
            self.contentView.addSubview( self.avatarButton )
            self.contentView.addSubview( self.floorView )
            self.contentView.addSubview( self.avatarTip )
            self.contentView.addSubview( self.nameView )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.nameField )
            self.contentView.addSubview( self.userNameField )
            self.contentView.addSubview( self.secretField )
            self.contentView.addSubview( self.actionsStack )
            self.contentView.addSubview( self.strengthTips )
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
            LayoutConfiguration( view: self.nameView )
                .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .activate()
            LayoutConfiguration( view: self.nameLabel )
                .constrain( as: .box, to: self.nameView.contentView, margin: true ).activate()
            LayoutConfiguration( view: self.nameField )
                .constrain( as: .box, to: self.nameView.contentView, margin: true ).activate()
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
            LayoutConfiguration( view: self.strengthTips )
                .constrain { $1.topAnchor.constraint( equalTo: self.secretField.bottomAnchor, constant: 12 ) }
                .constrain { $1.leadingAnchor.constraint( equalTo: self.secretField.leadingAnchor ) }
                .constrain { $1.trailingAnchor.constraint( equalTo: self.secretField.trailingAnchor ) }
                .activate()
            LayoutConfiguration( view: self.strengthMeter )
                .constrain { $1.topAnchor.constraint( equalTo: self.strengthTips.bottomAnchor, constant: 4 ) }
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
                .apply( LayoutConfiguration( view: self.nameView ) { active, inactive in
                    active.constrain { $1.bottomAnchor.constraint( equalTo: self.floorView.topAnchor ) }
                          .set(.on, keyPath: \.alpha)
                    inactive.constrain { $1.topAnchor.constraint( equalTo: self.floorView.bottomAnchor ) }
                            .set(.off, keyPath: \.alpha)
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
            self.updateTask.request()
        }

        // MARK: - Private

        func attemptBiometrics() -> Promise<User> {
            guard InAppFeature.biometrics.isEnabled
            else { return Promise( .failure( AppError.state( title: "Biometrics not available" ) ) ) }
            guard let userFile = self.userItem.file, userFile.biometricLock
            else { return Promise( .failure( AppError.state( title: "Biometrics not enabled", details: self.userItem.file ) ) ) }
            let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
            guard keychainKeyFactory.isKeyPresent( for: userFile.algorithm )
            else { return Promise( .failure( AppError.state( title: "Biometrics key not present" ) ) ) }

            return keychainKeyFactory.unlock().promising { userFile.authenticate( using: $0 ) }.then( on: .main ) {
                [unowned self] result in

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
                            wrn( "Biometrics cancelled: %@ [>PII]", error.localizedDescription )
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

            self.nameLabel.text = self.userItem.file?.userName ?? "Add a new user"
            self.nameLabel.isHidden = self.isSelected && self.userItem.file == nil
            self.nameField.isHidden = !self.nameLabel.isHidden
            self.avatarTip.isHidden = self.nameField.isHidden
            self.secretField.nameField = !self.nameField.isHidden ? self.nameField : nil
            self.avatarButton.isUserInteractionEnabled = self.isSelected && self.userItem.file == nil
            self.avatarButton.image = self.avatar?.image ?? .icon( "user-plus", withSize: 96, invert: true )
            self.actionsStack.isHidden = !self.isSelected || self.userItem.file == nil
            self.strengthTips.isHidden = !self.isSelected || self.userItem.file != nil
            self.strengthMeter.isHidden = !self.isSelected || self.userItem.file != nil
            self.strengthLabel.isHidden = !self.isSelected || self.userItem.file != nil
            self.biometricButton.isHidden = !InAppFeature.biometrics.isEnabled || !(self.userItem.file?.biometricLock ?? false)
            || !(self.userItem.file?.keychainKeyFactory.isKeyPresent( for: self.userItem.file?.algorithm ?? .current ) ?? false)
            self.biometricButton.image = .icon( KeychainKeyFactory.factor.iconName )

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
