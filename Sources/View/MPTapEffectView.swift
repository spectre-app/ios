//
// Created by Maarten Billemont on 2019-04-27.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPTapEffectView: UIView {
    private let host: UIView
    private lazy var flareView = FlareView( for: self.host )

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(for host: UIView) {
        self.host = host
        super.init( frame: .zero )

        self.isHidden = true
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.flareView.frame = self.bounds
        self.flareView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
        self.addSubview( self.flareView )

        var effectContainer: UIView = self.host, hostContainer: UIView = self.host
        while let next = effectContainer.next as? UIView {
            hostContainer = effectContainer
            effectContainer = next
        }

        effectContainer.insertSubview( self, aboveSubview: hostContainer )
        ViewConfiguration( view: self )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.host.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.host.centerYAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( greaterThanOrEqualTo: $0.widthAnchor, multiplier: 1 / 2 ) }
                .constrainTo { $1.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor, multiplier: 1 / 2 ) }
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .activate()
    }

    public func run() {
        if let hostSnapshot = self.host.snapshotView( afterScreenUpdates: false ) {
            self.addSubview( hostSnapshot )
            hostSnapshot.center = CGRectGetCenter( self.bounds )
        }

        self.flareView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
        UIView.animate( withDuration: 0.618, animations: {
            self.flareView.transform = CGAffineTransform( scaleX: 4, y: 4 )
            self.alpha = 0
        }, completion: { finished in
            self.removeFromSuperview()
        } )
        self.isHidden = false
    }

    private class FlareView: UIView {
        private let host: UIView

        init(for host: UIView) {
            self.host = host
            super.init( frame: .zero )
            self.backgroundColor = .clear
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func draw(_ rect: CGRect) {
            if let context = UIGraphicsGetCurrentContext() {
                let hostSize = max( self.host.bounds.size.width, self.host.bounds.size.height ) / 4
                let lineSize = self.bounds.size.width / 2 - hostSize / 2
                context.setStrokeColor( self.tintColor.withAlphaComponent( 0.618 ).cgColor )
                context.setLineWidth( lineSize )
                context.strokeEllipse( in: CGRectFromCenterWithSize(
                        CGRectGetCenter( self.bounds ), CGSize( width: lineSize + hostSize, height: lineSize + hostSize ) ) )
            }
        }
    }
}