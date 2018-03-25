//
//  MPAppDelegate.swift
//  MasterPassword
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

@UIApplicationMain
class MPAppDelegate: UIResponder, UIApplicationDelegate {

    let window: UIWindow = UIWindow()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        PearlLogger.get().printLevel = .trace

        // Start UI
        self.window.rootViewController = MPNavigationController( rootViewController: MPSitesViewController() )
        self.window.makeKeyAndVisible()

        return true
    }
}
