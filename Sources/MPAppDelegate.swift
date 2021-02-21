//
//  MPAppDelegate.swift
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
class MPAppDelegate: UIResponder, UIApplicationDelegate {

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

        MPLogSink.shared.register()
        MPTracker.shared.startup()

        self.window! => \.tintColor => Theme.current.color.tint
        self.window!.rootViewController = MPNavigationController( rootViewController: MPUsersViewController() )
        self.window!.makeKeyAndVisible()

        if let freshchatApp = freshchatApp.b64Decrypt(), let freshchatKey = freshchatKey.b64Decrypt() {
            let freshchatConfig = FreshchatConfig( appID: freshchatApp, andAppKey: freshchatKey )
            freshchatConfig.domain = "msdk.eu.freshchat.com"
            Freshchat.sharedInstance().initWith( freshchatConfig )
        }

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.tryDecisions()

        // Automatic subscription renewal (only if user is logged in to App Store and capable).
        AppStore.shared.update()

        return true
    }

    func tryDecisions() {

        // Diagnostics decision
        if !appConfig.diagnosticsDecided {
            let controller = UIAlertController( title: "Diagnostics", message:
            """
            We look for bugs, sudden crashes, runtime issues & statistics.

            Diagnostics are scrubbed and personal details will never leave your device.
            """, preferredStyle: .actionSheet )
            controller.addAction( UIAlertAction( title: "Disable", style: .cancel ) { _ in
                appConfig.diagnostics = false
                appConfig.diagnosticsDecided = true
                self.tryDecisions()
            } )
            controller.addAction( UIAlertAction( title: "Engage", style: .default ) { _ in
                appConfig.diagnostics = true
                appConfig.diagnosticsDecided = true
                self.tryDecisions()
            } )
            controller.popoverPresentationController?.sourceView = self.window
            self.window?.rootViewController?.present( controller, animated: true )
            return
        }

        // Notifications decision
        if !appConfig.notificationsDecided {
            let controller = UIAlertController( title: "Keeping Safe", message:
            """
            Things move fast in the online world.

            If you enable notifications, we can inform you of known breaches and keep you current on important security events.
            """, preferredStyle: .actionSheet )
            controller.popoverPresentationController?.sourceView = self.window
            controller.addAction( UIAlertAction( title: "Thanks!", style: .default ) { _ in
                MPTracker.enableNotifications()
                self.tryDecisions()
            } )
            self.window?.rootViewController?.present( controller, animated: true )
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        guard let viewController = app.keyWindow?.rootViewController
        else { return false }

        if let components = URLComponents( url: url, resolvingAgainstBaseURL: false ),
           components.scheme == "spectre" {
            // spectre:import?data=<export>
            if components.path == "import" {
                guard let data = components.queryItems?.first( where: { $0.name == "data" } )?.value?.data( using: .utf8 )
                else {
                    wrn( "Import URL missing data parameter: %@", url )
                    return false
                }

                MPMarshal.shared.import( data: data, viewController: viewController ).then {
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
                AppStore.shared.present( appleID: id, in: viewController )
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
                            MPAlert( title: "Your \(productName) app is up-to-date!", message: result.buildVersion,
                                     details: "build[\(result.buildVersion)] > store[\(result.storeVersion)]" )
                                    .show()
                        }
                        else {
                            inf( "%@ is outdated: build[%@] < store[%@]", productName, result.buildVersion, result.storeVersion )
                            AppStore.shared.present( in: viewController )
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
                let utis = utisValue as? Array<String> {
            for format in MPMarshalFormat.allCases {
                if let uti = format.uti, utis.contains( uti ) {
                    URLSession.required.dataTask( with: url, completionHandler: { (data, response, error) in
                        if let data = data, error == nil {
                            MPMarshal.shared.import( data: data, viewController: viewController ).then {
                                if case .failure(let error) = $0 {
                                    mperror( title: "Couldn't import user", error: error )
                                }
                            }
                        }
                        else {
                            mperror( title: "Couldn't open document", details: url, error: error )
                        }
                    } ).resume()
                    return true
                }
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
