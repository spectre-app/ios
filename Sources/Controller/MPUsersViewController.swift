//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import Crashlytics
import Stellar

class MPUsersViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, MPMarshalObserver {
    public lazy var fileSource = DataSource<MPMarshal.UserFile>( collectionView: self.usersSpinner )
    public var selectedFile: MPMarshal.UserFile? {
        get {
            self.usersSpinner.indexPathsForSelectedItems?.first.flatMap { self.fileSource.element( at: $0 ) }
        }
        set {
            self.usersSpinner.selectItem( at: newValue.flatMap { self.fileSource.indexPath( for: $0 ) },
                                          animated: true, scrollPosition: .centeredVertically )
        }
    }

    private let settingsButton = MPButton( image: UIImage( named: "icon_gears" ) )
    private let usersSpinner   = MPSpinnerView()
    private let userToolbar    = UIToolbar( frame: .infinite )
    private let detailsHost    = MPDetailsHostController()
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

        // - View
        self.view.layoutMargins = UIEdgeInsets( top: 8, left: 8, bottom: 8, right: 8 )

        self.usersSpinner.registerCell( UserCell.self )
        self.usersSpinner.delegate = self
        self.usersSpinner.dataSource = self
        self.usersSpinner.backgroundColor = .clear
        self.usersSpinner.indicatorStyle = .white

        self.settingsButton.darkBackground = true
        self.settingsButton.button.addAction( for: .touchUpInside ) { _, _ in
            if !self.detailsHost.hideDetails() {
                self.detailsHost.showDetails( MPAppDetailsViewController() )
            }
        }

        self.userToolbar.barStyle = .black
        self.userToolbar.items = [
            UIBarButtonItem( barButtonSystemItem: .trash, target: self, action: #selector( didTrashUser ) ),
            UIBarButtonItem( barButtonSystemItem: .rewind, target: self, action: #selector( didResetUser ) )
        ]

        // - Hierarchy
        self.addChild( self.detailsHost )
        defer {
            self.detailsHost.didMove( toParent: self )
        }
        self.view.addSubview( self.usersSpinner )
        self.view.addSubview( self.settingsButton )
        self.view.addSubview( self.userToolbar )
        self.view.addSubview( self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.usersSpinner )
                .constrainToOwner( withAnchors: .topBox )
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ).withPriority( .defaultHigh ) }
                .activate()

        LayoutConfiguration( view: self.settingsButton )
                .constrainToMarginsOfOwner( withAnchors: .bottomCenter )
                .activate()

        LayoutConfiguration( view: self.userToolbar )
                .constrainToOwner( withAnchors: .horizontally )
                .activate()

        LayoutConfiguration( view: self.detailsHost.view )
                .constrainToOwner()
                .activate()

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

        self.selectedFile = nil
    }

    // MARK: --- Private ---

    @objc
    private func didTrashUser() {
        if let user = self.selectedFile {
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
                if MPMarshal.shared.delete( userFile: user ) {
                    self.fileSource.remove( user )
                }
            } )
            self.present( alert, animated: true )
        }
    }

    @objc
    private func didResetUser() {
        if let user = self.selectedFile {
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIView.animate( withDuration: 0.382 ) {
            self.userToolbarConfiguration.updateActivated( self.usersSpinner.indexPathsForSelectedItems?.count ?? 0 > 0 )
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        UIView.animate( withDuration: 0.382 ) {
            self.userToolbarConfiguration.updateActivated( self.usersSpinner.indexPathsForSelectedItems?.count ?? 0 > 0 )
        }
    }

    // MARK: --- MPMarshalObserver ---

    func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]?) {
        self.fileSource.update( [ (userFiles ?? []).sorted() + [ nil ] ], reload: true )
        DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) ) { self.usersSpinner.flashScrollIndicators() }
    }

    // MARK: --- Types ---

    class UserCell: UICollectionViewCell {
        public var new: Bool = false
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

                    self.nameLabel.font.pointSize.animate(
                            to: UIFont.labelFontSize * (self.isSelected ? 2: 1), duration: 0.618, render: {
                        self.nameLabel.font = self.nameLabel.font.withSize( $0 )
                    } )

                    self.update()
                }
            }
        }
        public var userFile:             MPMarshal.UserFile? {
            didSet {
                self.passwordField.userFile = self.userFile
                self.avatar = self.userFile?.avatar ?? .avatar_add
                self.update()
            }
        }
        public var navigationController: UINavigationController?

        private var avatar        = MPUser.Avatar.avatar_add {
            didSet {
                self.update()
            }
        }
        private let nameLabel     = UILabel()
        private let nameField     = UITextField()
        private let avatarButton  = UIButton()
        private let passwordField = MPMasterPasswordField()
        private let idBadgeView   = UIImageView( image: UIImage( named: "icon_user" ) )
        private let authBadgeView = UIImageView( image: UIImage( named: "icon_key" ) )
        private var passwordConfiguration: LayoutConfiguration!
        private var path:                  CGPath? {
            didSet {
                if self.path != oldValue {
                    self.setNeedsDisplay()
                }
            }
        }

        // MARK: --- Life ---

        override init(frame: CGRect) {
            super.init( frame: CGRect() )

            self.isOpaque = false
            self.contentView.layoutMargins = UIEdgeInsets( top: 20, left: 20, bottom: 20, right: 20 )

            self.nameLabel.font = MPTheme.global.font.callout.get()
            self.nameLabel.adjustsFontSizeToFitWidth = true
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = MPTheme.global.color.body.get()
            self.nameLabel.numberOfLines = 0
            self.nameLabel.preferredMaxLayoutWidth = .infinity
            self.nameLabel.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )

            self.nameField.font = MPTheme.global.font.callout.get()?.withSize( UIFont.labelFontSize * 2 )
            self.nameField.adjustsFontSizeToFitWidth = true
            self.nameField.textAlignment = .center
            self.nameField.textColor = MPTheme.global.color.body.get()
            self.nameField.borderStyle = .none
            self.nameField.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 8 ) )
            self.nameField.attributedPlaceholder = stra( "Your Full Name", [
                NSAttributedString.Key.foregroundColor: MPTheme.global.color.secondary.get()!.withAlphaComponent( 0.382 )
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
            self.passwordField.authentication = { keyFactory in
                self.userFile?.mpw_authenticate( keyFactory: keyFactory ) ??
                        Promise( .success( MPUser( fullName: keyFactory.fullName, masterKeyFactory: keyFactory ) ) )
            }
            self.passwordField.authenticated = { user in
                self.navigationController?.pushViewController( MPSitesViewController( user: user ), animated: true )
            }

            self.idBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 8, bottom: 0, right: 0 ) )
            self.authBadgeView.setAlignmentRectOutsets( UIEdgeInsets( top: 0, left: 0, bottom: 0, right: 8 ) )

            self.contentView.addSubview( self.idBadgeView )
            self.contentView.addSubview( self.authBadgeView )
            self.contentView.addSubview( self.avatarButton )
            self.contentView.addSubview( self.nameLabel )
            self.contentView.addSubview( self.nameField )
            self.contentView.addSubview( self.passwordField )

            LayoutConfiguration( view: self.contentView )
                    .constrainToOwner()
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
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            let path = CGMutablePath()
            if self.isSelected {
                path.addPath( CGPathCreateBetween( self.idBadgeView.alignmentRect, self.nameLabel.alignmentRect ) )
                if self.passwordConfiguration.activated {
                    path.addPath( CGPathCreateBetween( self.authBadgeView.alignmentRect, self.passwordField.alignmentRect ) )
                }
            }
            self.path = path.isEmpty ? nil: path
        }

        override func draw(_ rect: CGRect) {
            super.draw( rect )

            if let path = self.path, let context = UIGraphicsGetCurrentContext() {
                MPTheme.global.color.mute.get()?.setStroke()
                context.addPath( path )
                context.strokePath()
            }
        }

        // MARK: --- Private ---

        private func update() {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: 0.618 ) {
                    self.nameLabel.alpha = self.isSelected && self.userFile == nil ? 0: 1
                    self.nameField.alpha = 1 - self.nameLabel.alpha

                    self.avatarButton.isUserInteractionEnabled = self.isSelected
                    self.avatarButton.setImage( self.avatar.image(), for: .normal )
                    self.nameLabel.text = self.userFile?.fullName ?? "Tap to create a new user"

                    if self.isSelected {
                        if let userFile = self.userFile, userFile.biometricLock,
                           MPKeychain.hasKey( for: userFile.fullName, algorithm: userFile.algorithm ) {
                            self.passwordConfiguration.deactivate()

                            userFile.mpw_authenticate( keyFactory: MPKeychainKeyFactory( fullName: userFile.fullName ) )
                                    .then( { result -> Void in
                                        switch result {
                                            case .success(let user):
                                                DispatchQueue.main.perform {
                                                    self.navigationController?
                                                        .pushViewController( MPSitesViewController( user: user ), animated: true )
                                                }

                                            case .failure:
                                                for algorithm in MPAlgorithmVersion.allCases {
                                                    MPKeychain.deleteKey( for: userFile.fullName, algorithm: algorithm )
                                                }
                                                self.update()
                                        }
                                    } )
                        }
                        else {
                            self.passwordConfiguration.activate()
                        }

                        if self.nameField.alpha != 0 {
                            self.nameField.becomeFirstResponder()
                        }
                        else if self.passwordConfiguration.activated {
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
