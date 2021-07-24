//==============================================================================
// Created by Maarten Billemont on 2020-09-12.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import AuthenticationServices
import LocalAuthentication

// Note: The Address Sanitizer will break the ability to load this extension due to its excessive memory usage.
class AutoFillProviderController: ASCredentialProviderViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        LogSink.shared.register()
        KeyboardMonitor.shared.install()

        super.init( nibName: nibNameOrNil, bundle: nibBundleOrNil )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func loadView() {
        self.view = BackgroundView( mode: .backdrop )
        self.view => \.tintColor => Theme.current.color.tint
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Tracker.shared.startup( extensionController: self )
        AutoFillModel.shared.context = AutoFillModel.Context()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        Tracker.shared.appeared()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange( previousTraitCollection )

        Theme.current.updateTask.request( now: true, await: true )
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        //dbg( "prepareCredentialList: %@", serviceIdentifiers )
        AutoFillModel.shared.context = AutoFillModel.Context( serviceIdentifiers: serviceIdentifiers )

        let usersViewController = AutoFillUsersViewController()

        // - Hierarchy
        self.addChild( usersViewController )
        self.view.addSubview( usersViewController.view )
        usersViewController.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: usersViewController.view )
                .constrain( as: .box ).activate()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        //dbg( "provideCredentialWithoutUserInteraction: %@", credentialIdentity )
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        Marshal.shared.updateTask.request( now: true ).promising( on: .api ) { userFiles in
            if let user = AutoFillModel.shared.cachedUser( userName: credentialIdentity.recordIdentifier ) {
                return Promise( .success( user ) )
            }

            guard let userFile = userFiles.first( where: { $0.userName == credentialIdentity.recordIdentifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No user named: \(credentialIdentity.recordIdentifier ?? "-")" ) }

            let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
            guard keychainKeyFactory.isKeyAvailable( for: userFile.algorithm )
            else { throw ASExtensionError( .userInteractionRequired, "Key unavailable from keychain for: \(userFile.userName)" ) }

            keychainKeyFactory.expiry = .minutes( 5 )
            return userFile.authenticate( using: keychainKeyFactory )
        }.promising { (user: User) in
            AutoFillModel.shared.cacheUser( user )

            guard let site = user.sites.first( where: { $0.siteName == credentialIdentity.serviceIdentifier.identifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No site named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.userName)" ) }

            return site.result( keyPurpose: .identification ).token.and( site.result( keyPurpose: .authentication ).token ).promise {
                ASPasswordCredential( user: $0.0, password: $0.1 )
            }
        }.failure( on: .main ) { error in
            Feedback.shared.play( .error )

            switch error {
                case let extensionError as ASExtensionError:
                    self.extensionContext.cancelRequest( withError: extensionError )

                case LAError.userCancel, LAError.userCancel, LAError.systemCancel, LAError.appCancel:
                    self.extensionContext.cancelRequest( withError: ASExtensionError(
                            .userCanceled, "Local authentication cancelled.", error: error ) )

                case let error as LAError:
                    self.extensionContext.cancelRequest( withError: ASExtensionError(
                            .userInteractionRequired, "Non-interactive authentication denied.", error: error ) )

                default:
                    self.extensionContext.cancelRequest( withError: ASExtensionError(
                            .failed, "Credential unavailable.", error: error ) )
            }
        }.success( on: .main ) { (credential: ASPasswordCredential) in
            Feedback.shared.play( .activate )

            self.extensionContext.completeRequest( withSelectedCredential: credential, completionHandler: nil )
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        //dbg( "prepareInterfaceToProvideCredential: %@", credentialIdentity )
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        let credentialViewController = AutoFillCredentialViewController()

        // - Hierarchy
        self.addChild( credentialViewController )
        self.view.addSubview( credentialViewController.view )
        credentialViewController.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: credentialViewController.view )
                .constrain( as: .box ).activate()
    }

    override func prepareInterfaceForExtensionConfiguration() {
        let configurationViewController = AutoFillConfigurationViewController()

        // - Hierarchy
        self.addChild( configurationViewController )
        self.view.addSubview( configurationViewController.view )
        configurationViewController.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: configurationViewController.view )
                .constrain( as: .box ).activate()
    }
}

extension ASExtensionError: Error {
    init(_ code: ASExtensionError.Code, _ failure: String, reason: CustomStringConvertible? = nil, error: Error? = nil) {
        var userInfo: [String: Any] = [ NSLocalizedFailureErrorKey: failure ]
        if let error = error {
            userInfo[NSUnderlyingErrorKey] = error
        }
        if let reason = reason ?? error?.localizedDescription {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason.description
        }

        self.init( code, userInfo: userInfo )
    }
}
