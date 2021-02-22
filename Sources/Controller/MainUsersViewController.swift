//
//  MainUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import LocalAuthentication

class MainUsersViewController: BaseUsersViewController {
    private let appToolbar  = UIStackView()
    private let userToolbar = UIToolbar( frame: .infinite )
    private var userToolbarConfiguration: LayoutConfiguration<UIToolbar>!

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.appToolbar.axis = .horizontal
        self.appToolbar.addArrangedSubview( EffectButton( track: .subject( "users", action: "app" ),
                                                          image: .icon( "" ), background: false ) { [unowned self] _, _ in
            self.detailsHost.show( DetailAppViewController(), sender: self )
        } )
        self.appToolbar.addArrangedSubview( TimedButton( track: .subject( "users.user", action: "auth" ),
                                                         image: .icon( "" ), background: false ) { [unowned self] _, incognitoButton in
            guard let incognitoButton = incognitoButton as? TimedButton
            else { return }
            let userEvent = Tracker.shared.begin( track: .subject( "users", action: "user" ) )

            let controller = UIAlertController( title: "Incognito Login", message:
            """
            While in incognito mode, no user information is kept on the device.
            """, preferredStyle: .alert )

            let secretField = UserSecretField()
            let spinner     = AlertController( title: "Unlocking", message: secretField.nameField?.text,
                                               content: UIActivityIndicatorView( style: .whiteLarge ) )
            secretField.authenticater = { keyFactory in
                spinner.show( dismissAutomatically: false )
                return User( userName: keyFactory.userName, file: nil ).login( using: keyFactory )
            }
            secretField.authenticated = { result in
                trc( "Incognito authentication: %@", result )
                spinner.dismiss()
                controller.dismiss( animated: true ) {
                    do {
                        let user = try result.get()
                        Feedback.shared.play( .trigger )
                        incognitoButton.timing?.end(
                                [ "result": "failure",
                                  "type": "incognito",
                                  "length": secretField.text?.count ?? 0,
                                  "entropy": Attacker.entropy( string: secretField.text ) ?? 0,
                                ] )
                        userEvent.end( [ "result": "incognito" ] )
                        self.navigationController?.pushViewController( MainSitesViewController( user: user ), animated: true )
                    }
                    catch {
                        incognitoButton.timing?.end(
                                [ "result": "failure",
                                  "type": "incognito",
                                  "length": secretField.text?.count ?? 0,
                                  "entropy": Attacker.entropy( string: secretField.text ) ?? 0,
                                  "error": error,
                                ] )
                        userEvent.end( [ "result": "deselected" ] )
                        mperror( title: "Couldn't unlock user", error: error )
                    }
                }
            }

            controller.addTextField { secretField.nameField = $0 }
            controller.addTextField { secretField.passwordField = $0 }
            controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                incognitoButton.timing?.end( [ "result": "cancel" ] )
            } )
            controller.addAction( UIAlertAction( title: "Log In", style: .default ) { [weak self] _ in
                guard let self = self
                else { return }

                if !secretField.try() {
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
                .constrain( as: .bottomCenter, margin: true ).activate()
        LayoutConfiguration( view: self.userToolbar )
                .constrain( as: .horizontal ).activate()

        self.userToolbarConfiguration = LayoutConfiguration( view: self.userToolbar ) { active, inactive in
            active.constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ).with( priority: .defaultHigh ) }
            active.set( .on, keyPath: \.alpha )
            inactive.constrain { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ).with( priority: .defaultHigh ) }
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

    override func login(user: User) {
        super.login( user: user )

        self.navigationController?.pushViewController( MainSitesViewController( user: user ), animated: true )
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
            When re-creating the user, make sure to use the exact same name and personal secret.
            The user's identicon (\(userFile.identicon.text() ?? "-")) is a good manual check that you got this right.
            """, preferredStyle: .alert )
            alert.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
            alert.addAction( UIAlertAction( title: "Delete", style: .destructive ) { [weak userFile] _ in
                guard let userFile = userFile
                else { return }
                trc( "Trashing user: %@", userFile )

                do {
                    try Marshal.shared.delete( userFile: userFile )
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
            let alert = UIAlertController( title: "Reset Personal Secret?", message:
            """
            This will allow you to change the personal secret for:
            \(userFile)

            Note: When your personal secret changes, all site passwords and other generated content will also change accordingly.
            The personal secret can always be changed back to revert to your current site passwords and generated content.
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

    // MARK: --- MarshalObserver ---

    override func userFilesDidChange(_ userFiles: [Marshal.UserFile]) {
        self.fileSource.update( [ userFiles.sorted() + [ nil ] ] )
    }
}
