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
        button.contentEdgeInsets = UIEdgeInsets( top: 4, left: 4, bottom: 4, right: 4 )
        button.addTarget( self, action: #selector( buttonAction ), for: .touchUpInside )

        self.button = button
        self.round = true
    }

    init(subview: UIView) {
        super.init( frame: .zero )

        self.layoutMargins = .zero
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
        ViewConfiguration( view: subview )
                .constrainTo { self.layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .constrainTo { self.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { self.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .constrainTo { self.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()
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
                    .constrainTo { self.host.centerXAnchor.constraint( equalTo: $1.centerXAnchor ) }
                    .constrainTo { self.host.centerYAnchor.constraint( equalTo: $1.centerYAnchor ) }
                    .constrainTo { $0.widthAnchor.constraint( lessThanOrEqualTo: $1.widthAnchor, multiplier: 2 ) }
                    .constrainTo { $0.heightAnchor.constraint( lessThanOrEqualTo: $1.heightAnchor, multiplier: 2 ) }
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
