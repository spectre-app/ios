//
// Created by Maarten Billemont on 2019-10-29.
//

import Foundation

public class WeakBox<E>: Equatable {
    private weak var _value: AnyObject?

    public var value: E? {
        get {
            self._value as? E
        }
        set {
            self._value = newValue as AnyObject
        }
    }

    public init(_ value: E) {
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

extension WeakBox: Hashable where E: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine( self.value?.hashValue )
    }
}
