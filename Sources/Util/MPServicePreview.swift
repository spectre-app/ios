//
// Created by Maarten Billemont on 2018-09-17.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import SwiftLinkPreview

struct MPServicePreview: Codable, Equatable {
    var color:     Color?
    var imageURL:  String?
    var imageDate: Date?
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
            else { return }

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

            // Use top weighted color as service's color.
            let sorted = scoresByColor.sorted( by: { $0.value > $1.value } )
            if let color = sorted.first?.key {
                self.color = color
            }
        }
    }

    static func cached(for url: String) -> MPServicePreview {
        let url = url.replacingOccurrences( of: ".*@", with: "", options: .regularExpression )

        return self.metadata[url] ?? MPServicePreview( color: Color( uiColor: url.color() ) )
    }

    static func latest(for url: String) -> Promise<MPServicePreview> {
        let url = url.replacingOccurrences( of: ".*@", with: "", options: .regularExpression )

        return self.metapromises[url] ?? using( Promise() ) { promise in
            self.metapromises[url] = promise
            var info = self.metadata[url] ?? MPServicePreview( color: Color( uiColor: url.color() ) )
            if let date = info.imageDate, date < Date().addingTimeInterval( .days( 30 ) ) {
                trc( "[preview cached] %@: %d", url, info.imageData?.count ?? 0 )
                promise.finish( .success( info ) )
                return
            }

            self.linkPreview.preview( url, onSuccess: { response in
                guard let imageURL = [ response.image, response.icon ]
                        .compactMap( { self.validURL( $0 ) } ).filter( { $0.pathExtension == "svg" } ).first
                        ?? self.byImageSize( [ response.image, response.icon ] + (response.images ?? []) )
                               .ordered( last: { $0.pathExtension == "gif" } ).first
                else {
                    trc( "[preview missing] %@: %@", url, response )
                    promise.finish( .failure( MPError.issue(
                            title: "No candidate images on site.", details: String( describing: response ) ) ) )
                    return
                }

                info.imageURL = imageURL.absoluteString
                URLSession.optional.promise( with: URLRequest( url: imageURL ) ).promise {
                    trc( "[preview fetched] %@: %d", url, $0.0.count )

                    info.imageDate = Date()
                    info.imageData = $0.0
                    self.metadata[url] = info
                    self.metapromises[url] = nil
                    return info
                }.finishes( promise )
            }, onError: { error in
                trc( "[preview error] %@: %@", url, error )
                promise.finish( .failure( error ) )
            } )
        }
    }

    // MARK: --- Private ---

    private static let linkPreview  = SwiftLinkPreview( session: .optional,
                                                        workQueue: DispatchQueue( label: "\(productName): Link Preview", qos: .background, attributes: [ .concurrent ] ),
                                                        responseQueue: DispatchQueue( label: "\(productName): Link Response", qos: .background, attributes: [ .concurrent ] ),
                                                        cache: InMemoryCache() )
    private static let caches       = try? FileManager.default.url( for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true )
    private static var metapromises = [ String: Promise<MPServicePreview> ]()
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
                mperror( title: "Couldn't save service metadata", error: error )
            }
        }
    }

    private static func loadMetadata() -> [String: MPServicePreview] {
        do {
            if let metadataURL = self.caches?.appendingPathComponent( "metadata" ).appendingPathExtension( "json" ),
               FileManager.default.fileExists( atPath: metadataURL.path ) {
                return try JSONDecoder().decode( [ String: MPServicePreview ].self, from: Data( contentsOf: metadataURL ) )
            }
        }
        catch {
            mperror( title: "Couldn't load service metadata", error: error )
        }

        return [:]
    }

    private static func byImageSize<S: Sequence>(_ urls: S) -> [URL] where S.Element == String? {
        urls.compactMap { self.validURL( $0 ) }
            .compactMap { URLSession.optional.promise( with: URLRequest( method: .head, url: $0 ) ) }
            .compactMap { (promise: Promise<(Data, URLResponse)>) -> URLResponse? in
                (try? promise.await())?.1
            }
            .filter { $0.mimeType?.contains( "image/" ) ?? false }
            .sorted { $0.expectedContentLength > $1.expectedContentLength }
            .compactMap { $0.url }
    }

    private static func validURL(_ string: String?) -> URL? {
        guard let string = string?.trimmingCharacters( in: .whitespacesAndNewlines ), !string.isEmpty
        else { return nil }

        return URL( string: string )
    }

    // MARK: --- Types ---

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
            else { return nil }

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
}
