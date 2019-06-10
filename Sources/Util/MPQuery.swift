//
// Created by Maarten Billemont on 2018-10-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPQuery {
    public let query: String?

    init(_ query: String?) {
        self.query = query
    }

    func find<V>(_ values: [V], keySupplier: @escaping (V) -> String) -> [Result<V>] {
        return values.map { value in Result( value: value, keySupplier: keySupplier ) }
                     .filter { result in result.matches( query: self.query ) }
    }

    class Result<V>: Hashable where V: Hashable {
        public let value:       V
        public let keySupplier: (V) -> String
        public let attributedKey = NSMutableAttributedString()
        public var matches       = [ String.Index ]()
        public var exact:       Bool {
            get {
                return (self.attributedKey.string.indices).elementsEqual( self.matches )
            }
        }

        init(value: V, keySupplier: @escaping (V) -> String) {
            self.value = value
            self.keySupplier = keySupplier
        }

        @discardableResult
        public func matches(query: String?) -> Bool {
            let key = self.keySupplier( self.value )
            self.attributedKey.setAttributedString( NSAttributedString( string: key ) )

            guard key.count > 0
            else {
                return query?.count == 0
            }
            guard let query = query, query.count > 0
            else {
                return true
            }

            // Consume query and key characters until one of them runs out, recording any matches against the result's key.
            var q = query.startIndex, k = key.startIndex, n = k
            while ((q < query.endIndex) && (k < key.endIndex)) {
                n = key.index( after: k )

                if query[q] == key[k] {
                    self.keyMatched( at: k, next: n )
                    q = query.index( after: q )
                }

                k = n
            }

            // If the match against the query broke before the end of the query, it failed.
            return !(q < query.endIndex)
        }

        private func keyMatched(at: String.Index, next: String.Index) {
            self.matches.append( at )
            self.attributedKey.addAttribute( NSAttributedStringKey.backgroundColor, value: UIColor.red,
                                             range: NSRange( at..<next, in: self.attributedKey.string ) )
        }

        static func ==(lhs: Result<V>, rhs: Result<V>) -> Bool {
            return lhs.value == rhs.value
        }

        func hash(into hasher: inout Hasher) {
            self.value.hash( into: &hasher )
        }

        func debugDescription() -> String {
            return "{Result: \(self.attributedKey.string)}"
        }
    }
}
