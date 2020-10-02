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
        let _ = Model.shared

        dbg( "init:nibName:bundle: %@", nibNameOrNil, nibBundleOrNil )
        super.init( nibName: nibNameOrNil, bundle: nibBundleOrNil )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        let backgroundView = MPBackgroundView( mode: .backdrop )

        // - Hierarchy
        self.view.addSubview( backgroundView )

        // - Layout
        LayoutConfiguration( view: backgroundView )
                .constrain()
                .activate()
    }

    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
    */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        dbg( "prepareCredentialList: %@", serviceIdentifiers )

        let vc = AutoFillUsersViewController( userFiles: Model.shared.userFiles )

        // - Hierarchy
        self.addChild( vc )
        self.view.addSubview( vc.view )
        vc.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: vc.view )
                .constrain()
                .activate()
    }

    /*
     Implement this method if your extension supports showing credentials in the QuickType bar.
     When the userfr selects a credential from your app, this method will be called with the
     ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
     Provide the password by completing the extension request with the associated ASPasswordCredential.
     If using the credential would require showing custom UI for authenticating the user, cancel
     the request with error code ASExtensionError.userInteractionRequired.
    */
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        dbg( "provideCredentialWithoutUserInteraction: %@", credentialIdentity )

        DispatchQueue.mpw.promising {
            if let user = Model.shared.users.first( where: { $0.fullName == credentialIdentity.recordIdentifier } ) {
                return Promise( .success( user ) )
            }

            guard let userFile = Model.shared.userFiles.first( where: { $0.fullName == credentialIdentity.recordIdentifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No user named: \(credentialIdentity.recordIdentifier ?? "-")" ) }

            let keychainKeyFactory = MPKeychainKeyFactory( fullName: userFile.fullName )
            guard keychainKeyFactory.hasKey( for: userFile.algorithm )
            else { throw ASExtensionError( .userInteractionRequired, "No key in keychain for: \(userFile.fullName)" ) }

            keychainKeyFactory.expiry = .minutes( 5 )
            return userFile.authenticate( using: keychainKeyFactory )
        }.promising { (user: MPUser) in
            Model.shared.users.append( user )

            guard let service = user.services.first( where: { $0.serviceName == credentialIdentity.serviceIdentifier.identifier } )
            else { throw ASExtensionError( .credentialIdentityNotFound, "No service named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.fullName)" ) }

            return service.result( keyPurpose: .identification ).and( service.result( keyPurpose: .authentication ) ).promise {
                ASPasswordCredential( user: $0.0.token, password: $0.1.token )
            }
        }.failure { error in
            MPFeedback.shared.play( .error )

            switch error {
                case LAError.userCancel, LAError.userCancel, LAError.systemCancel, LAError.appCancel:
                    self.cancel( ASExtensionError( .userCanceled, "Local authentication cancelled.", error: error ) )

                case let error as LAError:
                    self.cancel( ASExtensionError( .userInteractionRequired, "Non-interactive authentication denied.", error: error ) )

                case let extensionError as ASExtensionError:
                    self.cancel( extensionError )

                default:
                    self.cancel( ASExtensionError( .failed, "Credential unavailable.", error: error ) )
            }
        }.success { (credential: ASPasswordCredential) in
            dbg( "Non-interactive credential lookup succeeded: %@", credential )
            MPFeedback.shared.play( .activate )

            self.complete( credential )
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
    }

    override func prepareInterfaceForExtensionConfiguration() {
        dbg( "prepareInterfaceForExtensionConfiguration: inf" )
    }

    // MARK: --- Private ---

    func cancel(_ error: ASExtensionError) {
        dbg( "cancelling request: %@", error )
        self.extensionContext.cancelRequest( withError: error )
    }

    func complete(_ passwordCredential: ASPasswordCredential) {
        dbg( "completing request: %@", passwordCredential )
        self.extensionContext.completeRequest( withSelectedCredential: passwordCredential, completionHandler: nil )
    }

    // MARK: --- Types ---

    class Model: MPMarshalObserver {
        static let shared = Model()

        var users     = [ MPUser ]()
        var userFiles = [ MPMarshal.UserFile ]()

        init() {
            MPLogSink.shared.register()

            do {
                self.userFiles = try MPMarshal.shared.setNeedsUpdate().await()
                MPMarshal.shared.observers.register( observer: self )
            }
            catch {
                err( "Cannot read user documents: %@", error )
            }
        }

        // MARK: --- MPMarshalObserver ---

        func userFilesDidChange(_ userFiles: [MPMarshal.UserFile]) {
            trc( "Users updated: %@", userFiles )
            self.userFiles = userFiles
        }
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