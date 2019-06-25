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

    let window: UIWindow = UIWindow()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        PearlLogger.get().printLevel = .debug

        // Start UI
        self.window.rootViewController = MPNavigationController( rootViewController: MPUsersViewController() )
        self.window.makeKeyAndVisible()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        if let utisValue = UTTypeCreateAllIdentifiersForTag(
                kUTTagClassFilenameExtension, url.pathExtension as CFString, nil )?.takeRetainedValue(),
           let utis = utisValue as? Array<String> {
            for format in MPMarshalFormat.allCases {
                if let uti = format.uti, utis.contains( uti ) {
                    URLSession.shared.dataTask( with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                        if let data = data, error == nil {
                            MPMarshal.shared.import( data: data )
                        }
                        else {
                            // TODO: error handling
                            mperror( title: "Couldn't open document", context: url.lastPathComponent, error: error )
                        }
                    } ).resume()
                    return true
                }
            }
        }

        return false
    }
}
