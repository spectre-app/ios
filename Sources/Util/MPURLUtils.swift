//
// Created by Maarten Billemont on 2018-09-17.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import SwiftLinkPreview

class MPURLUtils {
    private static let processQueue = OperationQueue()
    private static let linkPreview  = SwiftLinkPreview( session: .shared, workQueue: SwiftLinkPreview.defaultWorkQueue,
                                                        responseQueue: .main, cache: InMemoryCache() )

    static func loadImage(url: URL, result: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask( with: url ) {
            (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
            if let responseData = responseData,
               let image = UIImage( data: responseData ) {
                result( image )
            }
            else {
                result( nil )
            }
        }.resume()
    }

    static func loadHTML(url: URL, result: @escaping (String?) -> Void) {
        URLSession.shared.dataTask( with: url ) {
            (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
            if let mimeType = response?.mimeType, mimeType.hasSuffix( "/html" ),
               let encoding = response?.textEncodingName, let responseData = responseData,
               let response = NSString( data: responseData, encoding:
               CFStringConvertEncodingToNSStringEncoding( CFStringConvertIANACharSetNameToEncoding( encoding as CFString ) ) ) {
                result( response as String )
            }
            else {
                result( nil )
            }
        }.resume()
    }

    static func preview(url: String, imageResult: @escaping (UIImage?) -> Void, colorResult: @escaping (UIColor?) -> Void) {
        linkPreview.preview( url, onSuccess: { response in
            if let imageURL = validImageURL( response[.image] as? String ) ?? validImageURL( response[.icon] as? String ) {
                self.loadImage( url: imageURL ) { image in
                    imageResult( image )
                }
            }
            else {
                imageResult( nil )
            }

            if let iconURL = validImageURL( response[.icon] as? String ) ?? validImageURL( response[.image] as? String ) {
                URLSession.shared.dataTask( with: iconURL ) {
                    (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
                    processQueue.addOperation {
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
                            var scoresByColor = [ UIColor: Int ]()
                            for offset in stride( from: 0, to: cgContext.bytesPerRow * cgContext.height, by: cgContext.bitsPerPixel / 8 ) {
                                let r                   = CGFloat( pixelData.load( fromByteOffset: offset + 0, as: UInt8.self ) ) / CGFloat( UInt8.max )
                                let g                   = CGFloat( pixelData.load( fromByteOffset: offset + 1, as: UInt8.self ) ) / CGFloat( UInt8.max )
                                let b                   = CGFloat( pixelData.load( fromByteOffset: offset + 2, as: UInt8.self ) ) / CGFloat( UInt8.max )
                                let a                   = CGFloat( pixelData.load( fromByteOffset: offset + 3, as: UInt8.self ) ) / CGFloat( UInt8.max )
                                let color               = UIColor( red: r, green: g, blue: b, alpha: a )

                                // Weigh colors according to interested parameters.
                                var saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                                color.getHue( nil, saturation: &saturation, brightness: &brightness, alpha: &alpha );

                                var score = 0
                                score += Int( pow( alpha, 2 ) * 400 )
                                score += Int( saturation * 200 )
                                score += Int( mirror( ratio: brightness, center: 0.85 ) * 100 )

                                scoresByColor[color] = score
                            }

                            // Use top weighted color as site's color.
                            let sorted = scoresByColor.sorted( by: { $0.value > $1.value } )
                            if let color = sorted.first?.key {
                                colorResult( color )
                            }
                            else {
                                colorResult( nil )
                            }
                        }
                        else {
                            colorResult( nil )
                        }
                    }
                }.resume()
            }
            else {
                colorResult( nil )
            }
        }, onError: { error in
            imageResult( nil )
            colorResult( nil )
        } )
    }

    private class func validImageURL(_ string: String?) -> URL? {
        if let string = string, !string.isEmpty, string.lowercased().hasSuffix( "png" ) ||
                string.lowercased().hasSuffix( "jpg" ) ||
                string.lowercased().hasSuffix( "jpeg" ) ||
                string.lowercased().hasSuffix( "gif" ),
           let url = URL( string: string ) {
            return url
        }

        return nil
    }
}
