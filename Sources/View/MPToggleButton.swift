//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPToggleButton: UIButton {
    private let checkLabel = UILabel()

    override var isSelected: Bool {
        didSet {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: 0.382 ) {
                    self.imageView?.alpha = self.isSelected ? 1: 0.318
                    self.checkLabel.alpha = self.isSelected ? 1: 0
                }
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.contentEdgeInsets = UIEdgeInsets( top: 10, left: 10, bottom: 10, right: 10 )
        self.layoutMargins = self.contentEdgeInsets
        self.layer.needsDisplayOnBoundsChange = true

        self.checkLabel.adjustsFontSizeToFitWidth = true
        self.checkLabel.font = MPTheme.global.font.callout.get()
        self.checkLabel.textColor = MPTheme.global.color.body.get()
        self.checkLabel.textAlignment = .center
        self.checkLabel.text = "✓"

        self.addSubview( self.checkLabel )

        self.widthAnchor.constraint( equalTo: self.heightAnchor ).activate()
        self.widthAnchor.constraint( equalToConstant: 70 ).withPriority( .defaultHigh ).activate()

        LayoutConfiguration( view: self.checkLabel )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        defer {
            UIView.performWithoutAnimation {
                self.isSelected = false
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.imageView?.alpha = self.isSelected ? 1: 0.318
    }

    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext(),
           let background = MPTheme.global.color.glow.get()?.withAlphaComponent( 0.382 ).cgColor,
           let border = MPTheme.global.color.body.get()?.cgColor {
            let content = self.bounds.inset( by: self.contentEdgeInsets )
                                     .insetBy( dx: 1 / self.contentScaleFactor, dy: 1 / self.contentScaleFactor )
            let circle  = CGRect( center: content.bottom, radius: self.contentEdgeInsets.bottom )
            context.addRect( self.bounds )
            context.addPath( CGPath( ellipseIn: circle, transform: nil ) )
            context.clip( using: .evenOdd )
            context.setFillColor( background )
            context.setStrokeColor( border )
            context.setLineWidth( 2 )
            context.fillEllipse( in: content )
            context.strokeEllipse( in: content )
            context.resetClip()
            context.setLineWidth( 1 )
            context.strokeEllipse( in: circle )
        }
    }
}
