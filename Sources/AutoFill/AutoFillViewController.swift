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
        MPLogSink.shared.register()

        dbg( "init:nibName:bundle: %@", nibNameOrNil, nibBundleOrNil )
        super.init( nibName: nibNameOrNil, bundle: nibBundleOrNil )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func loadView() {
        self.view = MPBackgroundView( mode: .backdrop )
        self.view => \.tintColor => Theme.current.color.tint
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dbg( "viewDidLoad" )
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
        LayoutConfiguration( view: usersViewController.view )
                .constrain()
                .activate()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        dbg( "provideCredentialWithoutUserInteraction: %@", credentialIdentity )
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        do { let _ = try MPMarshal.shared.setNeedsUpdate().await() }
        catch { err( "Cannot read user documents: %@", error ) }

        DispatchQueue.mpw.promising {
            if let user = AutoFillModel.shared.users.first( where: { $0.fullName == credentialIdentity.recordIdentifier } ) {
                return Promise( .success( user ) )
            }

            guard let userFile = AutoFillModel.shared.userFiles.first( where: { $0.fullName == credentialIdentity.recordIdentifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No user named: \(credentialIdentity.recordIdentifier ?? "-")" ) }

            let keychainKeyFactory = MPKeychainKeyFactory( fullName: userFile.fullName )
            guard keychainKeyFactory.hasKey( for: userFile.algorithm )
            else { throw ASExtensionError( .userInteractionRequired, "No key in keychain for: \(userFile.fullName)" ) }

            keychainKeyFactory.expiry = .minutes( 5 )
            return userFile.authenticate( using: keychainKeyFactory )
        }.promising { (user: MPUser) in
            AutoFillModel.shared.users.append( user )

            guard let service = user.services.first( where: { $0.serviceName == credentialIdentity.serviceIdentifier.identifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No service named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.fullName)" ) }

            return service.result( keyPurpose: .identification ).token.and( service.result( keyPurpose: .authentication ).token ).promise {
                ASPasswordCredential( user: $0.0, password: $0.1 )
            }
        }.failure { error in
            MPFeedback.shared.play( .error )

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
            MPFeedback.shared.play( .activate )

            self.extensionContext.completeRequest( withSelectedCredential: credential, completionHandler: nil )
        }
    }

    /*
     Implement this method if provideCredentialWithoutUserInteraction(for:) can fail with
     ASExtensionError.userInteractionRequired. In this case, the system may present your extension's
     UI and call this method. Show appropriate UI for authenticating the user then provide the password
     by completing the extension request with the associated ASPasswordCredential.
    */
    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        dbg( "prepareInterfaceToProvideCredential: %@", credentialIdentity )
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        let usersViewController = AutoFillUsersViewController()

        // - Hierarchy
        self.addChild( usersViewController )
        self.view.addSubview( usersViewController.view )
        usersViewController.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: usersViewController.view )
                .constrain()
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
