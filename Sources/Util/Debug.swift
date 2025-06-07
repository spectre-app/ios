//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

#if DEBUG
var debuggedObjects = [WeakBox<Any>]()

@discardableResult
func debugObject<O: AnyObject>(_ object: O, ifDebugging other: AnyObject? = nil) -> O {
    if !isDebuggingObject(object), other == nil || isDebuggingObject(other) {
        debuggedObjects.append(WeakBox(object))
        LeakRegistry.shared.setDebugging(object)
        dbg(ifDebugging: object, "Started debugging: \(ObjectIdentifier(object).identity): \(object)")
    }

    return object
}

func isDebuggingObject(_ object: AnyObject?) -> Bool {
    guard let object
    else { return false }

    return debuggedObjects.contains(WeakBox(object))
}
#endif
