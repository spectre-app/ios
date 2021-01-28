//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import LocalAuthentication

class MPUsersViewController: BasicUsersViewController {
    private let appToolbar  = UIStackView()
    private let userToolbar = UIToolbar( frame: .infinite )
    private var userToolbarConfiguration: LayoutConfiguration<UIToolbar>!

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.appToolbar.axis = .horizontal
        self.appToolbar.addArrangedSubview( MPButton( identifier: "users #app_settings", image: .icon( "" ), background: false ) { [unowned self] _, _ in
            self.detailsHost.show( MPAppDetailsViewController(), sender: self )
        } )
        self.appToolbar.addArrangedSubview( MPTimedButton( identifier: "users #auth_incognito", image: .icon( "" ), background: false ) { [unowned self] _, incognitoButton in
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
                return MPUser( fullName: keyFactory.fullName, file: nil ).login( using: keyFactory )
            }
            passwordField.authenticated = { result in
                trc( "Incognito authentication: %@", result )
                incognitoButton.timing?.end(
                        [ "result": result.name,
                          "length": passwordField.text?.count ?? 0,
                          "entropy": MPAttacker.entropy( string: passwordField.text ) ?? 0,
                        ] )

                spinner.dismiss()
                controller.dismiss( animated: true ) {
                    do {
                        let user = try result.get()
                        MPFeedback.shared.play( .trigger )
                        incognitoEvent.end( [ "result": "incognito" ] )
                        self.navigationController?.pushViewController( MPServicesViewController( user: user ), animated: true )
                    }
                    catch {
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

        self.userToolbar.items = [
            UIBarButtonItem( title: "🗑 Delete", style: .plain, target: self, action: #selector( didTrashUser ) ),
            UIBarButtonItem( title: "🔑 Reset", style: .plain, target: self, action: #selector( didResetUser ) )
        ]

        // - Hierarchy
        self.view.insertSubview( self.appToolbar, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.userToolbar, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.appToolbar )
                .constrain( margins: true, anchors: .bottomCenter )
                .activate()

        LayoutConfiguration( view: self.userToolbar )
                .constrain( anchors: .horizontal )
                .activate()

        self.userToolbarConfiguration = LayoutConfiguration( view: self.userToolbar ) { active, inactive in
            active.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ).with( priority: .defaultHigh ) }
            active.set( .on, keyPath: \.alpha )
            inactive.constrainTo { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ).with( priority: .defaultHigh ) }
            inactive.set( .off, keyPath: \.alpha )
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.keyboardLayoutGuide.add( constraints: { keyboardLayoutGuide in
            [ self.userToolbar.bottomAnchor.constraint( equalTo: keyboardLayoutGuide.topAnchor ).with( priority: .defaultHigh + 1 ) ]
        } )
    }

    // MARK: --- Interface ---

    override func login(user: MPUser) {
        super.login( user: user )

        self.navigationController?.pushViewController( MPServicesViewController( user: user ), animated: true )
    }

    // MARK: --- Private ---

    @objc
    private func didTrashUser() {
        if let userFile = self.selectedFile {
            let alert = UIAlertController( title: "Delete User?", message:
            """
            This will delete the user and all of its recorded state:
            \(userFile)

            Note: You can re-create the user at any time and add back your services to fully regenerate their stateless passwords and other content.
            When re-creating the user, make sure to use the exact same name and master password.
            The user's identicon (\(userFile.identicon.text() ?? "-")) is a good manual check that you got this right.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Delete", style: .destructive ) { [weak userFile] _ in
                guard let userFile = userFile
                else { return }
                trc( "Trashing user: %@", userFile )

                do {
                    try MPMarshal.shared.delete( userFile: userFile )
                    // TODO: Check that fileSource is getting updated.
                }
                catch {
                    mperror( title: "Couldn't delete user", error: error )
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

            Note: When the user's master password changes, its service passwords and other generated content will also change accordingly.
            The master password can always be changed back to revert to the user's current service passwords and generated content.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Reset", style: .destructive ) { [weak userFile] _ in
                trc( "Resetting user: %@", userFile )

                userFile?.resetKey = true
            } )
            self.present( alert, animated: true )
        }
    }

    // MARK: --- KeyboardLayoutObserver ---

    override func keyboardDidChange(showing: Bool, layoutGuide: KeyboardLayoutGuide) {
        super.keyboardDidChange( showing: showing, layoutGuide: layoutGuide )

        self.userToolbarConfiguration.isActive = showing && self.selectedFile != nil
    }

    // MARK: --- MPMarshalObserver ---

    override func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]) {
        self.fileSource.update( [ userFiles.sorted() + [ nil ] ] )
    }
}
