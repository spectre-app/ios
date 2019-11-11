//
// Created by Maarten Billemont on 2019-08-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPBackgroundView: UIView {
    private var gradientColor: CGGradient?
    private var gradientPoint  = CGPoint()
    private var gradientRadius = CGFloat( 0 )

    override func layoutSubviews() {
        super.layoutSubviews()

        self.gradientPoint = self.bounds.top
        self.gradientRadius = max( self.bounds.size.width, self.bounds.size.height )
        self.setNeedsDisplay()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        self.backgroundColor = appConfig.theme.color.backdrop.get()
        self.gradientColor = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            self.tintColor.withAlphaComponent( 0.618 ).cgColor,
            self.tintColor.withAlphaComponent( 1 ).cgColor,
        ] as CFArray, locations: nil )
        self.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let gradientColor = self.gradientColor
        else { return }

        UIGraphicsGetCurrentContext()?.drawRadialGradient(
                gradientColor, startCenter: self.gradientPoint, startRadius: 0,
                endCenter: self.gradientPoint, endRadius: self.gradientRadius, options: .drawsAfterEndLocation )
    }
}
