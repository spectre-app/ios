//
//  MPAppDelegate.swift
//  MasterPassword
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import CoreServices
import Network

@UIApplicationMain
class MPAppDelegate: UIResponder, UIApplicationDelegate {

    lazy var window: UIWindow? = UIWindow()

    // MARK: --- Life ---
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

        if let freshchatKey = freshchatKey.b64Decrypt() {
            Freshchat.sharedInstance().initWith(
                    FreshchatConfig( appID: "***REMOVED***", andAppKey: freshchatKey ) )
        }

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.tryDecisions()

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
            controller.addAction( UIAlertAction( title: "Thanks!", style: .default ) { _ in
                MPTracker.enableNotifications()
                self.tryDecisions()
            } )
            self.window?.rootViewController?.present( controller, animated: true )
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        let viewController = (app.keyWindow?.rootViewController)!

        if let components = URLComponents( url: url, resolvingAgainstBaseURL: false ),
           components.scheme == "spectre", components.path == "import" {
            if let data = components.queryItems?.first( where: { $0.name == "data" } )?.value?.data( using: .utf8 ) {
                MPMarshal.shared.import( data: data, viewController: viewController ).then {
                    if case .failure(let error) = $0 {
                        mperror( title: "Couldn't import user", error: error )
                    }
                }
                return true
            }

            wrn( "Import URL missing data parameter: %@", url )
        }
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
        err( "Couldn't register for remote notifications. [>TRC]" )
        pii( "[>] %@", error )
    }

    // MARK: --- MPConfigObserver ---
}
