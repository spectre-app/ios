//
// Created by Maarten Billemont on 2019-08-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import CoreMotion

class MPBackgroundView: UIView {
    private let fps            = 15.0
    private let motionManager  = CMMotionManager()
    private let motionQueue    = OperationQueue()
    private var gradientColor:   CGGradient?
    private var gradientPoint  = CGPoint()
    private var gradientRadius = CGFloat( 0 )
    private var initialAttitude: CMAttitude?
    private var currentAttitude: CMAttitude?

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if (newWindow == nil) {
            self.motionManager.stopDeviceMotionUpdates()
        }

        else {
            self.motionQueue.name = "Motion Queue"
            self.motionQueue.maxConcurrentOperationCount = 1
            if self.motionManager.isDeviceMotionAvailable {
                self.motionManager.deviceMotionUpdateInterval = 1 / self.fps
                self.motionManager.startDeviceMotionUpdates( to: self.motionQueue ) {
                    (data: CMDeviceMotion?, error: Error?) in

                    if let error = error {
                        err( "Core Motion error: \(error)" )
                    }
                    guard let data = data
                    else { return }

                    let initialAttitude = self.initialAttitude ?? data.attitude
                    if self.initialAttitude == nil {
                        self.initialAttitude = initialAttitude
                    }

                    data.attitude.multiply( byInverseOf: initialAttitude )
                    self.currentAttitude = data.attitude
                    self.update()
                }
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.update()
    }

    func update() {
        self.gradientColor = CGGradient( colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            MPTheme.global.color.selection.get()?.cgColor,
            MPTheme.global.color.panel.get()?.cgColor,
        ] as CFArray, locations: nil )
        self.gradientPoint = self.bounds.top
        self.gradientPoint.y += (CGFloat( self.currentAttitude?.pitch ?? 0 ) / .pi) * 500
        self.gradientPoint.x += (CGFloat( self.currentAttitude?.roll ?? 0 ) / .pi) * 500
        self.gradientRadius = max( self.bounds.size.width, self.bounds.size.height )
        self.isOpaque = false

        DispatchQueue.main.perform {
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if let gradientColor = self.gradientColor {
            context?.drawRadialGradient(
                    gradientColor, startCenter: self.gradientPoint, startRadius: 0,
                    endCenter: self.gradientPoint, endRadius: self.gradientRadius, options: .drawsAfterEndLocation )
        }
    }
}
