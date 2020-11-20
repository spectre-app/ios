//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

let productName       = Bundle.main.object( forInfoDictionaryKey: "CFBundleDisplayName" ) as? String ?? "Spectre"
let productBuild      = Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String ?? "0"
let productVersion    = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String ?? "0"
let productIdentifier = Bundle.main.bundleIdentifier ?? "app.spectre"
let productGroup      = "group.app.spectre"

func using<V>(_ value: V, _ initializer: (V) -> Void) -> V {
    initializer( value )
    return value
}

func cached<F: Hashable, T>(_ block: @escaping (F) -> T) -> (F) -> T {
    var cache = [ F: T ]()

    return { f in
        if let cached = cache[f] {
            return cached
        }

        let missed = block( f )
        cache[f] = missed
        return missed
    }
}

func always<F, T>(_ value: T) -> (F) -> T {
    { _ in value }
}

func ratio(of value: UInt8, from: Double, to: Double) -> Double {
    from + (to - from) * (Double( value ) / Double( UInt8.max ))
}

// Map a 0-max value such that it mirrors around a center point.
// 0 -> 0, center -> max, max -> 0
func mirror(ratio: Int, center: Int, max: Int) -> Int {
    if ratio < center {
        return max * ratio / center
    }
    else {
        return max - max * (ratio - center) / (max - center)
    }
}
