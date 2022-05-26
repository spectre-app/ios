//
// Created by Maarten Billemont on 2022-05-25.
// Copyright (c) 2022 Lyndir. All rights reserved.
//

import UIKit

class BaseView: UIView {
    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )
        LeakRegistry.shared.register( self )
        self.loadView()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    internal func loadView() {}
}
