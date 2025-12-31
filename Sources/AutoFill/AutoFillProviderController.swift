//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AuthenticationServices
import LocalAuthentication
import SwiftUI

#if canImport(UIKit)
typealias AHostingController = UIHostingController
#elseif canImport(AppKit)
typealias AHostingController = NSHostingController
#endif

// Note: The Address Sanitizer will break the ability to load this extension due to its excessive memory usage.
class AutoFillProviderController: ASCredentialProviderViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        LeakRegistry.shared.register(self)

        // FIXME: This needs to complete before moving on.
        Task { await LogSink.shared.register() }
        Tracker.shared.startup()
    }

    // MARK: - Life

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported for this class")
    }

    #if canImport(UIKit)
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        SpectreModel.shared.activeUser?.logout()
    }

    #elseif canImport(AppKit)
    override func viewWillDisappear() {
        super.viewWillDisappear()

        SpectreModel.shared.activeUser?.logout()
    }
    #endif

    // MARK: - ASCredentialProviderViewController

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        dbg("prepareCredentialList -> serviceIdentifiers: \(serviceIdentifiers)")
        self.show(autofill: .init(extensionContext: self.extensionContext, serviceIdentifiers: serviceIdentifiers))
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        dbg("provideCredentialWithoutUserInteraction -> credentialRequest: \(credentialRequest)")

        self.rootViewController = nil
        Task.detached { @MainActor in
            do {
                let userFiles = AppFeature.autofill.isEnabled ? await Marshal.shared.updateUserFiles().filter(\.autofill) : []
                let user = try await {
                    guard let userFile = userFiles.first(where: { $0.credentialOwnerName == credentialRequest.credentialIdentity.user })
                    else {
                        throw ASExtensionError(
                            .credentialIdentityNotFound, "No user named: \(credentialRequest.credentialIdentity.user)",
                        )
                    }

                    guard userFile.biometricLock, AppFeature.biometrics.isEnabled
                    else {
                        throw ASExtensionError(
                            .userInteractionRequired, "Biometrics not enabled for: \(userFile.userName)",
                        )
                    }

                    let keychainKeyFactory = KeychainKeyFactory(userName: userFile.userName, expiry: .minutes(5))
                    guard keychainKeyFactory.isKeyAvailable(for: userFile.algorithm)
                    else {
                        throw ASExtensionError(
                            .userInteractionRequired, "Key unavailable from keychain for: \(userFile.userName)",
                        )
                    }

                    return try await userFile.authenticate(using: keychainKeyFactory)
                }()

                guard let siteName = user.credential(for: credentialRequest.credentialIdentity.serviceIdentifier)?.siteName,
                      let site = user.sites.first(where: { $0.siteName == siteName })
                else {
                    throw ASExtensionError(
                        .credentialIdentityNotFound,
                        "No site for: \(credentialRequest.credentialIdentity.serviceIdentifier.identifier), in user: \(user.userName)",
                    )
                }

                guard let login = AppFeature.logins.isEnabled ? try await site.result(keyPurpose: .identification)?.task.value : "",
                      let password = try await site.result(keyPurpose: .authentication)?.task.value
                else {
                    throw ASExtensionError(
                        .userInteractionRequired, "Unauthenticated user: \(user.userName)",
                    )
                }

                inf("Autofilling non-interactively: \(login), for service: \(credentialRequest.credentialIdentity.serviceIdentifier)")
                let credential = ASPasswordCredential(user: login, password: password)
                self.extensionContext.completeRequest(withSelectedCredential: credential) { expired in
                    if !expired {
                        site.use()
                    }
                }
            }
            catch {
                wrn("Autofill unsuccessful.", data: error)

                self.extensionContext.cancelRequest(withError: ASExtensionError(for: error))
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
        self.rootViewController = AHostingController(rootView: AnyView(MainWindow().spectreStyle().modifier(LeakReporter())))
    }

    private var rootViewController: AHostingController<AnyView>? {
        didSet {
            if let oldViewController = oldValue {
                #if canImport(UIKit)
                oldViewController.willMove(toParent: nil)
                #endif
                oldViewController.viewIfLoaded?.removeFromSuperview()
                oldViewController.removeFromParent()
            }

            if let newViewController = self.rootViewController {
                self.addChild(newViewController)
                newViewController.view.frame = self.view.bounds
                #if canImport(UIKit)
                newViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                #elseif canImport(AppKit)
                newViewController.view.autoresizingMask = [.width, .height]
                #endif
                self.view.autoresizesSubviews = true
                self.view.addSubview(newViewController.view)
                #if canImport(UIKit)
                newViewController.didMove(toParent: self)
                #endif
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
