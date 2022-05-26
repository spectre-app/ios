//
// Created by Maarten Billemont on 2022-05-25.
// Copyright (c) 2022 Lyndir. All rights reserved.
//

import Foundation

class Cache<Key: AnyObject, Value: AnyObject>: NSObject, NSCacheDelegate, LeakObserver {
    let cache = NSCache<Key, Value>()

    init(named name: String) {
        super.init()

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
            if let newValue = newValue {
                self.cache.setObject(newValue, forKey: key)
            } else {
                self.cache.removeObject( forKey: key )
            }
        }
    }
    subscript(key: Key, cost cost: Int) -> Value {
        get { fatalError( "This subscript is write-only." ) }
        set { self.cache.setObject( newValue, forKey: key, cost: cost ) }
    }

    // NSCacheDelegate

    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        dbg( "Evicting from cache %@: %@", cache.name, obj )
    }

    // LeakObserver

    func willReportLeaks() {
        self.clear()
    }
}
