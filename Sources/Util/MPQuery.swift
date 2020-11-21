//
// Created by Maarten Billemont on 2018-10-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPQuery {
    public let query: String?

    init(_ query: String?) {
        self.query = query
    }

    func filter<V>(_ values: [V], key keySupplier: @escaping (V) -> String) -> [Result<V>] {
        values.map { value in Result( value: value, keySupplier: keySupplier ) }
              .filter { result in result.matches( query: self.query ) }
    }

    class Result<V>: Hashable where V: Hashable {
        public let value:       V
        public let keySupplier: (V) -> String
        public private(set) var attributedKey = NSAttributedString()
        public private(set) var matches       = [ String.Index ]()
        public var isExact: Bool {
            (self.attributedKey.string.indices).elementsEqual( self.matches )
        }
        public var flags = Set<Int>()

        init(value: V, keySupplier: @escaping (V) -> String) {
            self.value = value
            self.keySupplier = keySupplier
        }

        @discardableResult
        public func matches(query: String?) -> Bool {
            let key           = self.keySupplier( self.value )
            let attributedKey = NSMutableAttributedString( string: key )
            var matches       = [ String.Index ]()
            defer {
                self.attributedKey = attributedKey
                self.matches = matches
            }

            guard key.count > 0
            else { return query?.count == 0 }
            guard let query = query, query.count > 0
            else { return true }

            // Consume query and key characters until one of them runs out, recording any matches against the result's key.
            var q = query.startIndex, k = key.startIndex, n = k
            while ((q < query.endIndex) && (k < key.endIndex)) {
                n = key.index( after: k )

                if query[q] == key[k] {
                    matches.append( k )
                    attributedKey.addAttribute( NSAttributedString.Key.backgroundColor, value: UIColor.red,
                                                range: NSRange( k..<n, in: key ) )
                    q = query.index( after: q )
                }

                k = n
            }

            // If the match against the query broke before the end of the query, it failed.
            return !(q < query.endIndex)
        }

        static func ==(lhs: Result<V>, rhs: Result<V>) -> Bool {
            lhs.value == rhs.value
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.value )
        }

        func debugDescription() -> String {
            "{Result: \(self.attributedKey.string)}"
        }
    }
}
