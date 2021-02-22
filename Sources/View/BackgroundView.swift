//
// Created by Maarten Billemont on 2019-08-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class BackgroundView: UIView, ThemeObserver {
    var mode = Mode.backdrop {
        willSet {
            (self => \.backgroundColor).unbind()
            self.gradientColor = nil
            self.isOpaque = true
        }
        didSet {
            switch self.mode {
                case .clear:
                    self.backgroundColor = .clear
                    self.isOpaque = false

                case .gradient:
                    self.didChangeTheme()

                case .backdrop:
                    self => \.backgroundColor => Theme.current.color.backdrop

                case .panel:
                    self => \.backgroundColor => Theme.current.color.panel

                case .tint:
                    self.tintColorDidChange()

                case .custom(let color):
                    self.backgroundColor = color
            }
        }
    }
    var imageColor: UIColor? {
        get {
            self.imageView.backgroundColor
        }
        set {
            self.imageView.backgroundColor = newValue
        }
    }
    var image:      UIImage? {
        get {
            self.imageView.image
        }
        set {
            self.imageView.image = newValue
        }
    }

    let imageView = UIImageView()
    let imageTint = UIView()
    override var backgroundColor: UIColor? {
        didSet {
            self.imageTint.backgroundColor = self.backgroundColor.flatMap { $0.alpha == .on ? $0.with( alpha: .long ): .clear }
        }
    }
    private var imageMask      = CAGradientLayer()
    private var gradientColor:        CGGradient? {
        didSet {
            if oldValue != self.gradientColor {
                self.setNeedsDisplay()
            }
        }
    }
    private var gradientPoint  = CGPoint() {
        didSet {
            if oldValue != self.gradientPoint {
                self.setNeedsDisplay()
            }
        }
    }
    private var gradientRadius = CGFloat( 0 ) {
        didSet {
            if oldValue != self.gradientRadius {
                self.setNeedsDisplay()
            }
        }
    }
    private var imageViewObservation: NSKeyValueObservation?

    // MARK: --- Life ---

    init(mode: Mode = .panel) {
        super.init( frame: .zero )

        // - View
        self.imageView.contentMode = .scaleAspectFill
        self.imageView.layer.compositingFilter = "luminosityBlendMode"
        self.imageView.layer.mask = self.imageMask
        self.imageMask.needsDisplayOnBoundsChange = true
        self.imageMask.colors = [
            UIColor.black.with( alpha: .long ).cgColor,
            UIColor.black.with( alpha: .short ).cgColor,
            UIColor.black.with( alpha: .short * .short ).cgColor,
            UIColor.clear.cgColor ]
        self.imageViewObservation = self.imageView.observe( \.bounds ) { [unowned self] _, _ in
            self.imageMask.frame = self.imageView.bounds
        }

        // - Hierarchy
        self.addSubview( self.imageTint )
        self.imageTint.addSubview( self.imageView )

        // - Layout
        LayoutConfiguration( view: self.imageView )
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.imageTint )
                .constrain( as: .topBox )
                .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrain { $1.heightAnchor.constraint( equalToConstant: 200 ).with( priority: .defaultHigh ) }
                .compressionResistance( horizontal: .fittingSizeLevel, vertical: .fittingSizeLevel )
                .activate()

        defer {
            self.mode = mode
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if newWindow != nil {
            Theme.current.observers.register( observer: self )
        }
        else {
            Theme.current.observers.unregister( observer: self )
        }
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        if case .tint = self.mode {
            self.backgroundColor = self.tintColor
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if case .gradient = self.mode {
            self.gradientPoint = self.bounds.top
            self.gradientRadius = max( self.bounds.size.width, self.bounds.size.height )
        }
    }

    override func draw(_ rect: CGRect) {
        if let gradientColor = self.gradientColor {
            UIGraphicsGetCurrentContext()?.drawRadialGradient(
                    gradientColor, startCenter: self.gradientPoint, startRadius: 0,
                    endCenter: self.gradientPoint, endRadius: self.gradientRadius, options: .drawsAfterEndLocation )
        }
    }

    // MARK: --- ThemeObserver ---

    func didChangeTheme() {
        if case .gradient = self.mode {
            self.gradientColor = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                Theme.current.color.panel.get(), Theme.current.color.backdrop.get(),
            ] as CFArray, locations: nil )
        }
    }

    // MARK: --- Types ---

    enum Mode {
        case clear, gradient, backdrop, panel, tint, custom(color: UIColor?)
    }
}
