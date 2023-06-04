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
import CoreServices
import Network
import StoreKit
import SafariServices
import UniformTypeIdentifiers

import SwiftUI

//@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    static weak var shared: AppDelegate?

    lazy var window: UIWindow? = UIWindow()

    // MARK: - Public

    func reportLeaks() {
        self.window! => \.tintColor => nil
        self.window?.rootViewController = LeakRegistry.shared.reportViewController()
    }

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
            -> Bool {
        Self.shared = self

        // Require encrypted DNS.  Note: WebKit (eg. WKWebView/SFSafariViewController) ignores this.
        if #available( iOS 14.0, * ) {
            if let dohURL = URL( string: "https://cloudflare-dns.com/dns-query" ) {
                NWParameters.PrivacyContext.default.requireEncryptedNameResolution( true, fallbackResolver:
                .https( dohURL, serverAddresses: [
                    .hostPort( host: "2606:4700:4700::1111", port: 443 ),
                    .hostPort( host: "2606:4700:4700::1001", port: 443 ),
                    .hostPort( host: "1.1.1.1", port: 443 ),
                    .hostPort( host: "1.0.0.1", port: 443 ),
                ] ) )
            }
        }

        Task { @MainActor in
            await LogSink.shared.register()
            await Tracker.shared.startup()
            Migration.shared.perform()
            KeyboardMonitor.shared.install()

            alertWindow = self.window
            self.window! => \.tintColor => Theme.current.color.tint
            self.window!.rootViewController = MainNavigationController( rootViewController: MainUsersViewController() )
            self.window!.makeKeyAndVisible()
        }

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
            -> Bool {
        OperationQueue.main.addOperation {
            self.launchDecisions()
        }

        // Automatic subscription renewal (only if user is logged in to App Store and capable).
        Task.detached { try? await AppStore.shared.update( active: true ) }

        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Task.detached { await Marshal.shared.updateUserFiles() }
    }

    @available(iOS, deprecated: 15.0)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        guard let viewController = app.windows.first?.rootViewController
        else { return false }

        // spectre:action
        if Action.open( url: url, in: viewController ) {
            return true
        }

        // file share
        else {
            let urlUTIs = UTType.types( tag: url.pathExtension, tagClass: .filenameExtension, conformingTo: nil )
            if let format = SpectreFormat.allCases.first( where: { format in urlUTIs.contains { $0.identifier == format.uti } } ) {
                Task.detached {
                    let securityScoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if securityScoped {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        let user = try await self.user(from: url, options: options, in: viewController)

                        guard user.format == format
                        else {
                            wrn( "Imported user format: %@, doesn't match format: %@. [>PII]", user.format, format )
                            pii( "[>] URL: %@, UTIs: %@", url, urlUTIs )
                            return
                        }
                    }
                    catch {
                        if !(error is CancellationError) {
                            mperror( title: "Couldn't import user", error: error )
                        }
                    }
                }
                return true
            }

            wrn( "Import UTI not supported. [>PII]" )
            pii( "[>] URL: %@, UTIs: %@", url, urlUTIs )
        }

        return false
    }

    private func user(from url: URL, options: [UIApplication.OpenURLOptionsKey: Any], in viewController: UIViewController) async throws
            -> Marshal.UserFile {
        try await withCheckedThrowingContinuation { continuation in
            var error: NSError?
            let navigationController = viewController as? UINavigationController ?? viewController.navigationController

            NSFileCoordinator().coordinate( readingItemAt: url, error: &error ) { url in
                guard let importData = FileManager.default.contents( atPath: url.path )
                else {
                    continuation.resume(throwing: AppError.state( title: "Couldn't read import", details: url ) )
                    return
                }

                // Not In-Place: import the user from the file.
                guard (options[.openInPlace] as? Bool) ?? false, InAppFeature.premium.isEnabled
                else {
                    continuation.resume { try await Marshal.shared.import( data: importData, viewController: viewController ) }
                    return
                }

                // In-Place: allow choice between editing in-place or importing.
                do {
                    let importFile = try Marshal.UserFile( data: importData, origin: url )
                    let alertController = UIAlertController( title: importFile.userName, message:
                    """
                    Import this user into Spectre or sign-in from its current location?
                    """, preferredStyle: .alert )
                    alertController.addAction( UIAlertAction( title: "Import", style: .default ) { _ in
                        continuation.resume { try await Marshal.shared.import( data: importData, viewController: viewController ) }
                    } )
                    alertController.addAction( UIAlertAction( title: "Sign In (In-Place)", style: .default ) { _ in
                        Task {
                            do {
                                let user = try await UIAlertController.authenticate( userFile: importFile, title: importFile.userName,
                                                                                     action: "Log In", in: viewController )
                                navigationController?.pushViewController( MainSitesViewController( user: user ), animated: true )
                                continuation.resume( returning: importFile )
                            } catch {
                                mperror(title: "Couldn't authenticate \(importFile.userName)", error: error)
                            }
                        }
                    } )
                    alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                        continuation.resume(throwing: CancellationError() )
                    } )
                    viewController.present( alertController, animated: true )
                }
                catch {
                    continuation.resume(throwing: error )
                }
            }

            if let error = error {
                continuation.resume(throwing: error )
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        wrn( "Couldn't register for remote notifications: %@ [>PII]", error.localizedDescription )
        pii( "[>] Error: %@", error )
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        wrn( "Low Memory!" )
    }

    // - Private

    private func launchDecisions(completion: @escaping () -> Void = {}) {
        guard let window = self.window
        else { return }

        // Diagnostics decision
        if !AppConfig.shared.diagnosticsDecided {
            let alertController = UIAlertController( title: "Diagnostics", message:
            """
            If a bug, crash or issue should happen, Diagnostics will let us know and fix it.

            It's just code and statistics; personal information is sacred and cannot leave your device.
            """, preferredStyle: .actionSheet )
            alertController.addAction( UIAlertAction( title: "Disable", style: .cancel ) { _ in
                AppConfig.shared.diagnostics = false
                AppConfig.shared.diagnosticsDecided = true
                self.launchDecisions( completion: completion )
            } )
            alertController.addAction( UIAlertAction( title: "Engage", style: .default ) { _ in
                AppConfig.shared.diagnostics = true
                AppConfig.shared.diagnosticsDecided = true
                self.launchDecisions( completion: completion )
            } )
            alertController.popoverPresentationController?.sourceView = window
            alertController.popoverPresentationController?.sourceRect = CGRect( center: window.bounds.bottom, size: .zero )
            window.rootViewController?.present( alertController, animated: true )
            return
        }

        // Notifications decision
        if !AppConfig.shared.notificationsDecided {
            let alertController = UIAlertController( title: "Keeping Safe", message:
            """
            Things move fast in the online world.

            If you enable notifications, we can inform you of known breaches and keep you current on important security events.
            """, preferredStyle: .actionSheet )
            alertController.popoverPresentationController?.sourceView = window
            alertController.popoverPresentationController?.sourceRect = CGRect( center: window.bounds.bottom, size: .zero )
            alertController.addAction( UIAlertAction( title: "Thanks!", style: .default ) { _ in
                Tracker.shared.enableNotifications( consented: false ) { _ in
                    self.launchDecisions( completion: completion )
                }
            } )
            window.rootViewController?.present( alertController, animated: true )
            return
        }
    }
}
