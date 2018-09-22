//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPButton: UIView {
    let effectView = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    var button: UIButton!

    override var bounds: CGRect {
        didSet {
            if self.round {
                self.effectView.layer.cornerRadius = self.bounds.size.height / 2
            }
        }
    }
    var round = false {
        didSet {
            self.bounds = self.bounds.standardized
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    convenience init(image: UIImage? = nil, title: String? = nil) {
        let button = UIButton( type: .custom )
        self.init( subview: button )

        button.setImage( image, for: .normal )
        button.setTitle( title, for: .normal )
        button.setTitleColor( .lightText, for: .normal )
        button.addTarget( self, action: #selector( buttonAction ), for: .touchUpInside )

        if title != nil {
            button.contentEdgeInsets = UIEdgeInsets( top: 4, left: 10, bottom: 4, right: 10 )
        } else {
            button.contentEdgeInsets = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
        }

        self.layoutMargins = .zero
        self.button = button
        self.round = true
    }

    init(subview: UIView) {
        super.init( frame: .zero )

        if #available( iOS 11.0, * ) {
            self.insetsLayoutMarginsFromSafeArea = false
        }

        self.layer.shadowOffset = .zero
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 0.5

        self.effectView.layer.masksToBounds = true
        self.effectView.layer.cornerRadius = 4

        self.addSubview( self.effectView )
        self.effectView.contentView.addSubview( subview )

        ViewConfiguration( view: self.effectView ).constrainToSuperview().activate()
        ViewConfiguration( view: subview ).constrain( toMarginsOf: self ).activate()
    }

    @objc
    func buttonAction() {
        EffectView( for: self.effectView ).animate()
    }

    private class EffectView: UIView {
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

        func animate() {
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
