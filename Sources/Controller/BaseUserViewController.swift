//==============================================================================
// Created by Maarten Billemont on 2019-06-28.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

class BaseUserViewController: BaseViewController, UserObserver {
    var user: User? {
        willSet {
            self.user?.observers.unregister( observer: self )
        }
        didSet {
            self.user?.observers.register( observer: self )
            self.validate()
        }
    }

    private var backgroundTime: Date?

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: User) {
        super.init()

        defer {
            self.user = user
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.validate()

        self.view.isHidden = false
    }

    override func willResignActive() {
        super.willResignActive()

        self.user?.save( onlyIfDirty: true, await: true )
    }

    override func didEnterBackground() {
        super.didEnterBackground()

        self.view.isHidden = true

        self.backgroundTime = Date()
    }

    override func willEnterForeground() {
        super.willEnterForeground()

        self.view.isHidden = false

        if let backgroundTime = self.backgroundTime,
           Date().timeIntervalSince( backgroundTime ) > .minutes( 3 ) {
            self.user?.logout()
        }
        self.backgroundTime = nil
    }

    // MARK: --- UserObserver ---

    func didLogout(user: User) {
        self.validate()
    }

    // MARK: --- Private ---

    private func validate() {
        if self.user?.userKeyFactory == nil {
            DispatchQueue.main.perform {
                if let navigationController = self.navigationController {
                    trc( "Dismissing %@ since user logged out.", Self.self )
                    navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
                }
            }
        }
    }
}
