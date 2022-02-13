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
import SafariServices
import Countly

class MainUsersViewController: BaseUsersViewController, FeedbackObserver {
    private let tipsView     = TipsView( tips: [
        // App
        "Welcome\(AppConfig.shared.runCount <= 1 ? "" : " back") to Spectre!",
        "Spectre is 100% open source \(.icon( "osi" )) and Free Software.",
        "Leave no traces by using incognito \(.icon( "user-secret" )) mode.",
        "With Diagnostics \(.icon( "briefcase-medical" )), we can build you the best app.",
        "Be reachable for emergency security alerts \(.icon( "bell-exclamation" )).",
        "Personalize your app with our \(Theme.allCases.count) custom-made themes \(.icon( "brush" )).",
        "Premium \(.icon( "user-tie" )) subscribers make this app possible.",
        "Shake \(.icon( "mobile" )) for logs and advanced settings.",
        "Join the discussion \(.icon( "comments" )) in the Spectre Community.",
        "While in Offline Mode \(.icon( "wifi-slash" )), Spectre disables any features that use the Internet.",
        "Prefer a more consistent monochrome look? Try turning off Colorful Sites \(.icon( "paint-brush" )).",
        // User
        "Your identicon ╚☻╯⛄ helps you spot typos.",
        "Long press your user's initials button to sign out quickly \(.icon( "arrow-up-left-from-circle" )).",
        "Set your user's Standard Login \(.icon( "circle-user" )), usually your e-mail.",
        "For extra security, set your user's Default Password to max \(.icon( "dial-max" )).",
        "Worried about an attack? Set a Defense Strategy \(.icon( "shield" )).",
        "Turn on Masked •••• passwords to deter shoulder-snooping.",
        "Enable AutoFill \(.icon( "keyboard" )) to use Spectre from other apps.",
        "Biometric \(.icon( KeychainKeyFactory.factor.iconName ?? KeychainKeyFactory.Factor.biometricTouch.iconName )) login is the quickest way to sign in.",
        "File Sharing \(.icon( "file-export" )) makes your user's export file available from iTunes or the Files app.",
        // Site
        "Long press a site to quickly perform an action or open the site in a browser \(.icon( "globe" )).",
        "Long press a site's mode (\(.icon( "key" ))/\(.icon( "id-card-clip" ))/\(.icon( "comments-question-check" ))) to configure it.",
        "Increment your site's counter \(.icon( "caret-up" )) if its password is compromised.",
        "Site doesn't accept your password? Try a different Type.",
        "Defense Strategy shows password time-to-crack \(.icon( "shield-slash" )) if attacked.",
        "Use Security Answers \(.icon( "comments-question-check" )) to avoid divulging private information.",
        "Sites are automatically styled \(.icon( "paint-brush" )) from their home page.",
    ], first: 0, random: false )
    private let actionStack  = UIStackView()
    private let feedbackView = FeedbackView()
    private let appToolbar   = UIStackView()
    private lazy var appUpdate = EffectButton( track: .subject( "users", action: "update" ),
                                               title: "Update Available", background: false ) { [unowned self] _ in
        AppStore.shared.presentStore( in: self )
    }
    // swiftlint:disable inclusive_language
    private lazy var appMigrate = EffectButton( track: .subject( "users", action: "masterPassword" ),
                                                title: "Migrate from Master Password", background: false ) { [unowned self] _ in
        if let masterPasswordURL = URL( string: "masterpassword:" ) {
            UIApplication.shared.open( masterPasswordURL )
        }
    }
    // swiftlint:enable inclusive_language

    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.appUpdate.isHidden = true
        self.appMigrate.isHidden = true

        self.actionStack.axis = .vertical
        self.actionStack.addArrangedSubview( self.appUpdate )
        self.actionStack.addArrangedSubview( self.appMigrate )

        self.appToolbar.axis = .horizontal
        self.appToolbar.addArrangedSubview( EffectButton( track: .subject( "users", action: "app" ), image: .icon( "gears" ),
                                                          border: 0, background: false, square: true ) { [unowned self] _ in
            self.detailsHost.show( DetailAppViewController(), sender: self )
        } )
        self.appToolbar.addArrangedSubview( TimedButton( track: .subject( "users", action: "user" ), image: .icon( "user-secret" ),
                                                         border: 0, background: false, square: true ) { [unowned self] incognitoButton in
            guard let incognitoButton = incognitoButton as? TimedButton
            else { return }

            UIAlertController.authenticate(
                    title: "Incognito Login",
                    message: "While in incognito mode, no user information is kept on the device",
                    action: "Log In", in: self, track: .subject( "users.user", action: "auth" ),
                    authenticator: { User( userName: $0.userName, file: nil ).login( using: $0 ) } )
                             .then( on: .main ) {
                                 incognitoButton.timing?.end(
                                         [ "result": $0.name,
                                           "type": "incognito",
                                           "error": $0.error,
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
        self.appToolbar.addArrangedSubview( EffectButton( track: .subject( "users", action: "chat" ), image: .icon( "comments" ),
                                                          border: 0, background: false, square: true ) { [unowned self] _ in
            if let url = URL( string: "https://chat.spectre.app" ) {
                self.present( SFSafariViewController( url: url ), animated: true )
            }
        } )

        self.userActions = [
            .init( tracking: .subject( "users.user", action: "delete" ),
                   title: "Delete", icon: "trash-can" ) { [unowned self] userFile in
                self.doDelete( userFile: userFile )
            },
            .init( tracking: .subject( "users.user", action: "reset" ),
                   title: "Reset", icon: "delete-left" ) { [unowned self] userFile in
                self.doReset( userFile: userFile )
            },
        ]

        self.feedbackView.observers.register( observer: self )

        // - Hierarchy
        self.view.insertSubview( self.tipsView, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.actionStack, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.feedbackView, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.appToolbar, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: self.tipsView )
            .constrain( as: .topCenter, to: self.view.safeAreaLayoutGuide ).activate()
        LayoutConfiguration( view: self.actionStack )
            .constrain { $1.bottomAnchor.constraint( equalTo: self.appToolbar.topAnchor ) }
            .constrain { $1.centerXAnchor.constraint( equalTo: self.appToolbar.centerXAnchor ) }
            .activate()
        LayoutConfiguration( view: self.appToolbar )
            .constrain( as: .bottomCenter, margin: true ).activate()
        LayoutConfiguration( view: self.feedbackView )
            .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: self.appToolbar.topAnchor, constant: -8 ) }
            .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: self.keyboardLayoutGuide.topAnchor, constant: -8 ) }
            .constrain( as: .centerH ).activate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        AppStore.shared.isUpToDate().then( on: .main ) {
            do {
                let result = try $0.get()
                if !result.upToDate {
                    inf( "Update available: %@", result )
                }

                self.appUpdate.isHidden = result.upToDate
            }
            catch {
                wrn( "Application update check failed: %@ [>PII]", error.localizedDescription )
                pii( "[>] Error: %@", error )
            }
        }

        if AppConfig.shared.rating == 0, AppConfig.shared.runCount > 5 {
            self.feedbackView.show( in: self )
        }
    }

    // MARK: - Interface

    override func items(for userFiles: [Marshal.UserFile]) -> [Spectre.BaseUsersViewController.UserItem] {
        super.items( for: userFiles ) + [ .newUser ]
    }

    override func login(user: User) {
        super.login( user: user )

        self.navigationController?.pushViewController( MainSitesViewController( user: user ), animated: true )
    }

    // MARK: - MarshalObserver

    override func didUpdateUsers(isEmpty: Bool) {
        super.didUpdateUsers( isEmpty: isEmpty )

        self.appMigrate.isHidden = !isEmpty || !(URL( string: "masterpassword:" ).flatMap {
            UIApplication.shared.canOpenURL( $0 )
        } ?? false)
    }

    // MARK: - FeedbackObserver

    func didUpdate(feedback: FeedbackView, shown: Bool, expanded: Bool, submitted: Bool) {
        self.usersCarousel.alpha = shown && expanded ? .off : .on
        self.usersCarousel.isUserInteractionEnabled = !(shown && expanded)
    }

    // MARK: - Private

    private func doDelete(userFile: Marshal.UserFile) {
        let alertController = UIAlertController( title: "Delete User?", message:
        """
        This will delete the user and all of its recorded state:
        \(userFile)

        Note: You can recreate the user at any time and add back your sites to fully regenerate their stateless passwords and other content.
        When re-creating the user, make sure to use the exact same name and personal secret.
        The user's identicon (\(userFile.identicon.text() ?? "-")) is a good manual check that you got this right.
        """, preferredStyle: .alert )
        alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
        alertController.addAction( UIAlertAction( title: "Delete", style: .destructive ) { [weak userFile] _ in
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
        self.present( alertController, animated: true )
    }

    private func doReset(userFile: Marshal.UserFile) {
        let alertController = UIAlertController( title: "Reset Personal Secret?", message:
        """
        This will allow you to change the personal secret for:
        \(userFile)

        Note: When your personal secret changes, all site passwords and other generated content will also change accordingly.
        The personal secret can always be changed back to revert to your current site passwords and generated content.
        """, preferredStyle: .alert )
        alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) )
        alertController.addAction( UIAlertAction( title: "Reset", style: .destructive ) { [weak userFile] _ in
            trc( "Resetting user: %@", userFile )

            userFile?.resetKey = true
        } )
        self.present( alertController, animated: true )
    }
}
