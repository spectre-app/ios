// =============================================================================
// Created by Maarten Billemont on 2021-05-20.
// Copyright (c) 2021 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

private let cache = NSCache<NSString, NSArray>()

private func cachedLinesList(named name: String, extension ext: String = "txt") -> [String]? {
    if let linesList = cache.object( forKey: name as NSString ) as? [String] {
        return linesList
    }

    if let listURL = Bundle.main.url( forResource: name, withExtension: ext ),
       let listData = try? Data( contentsOf: listURL ),
       let listLines = String( data: listData, encoding: .utf8 )?.split( separator: "\n" ).filter( {
           !$0.isEmpty && !$0.hasPrefix( "//" )
       } ) {
        let linesList = listLines as NSArray
        cache.setObject( linesList, forKey: name as NSString )
        return linesList as? [String]
    }

    return nil
}

var dictionary:     [String]? {
    cachedLinesList( named: "enwiki-top-30000" )
}
var publicSuffixes: [String]? {
    cachedLinesList( named: "public-suffix-list" )
}
