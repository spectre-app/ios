//
// Created by Maarten Billemont on 2019-06-28.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPUserViewController: MPViewController, MPUserObserver {
    var user: MPUser {
        willSet {
            self.user.observers.unregister( observer: self )
        }
        didSet {
            self.user.observers.register( observer: self )
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser) {
        self.user = user
        super.init()

        defer {
            self.user = user
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        if self.user.masterKeyFactory == nil {
            mperror( title: "User logged out", message: "User is no longer authenticated", details: self.user )
            self.userDidLogout( self.user )
        }
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        DispatchQueue.main.perform {
            if user == self.user, let navigationController = self.navigationController {
                trc( "Dismissing \(type(of: self)) since user logged out." )
                navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
            }
        }
    }
}
