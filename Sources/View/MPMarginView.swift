//
// Created by Maarten Billemont on 2019-10-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPMarginView: UIView {
    init(for view: UIView, margins: UIEdgeInsets? = nil) {
        super.init( frame: .zero )

        if let margins = margins {
            self.layoutMargins = margins
        }

        self.addSubview( view )
        LayoutConfiguration( view: view )
                .constrain( margins: true )
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }
}
