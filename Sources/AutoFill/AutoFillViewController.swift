//
//  CredentialProviderViewController.swift
//  Spectre-AutoFill
//
//  Created by Maarten Billemont on 2020-09-12.
//  Copyright © 2020 Lyndir. All rights reserved.
//

import AuthenticationServices
import LocalAuthentication

class AutoFillViewController: ASCredentialProviderViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        LogSink.shared.register()

        dbg( "init:nibName:bundle: %@", nibNameOrNil, nibBundleOrNil )
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

        dbg( "viewDidLoad" )
        Tracker.shared.startup( extensionController: self )
        AutoFillModel.shared.context = AutoFillModel.Context()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        dbg( "prepareCredentialList: %@", serviceIdentifiers )
        AutoFillModel.shared.context = AutoFillModel.Context( serviceIdentifiers: serviceIdentifiers )

        let usersViewController = AutoFillUsersViewController()

        // - Hierarchy
        self.addChild( usersViewController )
        self.view.addSubview( usersViewController.view )
        usersViewController.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: usersViewController.view ).constrain( as: .box )
                                                             .activate()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        dbg( "provideCredentialWithoutUserInteraction: %@", credentialIdentity )
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        do { let _ = try Marshal.shared.setNeedsUpdate().await() }
        catch { err( "Cannot read user documents: %@", error ) }

        DispatchQueue.api.promising {
            if let user = AutoFillModel.shared.users.first( where: { $0.userName == credentialIdentity.recordIdentifier } ) {
                return Promise( .success( user ) )
            }

            guard let userFile = AutoFillModel.shared.userFiles.first( where: { $0.userName == credentialIdentity.recordIdentifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No user named: \(credentialIdentity.recordIdentifier ?? "-")" ) }

            let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
            guard keychainKeyFactory.hasKey( for: userFile.algorithm )
            else { throw ASExtensionError( .userInteractionRequired, "No key in keychain for: \(userFile.userName)" ) }

            keychainKeyFactory.expiry = .minutes( 5 )
            return userFile.authenticate( using: keychainKeyFactory )
        }.promising { (user: User) in
            AutoFillModel.shared.users.append( user )

            guard let site = user.sites.first( where: { $0.siteName == credentialIdentity.serviceIdentifier.identifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No site named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.userName)" ) }

            return site.result( keyPurpose: .identification ).token.and( site.result( keyPurpose: .authentication ).token ).promise {
                ASPasswordCredential( user: $0.0, password: $0.1 )
            }
        }.failure { error in
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
        }.success { (credential: ASPasswordCredential) in
            Feedback.shared.play( .activate )

            self.extensionContext.completeRequest( withSelectedCredential: credential, completionHandler: nil )
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        dbg( "prepareInterfaceToProvideCredential: %@", credentialIdentity )
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        let usersViewController = AutoFillUsersViewController()

        // - Hierarchy
        self.addChild( usersViewController )
        self.view.addSubview( usersViewController.view )
        usersViewController.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: usersViewController.view ).constrain( as: .box )
                                                             .activate()
    }

    override func prepareInterfaceForExtensionConfiguration() {
        dbg( "prepareInterfaceForExtensionConfiguration" )
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
