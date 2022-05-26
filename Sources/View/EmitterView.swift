// =============================================================================
// Created by Maarten Billemont on 2019-08-02.
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

private let kAnimationLayerKey = "com.nshipster.animationLayer"

class EmitterView: BaseView, CAAnimationDelegate {

    func emit(with contents: [Content], for duration: TimeInterval = 4.0) {
        let layer = Layer()
        layer.configure( with: contents )
        layer.frame = self.bounds
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer( layer )

        guard duration.isFinite
        else { return }

        let animation = CAKeyframeAnimation( keyPath: #keyPath( CAEmitterLayer.birthRate ) )
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction( name: .easeIn )
        animation.values = [ 1, 0, 0 ]
        animation.keyTimes = [ 0, 0.5, 1 ]
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        layer.beginTime = CACurrentMediaTime()
        layer.birthRate = 0.5

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            let transition = CATransition()
            transition.delegate = self
            transition.type = .fade
            transition.duration = .seconds( 1 )
            transition.timingFunction = CAMediaTimingFunction( name: .easeOut )
            transition.setValue( layer, forKey: kAnimationLayerKey )
            transition.isRemovedOnCompletion = false

            layer.add( transition, forKey: nil )

            layer.opacity = .off
        }
        layer.add( animation, forKey: nil )
        CATransaction.commit()
    }

    func animationDidStop(_ animation: CAAnimation, finished flag: Bool) {
        if let layer = animation.value( forKey: kAnimationLayerKey ) as? CALayer {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
    }

    enum Content {
        enum Shape {
            case circle
            case triangle
            case square
            case custom(CGPath)

            func path(in rect: CGRect) -> CGPath {
                switch self {
                    case .circle:
                        return CGPath( ellipseIn: rect, transform: nil )
                    case .triangle:
                        let path = CGMutablePath()
                        path.addLines( between: [
                            CGPoint( x: rect.midX, y: 0 ),
                            CGPoint( x: rect.maxX, y: rect.maxY ),
                            CGPoint( x: rect.minX, y: rect.maxY ),
                            CGPoint( x: rect.midX, y: 0 ),
                        ] )
                        return path
                    case .square:
                        return CGPath( rect: rect, transform: nil )
                    case .custom(let path):
                        return path
                }
            }

            func image(with color: UIColor) -> UIImage? {
                let rect = CGRect( origin: .zero, size: CGSize( width: 12.0, height: 12.0 ) )
                return UIGraphicsImageRenderer( size: rect.size ).image { context in
                    context.cgContext.setFillColor( color.cgColor )
                    context.cgContext.addPath( path( in: rect ) )
                    context.cgContext.fillPath()
                }
            }
        }

        case shape(Shape, UIColor?)
        case image(UIImage?, UIColor?)
        case emoji(Character)

        var color: UIColor? {
            switch self {
                case let .image(_, color?),
                     let .shape(_, color?):
                    return color
                default:
                    return nil
            }
        }

        var image: UIImage? {
            switch self {
                case let .image(image, _):
                    return image
                case let .shape(shape, color):
                    return shape.image( with: color ?? .white )
                case let .emoji(character):
                    return self.image( of: "\(character)" )
            }
        }

        func image(of string: String, with font: UIFont = UIFont.systemFont( ofSize: 16.0 )) -> UIImage? {

            let string     = NSString( string: string )
            let attributes = [ .font: font ] as [NSAttributedString.Key: Any]
            let size       = string.size( withAttributes: attributes )

            return UIGraphicsImageRenderer( size: size ).image { _ in
                string.draw( at: .zero, withAttributes: attributes )
            }
        }
    }

    class Layer: CAEmitterLayer {
        func configure(with contents: [Content]) {
            emitterCells = contents.map { content in
                let cell = CAEmitterCell()

                cell.birthRate = 5.0
                cell.lifetime = 10.0
                cell.velocity = 100
                cell.velocityRange = cell.velocity / 3
                cell.emissionLongitude = .pi
                cell.emissionRange = .pi / 4
                cell.spinRange = .pi * 6
                cell.scaleRange = 0.25
                cell.scale = 1.0 - cell.scaleRange
                content.color.flatMap { cell.color = $0.cgColor }
                content.image.flatMap { cell.contents = $0.cgImage }

                return cell
            }
        }

        override func layoutSublayers() {
            super.layoutSublayers()

            emitterShape = .line
            emitterSize = CGSize( width: frame.size.width, height: 1.0 )
            emitterPosition = CGPoint( x: frame.size.width / 2.0, y: 0 )
        }
    }
}
