//
// Created by Maarten Billemont on 2019-08-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPBackgroundView: UIView {
    var mode: Mode {
        didSet {
            self.update()
        }
    }

    private var gradientColor: CGGradient?
    private var gradientPoint  = CGPoint()
    private var gradientRadius = CGFloat( 0 )

    // MARK: --- Life ---

    init(mode: Mode = .panel) {
        self.mode = mode
        super.init( frame: .zero )

        self.update()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if case .gradient = self.mode {
            self.gradientPoint = self.bounds.top
            self.gradientRadius = max( self.bounds.size.width, self.bounds.size.height )
            self.setNeedsDisplay()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange( previousTraitCollection )

        self.update()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        self.update()
    }

    override func draw(_ rect: CGRect) {
        guard let gradientColor = self.gradientColor
        else { return }

        UIGraphicsGetCurrentContext()?.drawRadialGradient(
                gradientColor, startCenter: self.gradientPoint, startRadius: 0,
                endCenter: self.gradientPoint, endRadius: self.gradientRadius, options: .drawsAfterEndLocation )
    }

    // MARK: --- Private ---

    private func update() {
        switch self.mode {
            case .gradient:
                self.gradientColor = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    appConfig.theme.color.panel.get()!.cgColor,
                    appConfig.theme.color.backdrop.get()!.cgColor,
                ] as CFArray, locations: nil )

            case .backdrop:
                self.backgroundColor = appConfig.theme.color.backdrop.get()
                self.gradientColor = nil

            case .panel:
                self.backgroundColor = appConfig.theme.color.panel.get()
                self.gradientColor = nil

            case .tint:
                self.backgroundColor = self.tintColor
                self.gradientColor = nil
        }

        self.setNeedsDisplay()
    }

    // MARK: --- Types ---

    enum Mode {
        case gradient, backdrop, panel, tint
    }
}
