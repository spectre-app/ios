//
// Created by Maarten Billemont on 2019-05-13.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension String {
    /** Create a String from a signed c-string of valid UTF8 bytes. */
    init?(validate pointer: UnsafePointer<CSignedChar>?, deallocate: Bool = false) {
        guard let pointer = pointer
        else { return nil }
        defer { if deallocate { pointer.deallocate() } }

        self.init( validatingUTF8: pointer )
    }

    /** Create a String from an unsigned c-string of UTF8 bytes. */
    init?(decode pointer: UnsafePointer<CUnsignedChar>?, deallocate: Bool = false) {
        self.init( decode: pointer, as: Unicode.UTF8.self, deallocate: deallocate )
    }

    /** Create a String from an unsigned c-string of bytes in the given encoding. */
    init?<E>(decode pointer: UnsafePointer<E.CodeUnit>?, as encoding: E.Type, deallocate: Bool = false) where E: _UnicodeEncoding {
        guard let pointer = pointer
        else { return nil }
        defer { if deallocate { pointer.deallocate() } }

        self.init( decodingCString: pointer, as: encoding )
    }

    /** Create a String from an unsigned buffer of length-bytes in the given encoding. */
    init?(decode pointer: UnsafePointer<CUnsignedChar>?, as encoding: String.Encoding = .utf8, length: Int, deallocate: Bool = false) {
        // This API is not expected to mutate the bytes.
        self.init( decode: UnsafeMutableRawPointer( mutating: pointer ), as: encoding, length: length, deallocate: deallocate )
    }

    /** Create a String from a raw buffer of length-bytes in the given encoding. */
    init?(decode pointer: UnsafeRawPointer?, as encoding: String.Encoding = .utf8, length: Int, deallocate: Bool = false) {
        // This API is not expected to mutate the bytes.
        self.init( decode: UnsafeMutableRawPointer( mutating: pointer ), as: encoding, length: length, deallocate: deallocate )
    }

    /** Create a String from a raw buffer of length-bytes in the given encoding. */
    init?(decode pointer: UnsafeMutableRawPointer?, as encoding: String.Encoding = .utf8, length: Int, deallocate: Bool = false) {
        guard let pointer = pointer
        else { return nil }

        self.init( bytesNoCopy: pointer, length: length, encoding: encoding, freeWhenDone: deallocate )
    }
}
