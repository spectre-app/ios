//
// Created by Maarten Billemont on 2019-10-30.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPViewController: UIViewController {
    var screen: MPTracker.Screen? {
        willSet {
            self.screen?.dismiss()
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( nibName: nil, bundle: nil )
    }

    override func viewWillAppear(_ animated: Bool) {
        self.screen = MPTracker.shared.screen( named: type( of: self ).description() )

        super.viewWillAppear( animated )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear( animated )

        self.screen = nil
    }
}
