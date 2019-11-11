//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension NSObject {
    func propertyWithValue(_ value: AnyObject) -> String? {
        var count: UInt32 = 0
        guard let properties = class_copyPropertyList( type( of: self ), &count )
        else { return nil }
        defer { free( properties ) }

        for p in 0..<Int( count ) {
            guard let currentPropertyName = String( safeUTF8: property_getName( properties[p] ) )
            else { continue }

            if let ival = self.value( forKey: currentPropertyName ) as AnyObject?, ival === value {
                return currentPropertyName
            }
        }

        return nil
    }

    func ivarWithValue(_ value: AnyObject) -> String? {
        var type: AnyClass? = Swift.type( of: self )
        while (type != nil) {
            var count: UInt32 = 0
            guard let ivars = class_copyIvarList( type, &count )
            else { break }
            defer { free( ivars ) }

            for i in 0..<Int( count ) {
                if let ival = object_getIvar( self, ivars[i] ) as AnyObject?, ival === value {
                    return String( safeUTF8: ivar_getName( ivars[i] ) )
                }
            }

            type = class_getSuperclass( type )
        }

        return nil
    }
}
