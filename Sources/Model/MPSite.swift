//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite : NSObject {
    var observers = Observers<MPSiteObserver>()

    let siteName: String
    var uses:     UInt = 0
    var lastUsed: Date?
    var color:    UIColor

    // MARK: - Life

    init(named name: String, uses: UInt = 0, lastUsed: Date? = nil) {
        self.siteName = name
        self.uses = uses
        self.lastUsed = lastUsed
        self.color = MPUtils.color( message: self.siteName )
        super.init()

//        if self.siteName == "reddit.com" {
            URLSession.shared.dataTask( with: URL( string: "http://\(self.siteName)/favicon.ico" )! ) {
                (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
                if let responseData = responseData, let ciImage = CIImage( data: responseData ),
                   let cgImage = CIContext().createCGImage( ciImage, from: ciImage.extent ),
                   let cgContext = CGContext( data: nil, width: Int( cgImage.width ), height: Int( cgImage.height ),
                                              bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue ),
                   let pixelData = cgContext.data {

                    // Draw the image into the context to convert its color space and pixel format to a known format.
                    cgContext.draw( cgImage, in: CGRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) )

                    // Extract the colors from the image.
                    var colors = [ UIColor ]()
                    for offset in stride( from: 0, to: cgContext.bytesPerRow * cgContext.height, by: cgContext.bitsPerPixel / 8 ) {
                        let r = CGFloat( pixelData.load( fromByteOffset: offset + 0, as: UInt8.self ) ) / CGFloat( UInt8.max )
                        let g = CGFloat( pixelData.load( fromByteOffset: offset + 1, as: UInt8.self ) ) / CGFloat( UInt8.max )
                        let b = CGFloat( pixelData.load( fromByteOffset: offset + 2, as: UInt8.self ) ) / CGFloat( UInt8.max )
                        let a = CGFloat( pixelData.load( fromByteOffset: offset + 3, as: UInt8.self ) ) / CGFloat( UInt8.max )
                        colors.append( UIColor( red: r, green: g, blue: b, alpha: a ) )
                    }

                    // Weigh colors according to interested parameters.
                    var scoresByColor = [ UIColor: Int ]()
                    for color in colors {
                        var saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                        color.getHue( nil, saturation: &saturation, brightness: &brightness, alpha: &alpha );

                        let similarity = color.similarityOfHue( in: colors )
                        var score      = 0
                        score += Int( pow( alpha, 2 ) * 400 )
                        score += Int( saturation * 200 )
                        score += Int( MPUtils.mirror( ratio: brightness, center: 0.85 ) * 100 )
                        score += Int( similarity * 100 )

                        scoresByColor[color] = score
                    }

                    // Use top weighted color as site's color.
                    let sorted = scoresByColor.sorted( by: { $0.value > $1.value } )
                    if let color = sorted.first?.key, color != self.color {
                        self.color = color
                        self.changed()
                    }
                }
            }.resume()
//        }
    }

    private func changed() {
        self.observers.notify { $0.siteDidChange() }
    }
}

@objc
protocol MPSiteObserver {
    func siteDidChange()
}
