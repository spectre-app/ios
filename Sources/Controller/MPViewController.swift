//
// Created by Maarten Billemont on 2019-10-30.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPViewController: UIViewController {

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( nibName: nil, bundle: nil )
    }

    override func viewWillAppear(_ animated: Bool) {
        trc( "> %@", type( of: self ) )
        super.viewWillAppear( animated )
    }

    override func viewWillDisappear(_ animated: Bool) {
        trc( "< %@", type( of: self ) )
        super.viewWillDisappear( animated )
    }
}
