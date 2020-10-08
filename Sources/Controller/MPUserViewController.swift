//
// Created by Maarten Billemont on 2019-06-28.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPUserViewController: MPViewController, MPUserObserver {
    var user: MPUser? {
        willSet {
            self.user?.observers.unregister( observer: self )
        }
        didSet {
            if let user = self.user, user.masterKeyFactory != nil {
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

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser) {
        super.init()

        defer {
            self.user = user
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        // TODO: is this still necessary?
        if let user = self.user, user.masterKeyFactory == nil {
            mperror( title: "User logged out", message: "User is no longer authenticated", details: user )
            self.userDidLogout( user )
        }
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        if self.user == user {
            self.user = nil
        }
    }
}
