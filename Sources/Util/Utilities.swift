//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

let productName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Spectre"
let productBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
let productVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
let productIdentifier = Bundle.main.bundleIdentifier ?? "app.spectre"
let productGroup = "group.app.spectre"
let productAppleID = 1_526_402_806

@discardableResult
func using<V>(_ value: V, do: (inout V) -> Void) -> V {
    var value = value
    `do`(&value)
    return value
}

func none<V: Equatable>(if lhs: V, is rhs: V) -> V? {
    none(if: lhs) { $0 == rhs }
}

func none<V>(if value: V, where: (V) -> Bool) -> V? {
    `where`(value) ? nil : value
}

func scale(int value: UInt8, into: Range<Double>) -> Double {
    scale(value: Double(value), from: .zero ..< Double(UInt8.max), into: into)
}

func scale(value: Double, from: Range<Double>, into: Range<Double>) -> Double {
    into.lowerBound + (into.upperBound - into.lowerBound) * ((value - from.lowerBound) / (from.upperBound - from.lowerBound))
}

// Map a 0-max value such that it mirrors around a center point.
// 0 -> 0, center -> max, max -> 0
func mirror(ratio: Int, center: Int, max: Int) -> Int {
    if ratio < center {
        max * ratio / center
    }
    else {
        max - max * (ratio - center) / (max - center)
    }
}
