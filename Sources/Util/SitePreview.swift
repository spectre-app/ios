//
// Created by Maarten Billemont on 2018-09-17.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
#if TARGET_APP
import SwiftLinkPreview
#endif

class SitePreview: Equatable {

    private static var previews  = NSCache<NSString, SitePreview>()
    private static let semaphore = DispatchQueue( label: "SitePreview" )

    // MARK: --- Life ---

    var url:   String
    var data:  PreviewData
    var image: UIImage? {
        self.data.image
    }
    var color: UIColor? {
        self.data.color?.uiColor
    }

    static func `for`(_ siteName: String) -> SitePreview {
        let siteURL = self.url( for: siteName )

        // If a cached preview is known, use it.
        if let preview = self.semaphore.sync( execute: {
            self.previews.object( forKey: siteURL as NSString )
        } ) {
            return preview
        }

        // If a preview exists on disk, use it.
        do {
            if let previewURL = FileManager.groupCaches?.appendingPathComponent( "preview-\(siteURL)" ).appendingPathExtension( "json" ),
               FileManager.default.fileExists( atPath: previewURL.path ) {
                return SitePreview( url: siteURL, data:
                try JSONDecoder().decode( PreviewData.self, from: Data( contentsOf: previewURL ) ) )
            }
        }
        catch {
            mperror( title: "Couldn't load site preview", error: error )
        }

        // Create & cache a stub preview based on the site name.
        return SitePreview( url: siteURL, data: PreviewData( color: ColorData( uiColor: siteURL.color() ) ) )
    }

    private init(url: String, data: PreviewData) {
        self.url = url
        self.data = data

        SitePreview.semaphore.sync {
            SitePreview.previews.setObject( self, forKey: url as NSString, cost: self.data.imageData?.count ?? 0 )
        }
    }

    // MARK: --- Equatable ---

    static func ==(lhs: SitePreview, rhs: SitePreview) -> Bool {
        lhs.data == rhs.data
    }

    // MARK: --- Private ---

    private static func url(for siteName: String) -> String {
        siteName.replacingOccurrences( of: "/", with: "::" ).replacingOccurrences( of: ".*@", with: "", options: .regularExpression )
    }

    #if TARGET_APP
    private static let linkPreview = SwiftLinkPreview( session: .optional,
                                                       workQueue: DispatchQueue( label: "\(productName): Link Preview", qos: .background, attributes: [ .concurrent ] ),
                                                       responseQueue: DispatchQueue( label: "\(productName): Link Response", qos: .background, attributes: [ .concurrent ] ),
                                                       cache: InMemoryCache() )

    private var updating: Promise<Bool>?

    func update() -> Promise<Bool> {
        // If an update is already promised, reuse it.
        if let promise = self.updating {
            return promise
        }

        // If a preview exists with a known image < 30 days old, don't refresh it yet.
        if let date = self.data.imageDate, date < Date().addingTimeInterval( .days( 30 ) ) {
            //dbg( "[preview cached] %@: %d", self.url, self.data.imageData?.count ?? 0 )
            return Promise( .success( false ) )
        }

        let promise = Promise<Bool>()
        self.updating = promise

        // Resolve candidate image URLs for the site.
        // If the site URL is not a pure domain, install a fallback resolver for the site domain.
        var resolution = self.loadImage( for: self.url )
        if let siteDomain = self.url[#"^[^/]*\.([^/]+\.[^/]+)(/.*)?$"#].first?[1] {
            resolution = resolution.or( self.loadImage( for: String( siteDomain ) ) )
        }

        // Successful image resolution updates the preview, cache cost and persists the change to disk.
        resolution.promise { imageData in
            //dbg( "[preview fetched] %@: %d", self.url, imageData.count )

            self.data.imageDate = Date()
            self.data.imageData = imageData

            SitePreview.semaphore.sync {
                SitePreview.previews.setObject( self, forKey: self.url as NSString, cost: self.data.imageData?.count ?? 0 )
            }

            if let previewURL = FileManager.groupCaches?.appendingPathComponent( "preview-\(self.url)" ).appendingPathExtension( "json" ) {
                try JSONEncoder().encode( self.data ).write( to: previewURL )
            }

            self.updating = nil
            return true
        }.finishes( promise )

        return promise
    }

    private static func byImageSize<S: Sequence>(_ urls: S) -> [URL] where S.Element == String? {
        urls.compactMap { self.validURL( $0 ) }
            .compactMap { URLSession.optional.promise( with: URLRequest( method: .head, url: $0 ) ) }
            .compactMap { promise -> URLResponse? in (try? promise.await())?.response }
            .filter { $0.mimeType?.contains( "image/" ) ?? false }
            .sorted { $0.expectedContentLength > $1.expectedContentLength }
            .compactMap { $0.url }
    }

    private static func validURL(_ string: String?) -> URL? {
        guard let string = string?.trimmingCharacters( in: .whitespacesAndNewlines ), !string.isEmpty
        else { return nil }

        return URL( string: string )
    }

    private func loadImage(for url: String) -> Promise<Data> {
        let promise = Promise<Data>()

        SitePreview.linkPreview.preview( url, onSuccess: {
            self.extractImage( response: $0, into: promise )
        }, onError: { error in
            SitePreview.linkPreview.preview( "https://\(url)", onSuccess: {
                self.extractImage( response: $0, into: promise )
            }, onError: { error in
                wrn( "[preview error] %@: %@", self.url, error )

                promise.finish( .failure( error ) )
            } )
        } )

        return promise
    }

    private func extractImage(response: Response, into promise: Promise<Data>) {
        // Use SVG icons if available, otherwise use the largest bitmap, preferably non-GIF (to avoid large low-res animations)
        guard let imageURL = [ response.image, response.icon ]
                .compactMap( { SitePreview.validURL( $0 ) } ).filter( { $0.pathExtension == "svg" } ).first
                ?? SitePreview.byImageSize( [ response.image, response.icon ] + (response.images ?? []) )
                              .reordered( last: { $0.pathExtension == "gif" } ).first
        else {
            //dbg( "[preview missing] %@: %@", self.url, response )
            promise.finish( .failure( AppError.issue(
                    title: "No candidate images on site.", details: String( describing: response ) ) ) )
            return
        }

        // Fetch the image's data.
        self.data.imageURL = imageURL.absoluteString
        URLSession.optional.promise( with: URLRequest( url: imageURL ) ).promise { $0.0 }.finishes( promise )
    }
    #endif
}

struct PreviewData: Codable, Equatable {
    var color:     ColorData?
    var imageURL:  String?
    var imageDate: Date?
    var imageData: Data? {
        didSet {
            guard oldValue != self.imageData
            else { return }

            // Load image pixels and an image context.
            self.image = UIImage.load( data: self.imageData )
            guard let cgImage = self.image?.cgImage,
                  let cgContext = CGContext( data: nil, width: Int( cgImage.width ), height: Int( cgImage.height ),
                                             bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue ),
                  let pixelData = cgContext.data
            else { return }

            // Draw the image into the context to convert its color space and pixel format to a known format.
            cgContext.draw( cgImage, in: CGRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) )

            // Extract the colors from the image.
            var scoresByColor = [ ColorData: Int ]()
            for offset in stride( from: 0, to: cgContext.bytesPerRow * cgContext.height, by: cgContext.bitsPerPixel / 8 ) {
                let color      = ColorData(
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
    lazy var image: UIImage? = UIImage.load( data: self.imageData )
}

struct ColorData: Codable, Equatable, Hashable {
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
