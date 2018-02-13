//
// Created by Maarten Billemont on 2018-02-10.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import CoreMotion

func rate(radians: Double) -> Double {
    return radians / .pi - 2 * ((radians + .pi) / (2 * .pi)).rounded( .down );
}

class MPBackgroundView: UIView {
    let parallaxRate = 0.5
    let starSize     = 4
    var stars        = [ MPBackgroundStar ]()
    var lastDrawTime = CACurrentMediaTime()

    let queue   = OperationQueue()
    let manager = CMMotionManager()
    var initialAttitude: CMAttitude?
    var currentAttitude: CMAttitude? {
        didSet {
            OperationQueue.main.addOperation {
                self.setNeedsDisplay()
            }
        }
    }

    public override init(frame: CGRect) {
        super.init( frame: frame )

        for _ in 1...1000 {
            stars.append( .init() )
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) has not been implemented" )
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if (newWindow == nil) {
            manager.stopDeviceMotionUpdates()
        }
        else {
            if manager.isDeviceMotionAvailable {
                manager.deviceMotionUpdateInterval = 1 / 30
                manager.startDeviceMotionUpdates( to: queue ) {
                    (data: CMDeviceMotion?, error: Error?) in

                    if let error = error {
                        print( "Core Motion error: \(error)" )
                    }
                    guard let data = data else {
                        return
                    }
                    guard let initialAttitude = self.initialAttitude else {
                        self.initialAttitude = data.attitude
                        return
                    }
                    data.attitude.multiply( byInverseOf: initialAttitude )
                    self.currentAttitude = data.attitude
                }
            }
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw( rect )

        let context         = UIGraphicsGetCurrentContext()!
        let spacePadding    = CGSize( width: self.bounds.size.width * CGFloat( parallaxRate ),
                                      height: self.bounds.size.height * CGFloat( parallaxRate ) )
        let spaceBounds     = self.bounds.insetBy( dx: -spacePadding.width, dy: -spacePadding.height )
        let rollRate        = CGFloat( rate( radians: self.currentAttitude?.roll ?? 0 ) )
        let pitchRate       = CGFloat( rate( radians: self.currentAttitude?.pitch ?? 0 ) )
        let currentDrawTime = CACurrentMediaTime()

        for star in stars {
            star.travel( seconds: currentDrawTime - lastDrawTime )

            let starBounds = CGRect(
                    x: spaceBounds.origin.x + star.location.x * spaceBounds.size.width + spacePadding.width * star.distance * rollRate,
                    y: spaceBounds.origin.y + star.location.y * spaceBounds.size.height + spacePadding.height * star.distance * pitchRate,
                    width: star.distance * CGFloat( starSize ), height: star.distance * CGFloat( starSize ) )

            tintColor.withAlphaComponent( star.distance ).setFill()
            context.fillEllipse( in: starBounds )
        }

        lastDrawTime = currentDrawTime
    }
}

class MPBackgroundStar {
    let travelSpeed = 0.01
    var distance    = CGFloat( drand48() )
    var location    = CGPoint( x: drand48(), y: drand48() )

    func travel(seconds: TimeInterval) {
        location.x += CGFloat( travelSpeed ) * CGFloat( seconds ) * (location.x - 0.5) * distance;
        location.y += CGFloat( travelSpeed ) * CGFloat( seconds ) * (location.y - 0.5) * distance;
        distance = min( 1, distance + CGFloat( travelSpeed ) * CGFloat( seconds ) * distance );

        if (location.x < 0 || location.y < 0 || location.x > 1 || location.y > 1) {
            location = CGPoint( x: drand48(), y: drand48() )
            distance = 0.3
        }
    }
}
