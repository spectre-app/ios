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
            if let user = self.user, user.userKeyFactory != nil {
                user.observers.register( observer: self )
            }
            else {
                DispatchQueue.main.perform {
                    if let navigationController = self.navigationController {
                        trc( "Dismissing %@ since user logged out.", Self.self )
                        navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
                    }
                }
            }
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

        self.view.isHidden = false

        // TODO: is this still necessary?
        if let user = self.user, user.userKeyFactory == nil {
            mperror( title: "User logged out", message: "User is no longer authenticated", details: user )
            self.didLogout( user: user )
            return
        }
    }

    override func willResignActive() {
        super.willResignActive()

        self.user?.save( await: true ).failure { error in
            mperror( title: "Couldn't save user", error: error )
        }
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
        if self.user == user {
            self.user = nil
        }
    }
}
