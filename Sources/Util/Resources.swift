//
// Created by Maarten Billemont on 2021-05-20.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

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
