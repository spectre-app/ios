// =============================================================================
// Created by Maarten Billemont on 2021-07-29.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation
import Darwin

private typealias CGSVGDocumentReleaseFunction =
        @convention(c) (_ document: UnsafeMutableRawPointer?) -> Void
private typealias CGSVGDocumentCreateFromDataFunction =
        @convention(c) (_ data: CFData?, _ options: CFDictionary?) -> UnsafeMutableRawPointer?
private typealias ImageWithCGSVGDocumentFunction =
        @convention(c) (_ type: AnyClass, _ selector: Selector, _ document: UnsafeMutableRawPointer?) -> UIImage?

private let MAGIC                                                             = "</svg>".data( using: .utf8 )
private let CGSVGDocumentRelease:        CGSVGDocumentReleaseFunction?        = load( "CGSVGDocumentRelease" )
private let CGSVGDocumentCreateFromData: CGSVGDocumentCreateFromDataFunction? = load( "CGSVGDocumentCreateFromData" )
private let imageWithCGSVGDocument:      Selector?                            = Selector( ("_imageWithCGSVGDocument:") )

extension UIImage {
    static func isSVG(data: Data) -> Bool {
        MAGIC.flatMap {
            data.range( of: $0, options: .backwards, in: max( data.startIndex, data.endIndex - 100 )..<data.endIndex )
        } != nil
    }

    static func svg(data: Data) -> UIImage? {
        guard let imageWithCGSVGDocument = imageWithCGSVGDocument, UIImage.responds( to: imageWithCGSVGDocument ),
              let document = CGSVGDocumentCreateFromData?( data as NSData, nil )
        else { return nil }
        defer {
            CGSVGDocumentRelease?( document )
        }

        let imageWithDocument = unsafeBitCast( UIImage.method( for: imageWithCGSVGDocument ), to: ImageWithCGSVGDocumentFunction?.self )
        return imageWithDocument?( UIImage.self, imageWithCGSVGDocument, document )
    }
}
