//
// Created by Maarten Billemont on 2018-02-10.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import CoreMotion

func rate(radians: Double) -> Double {
    return radians / .pi - 2 * ((radians + .pi) / (2 * .pi)).rounded( .down )
}

class MPStarView: UIView {
    private let fps            = 40.0
    private let motionParallax = 0.5
    private let motionQueue    = OperationQueue()
    private let motionManager  = CMMotionManager()
    private let field          = MPStarField( layout: .bang )
    private let debugLabel     = UILabel()
    private var lastDrawTime   = CACurrentMediaTime()
    private var rolled         = 0.0, pitched = 0.0
    private var initialAttitude: CMAttitude?
    private var currentAttitude: CMAttitude? {
        didSet {
            rolled = rate( radians: self.currentAttitude?.roll ?? 0 )
            pitched = rate( radians: self.currentAttitude?.pitch ?? 0 )
        }
    }

    // MARK: - Life

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.isOpaque = false
        self.backgroundColor = UIColor.black

        self.addSubview( self.debugLabel )
        self.debugLabel.text = " ";
        self.debugLabel.textColor = UIColor.white;
        self.debugLabel.font = .monospacedDigitSystemFont( ofSize: 12, weight: .thin );
        self.debugLabel.setFrameFrom( "-|>[]20|-" )
        self.debugLabel.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove( toWindow: newWindow )

        if (newWindow == nil) {
            self.motionManager.stopDeviceMotionUpdates()
        }

        else {
            if self.motionManager.isDeviceMotionAvailable {
                self.motionManager.deviceMotionUpdateInterval = 1 / self.fps
                self.motionManager.startDeviceMotionUpdates( to: OperationQueue.main ) {
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
                }
            }
        }
    }

    override func draw(_ rect: CGRect) {
        // TODO: This is not very accurate since the reschedule is delayed by the dt between setNeedsDisplay and draw:.
        // TODO: UIView's draw flow is also suboptimal for a constantly changing layer. Consider using an EAGL layer or Metal instead.
        self.perform( #selector( self.setNeedsDisplay as () -> () ), with: nil, afterDelay: 1 / self.fps )

        super.draw( rect )

        let spacePadding = CGSize( width: self.bounds.size.width * CGFloat( self.motionParallax ),
                                   height: self.bounds.size.height * CGFloat( self.motionParallax ) )
        let spaceBounds  = self.bounds.insetBy( dx: -spacePadding.width, dy: -spacePadding.height )

        let context  = UIGraphicsGetCurrentContext()!
        let drawTime = CACurrentMediaTime(), dt = drawTime - self.lastDrawTime
        self.lastDrawTime = drawTime;

        self.field.animate( seconds: dt )

        if !self.debugLabel.isHidden {
            self.debugLabel.text = String( format: "fps: %02.1f, speed: %01.1f (%+01.1f @ %01.1f/s)", 1 / dt,
                                           self.field.speed, self.field.speedDelta, self.field.speedAcceleration )
        }

        self.field.draw( bounds: spaceBounds, padding: spacePadding, context: context, rolled: self.rolled, pitched: self.pitched )
    }

    class MPStarField {
        var stars             = [ MPBackgroundStar ]()
        var speed             = 100.0
        var speedDelta        = 0.0
        var speedAcceleration = 9.0
        let speedQueue        = OperationQueue()

        // MARK: - Life

        init(layout: MPStarFieldLayout) {
            for _ in 1...1000 {
                self.stars.append( .init( field: self, layout: layout ) )
            }

            switch layout {
                case .bang:
                    self.speedQueue.addOperation( MPStarFieldDistanceSpeedOperation( field: self, distance: 50, time: 1.5 ) )
                default:
                    ()
            }
        }

        // MARK: - Interface

        public func speed(operation: MPStarFieldSpeedOperation) {
            self.speedQueue.addOperation( operation )
        }

        public func animate(seconds: TimeInterval) {
            if self.speedDelta != 0 {
                let speedAdvance = copysign( min( abs( self.speedDelta ), abs( self.speedAcceleration * seconds ) ), self.speedDelta );
                self.speed += speedAdvance;
                self.speedDelta -= speedAdvance;
            }
            let speedTime = self.speed * seconds

            for operation in self.speedQueue.operations {
                if let speedOperation = operation as? MPStarFieldSpeedOperation {
                    speedOperation.animate( seconds: speedTime )
                }
            }

            for star in self.stars {
                star.animate( seconds: speedTime )
            }
        }

        public func draw(bounds: CGRect, padding: CGSize, context: CGContext, rolled: Double, pitched: Double) {
            for star in self.stars {
                star.draw( bounds: bounds, padding: padding, context: context, rolled: rolled, pitched: pitched )
            }
        }

        enum MPStarFieldLayout {
            case full
            case bang
        }

        class MPStarFieldSpeedOperation: Operation {

            // MARK: - Interface

            public func animate(seconds: TimeInterval) {
            }
        }

        class MPStarFieldDistanceSpeedOperation: MPStarFieldSpeedOperation {
            let field:          MPStarField
            let distanceNeeded: Double
            let time:           TimeInterval
            var distanceTravelled = 0.0

            // MARK: - Life

            init(field: MPStarField, distance: Double = 10, time: TimeInterval = 3) {
                self.field = field
                self.distanceNeeded = distance;
                self.time = time;
            }

            override func main() {
                super.main()

                self.field.speedDelta = 1 - self.field.speed
                self.field.speedAcceleration = self.field.speedDelta / self.time
            }

            override func animate(seconds: TimeInterval) {
                super.animate( seconds: seconds )

                self.willChangeValue( forKey: "isReady" )
                self.distanceTravelled += seconds
                self.didChangeValue( forKey: "isReady" )
            }

            override var isReady: Bool {
                return super.isReady && self.distanceTravelled > self.distanceNeeded
            }
        }
    }

    class MPBackgroundStar {
        private let field: MPStarField
        private let radius       = 1.5
        private let starGradient = CGGradient( colorsSpace: nil,
                                               colors: [ UIColor.white.cgColor,
                                                         UIColor.white.cgColor,
                                                         UIColor.white.withAlphaComponent( 0 ).cgColor ] as CFArray,
                                               locations: [ CGFloat( 0 ),
                                                            CGFloat( 0.5 ),
                                                            CGFloat( 1 ) ] )!
        private let haloGradient = CGGradient( colorsSpace: nil,
                                               colors: [ UIColor.blue.cgColor,
                                                         UIColor.blue.withAlphaComponent( 0 ).cgColor ] as CFArray,
                                               locations: nil )!
        private var actions      = [ MPBackgroundStarAction ]()

        var halo = 0.0
        var distance: Double
        var location: CGPoint

        // MARK: - Life

        init(field: MPStarField, layout: MPStarField.MPStarFieldLayout) {
            self.field = field

            switch layout {
                case .full:
                    self.distance = drand48()
                    self.location = CGPoint( x: drand48(), y: drand48() )
                case .bang:
                    let bangSpace = 0.3;
                    var dx = drand48(), dy = drand48()
                    dx = 0.5 - dx
                    dy = 0.5 - dy
                    self.location = CGPoint( x: 0.5 + bangSpace * dx, y: 0.5 + bangSpace * dy )
                    self.distance = drand48() * sqrt( (0.5 - abs( dx )) * (0.5 - abs( dy )) )
            }

            self.actions.append( MPBackgroundStarTravelAction( star: self ) )
        }

        // MARK: - Interface

        public func animate(seconds: TimeInterval) {
            if (drand48() < seconds / 100) {
                self.actions.append( MPBackgroundStarFlickerAction( star: self ) )
            }

            for a in (self.actions.startIndex..<self.actions.endIndex).reversed() {
                let action = self.actions[a]
                if !action.animate( seconds: seconds ) {
                    self.actions.remove( at: a )
                }
            }
        }

        public func draw(bounds: CGRect, padding: CGSize, context: CGContext, rolled: Double, pitched: Double) {
            let center: CGPoint = CGPoint(
                    x: bounds.origin.x + self.location.x * bounds.size.width + padding.width * CGFloat( self.distance * rolled ),
                    y: bounds.origin.y + self.location.y * bounds.size.height + padding.height * CGFloat( self.distance * pitched ) )
            if center.x - CGFloat( 2 * self.radius ) < bounds.minX || center.x + CGFloat( 2 * self.radius ) > bounds.maxX ||
                       center.y - CGFloat( 2 * self.radius ) < bounds.minY || center.y + CGFloat( 2 * self.radius ) > bounds.maxY {
                return
            }

            if self.distance > 0 {
                context.setAlpha( CGFloat( self.distance ) )
                context.drawRadialGradient( self.starGradient, startCenter: center, startRadius: 0,
                                            endCenter: center, endRadius: CGFloat( self.distance * self.radius ), options: [] )

                if self.halo > 0 {
                    context.setAlpha( CGFloat( self.halo * self.distance / 2 ) )
                    context.drawRadialGradient( self.haloGradient, startCenter: center, startRadius: 0,
                                                endCenter: center, endRadius: CGFloat( self.distance * self.radius * 1.5 ), options: [] )
                }
            }
        }

        class MPBackgroundStarAction {
            let star:     MPBackgroundStar
            let duration: TimeInterval
            var elapsed:  TimeInterval = 0

            // MARK: - Life

            init(star: MPBackgroundStar, duration: TimeInterval) {
                self.star = star
                self.duration = duration
            }

            // MARK: - Interface

            public func animate(seconds: TimeInterval) -> Bool {
                self.step( progress: self.elapsed / self.duration, increment: seconds / self.duration )
                self.elapsed += seconds

                return !self.finished()
            }

            public func step(progress: Double, increment: Double) {
            }

            public func finished() -> Bool {
                return self.elapsed >= self.duration
            }
        }

        class MPBackgroundStarTravelAction: MPBackgroundStarAction {

            // MARK: - Life

            init(star: MPBackgroundStar) {
                super.init( star: star, duration: 50 )
            }

            override func step(progress: Double, increment: Double) {
                let travel = CGFloat( increment * self.star.distance )

                // Move the star according to the step distance.
                self.star.location.x += travel * (self.star.location.x - 0.5)
                self.star.location.y += travel * (self.star.location.y - 0.5)
                self.star.distance = min( 1, Double( travel ) + self.star.distance )

                // Reset the star's position if it travels outside of the bounds, recycling it as a new star.
                if (self.star.location.x < 0 || self.star.location.y < 0 || self.star.location.x > 1 || self.star.location.y > 1) {
                    self.star.location = CGPoint( x: drand48(), y: drand48() )
                    self.star.distance = 0.3
                }
            }

            override func finished() -> Bool {
                return false
            }
        }

        class MPBackgroundStarFlickerAction: MPBackgroundStarAction {

            // MARK: - Life

            init(star: MPBackgroundStar) {
                super.init( star: star, duration: 8 )
            }

            override func step(progress: Double, increment: Double) {
                self.star.halo = sin( progress * Double.pi )
            }
        }
    }
}
