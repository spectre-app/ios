//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

let productName       = Bundle.main.object( forInfoDictionaryKey: "CFBundleDisplayName" ) as? String ?? "Spectre"
let productIdentifier = Bundle.main.object( forInfoDictionaryKey: "CFBundleIdentifier" ) as? String ?? "app.spectre"
let productVersion    = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String ?? "0"
let productBuild      = Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String ?? "0"

postfix operator <

postfix public func <(a: Any?) -> Any? {
    (a as? String)< ?? (a as? Int)< ?? (a as? Int64)<
}

postfix public func <(s: String?) -> String? {
    (s?.isEmpty ?? true) ? nil: s
}

postfix public func <(i: Int?) -> Int? {
    i ?? 0 == 0 ? nil: i
}

postfix public func <(i: Int64?) -> Int64? {
    i ?? 0 == 0 ? nil: i
}

func ratio(of value: UInt8, from: Double, to: Double) -> Double {
    from + (to - from) * (Double( value ) / Double( UInt8.max ))
}

prefix public func -(a: UIEdgeInsets) -> UIEdgeInsets {
    UIEdgeInsets( top: -a.top, left: -a.left, bottom: -a.bottom, right: -a.right )
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
