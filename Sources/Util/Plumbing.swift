//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

// The va_list C type is incompatible with CVaListPointer on x86_64.
// FIXME: https://bugs.swift.org/browse/SR-13779
#if arch(x86_64)
typealias va_list_c = va_list // swiftlint:disable:this type_name
#else
typealias va_list_c = CVaListPointer? // swiftlint:disable:this type_name
#endif

dynamic func property(of object: Any, withValue value: AnyObject) -> String? {
    var mirror: Mirror? = Mirror(reflecting: object)
    while let mirror_ = mirror {
        if let child = mirror_.children.first(where: { $0.value as AnyObject? === value }) {
            if child.label == nil {
                wrn("Missing label for mirror: \(mirror_), child: \(child)")
            }

            return child.label?.replacingOccurrences(of: ".*_\\$_", with: "", options: .regularExpression)
        }

        mirror = mirror_.superclassMirror
    }

    var type: AnyClass? = type(of: object) as? AnyClass
    while type != nil {
        var count: UInt32 = .zero

        // let properties = UnsafeBufferPointer( start: class_copyPropertyList( type, &count ), count: Int( count ) )
        // defer { properties.deallocate() }
        // for property in properties {
        //    if let propertyName = String.valid( property_getName( property ) ),
        //       let propertyValue = self.value( forKey: propertyName ) as AnyObject?,
        //       value === propertyValue {
        //        return propertyName
        //    }
        // }

        let ivars = UnsafeBufferPointer(start: class_copyIvarList(type, &count), count: Int(count))
        defer { ivars.deallocate() }
        for ivar in ivars {
            if let encoding = ivar_getTypeEncoding(ivar), encoding.pointee == 64,
               value === object_getIvar(object, ivar) as AnyObject? {
                return String.valid(ivar_getName(ivar))?
                    .replacingOccurrences(of: ".*_\\$_", with: "", options: .regularExpression)
            }
        }

        type = class_getSuperclass(type)
    }

    return nil
}

private let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)

func load<T>(_ name: String) -> T? {
    unsafeBitCast(dlsym(RTLD_DEFAULT, name), to: T?.self)
}

extension NSObject {
    dynamic var identityDescription: String {
        var description      = ""
        var type_: AnyClass? = Self.self
        while let type = type_ {
            description += "\(type):\n"
            var count: UInt32 = .zero
            let ivars         = UnsafeBufferPointer(start: class_copyIvarList(type, &count), count: Int(count))
            defer { ivars.deallocate() }

            for ivar in ivars {
                if let iname = String.valid(ivar_getName(ivar)) {
                    let ival = String.valid(ivar_getTypeEncoding(ivar)) == "@" ? object_getIvar(self, ivar) as AnyObject? : nil
                    description += " - \(iname): \(String(reflecting: ival))\n"
                }
            }

            type_ = class_getSuperclass(type)
        }

        return description
    }
}
