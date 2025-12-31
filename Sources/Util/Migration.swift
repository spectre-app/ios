//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Countly
import Foundation

class Migration {
    static let shared = Migration()

    var migrationBuild: String {
        get { UserDefaults.shared.string(forKey: #function) ?? "" }
        set { UserDefaults.shared.set(newValue, forKey: #function) }
    }

    func perform() {
        let migrationBuild = self.migrationBuild
        if migrationBuild.isVersionOutdated(by: "30") {
            // Countly API keys have changed.
            Countly.sharedInstance().flushQueues()
        }

        self.migrationBuild = productBuild
    }
}
