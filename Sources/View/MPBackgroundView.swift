//
// Created by Maarten Billemont on 2019-08-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPBackgroundView: UIView, ThemeObserver {
    var mode = Mode.backdrop {
        didSet {
            switch self.mode {
                case .gradient:
                    self.gradientColor = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                        Theme.current.color.panel.get(), Theme.current.color.backdrop.get(),
                    ] as CFArray, locations: nil )

                case .backdrop:
                    self => \.backgroundColor => Theme.current.color.backdrop
                    self.gradientColor = nil

                case .panel:
                    self => \.backgroundColor => Theme.current.color.panel
                    self.gradientColor = nil

                case .tint:
                    self.backgroundColor = self.tintColor
                    self.gradientColor = nil
            }

            self.setNeedsDisplay()
        }
    }

    private var gradientColor: CGGradient?
    private var gradientPoint  = CGPoint()
    private var gradientRadius = CGFloat( 0 )

    // MARK: --- Life ---

    init(mode: Mode = .panel) {
        super.init( frame: .zero )

        defer {
            self.mode = mode
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
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

    override func layoutSubviews() {
        super.layoutSubviews()

        if case .gradient = self.mode {
            self.gradientPoint = self.bounds.top
            self.gradientRadius = max( self.bounds.size.width, self.bounds.size.height )
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let gradientColor = self.gradientColor
        else { return }

        UIGraphicsGetCurrentContext()?.drawRadialGradient(
                gradientColor, startCenter: self.gradientPoint, startRadius: 0,
                endCenter: self.gradientPoint, endRadius: self.gradientRadius, options: .drawsAfterEndLocation )
    }

    // MARK: --- ThemeObserver ---

    func didChangeTheme() {
        self.setNeedsDisplay()
    }

    // MARK: --- Types ---

    enum Mode {
        case gradient, backdrop, panel, tint
    }
}
