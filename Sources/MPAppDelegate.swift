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

        // Dummy user
        let maarten = MPUser( named: "Maarten Billemont", avatar: .avatar_3 )
        let robert  = MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 )
        robert.sites.append( contentsOf: [
            MPSite( user: robert, named: "apple.com", uses: 5, lastUsed: Date().addingTimeInterval( -1000 ) ),
            MPSite( user: robert, named: "google.com", uses: 20, lastUsed: Date().addingTimeInterval( -2000 ) ),
            MPSite( user: robert, named: "twitter.com", uses: 3, lastUsed: Date().addingTimeInterval( -5000 ) ),
            MPSite( user: robert, named: "reddit.com", uses: 8, lastUsed: Date().addingTimeInterval( -10000 ) ),
            MPSite( user: robert, named: "pinterest.com", uses: 7, lastUsed: Date().addingTimeInterval( -12000 ) ),
            MPSite( user: robert, named: "whatsapp.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "ivpn.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "amazon.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "matrix.org", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "spotify.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "netflix.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "uber.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "battle.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "gandi.net", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "ebay.com", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
            MPSite( user: robert, named: "last.fm", uses: 5, lastUsed: Date().addingTimeInterval( -13000 ) ),
        ] )
        robert.masterKey = mpw_masterKey( robert.fullName, "test", robert.algorithm )

        // Start UI
        self.window.rootViewController = MPNavigationController(
                rootViewController: MPUsersViewController( users: [ maarten, robert ] )
//                rootViewController: MPSitesViewController( user: robert )
        )
        self.window.makeKeyAndVisible()

        return true
    }
}
