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
import UIKit
#endif

class SitePreview: Equatable {
    private static var previews  = NSCache<NSString, SitePreview>()

    // MARK: - Life

    var name:  String {
        didSet {
            #if TARGET_APP
            self.updateTask.request()
            #endif
        }
    }
    var url:   String? {
        didSet {
            #if TARGET_APP
            self.updateTask.request()
            #endif
        }
    }
    var data:  PreviewData
    #if TARGET_APP
    var image: UIImage? {
        self.data.image
    }
    #else
    let image: UIImage? = nil
    #endif
    var color: UIColor? {
        self.data.color?.uiColor
    }

    static func `for`(_ siteName: String, withURL url: String?) -> SitePreview {
        let previewName = siteName.domainName( .host )

        // If a cached preview is known, use it.
        if let preview = self.previews.object( forKey: previewName as NSString ) {
            return preview
        }

        // If a preview exists on disk, use it.
        if let previewFile = SitePreview.previewDataFile( for: previewName ),
           FileManager.default.fileExists( atPath: previewFile.path ) {
            do {
                return SitePreview( name: previewName, url: url, data:
                try JSONDecoder().decode( PreviewData.self, from: Data( contentsOf: previewFile ) ) )
            }
            catch {
                mperror( title: "Couldn't load site preview", error: error )
            }
        }

        // Create & cache a stub preview based on the site name.
        return SitePreview( name: previewName, url: url, data:
        PreviewData( color: ColorData( uiColor: previewName.color() ), siteName: previewName, siteURL: url ) )
    }

    private init(name: String, url: String?, data: PreviewData) {
        self.name = name
        self.url = url
        self.data = data

        SitePreview.previews.setObject( self, forKey: name as NSString, cost: self.data.imageSize )
    }

    // MARK: - Equatable

    static func == (lhs: SitePreview, rhs: SitePreview) -> Bool {
        lhs.data == rhs.data
    }

    // MARK: - Private

    fileprivate static func previewDataFile(for previewName: String) -> URL? {
        FileManager.groupCaches?.appendingPathComponent( "preview-\(previewName)" ).appendingPathExtension( "json" )
    }

    fileprivate static func previewImageFile(for previewName: String) -> URL? {
        FileManager.groupCaches?.appendingPathComponent( "preview-\(previewName)" ).appendingPathExtension( "image" )
    }

    #if TARGET_APP
    lazy var updateTask: DispatchTask<Bool> = DispatchTask.update( self, queue: Self.taskQueue ) { [weak self] in
        guard let self = self
        else { return false }

        // If a preview exists with identical metadata and a known image < 30 days old, don't refresh it yet.
        if self.name == self.data.siteName, self.url == self.data.siteURL,
           let date = self.data.imageDate, date < Date().addingTimeInterval( .days( 30 ) ) {
            return false
        }

        // Resolve candidate image URLs for the site.
        // If the site URL is not a pure domain, install a fallback resolver for the site domain.
        let candidates = Set(
                [ self.name, self.url?.nonEmpty ]
                    .compactMap { $0 }
                    .flatMap {
                        [
                            $0,
                            $0.domainName( .host ),
                            $0.domainName( .topPrivate ),
                            "www.\($0.domainName( .topPrivate ))",
                        ]
                    }
                    .map { "https://\($0.replacingOccurrences( of: "^[^:/]*:/*", with: "", options: .regularExpression ))" }
        )

        return try candidates
            .map { Self.preview( forURL: $0 ) }.compactPromise()
            .promising { Self.bestImage( fromPreviews: $0.compactMap { $0 } ) }
            .finally { self?.data.imageDate = Date() }
            .promise { [weak self] in
                guard let self = self
                else { return false }

                self.data.imageURL = $0.response.url?.absoluteString
                self.data.imageData = $0.data

                SitePreview.previews.setObject( self, forKey: self.name as NSString, cost: self.data.imageSize )
                if let previewFile = SitePreview.previewDataFile( for: self.name ) {
                    try JSONEncoder().encode( self.data ).write( to: previewFile )
                }

                return true
            }
            .failure {
                wrn( "Preview issue for %@: %@ [>PII]", self.name, $0.localizedDescription )
                pii( "[>] Candidates: %@, Error: %@", candidates, $0 )
            }
            .await()
    }

    private static let previewQueue = DispatchQueue( label: "SwiftLinkPreview", qos: .background, attributes: [ .concurrent ] )
    private static let taskQueue    = DispatchQueue( label: "\(productName): SitePreview", qos: .utility, attributes: [ .concurrent ] )
    private static let linkPreview = LazyBox {
        URLSession.optional.get().flatMap {
            SwiftLinkPreview( session: $0, workQueue: previewQueue, responseQueue: previewQueue, cache: InMemoryCache() )
        }
    }

    private static func byImageSize(_ urls: [String?], in session: URLSession) -> Promise<[URL]> {
        // Perform a HEAD request for each candidate URL
        urls.compactMap { self.validURL( $0 ) }.map { url in
                session.promise( with: URLRequest( method: .head, url: url ) ).promise { $0.1 }.failure {
                    pii( "Cannot preview %@: %@", url, $0 )
                }
            }
            .compactPromise().promise {
                // Return all URLs that resulted in image responses, sorted by content length.
                $0.filter { $0.mimeType?.contains( "image/" ) ?? false }
                  .sorted { $0.expectedContentLength > $1.expectedContentLength }
                  .compactMap { $0.url }
            }
    }

    private static func validURL(_ string: String?) -> URL? {
        guard let string = string?.trimmingCharacters( in: .whitespacesAndNewlines ), !string.isEmpty
        else { return nil }

        return URL( string: "https://\(string.replacingOccurrences( of: "^[^:/]*:/*", with: "", options: .regularExpression ))" )
    }

    private static func preview(forURL url: String) -> Promise<Response?> {
        guard let linkPreview = SitePreview.linkPreview.get()
        else { return Promise( .failure( AppError.state( title: "App is in offline mode" ) ) ) }

        let promise = Promise<Response?>()
        linkPreview.preview( url, onSuccess: {
            promise.finish( .success( $0 ) )
        }, onError: {
            pii( "Cannot preview %@: %@", url, $0 )
            promise.finish( .success( nil ) )
        } )
        return promise
    }

    private static func bestImage(fromPreviews previews: [Response]) -> Promise<(data: Data, response: URLResponse)> {
        guard let session = URLSession.optional.get()
        else { return Promise( .failure( AppError.state( title: "App is in offline mode" ) ) ) }

        // Use SVG icons if available, otherwise use the largest bitmap, preferably non-GIF (to avoid large low-res animations)
        let imageURL: Promise<URL?>
        if let svgImageURL = previews.flatMap( { [ $0.image, $0.icon ] } ).compactMap( { SitePreview.validURL( $0 ) } )
                                     .filter( { $0.pathExtension == "svg" } ).first {
            imageURL = Promise( .success( svgImageURL ) )
        }
        else {
            let candidates = previews.flatMap( { [ $0.image, $0.icon ] + ($0.images ?? []) } )
            imageURL = SitePreview.byImageSize( candidates, in: session ).promise {
                $0.reordered( last: { $0.pathExtension == "gif" } ).first
            }
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

#if TARGET_APP
extension SitePreview: Updatable {
}
#endif

struct PreviewData: Codable, Equatable {
    var color:     ColorData?
    var siteName:  String
    var siteURL:   String?
    var imageURL:  String?
    var imageDate: Date?
    var imageSize: Int = 0

    #if TARGET_APP
    lazy var image: UIImage? = .load( data: self.imageData )
    lazy var imageData: Data? = SitePreview.previewImageFile( for: self.siteName ).flatMap {
        let data = try? Data( contentsOf: $0 )
        self.imageSize = data?.count ?? 0
        return data
    } {
        didSet {
            if oldValue != self.imageData {
                self.image = .load( data: self.imageData )
                self.imageSize = self.imageData?.count ?? 0
                self.color = .load( image: self.image )

                if let imageData = self.imageData, let imageFile = SitePreview.previewImageFile( for: self.siteName ) {
                    do { try imageData.write( to: imageFile ) }
                    catch {
                        wrn( "Couldn't save site preview image: %@ [>PII]", error.localizedDescription )
                        pii( "[>] %@: error: %@", self.siteName, error )
                    }
                }
            }
        }
    }
    #endif
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

extension ColorData {
    fileprivate static func load(image: UIImage?) -> ColorData? {
        guard let cgImage = image?.cgImage,
              let cgContext = CGContext( data: nil, width: Int( cgImage.width ), height: Int( cgImage.height ),
                                         bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue )
        else { return nil }
        cgContext.draw( cgImage, in: CGRect( x: 0, y: 0, width: cgImage.width, height: cgImage.height ) )
        guard let cgImage = cgContext.makeImage(), let pixelData = cgImage.dataProvider?.data as Data?
        else { return nil }

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
        return scoresByColor.sorted( by: { $0.value > $1.value } ).first?.key
    }
}
