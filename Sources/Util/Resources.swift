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

actor Resources {
    static let shared = Resources()

    private let cache = Cache<NSString, NSObject>( named: "Resources" )

    private func cachedLinesList(named name: String, extension ext: String = "txt") -> [String]? {
        if let linesList = self.cache[name as NSString] as? [String] {
            return linesList
        }

        if let listURL = Bundle.main.url( forResource: name, withExtension: ext ),
           let listData = try? Data( contentsOf: listURL ),
           let listLines = String( data: listData, encoding: .utf8 )?.split( separator: "\n" ).filter( {
               !$0.isEmpty && !$0.hasPrefix( "//" )
           } ) {
            self.cache[name as NSString] = listLines as NSArray
            return listLines.map { String( $0 ) }
        }

        wrn( "Couldn't load resource for: %@", name )
        return nil
    }

    private func cachedMap(named name: String, extension ext: String = "json") -> [String: String]? {
        if let map = self.cache[name as NSString] as? [String: String] {
            return map
        }

        if let mapURL = Bundle.main.url( forResource: name, withExtension: ext ),
           let mapData = try? Data( contentsOf: mapURL ),
           let map = try? JSONDecoder().decode( [ String: String].self, from: mapData ) {
            self.cache[name as NSString] = map as NSObject
            return map
        }

        wrn( "Couldn't load resource for: %@", name )
        return nil
    }

    var vocabulary:     [String]? {
        self.cachedLinesList( named: "enwiki-top-30000" )
    }
    var publicSuffixes: [String]? {
        self.cachedLinesList( named: "public-suffix-list" )
    }
    var countryCode3to2: [String: String]? {
        self.cachedMap( named: "country-codes" )
    }
}
