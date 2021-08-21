//
// Created by Maarten Billemont on 2021-08-21.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import Foundation
import Countly

class Migration {
    public static let shared = Migration()

    public var migrationBuild: String {
        get {
            UserDefaults.shared.string( forKey: #function ) ?? ""
        }
        set {
            if newValue != self.migrationBuild {
                UserDefaults.shared.set( newValue, forKey: #function )
            }
        }
    }

    func perform() {
        let migrationBuild = self.migrationBuild
        if migrationBuild.isVersionOutdated( by: "30" ) {
            // Countly API keys have changed.
            Countly.sharedInstance().flushQueues()
        }

        self.migrationBuild = productBuild
    }
}
