//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

func withVaStrings<R>(_ strings: [StaticString], terminate: Bool = true, body: (CVaListPointer) -> R) -> R {
    var va: [CVarArg] = strings.map { $0.utf8Start }
    if terminate {
        va.append( Int( bitPattern: nil ) )
    }
    defer {
        va.forEach { free( $0 as? UnsafeMutablePointer<Int8> ) }
    }

    return withVaList( va, body )
}

extension NSObject {
    dynamic func propertyWithValue(_ value: AnyObject) -> String? {
        var count: UInt32 = 0
        guard let properties = class_copyPropertyList( type( of: self ), &count )
        else { return nil }
        defer { free( properties ) }

        for p in 0..<Int( count ) {
            guard let currentPropertyName = String.valid( property_getName( properties[p] ) )
            else { continue }

            if let ival = self.value( forKey: currentPropertyName ) as AnyObject?, ival === value {
                return currentPropertyName
            }
        }

        return nil
    }

    dynamic func ivarWithValue(_ value: AnyObject) -> String? {
        var type: AnyClass? = Swift.type( of: self )
        while (type != nil) {
            var count: UInt32 = 0
            guard let ivars = class_copyIvarList( type, &count )
            else { break }
            defer { free( ivars ) }

            for i in 0..<Int( count ) {
                let ivar = ivars[i]
                if String.valid( ivar_getTypeEncoding( ivar ) ) == "@",
                   let ival = object_getIvar( self, ivar ) as AnyObject?,
                   ival === value {
                    return .valid( ivar_getName( ivar ) )
                }
            }

            type = class_getSuperclass( type )
        }

        return nil
    }

    dynamic var identityDescription: String {
        var description      = ""
        var type_: AnyClass? = Swift.type( of: self )
        while let type = type_ {
            description += "\(type):\n"
            var count: UInt32 = 0
            guard let ivars = class_copyIvarList( type, &count )
            else { break }
            defer { free( ivars ) }

            for i in 0..<Int( count ) {
                let ivar = ivars[i]
                if let iname = String.valid( ivar_getName( ivar ) ) {
                    let ival = String.valid( ivar_getTypeEncoding( ivar ) ) == "@" ? object_getIvar( self, ivar ) as AnyObject?: nil
                    description += " - \(iname): \(String( reflecting: ival ))\n"
                }
            }

            type_ = class_getSuperclass( type )
        }

        return description
    }
}