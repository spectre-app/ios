//
//  AppDelegate.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import CoreServices
import Network
import StoreKit
import SafariServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    lazy var window: UIWindow? = UIWindow()

    // MARK: --- UIApplicationDelegate ---

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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

        self.window! => \.tintColor => Theme.current.color.tint
        self.window!.rootViewController = MainNavigationController( rootViewController: MainUsersViewController() )
        self.window!.makeKeyAndVisible()

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        OperationQueue.main.addOperation {
            self.launchDecisions()
        }

        // Automatic subscription renewal (only if user is logged in to App Store and capable).
        AppStore.shared.update()

        return true
    }

    func launchDecisions(completion: @escaping () -> () = {}) {
        guard let window = self.window
        else { return }

        // Diagnostics decision
        if !AppConfig.shared.diagnosticsDecided {
            let controller = UIAlertController( title: "Diagnostics", message:
            """
            If a bug, crash or issue should happen, Diagnostics will let us know and fix it.

            It's just code and statistics, personal information is sacred and cannot leave your device.
            """, preferredStyle: .actionSheet )
            controller.addAction( UIAlertAction( title: "Disable", style: .cancel ) { _ in
                AppConfig.shared.diagnostics = false
                AppConfig.shared.diagnosticsDecided = true
                self.launchDecisions( completion: completion )
            } )
            controller.addAction( UIAlertAction( title: "Engage", style: .default ) { _ in
                AppConfig.shared.diagnostics = true
                AppConfig.shared.diagnosticsDecided = true
                self.launchDecisions( completion: completion )
            } )
            controller.popoverPresentationController?.sourceView = window
            controller.popoverPresentationController?.sourceRect = CGRect( center: window.bounds.bottom, size: .zero )
            window.rootViewController?.present( controller, animated: true )
            return
        }

        // Notifications decision
        if !AppConfig.shared.notificationsDecided {
            let controller = UIAlertController( title: "Keeping Safe", message:
            """
            Things move fast in the online world.

            If you enable notifications, we can inform you of known breaches and keep you current on important security events.
            """, preferredStyle: .actionSheet )
            controller.popoverPresentationController?.sourceView = window
            controller.popoverPresentationController?.sourceRect = CGRect( center: window.bounds.bottom, size: .zero )
            controller.addAction( UIAlertAction( title: "Thanks!", style: .default ) { _ in
                Tracker.shared.enableNotifications( consented: false ) { _ in
                    self.launchDecisions( completion: completion )
                }
            } )
            window.rootViewController?.present( controller, animated: true )
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        guard let viewController = app.keyWindow?.rootViewController
        else { return false }
        let navigationController = viewController as? UINavigationController ?? viewController.navigationController

        if let components = URLComponents( url: url, resolvingAgainstBaseURL: false ),
           components.scheme == "spectre" {
            // spectre:import?data=<export>
            if components.path == "import" {
                guard let data = components.queryItems?.first( where: { $0.name == "data" } )?.value?.data( using: .utf8 )
                else {
                    wrn( "Import URL missing data parameter: %@", url )
                    return false
                }

                Marshal.shared.import( data: data, viewController: viewController ).then {
                    if case .failure(let error) = $0 {
                        mperror( title: "Couldn't import user", error: error )
                    }
                }
                return true
            }

            // spectre:web?url=<url>
            else if components.path == "web" {
                guard components.verifySignature()
                else {
                    wrn( "Untrusted: %@", url )
                    return false
                }
                let openString = components.queryItems?.first( where: { $0.name == "url" } )?.value ?? "https://spectre.app"
                guard let openURL = URL( string: openString )
                else {
                    wrn( "Cannot open malformed URL: %@", openString )
                    return false
                }

                viewController.present( SFSafariViewController( url: openURL ), animated: true )
                return true
            }

            // spectre:review
            else if components.path == "review" {
                guard components.verifySignature()
                else {
                    wrn( "Untrusted: %@", url )
                    return false
                }

                SKStoreReviewController.requestReview()
                return true
            }

            // spectre:store[?id=<appleid>]
            else if components.path == "store" {
                guard components.verifySignature()
                else {
                    wrn( "Untrusted: %@", url )
                    return false
                }

                let id = (components.queryItems?.first( where: { $0.name == "id" } )?.value as NSString?)?.integerValue
                AppStore.shared.presentStore( appleID: id, in: viewController )
                return true
            }

            // spectre:update[?id=<appleid>[&build=<version>]]
            else if components.path == "update" {
                guard components.verifySignature()
                else {
                    wrn( "Untrusted: %@", url )
                    return false
                }

                let id = (components.queryItems?.first( where: { $0.name == "id" } )?.value as NSString?)?.integerValue
                let build = components.queryItems?.first( where: { $0.name == "build" } )?.value
                AppStore.shared.isUpToDate( appleID: id, buildVersion: build ).then {
                    do {
                        let result = try $0.get()
                        if result.upToDate {
                            AlertController( title: "Your \(productName) app is up-to-date!", message: result.buildVersion,
                                             details: "build[\(result.buildVersion)] > store[\(result.storeVersion)]" )
                                    .show()
                        }
                        else {
                            inf( "%@ is outdated: build[%@] < store[%@]", productName, result.buildVersion, result.storeVersion )
                            AppStore.shared.presentStore( in: viewController )
                        }
                    }
                    catch {
                        mperror( title: "Couldn't check for updates", error: error )
                    }
                }
                return true
            }
        }

        // file share
        else if let utisValue = UTTypeCreateAllIdentifiersForTag(
                kUTTagClassFilenameExtension, url.pathExtension as CFString, nil )?.takeRetainedValue(),
                let utis = utisValue as? Array<String?> {
            for format in SpectreFormat.allCases
                where utis.contains( format.uti ) {
                var error: NSError?
                NSFileCoordinator().coordinate( readingItemAt: url, error: &error ) { url in
                    // Not In-Place: import the user from the file.
                    if !((options[.openInPlace] as? Bool) ?? false) {
                        guard let importData = FileManager.default.contents( atPath: url.path )
                        else {
                            mperror( title: "Couldn't read import", details: url )
                            return
                        }
                        Marshal.shared.import( data: importData, viewController: viewController ).failure { error in
                            mperror( title: "Couldn't import user", error: error )
                        }
                        return
                    }

                    // In-Place: allow choice between editing in-place or importing.
                    let securityScoped = url.startAccessingSecurityScopedResource()
                    guard let importData = FileManager.default.contents( atPath: url.path )
                    else {
                        mperror( title: "Couldn't read import", details: url )
                        return
                    }
                    guard InAppFeature.premium.isEnabled
                    else {
                        inf( "In-place editing is not available at this time." )
                        Marshal.shared.import( data: importData, viewController: viewController )
                                      .failure { error in
                                          mperror( title: "Couldn't import user", error: error )
                                      }
                                      .finally {
                                          if securityScoped {
                                              url.stopAccessingSecurityScopedResource()
                                          }
                                      }
                        return
                    }

                    do {
                        let importFile = try Marshal.UserFile( data: importData, origin: url )
                        let controller = UIAlertController( title: importFile.userName, message:
                        """
                        Import this user into Spectre or sign-in from its current location?
                        """, preferredStyle: .alert )
                        controller.addAction( UIAlertAction( title: "Import", style: .default ) { _ in
                            Marshal.shared.import( data: importData, viewController: viewController )
                                          .failure { error in
                                              mperror( title: "Couldn't import user", error: error )
                                          }
                                          .finally {
                                              if securityScoped {
                                                  url.stopAccessingSecurityScopedResource()
                                              }
                                          }
                        } )
                        controller.addAction( UIAlertAction( title: "Sign In (In-Place)", style: .default ) { _ in
                            UIAlertController.authenticate( userFile: importFile, title: importFile.userName, in: viewController, action: "Log In" )
                                             .success {
                                                 navigationController?.pushViewController(
                                                         MainSitesViewController( user: $0 ), animated: true )
                                             }
                                             .failure { error in
                                                 mperror( title: "Couldn't unlock user", error: error )
                                             }
                                             .finally {
                                                 if securityScoped {
                                                     url.stopAccessingSecurityScopedResource()
                                                 }
                                             }
                        } )
                        controller.addAction( UIAlertAction( title: "Cancel", style: .cancel ) { _ in
                            if securityScoped {
                                url.stopAccessingSecurityScopedResource()
                            }
                        } )
                        viewController.present( controller, animated: true )
                    }
                    catch {
                        mperror( title: "Couldn't open import", error: error )
                        if securityScoped {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }
                if let error = error {
                    mperror( title: "Couldn't access import", error: error )
                }
                return true
            }

            wrn( "Import UTI not supported: %@: %@", url, utis )
        }
        else {
            wrn( "Open URL not supported: %@", url )
        }

        return false
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        wrn( "Couldn't register for remote notifications. [>TRC]" )
        pii( "[>] %@", error )
    }
}
