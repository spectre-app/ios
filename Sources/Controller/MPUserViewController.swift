//
// Created by Maarten Billemont on 2019-06-28.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPUserViewController: UIViewController, MPUserObserver {
    var user: MPUser {
        willSet {
            if (newValue !== self.user) {
                self.user.observers.unregister( observer: self )
            }
        }
        didSet {
            if (oldValue !== self.user) {
                self.user.observers.register( observer: self )
            }
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser) {
        self.user = user
        defer {
            // didSet
            self.user.observers.register( observer: self )
            self.user = user
        }
        super.init( nibName: nil, bundle: nil )
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        if user == self.user, let navigationController = self.navigationController {
            navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
        }
    }
}
