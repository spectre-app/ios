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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    lazy var window: UIWindow? = UIWindow()

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
                    -> Bool {
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

        LogSink.shared.register()
        Tracker.shared.startup()
        Migration.shared.perform()
        KeyboardMonitor.shared.install()

        self.window! => \.tintColor => Theme.current.color.tint
        self.window!.rootViewController = MainNavigationController( rootViewController: MainUsersViewController() )
        self.window!.makeKeyAndVisible()

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
                    -> Bool {
        OperationQueue.main.addOperation {
            self.launchDecisions()
        }

        // Automatic subscription renewal (only if user is logged in to App Store and capable).
        AppStore.shared.update( active: true )

        return true
    }

    func launchDecisions(completion: @escaping () -> Void = {}) {
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

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        guard let viewController = app.keyWindow?.rootViewController
        else { return false }
        let navigationController = viewController as? UINavigationController ?? viewController.navigationController

        // spectre:action
        if Action.open( url: url, in: viewController ) {
            return true
        }

        // file share
        else if let utisValue = UTTypeCreateAllIdentifiersForTag(
                kUTTagClassFilenameExtension, url.pathExtension as CFString, nil )?.takeRetainedValue(),
                let utis = utisValue as? [String?] {
            if let format = SpectreFormat.allCases.first( where: { utis.contains( $0.uti ) } ) {
                let securityScoped = url.startAccessingSecurityScopedResource()
                let promise = Promise<Marshal.UserFile>()
                        .failure {
                            if let error = $0 as? AppError, case AppError.cancelled = error {
                                return
                            }
                            mperror( title: "Couldn't import user", error: $0 )
                        }
                        .success {
                            guard $0.format == format
                            else {
                                wrn( "Imported user format: %@, doesn't match format: %@. [>PII]", $0.format, format )
                                pii( "[>] URL: %@, UTIs: %@", url, utis )
                                return
                            }
                        }
                        .finally {
                            if securityScoped {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                var error: NSError?
                NSFileCoordinator().coordinate( readingItemAt: url, error: &error ) { url in
                    guard let importData = FileManager.default.contents( atPath: url.path )
                    else {
                        promise.finish( .failure( AppError.state( title: "Couldn't read import", details: url ) ) )
                        return
                    }

                    // Not In-Place: import the user from the file.
                    guard (options[.openInPlace] as? Bool) ?? false, InAppFeature.premium.isEnabled
                    else {
                        Marshal.shared.import( data: importData, viewController: viewController ).finishes( promise )
                        return
                    }

                    // In-Place: allow choice between editing in-place or importing.
                    do {
                        let importFile = try Marshal.UserFile( data: importData, origin: url )

                        DispatchQueue.main.perform {
                            let alertController = UIAlertController( title: importFile.userName, message:
                            """
                            Import this user into Spectre or sign-in from its current location?
                            """, preferredStyle: .alert )
                            alertController.addAction( UIAlertAction( title: "Import", style: .default ) { _ in
                                Marshal.shared.import( data: importData, viewController: viewController ).finishes( promise )
                            } )
                            alertController.addAction( UIAlertAction( title: "Sign In (In-Place)", style: .default ) { _ in
                                UIAlertController.authenticate( userFile: importFile, title: importFile.userName,
                                                                action: "Log In", in: viewController )
                                                 .success( on: .main ) {
                                                     navigationController?.pushViewController(
                                                             MainSitesViewController( user: $0 ), animated: true )
                                                 }
                                                 .promise { _ in importFile }
                                                 .finishes( promise )
                            } )
                            alertController.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                                promise.finish( .failure( AppError.cancelled ) )
                            } )
                            viewController.present( alertController, animated: true )
                        }
                    }
                    catch {
                        promise.finish( .failure( error ) )
                    }
                }
                if let error = error {
                    promise.finish( .failure( error ) )
                }
                return true
            }

            wrn( "Import UTI not supported. [>PII]" )
            pii( "[>] URL: %@, UTIs: %@", url, utis )
        }
        else {
            wrn( "Open URL not supported. [>PII]" )
            pii( "[>] URL: %@", url )
        }

        return false
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        wrn( "Couldn't register for remote notifications. [>PII]" )
        pii( "[>] Error: %@", error )
    }
}
