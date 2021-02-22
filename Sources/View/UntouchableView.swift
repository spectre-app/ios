//
// Created by Maarten Billemont on 2019-05-27.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class UntouchableView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest( point, with: event )
        return hitView == self ? nil: hitView
    }
}
