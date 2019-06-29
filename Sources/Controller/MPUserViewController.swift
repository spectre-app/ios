//
// Created by Maarten Billemont on 2019-06-28.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPUserViewController: UIViewController, MPUserObserver {
    var user: MPUser? {
        willSet {
            if (newValue !== self.user) {
                self.user?.observers.unregister( observer: self )
            }
        }
        didSet {
            if (oldValue !== self.user) {
                self.user?.observers.register( observer: self )
            }

            DispatchQueue.main.perform {
                self.viewIfLoaded?.tintColor = MPTheme.global.color.password.tint( self.user?.identicon.uiColor() )
            }
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser?) {
        super.init( nibName: nil, bundle: nil )

        defer {
            self.user = user
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.tintColor = MPTheme.global.color.password.tint( self.user?.identicon.uiColor() )
    }

    // MARK: --- MPUserObserver ---

    func userDidLogout(_ user: MPUser) {
        if user == self.user, let navigationController = self.navigationController {
            navigationController.setViewControllers( navigationController.viewControllers.filter { $0 !== self }, animated: true )
        }
    }
}
