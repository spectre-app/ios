// =============================================================================
// Created by Maarten Billemont on 2019-08-08.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

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
                    self.didChange( theme: Theme.current )

                case .backdrop:
                    self => \.backgroundColor => Theme.current.color.backdrop

                case .panel:
                    self => \.backgroundColor => Theme.current.color.panel

                case .tint:
                    self.tintColorDidChange()

                case .custom:
                    self.didChange( theme: Theme.current )
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

    lazy var imageView = using(UIImageView()) {
        $0.contentMode = .scaleAspectFill
        $0.layer.compositingFilter = "luminosityBlendMode"
        $0.layer.mask = self.imageMask
        self.imageViewObservation = $0.observe( \.bounds ) {
            $0.layer.mask?.frame = $1.newValue ?? .zero
        }

        self.imageTint.addSubview( $0 )

        LayoutConfiguration( view: $0 )
            .constrain( as: .box ).activate()
    }
    private lazy var imageTint = using(UIView()) {
        self.imageTintObservation = self.observe( \.backgroundColor ) { [imageTint = $0] in
            imageTint.backgroundColor = ($1.newValue ?? nil).flatMap { $0.alpha == .on ? $0.with( alpha: .long ) : .clear }
        }

        self.addSubview( $0 )

        LayoutConfiguration( view: $0 )
            .constrain( as: .topBox )
            .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
            .constrain { $1.heightAnchor.constraint( equalTo: $1.widthAnchor, multiplier: .long ).with( priority: .defaultHigh + 1 ) }
            .activate()
    }
    private lazy var imageMask      = using(CAGradientLayer()) {
        $0.needsDisplayOnBoundsChange = true
        $0.colors = [
            UIColor.black.with( alpha: .short * .short ).cgColor,
            UIColor.black.with( alpha: .short * .short * .short ).cgColor,
            UIColor.black.with( alpha: .off ).cgColor,
        ]
    }

    private var gradientColor:        CGGradient? {
        didSet {
            if oldValue != self.gradientColor {
                self.setNeedsDisplay()
            }
        }
    }
    private lazy var gradientPoint  = CGPoint() {
        didSet {
            if oldValue != self.gradientPoint {
                self.setNeedsDisplay()
            }
        }
    }
    private lazy var gradientRadius = CGFloat( 0 ) {
        didSet {
            if oldValue != self.gradientRadius {
                self.setNeedsDisplay()
            }
        }
    }
    private var imageViewObservation: NSKeyValueObservation?
    private var imageTintObservation: NSKeyValueObservation?

    // MARK: - Life

    init(mode: Mode = .panel) {
        super.init( frame: .zero )

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

    // MARK: - ThemeObserver

    func didChange(theme: Theme) {
        if case .gradient = self.mode {
            self.gradientColor = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: [ Theme.current.color.panel.get(), Theme.current.color.backdrop.get() ] as CFArray,
                                             locations: nil )
        }
        else if case .custom(let color) = self.mode {
            self.backgroundColor = color()
        }
    }

    // MARK: - Types

    enum Mode {
        case clear, gradient, backdrop, panel, tint, custom(color: () -> UIColor?)
    }
}
