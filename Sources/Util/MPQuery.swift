//
// Created by Maarten Billemont on 2018-10-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPQuery {
    public let query: String

    init(_ query: String) {
        self.query = query
    }

    func matches<V>(_ value: V, key: String)
                    -> Result<V>? {
        let result = Result( value: value, key: key )
        guard self.query.count > 0
        else {
            return result
        }
        guard key.count > 0
        else {
            return nil
        }

        // Consume query and key characters until one of them runs out, recording any matches against the result's key.
        var q = self.query.startIndex, k = key.startIndex
        while ((q < self.query.endIndex) && (k < key.endIndex)) {
            if self.query[q] == key[k] {
                result.keyMatched( at: k )
                q = self.query.index( after: q )
            }

            k = key.index( after: k )
        }

        // If the match against the query broke before the end of the query, it failed.
        return (q < self.query.endIndex) ? nil: result
    }

    func find<V>(_ values: [V], valueToKey: (V) -> String) -> [Result<V>] {
        var results = [ Result<V> ]()
        for value in values {
            if let result = self.matches( value, key: valueToKey( value ) ) {
                results.append( result )
            }
        }

        return results
    }

    class Result<V> : NSObject where V: Hashable {
        let value: V
        let key:   String
        var keyMatched = Set<String.Index>()

        init(value: V, key: String) {
            self.value = value
            self.key = key
        }

        func keyMatched(at k: String.Index) {
            self.keyMatched.insert( k )
        }

        override func isEqual(_ object: Any?) -> Bool {
            if let object = object as? Result<V> {
                return self.value == object.value && self.key == object.key && self.keyMatched == object.keyMatched
            } else {
                return false
            }
        }

        override var hash: Int {
            return self.value.hashValue
        }

        func debugDescription() -> String {
            return "{Result: \(self.key)}"
        }
    }
}
