//
// Created by Maarten Billemont on 2018-09-17.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import SwiftLinkPreview

class MPURLUtils {
    private static let queue    = OperationQueue( queue: DispatchQueue.net )
    public static let  session  = URLSession( configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: queue )
    private static let preview  = SwiftLinkPreview( session: session, workQueue: DispatchQueue.net, responseQueue: DispatchQueue.net, cache: InMemoryCache() )
    private static let caches   = try? FileManager.default.url( for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true )
    private static var metadata = loadMetadata() {
        didSet {
            do {
                if oldValue != self.metadata {
                    if let metadataURL = self.caches?.appendingPathComponent( "metadata" ).appendingPathExtension( "json" ) {
                        try JSONEncoder().encode( self.metadata ).write( to: metadataURL )
                    }
                }
            }
            catch {
                mperror( title: "Couldn't save site metadata", error: error )
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
            mperror( title: "Couldn't load site metadata", error: error )
        }

        return [:]
    }

    static func load(url: URL, result: @escaping (Data?) -> Void) {
        MPURLUtils.session.dataTask( with: url ) {
                              (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
                              result( responseData )
                          }
                          .resume()
    }

    static func loadHTML(url: URL, result: @escaping (String?) -> Void) {
        MPURLUtils.session.dataTask( with: url ) {
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

        self.preview.preview( url, onSuccess: { response in
            guard let imageURL = self.validImageURL( response[.image] as? String ) ?? self.validImageURL( response[.icon] as? String )
            else {
                return
            }

            session.dataTask( with: imageURL ) {
                (responseData: Data?, response: URLResponse?, error: Error?) -> Void in
                var info = self.metadata[url] ?? Meta( color: Color( uiColor: url.color() ), imageData: nil )

                if let error = error {
                    wrn( "Couldn't fetch site preview. [>TRC]" )
                    trc( "\(imageURL): HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(error)" )
                }

                if let responseData = responseData {
                    info.imageData = responseData
                    self.metadata[url] = info
                }

                result( info )
            }.resume()
        }, onError: { error in
            switch error {
                case .noURLHasBeenFound:
                    break
                default:
                    wrn( "No site preview. [>TRC]" )
                    trc( "\(url): \(error)" )
            }

            result( self.metadata[url] ?? Meta( color: Color( uiColor: url.color() ), imageData: nil ) )
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
                let color      = Color(
                        red: pixelData.load( fromByteOffset: offset + 0, as: UInt8.self ),
                        green: pixelData.load( fromByteOffset: offset + 1, as: UInt8.self ),
                        blue: pixelData.load( fromByteOffset: offset + 2, as: UInt8.self ),
                        alpha: pixelData.load( fromByteOffset: offset + 3, as: UInt8.self ) )

                // Weigh colors according to interested parameters.
                let saturation = color.saturation, value = color.value, alpha = Int( color.alpha )
                scoresByColor[color] = 0 +
                        400 * alpha * alpha / 65536 +
                        200 * saturation / 256 +
                        100 * mirror( ratio: value, center: 216, max: 256 ) / 256
            }

            // Use top weighted color as site's color.
            let sorted = scoresByColor.sorted( by: { $0.value > $1.value } )
            if let color = sorted.first?.key {
                self.color = color
            }
        }
    }
}

struct Color: Codable, Equatable, Hashable {
    let red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8

    var uiColor: UIColor {
        UIColor( red: CGFloat( self.red ) / CGFloat( UInt8.max ),
                 green: CGFloat( self.green ) / CGFloat( UInt8.max ),
                 blue: CGFloat( self.blue ) / CGFloat( UInt8.max ),
                 alpha: CGFloat( self.alpha ) / CGFloat( UInt8.max ) )
    }

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(uiColor: UIColor?) {
        guard let uiColor = uiColor
        else {
            return nil
        }

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed( &red, green: &green, blue: &blue, alpha: &alpha )
        self.init( red: UInt8( red * 255 ), green: UInt8( green * 255 ), blue: UInt8( blue * 255 ), alpha: UInt8( alpha * 255 ) )
    }

    var hue:        Int {
        let min = Int( Swift.min( self.red, self.green, self.blue ) )
        let max = Int( Swift.max( self.red, self.green, self.blue ) )

        if (max == 0) {
            return 0
        }
        else if (max == self.red) {
            return 0 + 43 * (Int( self.green ) - Int( self.blue )) / (max - min)
        }
        else if (max == self.green) {
            return 85 + 43 * (Int( self.blue ) - Int( self.red )) / (max - min)
        }
        else {
            return 171 + 43 * (Int( self.red ) - Int( self.green )) / (max - min)
        }
    }
    var saturation: Int {
        let max = Int( Swift.max( self.red, self.green, self.blue ) )
        if max == 0 {
            return 0
        }

        let min = Int( Swift.min( self.red, self.green, self.blue ) )
        return 255 * (max - min) / max
    }
    var value:      Int {
        Int( Swift.max( self.red, self.green, self.blue ) )
    }
}
