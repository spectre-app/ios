//
//  MainUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import LocalAuthentication
import SafariServices

class MainUsersViewController: BaseUsersViewController {
    private let tipsView = TipsView( tips: [
        // App
        "Welcome\(AppConfig.shared.runCount <= 1 ? "": " back") to Spectre!",
        "Spectre is 100% open source \(.icon( "" )) and Free Software.",
        "Leave no traces by using incognito \(.icon( "" )) mode.",
        "With Diagnostics \(.icon( "" )), we can build you the best app.",
        "Be reachable for emergency security alerts \(.icon( "" )).",
        "Personalize your app with our \(Theme.allCases.count) custom-made themes \(.icon( "" )).",
        "Premium \(.icon( "" )) subscribers make this app possible.",
        "Shake \(.icon( "" )) for logs and advanced settings.",
        "Join the discussion \(.icon( "" )) in the Spectre Community.",
        // User
        "Your identicon ╚☻╯⛄ helps you spot typos.",
        "Set your user's Standard Login \(.icon( "" )), usually your e-mail.",
        "For extra security, set your user's Default Password to max \(.icon( "" )).",
        "Worried about an attack? Set a Defense Strategy \(.icon( "" )).",
        "Turn on Masked •••• passwords to deter shoulder-snooping.",
        "Enable AutoFill \(.icon( "" )) to use Spectre from other apps.",
        "Biometric \(.icon( KeychainKeyFactory.factor.icon ?? KeychainKeyFactory.Factor.biometricTouch.icon )) login is the quickest way to sign in.",
        // Site
        "Increment your site's counter \(.icon( "" )) if its password is compromised.",
        "Site doesn't accept your password? Try a different Type.",
        "Defense Strategy shows password time-to-crack \(.icon( "" )) if attacked.",
        "Use Security Answers \(.icon( "" )) to avoid divulging private information.",
        "Sites are automatically styled \(.icon( "" )) from their home page.",
    ], first: 0, random: false)

    private let appToolbar  = UIStackView()
    private let userToolbar = UIToolbar( frame: .infinite )
    private var userToolbarConfiguration: LayoutConfiguration<UIToolbar>!

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.appToolbar.axis = .horizontal
        self.appToolbar.addArrangedSubview( EffectButton( track: .subject( "users", action: "app" ),
                                                          image: .icon( "" ), border: 0, background: false, square: true ) { [unowned self] _, _ in
            self.detailsHost.show( DetailAppViewController(), sender: self )
        } )
        self.appToolbar.addArrangedSubview( TimedButton( track: .subject( "users", action: "user" ),
                                                         image: .icon( "" ), border: 0, background: false, square: true ) { [unowned self] _, incognitoButton in
            guard let incognitoButton = incognitoButton as? TimedButton
            else { return }

            UIAlertController.authenticate(
                                     title: "Incognito Login", message: "While in incognito mode, no user information is kept on the device",
                                     in: self, track: .subject( "users.user", action: "auth" ),
                                     action: "Log In", authenticator: { User( userName: $0.userName, file: nil ).login( using: $0 ) } )
                             .then( on: .main ) {
                                 incognitoButton.timing?.end(
                                         [ "result": $0.name,
                                           "type": "incognito",
                                           "error": $0.error ?? "-",
                                         ] )

                                 if $0.isCancelled {
                                     return
                                 }

                                 do {
                                     let user = try $0.get()
                                     self.navigationController?.pushViewController( MainSitesViewController( user: user ), animated: true )
                                 }
                                 catch {
                                     mperror( title: "Couldn't unlock user", error: error )
                                 }
                             }
        } )
        self.appToolbar.addArrangedSubview( EffectButton( track: .subject( "users", action: "chat" ),
                                                          image: .icon( "" ), border: 0, background: false, square: true ) { [unowned self] _, _ in
            let controller = SFSafariViewController( url: URL( string: "https://chat.spectre.app" )! )
            controller.dismissButtonStyle = .close
            controller.modalPresentationStyle = .pageSheet
            controller.preferredBarTintColor = Theme.current.color.backdrop.get()
            controller.preferredControlTintColor = Theme.current.color.tint.get()
            return self.present( controller, animated: true )
        } )

        self.userToolbar.items = [
            UIBarButtonItem( title: "🗑 Delete", style: .plain, target: self, action: #selector( didTrashUser ) ),
            UIBarButtonItem( title: "🔑 Reset", style: .plain, target: self, action: #selector( didResetUser ) )
        ]

        // - Hierarchy
        self.view.insertSubview( self.tipsView, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.appToolbar, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.userToolbar, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.tipsView )
                .constrain( as: .topCenter, to: self.view.safeAreaLayoutGuide ).activate()
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
