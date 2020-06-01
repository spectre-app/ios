//
//  MPAppDelegate.swift
//  MasterPassword
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import CoreServices

@UIApplicationMain
class MPAppDelegate: UIResponder, UIApplicationDelegate {

    lazy var window: UIWindow? = UIWindow()

    // MARK: --- Life ---
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MPLogSink.shared.register()
        MPTracker.shared.startup()

        self.window! & \.tintColor <- Theme.current.color.tint
        self.window!.rootViewController = MPNavigationController( rootViewController: MPUsersViewController() )
        self.window!.makeKeyAndVisible()

        Freshchat.sharedInstance().initWith(
                FreshchatConfig( appID: "***REMOVED***", andAppKey: decrypt( secret: freshchatKey ) ) )

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.tryDecisions()

        return true
    }

    func tryDecisions() {

        // Diagnostics decision
        if !appConfig.diagnosticsDecided {
            let controller = UIAlertController( title: "Welcome to \(productName)!", message:
            """
            We want this to be a top-notch experience for you.
            Diagnostics helps ensure us your app performs ideally and adds 1 to our count of active users.

            We look out for application bugs, issues, crashes & usage counters.
            Needless to say, no personal details or secrets ever leave your device.
            """, preferredStyle: .actionSheet )
            controller.addAction( UIAlertAction( title: "Disable", style: .cancel ) { _ in
                appConfig.diagnostics = false
                appConfig.diagnosticsDecided = true
                self.tryDecisions()
            } )
            controller.addAction( UIAlertAction( title: "Thanks!", style: .default ) { _ in
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
            Things move fast in the online world.
            To help keep you safe from password breaches and current on important security events, we inform our users through notifications.

            Enable notifications to be informed of these important events.
            """, preferredStyle: .actionSheet )
            controller.addAction( UIAlertAction( title: "Thanks!", style: .default ) { _ in
                MPTracker.enableNotifications()
                self.tryDecisions()
            } )
            self.window?.rootViewController?.present( controller, animated: true )
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        dbg( "opening: %@, options: %@", url, options )
        if let components = URLComponents( url: url, resolvingAgainstBaseURL: false ),
           components.scheme == "volto", components.path == "import" {
            if let data = components.queryItems?.first( where: { $0.name == "data" } )?.value?.data( using: .utf8 ) {
                MPMarshal.shared.import( data: data )
            }
        }
        else if let utisValue = UTTypeCreateAllIdentifiersForTag(
                kUTTagClassFilenameExtension, url.pathExtension as CFString, nil )?.takeRetainedValue(),
                let utis = utisValue as? Array<String> {
            for format in MPMarshalFormat.allCases {
                if let uti = format.uti, utis.contains( uti ) {
                    dbg( "connecting to: %@", url )
                    MPURLUtils.session.dataTask( with: url, completionHandler: { (data, response, error) in
                        dbg( "connected to: %@, response: %@, error: %@", url, response, error )
                        if let data = data, error == nil {
                            MPMarshal.shared.import( data: data )
                        }
                        else {
                            mperror( title: "Couldn't open document", details: url.lastPathComponent, error: error )
                        }
                    } ).resume()
                    return true
                }
            }
        }

        return false
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        err( "Couldn't register for remote notifications. [>TRC]" )
        trc( "[>] %@", error )
    }

    // MARK: --- MPConfigObserver ---
}
