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
class MPAppDelegate: UIResponder, UIApplicationDelegate, MPConfigObserver {

    lazy var window: UIWindow? = UIWindow()

    // MARK: --- Life ---
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MPLogSink.shared.register()
        MPTracker.shared.startup()

        self.window?.tintColor = appConfig.theme.color.tint.get()
        self.window?.rootViewController = MPNavigationController( rootViewController: MPUsersViewController() )
        self.window?.makeKeyAndVisible()

        Freshchat.sharedInstance().initWith(
                FreshchatConfig( appID: "***REMOVED***", andAppKey: "" ) )

        appConfig.observers.register( observer: self )

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        dbg( "opening: %@, options: %@", url, options )
        if let utisValue = UTTypeCreateAllIdentifiersForTag(
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

    // MARK: --- MPConfigObserver ---

    func didChangeConfig() {
        DispatchQueue.main.perform {
            self.window?.tintColor = appConfig.theme.color.tint.get()
        }
    }
}
