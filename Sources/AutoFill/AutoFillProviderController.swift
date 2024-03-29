// =============================================================================
// Created by Maarten Billemont on 2020-09-12.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import AuthenticationServices
import LocalAuthentication

// Note: The Address Sanitizer will break the ability to load this extension due to its excessive memory usage.
class AutoFillProviderController: ASCredentialProviderViewController {
    static weak var shared: AutoFillProviderController?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init( nibName: nibNameOrNil, bundle: nibBundleOrNil )

        Self.shared = self
        LogSink.shared.register()
        Tracker.shared.startup( extensionController: self )
    }

    // MARK: - Public

    func reportLeaks() {
        self.view => \.tintColor => nil
        self.rootViewController = LeakRegistry.shared.reportViewController()
    }

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view => \.tintColor => Theme.current.color.tint
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        KeyboardMonitor.shared.install()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        Tracker.shared.appeared()
    }

    // MARK: - UITraitEnvironment

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange( previousTraitCollection )

        Theme.current.updateTask.request( now: true, await: true )
    }

    // MARK: - ASCredentialProviderViewController

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        AutoFillModel.shared.context = AutoFillModel.Context( serviceIdentifiers: serviceIdentifiers )

        self.rootViewController = MainNavigationController( rootViewController: AutoFillUsersViewController() )
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        self.rootViewController = nil

        Marshal.shared.updateTask.request( now: true )
               .promising( on: .api ) { userFiles in
                   if let user = AutoFillModel.shared.cachedUser( userName: credentialIdentity.recordIdentifier ) {
                       return Promise( .success( user ) )
                   }

                   guard let userFile = userFiles.first( where: { $0.userName == credentialIdentity.recordIdentifier } )
                   else {
                       throw ASExtensionError(
                               .credentialIdentityNotFound, "No user named: \(credentialIdentity.recordIdentifier ?? "-")" )
                   }

                   let keychainKeyFactory = KeychainKeyFactory( userName: userFile.userName )
                   guard keychainKeyFactory.isKeyAvailable( for: userFile.algorithm )
                   else {
                       throw ASExtensionError(
                               .userInteractionRequired, "Key unavailable from keychain for: \(userFile.userName)" )
                   }

                   keychainKeyFactory.expiry = .minutes( 5 )
                   return userFile.authenticate( using: keychainKeyFactory )
               }
               .promising { (user: User) in
                   AutoFillModel.shared.cacheUser( user )

                   guard let siteName = user.credential( for: credentialIdentity.serviceIdentifier )?.siteName,
                         let site = user.sites.first( where: { $0.siteName == siteName } )
                   else {
                       throw ASExtensionError(
                               .credentialIdentityNotFound,
                               "No site named: \(credentialIdentity.serviceIdentifier.identifier), for user: \(user.userName)" )
                   }

                   guard let login = site.result( keyPurpose: .identification ), let password = site.result( keyPurpose: .authentication )
                   else {
                       throw ASExtensionError(
                               .userInteractionRequired, "Unauthenticated user: \(user.userName)" )
                   }

                   return login.token.and( password.token ).promise {
                       ASPasswordCredential( user: $0.0, password: $0.1 )
                   }
               }
               .success( on: .main ) { (credential: ASPasswordCredential) in
                   inf( "Autofilling non-interactively: %@, for service: %@", credential.user, credentialIdentity.serviceIdentifier )
                   Feedback.shared.play( .activate )

                   self.extensionContext.completeRequest( withSelectedCredential: credential, completionHandler: nil )
               }
               .failure( on: .main ) { error in
                   wrn( "Autofill unsuccessful: %@ [>PII]", error.localizedDescription )
                   pii( "[>] Error: %@", error )
                   Feedback.shared.play( .error )

                   self.extensionContext.cancelRequest( withError: ASExtensionError(for: error ) )
               }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        AutoFillModel.shared.context = AutoFillModel.Context( credentialIdentity: credentialIdentity )

        self.rootViewController = MainNavigationController( rootViewController: AutoFillCredentialViewController() )
    }

    override func prepareInterfaceForExtensionConfiguration() {
        AutoFillModel.shared.context = AutoFillModel.Context()

        self.rootViewController = MainNavigationController( rootViewController: AutoFillConfigurationViewController() )
    }

    // MARK: - Private

    private var rootViewController: UIViewController? {
        didSet {
            if let oldViewController = oldValue {
                oldViewController.willMove(toParent: nil)
                oldViewController.viewIfLoaded?.removeFromSuperview()
                oldViewController.removeFromParent()
            }

            if let newViewController = self.rootViewController {
                self.addChild(newViewController)
                newViewController.view.layer.cornerRadius = 8
                self.view.addSubview( newViewController.view )
                LayoutConfiguration( view: newViewController.view )
                    .constrain( as: .box, margin: true ).activate()
                newViewController.didMove( toParent: self )
            }
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

    init(for error: Error) {
        switch error {
            case let extensionError as ASExtensionError:
                self = extensionError

            case LAError.userCancel, LAError.userCancel, LAError.systemCancel, LAError.appCancel:
                self = ASExtensionError( .userCanceled, "Local authentication cancelled.", error: error )

            case let error as LAError:
                self = ASExtensionError( .userInteractionRequired, "Non-interactive authentication denied.", error: error )

            default:
                self = ASExtensionError( .failed, "Credential unavailable.", error: error )
        }
    }
}
