//
// Created by Maarten Billemont on 2019-05-13.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension String {
    /** Create a String from a signed c-string of valid UTF8 bytes. */
    static func valid(_ pointer: UnsafePointer<CSignedChar>?, deallocate: Bool = false) -> String? {
        defer { if deallocate { pointer?.deallocate() } }
        return pointer.flatMap { self.init( validatingUTF8: $0 ) }
    }

    /** Create a String from an unsigned c-string of valid UTF8 bytes. */
    static func valid(_ pointer: UnsafePointer<CUnsignedChar>?, deallocate: Bool = false) -> String? {
        defer { if deallocate { pointer?.deallocate() } }
        return self.decodeCString( pointer, as: Unicode.UTF8.self, repairingInvalidCodeUnits: false )?.result
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeRawPointer?, length: Int, deallocate: Bool = false) -> String? {
        self.valid(pointer?.bindMemory(to: UInt8.self, capacity: length), deallocate: deallocate)
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeMutableRawPointer?, length: Int, deallocate: Bool = false) -> String? {
        self.valid(pointer?.bindMemory(to: UInt8.self, capacity: length), deallocate: deallocate)
    }
}
