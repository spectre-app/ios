// =============================================================================
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

let productName       = Bundle.main.object( forInfoDictionaryKey: "CFBundleDisplayName" ) as? String ?? "Spectre"
let productBuild      = Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String ?? "0"
let productVersion    = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String ?? "0"
let productIdentifier = Bundle.main.bundleIdentifier ?? "app.spectre"
let productGroup      = "group.app.spectre"
let productAppleID    = 1526402806

@discardableResult
func using<V>(_ value: V, _ initializer: (V) -> Void) -> V {
    initializer( value )
    return value
}

func scale(int value: UInt8, into: Range<Double>) -> Double {
    scale( value: Double( value ), from: 0..<Double( UInt8.max ), into: into )
}

func scale(value: Double, from: Range<Double>, into: Range<Double>) -> Double {
    into.lowerBound + (into.upperBound - into.lowerBound) * ((value - from.lowerBound) / (from.upperBound - from.lowerBound))
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
