//
// Created by Maarten Billemont on 2019-04-27.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPTapEffectView: UIView {
    private lazy var flareView = FlareView()

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( frame: .zero )

        self.isHidden = true
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.flareView.frame = self.bounds
        self.flareView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
        self.addSubview( self.flareView )
    }

    public func run(for host: UIView) {
        UIView.performWithoutAnimation {
            self.flareView.host = host

            var effectContainer: UIView = host, hostContainer: UIView = host
            while let next = effectContainer.next as? UIView {
                hostContainer = effectContainer
                effectContainer = next
            }

            effectContainer.insertSubview( self, aboveSubview: hostContainer )
            LayoutConfiguration( view: self )
                    .constrainTo { $1.centerXAnchor.constraint( equalTo: host.centerXAnchor ) }
                    .constrainTo { $1.centerYAnchor.constraint( equalTo: host.centerYAnchor ) }
                    .constrainTo { $1.widthAnchor.constraint( greaterThanOrEqualTo: $0.widthAnchor, multiplier: 1 / 2 ) }
                    .constrainTo { $1.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor, multiplier: 1 / 2 ) }
                    .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                    .activate()

            if let hostSnapshot = host.snapshotView( afterScreenUpdates: false ) {
                self.addSubview( hostSnapshot )
                hostSnapshot.center = self.bounds.center
            }

            self.flareView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
            self.flareView.layoutIfNeeded()
        }

        UIView.animate( withDuration: .long, animations: {
            self.flareView.transform = CGAffineTransform( scaleX: 4, y: 4 )
            self.alpha = 0
        }, completion: { finished in
            self.removeFromSuperview()
        } )

        self.isHidden = false

        MPFeedback.shared.play( .activate )
    }

    private class FlareView: UIView {
        var host: UIView?

        init() {
            super.init( frame: .zero )
            self.backgroundColor = .clear
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func draw(_ rect: CGRect) {
            if let context = UIGraphicsGetCurrentContext(), let host = self.host {
                let hostSize = max( host.bounds.size.width, host.bounds.size.height ) / 4
                let lineSize = self.bounds.size.width / 2 - hostSize / 2
                context.setStrokeColor( self.tintColor.withAlphaComponent( .long ).cgColor )
                context.setLineWidth( lineSize )
                context.strokeEllipse( in: CGRect(
                        center: self.bounds.center,
                        size: CGSize( width: lineSize + hostSize, height: lineSize + hostSize ) ) )
            }
        }
    }
}
