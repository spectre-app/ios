//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

class Resources {
    static let shared = Resources()

    var vocabulary: [String]? {
        self.cachedLinesList(named: "enwiki-top-30000")
    }

    var publicSuffixes: [String]? {
        self.cachedLinesList(named: "public-suffix-list")
    }

    var countryCode3to2: [String: String]? {
        self.cachedMap(named: "country-codes")
    }

    private let cache = SingleLockBox(value: Cache<NSString, NSObject>(named: "Resources"))

    private init() {}

    private func cachedLinesList(named name: String, extension ext: String = "txt") -> [String]? {
        self.cache.use { cache in
            if let linesList = cache[name as NSString] as? [String] {
                return linesList
            }

            if let listURL = Bundle.main.url(forResource: name, withExtension: ext),
               let listData = try? Data(contentsOf: listURL),
               let listLines = String(data: listData, encoding: .utf8)?.split(separator: "\n").filter({
                   !$0.isEmpty && !$0.hasPrefix("//")
               }) {
                cache[name as NSString] = listLines as NSArray
                return listLines.map { String($0) }
            }

            wrn("Couldn't load resource for: \(name)")
            return nil
        }
    }

    private func cachedMap(named name: String, extension ext: String = "json") -> [String: String]? {
        self.cache.use { cache in
            if let map = cache[name as NSString] as? [String: String] {
                return map
            }

            if let mapURL = Bundle.main.url(forResource: name, withExtension: ext),
               let mapData = try? Data(contentsOf: mapURL),
               let map = try? JSONDecoder().decode([String: String].self, from: mapData) {
                cache[name as NSString] = map as NSObject
                return map
            }

            wrn("Couldn't load resource for: \(name)")
            return nil
        }
    }
}
