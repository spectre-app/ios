//
// Created by Maarten Billemont on 2021-07-29.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import Foundation
import Darwin

private typealias CGSVGDocumentReleaseFunction = @convention(c) (_ document: UnsafeMutableRawPointer?) -> Void
private typealias CGSVGDocumentCreateFromDataFunction = @convention(c) (_ data: CFData?, _ options: CFDictionary?) -> UnsafeMutableRawPointer?
private typealias imageWithCGSVGDocumentFunction = @convention(c) (_ class : AnyClass, _ selector: Selector, _ document: UnsafeMutableRawPointer?) -> UIImage?

private let MAGIC                                                             = "</svg>".data( using: .utf8 )
private let CGSVGDocumentRelease:        CGSVGDocumentReleaseFunction?        = load( "CGSVGDocumentRelease" )
private let CGSVGDocumentCreateFromData: CGSVGDocumentCreateFromDataFunction? = load( "CGSVGDocumentCreateFromData" )
private let imageWithCGSVGDocument:      Selector?                            = NSSelectorFromString( "_imageWithCGSVGDocument:" )

extension UIImage {
    static func isSVG(data: Data) -> Bool {
        MAGIC.flatMap {
            data.range( of: $0, options: .backwards,
                        in: max( data.startIndex, data.endIndex - 100 )..<data.endIndex )
        }
                != nil
    }

    static func svg(data: Data) -> UIImage? {
        guard let imageWithCGSVGDocument = imageWithCGSVGDocument, UIImage.responds( to: imageWithCGSVGDocument ),
              let document = CGSVGDocumentCreateFromData?( data as NSData, nil )
        else { return nil }
        defer {
            CGSVGDocumentRelease?( document )
        }

        let imageWithDocument = unsafeBitCast( UIImage.method( for: imageWithCGSVGDocument ), to: imageWithCGSVGDocumentFunction?.self )
        return imageWithDocument?( UIImage.self, imageWithCGSVGDocument, document )
    }
}
