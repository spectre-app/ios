//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AuthenticationServices
import LocalAuthentication
import SwiftUI

// Note: The Address Sanitizer will break the ability to load this extension due to its excessive memory usage.
class AutoFillProviderController: ASCredentialProviderViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        LeakRegistry.shared.register(self)

        LogSink.shared.register()
        Tracker.shared.startup(extensionController: self)
    }

    // MARK: - Life

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported for this class")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        SpectreModel.shared.activeUser?.logout()
    }

    // MARK: - ASCredentialProviderViewController

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        dbg("prepareCredentialList -> serviceIdentifiers: \(serviceIdentifiers)")
        self.show(autofill: .init(extensionContext: self.extensionContext, serviceIdentifiers: serviceIdentifiers))
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        dbg("provideCredentialWithoutUserInteraction -> credentialRequest: \(credentialRequest)")

        self.rootViewController = nil
        Task.detached {
            do {
                let userFiles = AppFeature.autofill.isEnabled ? await Marshal.shared.updateUserFiles().filter(\.autofill) : []
                let user = try await {
                    guard let userFile = userFiles.first(where: { $0.credentialOwnerName == credentialRequest.credentialIdentity.user })
                    else {
                        throw ASExtensionError(
                            .credentialIdentityNotFound, "No user named: \(credentialRequest.credentialIdentity.user)"
                        )
                    }

                    guard userFile.biometricLock, AppFeature.biometrics.isEnabled
                    else {
                        throw ASExtensionError(
                            .userInteractionRequired, "Biometrics not enabled for: \(userFile.userName)"
                        )
                    }

                    let keychainKeyFactory = KeychainKeyFactory(userName: userFile.userName, expiry: .minutes(5))
                    guard keychainKeyFactory.isKeyAvailable(for: userFile.algorithm)
                    else {
                        throw ASExtensionError(
                            .userInteractionRequired, "Key unavailable from keychain for: \(userFile.userName)"
                        )
                    }

                    return try await userFile.authenticate(using: keychainKeyFactory)
                }()

                guard let siteName = user.credential(for: credentialRequest.credentialIdentity.serviceIdentifier)?.siteName,
                      let site = user.sites.first(where: { $0.siteName == siteName })
                else {
                    throw ASExtensionError(
                        .credentialIdentityNotFound,
                        "No site for: \(credentialRequest.credentialIdentity.serviceIdentifier.identifier), in user: \(user.userName)"
                    )
                }

                guard let login = AppFeature.logins.isEnabled ? try await site.result(keyPurpose: .identification)?.task.value : "",
                      let password = try await site.result(keyPurpose: .authentication)?.task.value
                else {
                    throw ASExtensionError(
                        .userInteractionRequired, "Unauthenticated user: \(user.userName)"
                    )
                }

                inf("Autofilling non-interactively: \(login), for service: \(credentialRequest.credentialIdentity.serviceIdentifier)")
                let credential = ASPasswordCredential(user: login, password: password)
                await self.extensionContext.completeRequest(withSelectedCredential: credential) { expired in
                    if !expired {
                        site.use()
                    }
                }
            }
            catch {
                wrn("Autofill unsuccessful.", data: error)

                await self.extensionContext.cancelRequest(withError: ASExtensionError(for: error))
            }
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        dbg("prepareInterfaceToProvideCredential -> credentialRequest: \(credentialRequest)")
        self.show(autofill: .init(extensionContext: self.extensionContext, credentialRequest: credentialRequest))
    }

    override func prepareInterfaceForExtensionConfiguration() {
        dbg("prepareInterfaceForExtensionConfiguration")
        self.show(autofill: .init(extensionContext: self.extensionContext))
    }

//    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
//    }
//    override func performWithoutUserInteractionIfPossible(passkeyRegistration registrationRequest: ASPasskeyCredentialRequest) {
//    }

    // MARK: - Private

    private func show(autofill: SpectreModel.AutoFill) {
        SpectreModel.shared.autofill = autofill
        self.rootViewController = UIHostingController(rootView: MainWindow().spectreStyle().modifier(LeakReporter()))
    }

    private var rootViewController: UIViewController? {
        didSet {
            if let oldViewController = oldValue {
                oldViewController.willMove(toParent: nil)
                oldViewController.viewIfLoaded?.removeFromSuperview()
                oldViewController.removeFromParent()
            }

            if let newViewController = self.rootViewController {
                self.addChild(newViewController)
                newViewController.view.frame = self.view.bounds
                newViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.view.autoresizesSubviews = true
                self.view.addSubview(newViewController.view)
                newViewController.didMove(toParent: self)
            }
        }
    }
}

extension ASExtensionError: @retroactive Error {
    init(_ code: ASExtensionError.Code, _ failure: String, reason: CustomStringConvertible? = nil, error: Error? = nil) {
        var userInfo: [String: Any] = [NSLocalizedFailureErrorKey: failure]
        if let error {
            userInfo[NSUnderlyingErrorKey] = error
        }
        if let reason = reason ?? error?.localizedDescription {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason.description
        }

        self.init(code, userInfo: userInfo)
    }

    init(for error: Error) {
        switch error {
            case let extensionError as ASExtensionError:
                self = extensionError

            case LAError.userCancel, LAError.systemCancel, LAError.appCancel:
                self = ASExtensionError(.userCanceled, "Local authentication cancelled.", error: error)

            case let error as LAError:
                self = ASExtensionError(.userInteractionRequired, "Non-interactive authentication denied.", error: error)

            default:
                self = ASExtensionError(.failed, "Credential unavailable.", error: error)
        }
    }
}
