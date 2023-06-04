//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

class Cache<Key: AnyObject, Value: AnyObject>: NSObject, NSCacheDelegate, LeakObserver {
    let cache = NSCache<Key, Value>()
    var isEnabled = true

    init(named name: String) {
        super.init()
        LeakRegistry.shared.register(self)

        self.cache.name = name
        self.cache.delegate = self

        LeakRegistry.shared.observers.register(observer: self)
    }

    func clear() {
        self.cache.removeAllObjects()
    }

    subscript(key: Key) -> Value? {
        get {
            self.cache.object(forKey: key)
        }
        set {
            if self.isEnabled, let newValue {
                self.cache.setObject(newValue, forKey: key)
            }
            else {
                self.cache.removeObject(forKey: key)
            }
        }
    }

    subscript(key: Key, cost cost: Int) -> Value {
        get { fatalError("This subscript is write-only.") }
        set {
            if self.isEnabled {
                self.cache.setObject(newValue, forKey: key, cost: cost)
            }
            else {
                self.cache.removeObject(forKey: key)
            }
        }
    }

    // NSCacheDelegate

    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // dbg( "Evicting from cache %@: %@", cache.name, obj )
    }

    // LeakObserver

    func willReportLeaks() {
        self.clear()
    }

    func shouldCancelOperations() {
        self.isEnabled = false
    }
}
