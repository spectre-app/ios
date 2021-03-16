//
// Created by Maarten Billemont on 2019-10-29.
//

import Foundation

public class WeakBox<E>: Equatable, CustomDebugStringConvertible {
    private weak var _value: AnyObject?

    private let name:  String
    public var  value: E? {
        get {
            self._value as? E
        }
        set {
            self._value = newValue as AnyObject
        }
    }

    public var debugDescription: String {
        "[\(self.value.flatMap { String( reflecting: $0 ) } ?? "gone: \(self.name)")]"
    }

    public init(_ value: E) {
        self.name = "\(String( reflecting: value ))"
        self.value = value
    }

    public static func ==(lhs: WeakBox<E>, rhs: WeakBox<E>) -> Bool {
        lhs._value === rhs._value
    }

    public static func ==(lhs: WeakBox<E>, rhs: E) -> Bool {
        lhs._value === rhs as AnyObject
    }

    public static func ==(lhs: WeakBox<E>, rhs: WeakBox<E>) -> Bool where E: Equatable {
        guard let lhs = lhs.value, let rhs = rhs.value
        else { return false }

        return lhs == rhs
    }

    public static func ==(lhs: WeakBox<E>, rhs: E) -> Bool where E: Equatable {
        lhs.value == rhs
    }
}

extension WeakBox: CustomStringConvertible where E: CustomStringConvertible {
    public var description: String {
        "<\(self.value?.description ?? "nil")>"
    }
}

extension WeakBox: Hashable where E: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine( self.value?.hashValue )
    }
}
