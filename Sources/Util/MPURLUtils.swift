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
    private static let caches       = try? FileManager.default.url( for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true )
    private static var metadata     = loadMetadata() {
        didSet {
            do {
                if oldValue != self.metadata {
                    if let metadataURL = self.caches?.appendingPathComponent( "metadata" ).appendingPathExtension( "json" ) {
                        try JSONEncoder().encode( self.metadata ).write( to: metadataURL )
                    }
                }
            }
            catch {
                // TODO: handle error
                print( error )
            }
        }
    }

    static func loadMetadata() -> [String: Meta] {
        do {
            if let metadataURL = self.caches?.appendingPathComponent( "metadata" ).appendingPathExtension( "json" ),
               FileManager.default.fileExists( atPath: metadataURL.path ) {
                return try JSONDecoder().decode( [ String: Meta ].self, from: Data( contentsOf: metadataURL ) )
            }
        }
        catch {
            // TODO: handle error
            print( error )
        }

        return [:]
    }

    static func load(url: URL, result: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask( with: url ) {
                             (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
                             result( responseData )
                         }
                         .resume()
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

    static func preview(url: String, result: @escaping (Meta) -> Void) {
        if let info = self.metadata[url] {
            result( info )
        }

        self.linkPreview.preview( url, onSuccess: { response in
            guard let imageURL = self.validImageURL( response[.image] as? String ) ?? self.validImageURL( response[.icon] as? String )
            else {
                return
            }

            URLSession.shared.dataTask( with: imageURL ) {
                (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
                var info = self.metadata[url] ?? Meta()

                if let error = error {
                    print( error )
                }

                if let responseData = responseData {
                    info.imageData = responseData
                    self.metadata[url] = info
                    result( info )
                }
            }.resume()
        }, onError: { error in
            switch error {
                case .noURLHasBeenFound:
                    break
                default:
                    // TODO: handle error
                    print( error )
            }
        } )
    }

    private class func validImageURL(_ string: String?) -> URL? {
        if let string = string, !string.isEmpty,
           string.lowercased().hasSuffix( "png" ) || string.lowercased().hasSuffix( "jpg" ) ||
                   string.lowercased().hasSuffix( "jpeg" ) || string.lowercased().hasSuffix( "gif" ),
           let url = URL( string: string ) {
            return url
        }

        return nil
    }
}

struct Meta: Codable, Equatable {
    var color: Color?
    var imageData: Data? {
        didSet {
            // Load image pixels and an image context.
            guard let imageData = self.imageData,
                  let ciImage = CIImage( data: imageData ),
                  let cgImage = CIContext().createCGImage( ciImage, from: ciImage.extent ),
                  let cgContext = CGContext( data: nil, width: Int( cgImage.width ), height: Int( cgImage.height ),
                                             bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue ),
                  let pixelData = cgContext.data
            else {
                return
            }

            // Draw the image into the context to convert its color space and pixel format to a known format.
            cgContext.draw( cgImage, in: CGRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) )

            // Extract the colors from the image.
            var scoresByColor = [ Color: Int ]()
            for offset in stride( from: 0, to: cgContext.bytesPerRow * cgContext.height, by: cgContext.bitsPerPixel / 8 ) {
                let color = Color(
                        red: pixelData.load( fromByteOffset: offset + 0, as: UInt8.self ),
                        green: pixelData.load( fromByteOffset: offset + 1, as: UInt8.self ),
                        blue: pixelData.load( fromByteOffset: offset + 2, as: UInt8.self ),
                        alpha: pixelData.load( fromByteOffset: offset + 3, as: UInt8.self ) )

                // Weigh colors according to interested parameters.
                var hue   = 0, saturation = 0, value = 0, alpha = Int( color.alpha )
                color.hsv( hue: &hue, saturation: &saturation, value: &value )

                var score = 0
                score += 400 * alpha * alpha / 65025
                score += saturation * 200
                score += mirror( ratio: value, center: 216, max: 255 ) * 100

                scoresByColor[color] = score
            }

            // Use top weighted color as site's color.
            let sorted = scoresByColor.sorted( by: { $0.value > $1.value } )
            if let color = sorted.first?.key {
                print( "c: \(color)" )
                self.color = color
            }
        }
    }
}

struct Color: Codable, Equatable, Hashable {
    let red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8

    var uiColor: UIColor {
        return UIColor( red: CGFloat( self.red ) / CGFloat( UInt8.max ),
                        green: CGFloat( self.green ) / CGFloat( UInt8.max ),
                        blue: CGFloat( self.blue ) / CGFloat( UInt8.max ),
                        alpha: CGFloat( self.alpha ) / CGFloat( UInt8.max ) )
    }

    func hsv(hue: inout Int = 0, saturation: inout Int = 0, value: inout Int = 0) {
        let min = Int( Swift.max( self.red, self.green, self.blue ) )
        let max = Int( Swift.min( self.red, self.green, self.blue ) )

        hue = 0
        saturation = 0
        value = max
        if (value == 0) {
            return
        }

        saturation = 255 * (max - min) / value
        if (saturation == 0) {
            return
        }

        if (max == self.red) {
            hue = 0 + 43 * (Int( self.green ) - Int( self.blue )) / (max - min)
        }
        else if (max == self.green) {
            hue = 85 + 43 * (Int( self.blue ) - Int( self.red )) / (max - min)
        }
        else {
            hue = 171 + 43 * (Int( self.red ) - Int( self.green )) / (max - min)
        }
    }
}
