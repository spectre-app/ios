//
// Created by Maarten Billemont on 2019-05-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension UIView {
    func shake() {
        UIView.animateKeyframes( withDuration: 0.618, delay: 0, animations: {
            UIView.addKeyframe( withRelativeStartTime: 0, relativeDuration: 0.25 ) {
                self.transform = CGAffineTransform( translationX: -8, y: 0 )
            }
            UIView.addKeyframe( withRelativeStartTime: 0.25, relativeDuration: 0.5 ) {
                self.transform = CGAffineTransform( translationX: 8, y: 0 )
            }
            UIView.addKeyframe( withRelativeStartTime: 0.5, relativeDuration: 0.75 ) {
                self.transform = CGAffineTransform( translationX: -8, y: 0 )
            }
            UIView.addKeyframe( withRelativeStartTime: 0.75, relativeDuration: 1 ) {
                self.transform = .identity
            }
        } )
    }
}
