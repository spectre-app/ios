//
// Created by Maarten Billemont on 2019-03-31.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPToggleButton: UIButton, ThemeObserver {
    private let checkLabel = MPTintLabel()

    var tapEffect = true
    var identifier: String?
    override var isSelected: Bool {
        didSet {
            DispatchQueue.main.perform {
                UIView.animate( withDuration: .short ) {
                    self.imageView?.alpha = self.isSelected ? 1: .short
                    self.checkLabel.alpha = self.isSelected ? 1: 0
                }
            }
        }
    }
    override var isEnabled:  Bool {
        didSet {
            self.tintAdjustmentMode = self.isEnabled ? .automatic: .dimmed
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(identifier: String? = nil) {
        self.identifier = identifier
        super.init( frame: .zero )
        self.addTarget( self, action: #selector( action(_:) ), for: .primaryActionTriggered )

        self.contentEdgeInsets = UIEdgeInsets( top: 10, left: 10, bottom: 10, right: 10 )
        self.layoutMargins = self.contentEdgeInsets
        self.layer.needsDisplayOnBoundsChange = true

        self.checkLabel => \.font => Theme.current.font.callout
        self.checkLabel.textAlignment = .center
        self.checkLabel.text = "✓"

        self.addSubview( self.checkLabel )

        self.widthAnchor.constraint( equalTo: self.heightAnchor ).isActive = true
        self.widthAnchor.constraint( equalToConstant: 70 ).with( priority: .defaultHigh ).isActive = true

        LayoutConfiguration( view: self.checkLabel )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        defer {
            self.isSelected = false
        }
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove( toSuperview: newSuperview )

        if newSuperview != nil {
            Theme.current.observers.register( observer: self )
        }
        else {
            Theme.current.observers.unregister( observer: self )
        }
    }

    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext(),
           let borderColor: CGColor = Theme.current.color.body.get(),
           let backgroundColor: CGColor = Theme.current.color.mute.get() {

            let content = self.bounds.inset( by: self.contentEdgeInsets )
                                     .insetBy( dx: 1 / self.contentScaleFactor, dy: 1 / self.contentScaleFactor )
            let circle  = CGRect( center: content.bottom, radius: self.contentEdgeInsets.bottom )

            context.addRect( self.bounds )
            context.addPath( CGPath( ellipseIn: circle, transform: nil ) )
            context.clip( using: .evenOdd )

            context.setFillColor( backgroundColor )
            context.fillEllipse( in: content )

            context.setLineWidth( 1 )
            context.setStrokeColor( borderColor )
            context.strokeEllipse( in: content )

            context.resetClip()
            context.setLineWidth( self.isSelected ? 1.5: 1 )
            context.strokeEllipse( in: circle )
        }
    }

    @objc
    func action(_ event: UIEvent) {
        self.isSelected = !self.isSelected
        self.track()

        if self.tapEffect {
            MPTapEffectView().run( for: self )
        }

        MPFeedback.shared.play( .trigger )
    }

    func track() {
        if let identifier = self.identifier {
            MPTracker.shared.event( named: identifier, [ "value": self.isSelected ] )
        }
    }

    // MARK: --- ThemeObserver ---

    func didChangeTheme() {
        self.setNeedsDisplay()
    }
}
