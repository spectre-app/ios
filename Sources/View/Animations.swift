//
// Created by Maarten Billemont on 2019-05-12.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension UIView {
    func shake() {
        UIView.animateKeyframes( withDuration: .long, delay: .immediate, animations: {
            UIView.addKeyframe( withRelativeStartTime: .milliseconds( 0 ), relativeDuration: .milliseconds( 250 ) ) {
                self.transform = CGAffineTransform( translationX: -8, y: 0 )
            }
            UIView.addKeyframe( withRelativeStartTime: .milliseconds( 250 ), relativeDuration: .milliseconds( 500 ) ) {
                self.transform = CGAffineTransform( translationX: 8, y: 0 )
            }
            UIView.addKeyframe( withRelativeStartTime: .milliseconds( 500 ), relativeDuration: .milliseconds( 750 ) ) {
                self.transform = CGAffineTransform( translationX: -8, y: 0 )
            }
            UIView.addKeyframe( withRelativeStartTime: .milliseconds( 750 ), relativeDuration: .seconds( 1 ) ) {
                self.transform = .identity
            }
        } )
    }
}
