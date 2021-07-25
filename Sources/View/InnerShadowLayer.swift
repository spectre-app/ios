//
// Created by Maarten Billemont on 2021-07-24.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import UIKit

class InnerShadowLayer: CALayer {
    required init?(coder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(layer: Any) {
        super.init( layer: layer )
    }

    override init() {
        super.init()

        self => \.shadowColor => Theme.current.color.shadow
        self.shadowRadius = 4
        self.shadowOpacity = .short
        self.shadowOffset = .zero
        self.masksToBounds = true
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        if self.bounds.isEmpty {
            self.shadowPath = nil
        }
        else {
            let shadowPath = UIBezierPath( roundedRect: self.bounds.insetBy( dx: self.shadowRadius, dy: self.shadowRadius ),
                                           cornerRadius: self.cornerRadius ).reversing()
            shadowPath.append( UIBezierPath( roundedRect: self.bounds.insetBy( dx: -self.shadowRadius, dy: -self.shadowRadius ),
                                             cornerRadius: self.cornerRadius ) )
            self.shadowPath = shadowPath.cgPath
        }
    }
}
