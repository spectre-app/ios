//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUtils {
    static func sha256(message: String) -> Data {
        return sha256( message: message.data( using: .utf8 )! )
    }

    static func sha256(message: Data) -> Data {
        var hash = Data( count: Int( CC_SHA256_DIGEST_LENGTH ) )
        message.withUnsafeBytes { messageBytes in
            hash.withUnsafeMutableBytes { hashBytes in
                _ = CC_SHA256( messageBytes, CC_LONG( message.count ), hashBytes )
            }
        }

        return hash
    }

    static func ratio(of value: UInt8, from: Double, to: Double) -> Double {
        return from + (to - from) * (Double( value ) / Double( UInt8.max ))
    }

    // Map a 0-1 value such that it mirrors around a center point.
    // 0 -> 0, center -> 1, 1 -> 0
    static func mirror(ratio: CGFloat, center: CGFloat) -> CGFloat {
        if ratio < center {
            return ratio / center
        } else {
            return 1 - (ratio - center) / (1 - center)
        }
    }

    static func color(message: String) -> UIColor {
        let sha256     = MPUtils.sha256( message: message )
        let hue        = CGFloat( self.ratio( of: sha256[0], from: 0, to: 1 ) )
        let saturation = CGFloat( self.ratio( of: sha256[1], from: 0.3, to: 1 ) )
        let brightness = CGFloat( self.ratio( of: sha256[2], from: 0.5, to: 0.7 ) )

        return UIColor( hue: hue, saturation: saturation, brightness: brightness, alpha: 1 )
    }
}

extension UIColor {
    // Determine how common a color is in a list of colors.
    // Compares the color to the other colors only by average hue distance.
    func similarityOfHue(in colors: [UIColor]) -> CGFloat {
        let swatchHue = self.hue()

        var commonality: CGFloat = 0
        for color in colors {
            let colorHue = color.hue()
            commonality += abs( colorHue - swatchHue )
        }

        return commonality / CGFloat( colors.count )
    }

    func hue() -> CGFloat {
        var hue: CGFloat = 0
        self.getHue( &hue, saturation: nil, brightness: nil, alpha: nil )

        return hue;
    }

    func saturation() -> CGFloat {
        var saturation: CGFloat = 0
        self.getHue( nil, saturation: &saturation, brightness: nil, alpha: nil )

        return saturation;
    }

    func brightness() -> CGFloat {
        var brightness: CGFloat = 0
        self.getHue( nil, saturation: nil, brightness: &brightness, alpha: nil )

        return brightness;
    }
}
