// =============================================================================
// Created by Maarten Billemont on 2018-09-17.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation
#if TARGET_APP
import SwiftLinkPreview
#endif

class SitePreview: Equatable {

    private static var previews  = NSCache<NSString, SitePreview>()
    private static let semaphore = DispatchQueue( label: "SitePreview" )

    // MARK: - Life

    var name:  String {
        didSet {
            #if TARGET_APP
            self.update()
            #endif
        }
    }
    var url:   String? {
        didSet {
            #if TARGET_APP
            self.update()
            #endif
        }
    }
    var data:  PreviewData
    var image: UIImage? {
        self.data.image
    }
    var color: UIColor? {
        self.data.color?.uiColor
    }

    static func `for`(_ siteName: String, withURL url: String?) -> SitePreview {
        let previewName = siteName.domainName( .host )

        // If a cached preview is known, use it.
        if let preview = self.semaphore.await( execute: {
            self.previews.object( forKey: previewName as NSString )
        } ) {
            return preview
        }

        // If a preview exists on disk, use it.
        do {
            if let previewFile = SitePreview.previewFile( for: previewName ), FileManager.default.fileExists( atPath: previewFile.path ) {
                return SitePreview( name: previewName, url: url, data:
                try JSONDecoder().decode( PreviewData.self, from: Data( contentsOf: previewFile ) ) )
            }
        }
        catch {
            mperror( title: "Couldn't load site preview", error: error )
        }

        // Create & cache a stub preview based on the site name.
        return SitePreview( name: previewName, url: url, data:
        PreviewData( color: ColorData( uiColor: previewName.color() ), siteName: previewName, siteURL: url ) )
    }

    private init(name: String, url: String?, data: PreviewData) {
        self.name = name
        self.url = url
        self.data = data

        SitePreview.semaphore.await {
            SitePreview.previews.setObject( self, forKey: name as NSString, cost: self.data.imageData?.count ?? 0 )
        }
    }

    // MARK: - Equatable

    static func == (lhs: SitePreview, rhs: SitePreview) -> Bool {
        lhs.data == rhs.data
    }

    // MARK: - Private

    private static func previewFile(for previewName: String) -> URL? {
        FileManager.groupCaches?.appendingPathComponent( "preview-\(previewName)" ).appendingPathExtension( "json" )
    }

    #if TARGET_APP
    private static let linkPreview = LazyBox {
        URLSession.optional.get().flatMap {
            SwiftLinkPreview(
                    session: $0,
                    workQueue: DispatchQueue( label: "\(productName): Link Preview", qos: .background, attributes: [ .concurrent ] ),
                    responseQueue: DispatchQueue( label: "\(productName): Link Response", qos: .background, attributes: [ .concurrent ] ),
                    cache: InMemoryCache() )
        }
    }

    private var updating: Promise<Bool>?

    @discardableResult
    func update() -> Promise<Bool> {
        SitePreview.semaphore.await {
            // If an update is already promised, reuse it.
            if let promise = self.updating {
                return promise
            }

            // If a preview exists with identical metadata and a known image < 30 days old, don't refresh it yet.
            if self.name == self.data.siteName, self.url == self.data.imageURL,
               let date = self.data.imageDate, date < Date().addingTimeInterval( .days( 30 ) ) {
                //dbg( "[preview cached] %@: %d", self.url, self.data.imageData?.count ?? 0 )
                return Promise( .success( false ) )
            }

            // Resolve candidate image URLs for the site.
            // If the site URL is not a pure domain, install a fallback resolver for the site domain.
            var candidates = Set<String>( [ self.name, self.name.domainName( .host ), self.name.domainName( .topPrivate ) ] )
            if let url = self.url?.nonEmpty {
                candidates.formUnion( [ url, url.domainName( .host ), url.domainName( .topPrivate ) ] )
            }
            candidates = Set( candidates.map {
                "https://\($0.replacingOccurrences( of: "^[^:/]*:", with: "", options: .regularExpression ))"
            } )

            let updating: Promise<Bool> =
                    candidates.map { self.preview( forURL: $0 ) }.flatten().promising {
                        self.bestImage( fromPreviews: $0.compactMap( { try? $0.get() } ) )
                    }.thenPromise {
                        do {
                            let result = try $0.get()
                            //dbg( "[preview fetched] %@: %d", self.url, imageData.count )
                            self.data.imageURL = result.response.url?.absoluteString
                            self.data.imageData = result.data
                            self.data.imageDate = Date()
                        }
                        catch {
                            //dbg( "[preview fetched] %@: %d", self.url, imageData.count )
                            self.data.imageURL = nil
                            self.data.imageData = nil
                            self.data.imageDate = Date()
                            wrn( "[preview error] [>PII]" )
                            pii( "[>] URL: %@, Error: %@", self.url, error )
                        }

                        SitePreview.semaphore.await {
                            SitePreview.previews.setObject( self, forKey: self.name as NSString, cost: self.data.imageData?.count ?? 0 )
                        }

                        if let previewFile = SitePreview.previewFile( for: self.name ) {
                            try JSONEncoder().encode( self.data ).write( to: previewFile )
                        }

                        return true
                    }
            self.updating = updating.finally( on: SitePreview.semaphore ) {
                self.updating = nil
            }

            return updating
        }
    }

    private static func byImageSize(_ urls: [String?]) -> Promise<[URL]> {
        // Perform a HEAD request for each candidate URL
        urls.compactMap { self.validURL( $0 ) }.compactMap {
            URLSession.optional.get()?.promise( with: URLRequest( method: .head, url: $0 ) ).promise { $0.1 }
        }.flatten().promise {
            // Return all URLs that resulted in image responses, sorted by content length.
            $0.compactMap { try? $0.get() }
              .filter { $0.mimeType?.contains( "image/" ) ?? false }
              .sorted { $0.expectedContentLength > $1.expectedContentLength }
              .compactMap { $0.url }
        }
    }

    private static func validURL(_ string: String?) -> URL? {
        guard let string = string?.trimmingCharacters( in: .whitespacesAndNewlines ), !string.isEmpty
        else { return nil }

        return URL( string: string )
    }

    private func preview(forURL url: String) -> Promise<Response> {
        let promise = Promise<Response>()

        if let linkPreview = SitePreview.linkPreview.get() {
            linkPreview.preview( url, onSuccess: {
                promise.finish( .success( $0 ) )
            }, onError: { error in
                promise.finish( .failure( error ) )
            } )
        }
        else {
            promise.finish( .failure( AppError.state( title: "App is in offline mode" ) ) )
        }

        return promise
    }

    private func bestImage(fromPreviews previews: [Response]) -> Promise<(data: Data, response: URLResponse)> {
        guard let session = URLSession.optional.get()
        else {
            //dbg( "[preview unavailable] %@: %@", self.url, response )
            return Promise( .failure( AppError.state( title: "App is in offline mode" ) ) )
        }
        // Use SVG icons if available, otherwise use the largest bitmap, preferably non-GIF (to avoid large low-res animations)
        let imageURL: Promise<URL?>
        if let svgImageURL = previews.flatMap( { [ $0.image, $0.icon ] } ).compactMap( { SitePreview.validURL( $0 ) } )
                                     .filter( { $0.pathExtension == "svg" } ).first {
            imageURL = Promise( .success( svgImageURL ) )
        }
        else {
            imageURL = SitePreview.byImageSize( previews.flatMap( { [ $0.image, $0.icon ] + ($0.images ?? []) } ) )
                                  .promise( { $0.reordered( last: { $0.pathExtension == "gif" } ).first } )
        }

        // Fetch the image's data.
        return imageURL.promising {
            guard let imageURL = $0
            else { throw AppError.issue( title: "No candidate images on site", details: String( describing: previews ) ) }

            return session.promise( with: URLRequest( url: imageURL ) )
        }
    }
    #endif
}

struct PreviewData: Codable, Equatable {
    var color:     ColorData?
    var siteName:  String
    var siteURL:   String?
    var imageURL:  String?
    var imageDate: Date?
    var imageData: Data? {
        didSet {
            guard oldValue != self.imageData
            else { return }

            // Load image pixels and convert the color space and pixel format to a known format.
            self.image = UIImage.load( data: self.imageData )
            guard let cgImage = self.image?.cgImage,
                  let cgContext = CGContext( data: nil, width: Int( cgImage.width ), height: Int( cgImage.height ),
                                             bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue )
            else { return }
            cgContext.draw( cgImage, in: CGRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) )
            guard let cgImage = cgContext.makeImage(), let pixelData = cgImage.dataProvider?.data as Data?
            else { return }

            // Extract the colors from the image.
            var scoresByColor = [ ColorData: Int ]()
            for offset in stride( from: 0, to: cgImage.bytesPerRow * cgImage.height, by: cgImage.bitsPerPixel / 8 ) {
                let color      = ColorData(
                        red: pixelData[offset], green: pixelData[offset + 1], blue: pixelData[offset + 2], alpha: pixelData[offset + 3] )

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

        if max == 0 {
            return 0
        }
        else if max == self.red {
            return 0 + 43 * (Int( self.green ) - Int( self.blue )) / (max - min)
        }
        else if max == self.green {
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
