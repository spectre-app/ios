//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

// The va_list C type is incompatible with CVaListPointer on x86_64.
// FIXME: https://bugs.swift.org/browse/SR-13779
#if arch( x86_64 )
typealias va_list_c = va_list
#else
typealias va_list_c = CVaListPointer?
#endif

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
    dynamic func property(withValue value: AnyObject) -> String? {
        var mirror: Mirror? = Mirror.init( reflecting: self )
        while let mirror_ = mirror {
            if let child = mirror_.children.first( where: { $0.value as AnyObject? === value } ) {
                if child.label == nil {
                    wrn( "Missing label for mirror: %@, child: %@", mirror_, child )
                }

                return child.label?.replacingOccurrences( of: ".*_\\$_", with: "", options: .regularExpression )
            }

            mirror = mirror_.superclassMirror
        }

        var type: AnyClass? = Self.self
        while (type != nil) {
            var count: UInt32 = 0

//            if let properties = class_copyPropertyList( type, &count ) {
//                defer { free( properties ) }
//
//                for p in 0..<Int( count ) {
//                    if let propertyName = String.valid( property_getName( properties[p] ) ),
//                       let propertyValue = self.value( forKey: propertyName ) as AnyObject?,
//                       value === propertyValue {
//                        return propertyName
//                    }
//                }
//            }

            if let ivars = class_copyIvarList( type, &count ) {
                defer { free( ivars ) }

                for i in 0..<Int( count ) {
                    let ivar = ivars[i]

                    if let encoding = ivar_getTypeEncoding( ivar ), encoding.pointee == 64,
                       value === object_getIvar( self, ivar ) as AnyObject? {
                        return String.valid( ivar_getName( ivar ) )?
                                     .replacingOccurrences( of: ".*_\\$_", with: "", options: .regularExpression )
                    }
                }
            }

            type = class_getSuperclass( type )
        }

        return nil
    }

    dynamic var identityDescription: String {
        var description      = ""
        var type_: AnyClass? = Self.self
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
