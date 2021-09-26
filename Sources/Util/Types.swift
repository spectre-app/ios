// =============================================================================
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

public enum AppError: LocalizedError {
    case cancelled
    case `issue`(_ error: Error? = nil, title: String, details: CustomStringConvertible? = nil)
    case `internal`(cause: String, details: CustomStringConvertible? = nil)
    case `state`(title: String, details: CustomStringConvertible? = nil)
    case `marshal`(SpectreMarshalError, title: String, details: CustomStringConvertible? = nil)

    public var errorDescription: String? {
        switch self {
            case .cancelled:
                return "Operation Cancelled"
            case .issue(let error, title: let title, _):
                return [ title, error?.localizedDescription ]
                        .compactMap( { $0 } ).joined( separator: ": " ).nonEmpty
            case .internal( _, _ ):
                return "Internal Inconsistency"
            case .state(let title, _):
                return title
            case .marshal(let error, let title, _):
                return [ title, error.localizedDescription ]
                        .compactMap( { $0 } ).joined( separator: ": " ).nonEmpty
        }
    }
    public var failureReason: String? {
        switch self {
            case .cancelled:
                return nil
            case .issue(let error, _, let details):
                return [ (error as NSError?)?.localizedFailureReason, details?.description ]
                        .compactMap( { $0 } ).joined( separator: "\n" ).nonEmpty
            case .internal(let cause, let details):
                return [ cause, details?.description ]
                        .compactMap( { $0 } ).joined( separator: "\n" ).nonEmpty
            case .state(_, let details):
                return details?.description
            case .marshal(let error, _, let details):
                return [ (error as NSError).localizedFailureReason, details?.description ]
                        .compactMap( { $0 } ).joined( separator: "\n" ).nonEmpty
        }
    }
    public var recoverySuggestion: String? {
        switch self {
            case .issue(let error, _, _):
                return (error as NSError?)?.localizedRecoverySuggestion
            case .marshal(let error, _, _):
                return (error as NSError).localizedRecoverySuggestion
            default:
                return nil
        }
    }
}

extension SpectreAlgorithm: Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [ SpectreAlgorithm ]( (.first)...(.last) )

    public var description:          String {
        String.valid( spectre_algorithm_short_name( self ) ) ?? "?"
    }
    public var localizedDescription: String {
        String.valid( spectre_algorithm_long_name( self ) ) ?? "?"
    }
}

extension SpectreCounter: Strideable, CustomStringConvertible {
    public var description: String {
        "\(self.rawValue)"
    }
}

extension SpectreIdenticon: Equatable {
    public static func == (lhs: SpectreIdenticon, rhs: SpectreIdenticon) -> Bool {
        lhs.leftArm == rhs.leftArm && lhs.body == rhs.body && lhs.rightArm == rhs.rightArm &&
                lhs.accessory == rhs.accessory && lhs.color == rhs.color
    }

    public var isUnset: Bool {
        self.color == .unset
    }

    public func encoded() -> String? {
        self.isUnset ? nil:
                .valid( spectre_identicon_encode( self ), consume: true )
    }

    public func text() -> String? {
        self.isUnset ? nil: [
            String( cString: self.leftArm ),
            String( cString: self.body ),
            String( cString: self.rightArm ),
            String( cString: self.accessory ),
        ].joined()
    }

    public func attributedText() -> NSAttributedString? {
        if self.isUnset {
            return nil
        }

        let shadow = NSShadow()
        shadow.shadowColor = Theme.current.color.shadow.get() // TODO: Update on theme change.
        shadow.shadowOffset = CGSize( width: 0, height: 1 )
        return self.text().flatMap {
            NSAttributedString( string: $0, attributes: [
                .foregroundColor: self.color.ui(),
                .shadow: shadow,
            ] )
        }
    }
}

extension SpectreKeyID: Hashable, CustomStringConvertible {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        withUnsafeBytes( of: lhs.bytes, { lhs in withUnsafeBytes( of: rhs.bytes, lhs.elementsEqual ) } )
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes( of: self.bytes, { hasher.combine( bytes: $0 ) } )
    }

    public var description: String {
        withUnsafeBytes( of: self.hex, { String.valid( $0 ) ?? "-" } )
    }
}

extension SpectreIdenticonColor {
    public func ui() -> UIColor {
        switch self {
            case .unset:
                return .clear
            case .red:
                return .red
            case .green:
                return .green
            case .yellow:
                return .yellow
            case .blue:
                return .blue
            case .magenta:
                return .magenta
            case .cyan:
                return .cyan
            case .mono:
                if #available( iOS 13, * ) {
                    return .label
                }
                else {
                    return .lightText
                }
            default:
                fatalError( "Unsupported color: \(self)" )
        }
    }
}

extension SpectreKeyPurpose: CustomStringConvertible {
    public var description: String {
        switch self {
            case .authentication:
                return "password"
            case .identification:
                return "login name"
            case .recovery:
                return "security answer"
            @unknown default:
                return ""
        }
    }

    public var scope: String? {
        .valid( spectre_purpose_scope( .authentication ) )
    }
}

extension SpectreFormat: Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [ SpectreFormat ]( (.first)...(.last) )

    public var name: String? {
        .valid( spectre_format_name( self ) )
    }

    public var uti:         String? {
        switch self {
            case .none:
                return nil
            case .flat:
                return "app.spectre.user.mpsites"
            case .JSON:
                return "app.spectre.user.json"
            default:
                fatalError( "Unsupported format: \(self)" )
        }
    }
    public var description: String {
        switch self {
            case .none:
                return "No Output"
            case .flat:
                return "v1 (sites)"
            case .JSON:
                return "v2 (json)"
            default:
                fatalError( "Unsupported format: \(self.rawValue)" )
        }
    }

    public func `is`(url: URL) -> Bool {
        var count      = 0
        let extensions = UnsafeBufferPointer( start: spectre_format_extensions( self, &count ), count: count )
        defer {
            extensions.deallocate()
        }

        return extensions.map { String.valid( $0 ) }.contains( url.pathExtension )
    }
}

extension SpectreResultType: CustomStringConvertible, CaseIterable {
    public static let allCases: [SpectreResultType] = [
        .templateMaximum, .templateLong, .templateMedium, .templateShort,
        .templateBasic, .templatePIN, .templateName, .templatePhrase,
        .statePersonal, .stateDevice, .deriveKey,
    ]
    static let recommendedTypes: [SpectreKeyPurpose: [SpectreResultType]] = [
        .authentication: [ .templateMaximum, .templatePhrase, .templateLong, .templateBasic, .templatePIN ],
        .identification: [ .templateName, .templateBasic, .templateShort ],
        .recovery: [ .templatePhrase ],
    ]

    public var abbreviation:         String {
        String.valid( spectre_type_abbreviation( self ) ) ?? "?"
    }
    public var description:          String {
        String.valid( spectre_type_short_name( self ) ) ?? "?"
    }
    public var localizedDescription: String {
        String.valid( spectre_type_long_name( self ) ) ?? "?"
    }

    public var nonEmpty: Self? {
        self == .none ? nil: self
    }

    func `in`(class: SpectreResultClass) -> Bool {
        self.rawValue & UInt32( `class`.rawValue ) == UInt32( `class`.rawValue )
    }

    func has(feature: SpectreResultFeature) -> Bool {
        self.rawValue & UInt32( feature.rawValue ) == UInt32( feature.rawValue )
    }
}

extension UnsafeMutablePointer where Pointee == SpectreMarshalledFile {
    public func spectre_get(path: String...) -> Bool? {
        self.pointee.data.spectre_get( path: path )
    }

    public func spectre_get(path: String...) -> Double? {
        self.pointee.data.spectre_get( path: path )
    }

    public func spectre_get(path: String...) -> String? {
        self.pointee.data.spectre_get( path: path )
    }

    public func spectre_get(path: String...) -> Date? {
        self.pointee.data.spectre_get( path: path )
    }

    @discardableResult
    public func spectre_set(_ value: Bool, path: String...) -> Bool {
        self.pointee.data.spectre_set( value, path: path )
    }

    @discardableResult
    public func spectre_set(_ value: Double, path: String...) -> Bool {
        self.pointee.data.spectre_set( value, path: path )
    }

    @discardableResult
    public func spectre_set(_ value: String?, path: String...) -> Bool {
        self.pointee.data.spectre_set( value, path: path )
    }

    public func spectre_find(path: String...) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        self.pointee.data.spectre_find( path: path )
    }
}

extension SpectreMarshalledData {
    public func spectre_get(path: String...) -> Bool? {
        withUnsafePointer( to: self ) {
            Optional( $0 ).spectre_get( path: path )
        }
    }

    public func spectre_get(path: String...) -> Double? {
        withUnsafePointer( to: self ) {
            Optional( $0 ).spectre_get( path: path )
        }
    }

    public func spectre_get(path: String...) -> String? {
        withUnsafePointer( to: self ) {
            Optional( $0 ).spectre_get( path: path )
        }
    }

    public func spectre_get(path: String...) -> Date? {
        withUnsafePointer( to: self ) {
            Optional( $0 ).spectre_get( path: path )
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: Bool, path: String...) -> Bool {
        withUnsafeMutablePointer( to: &self ) {
            Optional( $0 ).spectre_set( value, path: path )
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: Double, path: String...) -> Bool {
        withUnsafeMutablePointer( to: &self ) {
            Optional( $0 ).spectre_set( value, path: path )
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: String?, path: String...) -> Bool {
        withUnsafeMutablePointer( to: &self ) {
            Optional( $0 ).spectre_set( value, path: path )
        }
    }

    public func spectre_find(path: String...) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        withUnsafePointer( to: self ) {
            Optional( $0 ).spectre_find( path: path )
        }
    }
}

extension Optional where Wrapped == UnsafeMutablePointer<SpectreMarshalledData> {
    public func spectre_get(path: String...) -> Bool? {
        self.spectre_get( path: path )
    }

    public func spectre_get(path: String...) -> Double? {
        self.spectre_get( path: path )
    }

    public func spectre_get(path: String...) -> String? {
        self.spectre_get( path: path )
    }

    public func spectre_get(path: String...) -> Date? {
        self.spectre_get( path: path )
    }

    @discardableResult
    public func spectre_set(_ value: Bool, path: String...) -> Bool {
        self.spectre_set( value, path: path )
    }

    @discardableResult
    public func spectre_set(_ value: Double, path: String...) -> Bool {
        self.spectre_set( value, path: path )
    }

    @discardableResult
    public func spectre_set(_ value: String?, path: String...) -> Bool {
        self.spectre_set( value, path: path )
    }

    public func spectre_find(path: String...) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        self.spectre_find( path: path )
    }
}

extension Optional where Wrapped == UnsafePointer<SpectreMarshalledData> {
    public func spectre_get(path: [String]) -> Bool? {
        path.withCStringVaList { spectre_marshal_data_vget_bool( self, $0 ) }
    }

    public func spectre_get(path: [String]) -> Double? {
        path.withCStringVaList { spectre_marshal_data_vget_num( self, $0 ) }
    }

    public func spectre_get(path: [String]) -> String? {
        path.withCStringVaList { .valid( spectre_marshal_data_vget_str( self, $0 ) ) }
    }

    public func spectre_get(path: [String]) -> Date? {
        path.withCStringVaList {
            let time = spectre_get_timegm( spectre_marshal_data_vget_str( self, $0 ) )
            if time == ERR {
                return nil
            }

            return Date( timeIntervalSince1970: TimeInterval( time ) )
        }
    }

    public func spectre_find(path: [String]) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        guard let found = path.withCStringVaList( body: { spectre_marshal_data_vfind( self, $0 ) } )
        else { return nil }

        return UnsafeBufferPointer( start: found.pointee.children, count: found.pointee.children_count )
    }
}

extension Optional where Wrapped == UnsafeMutablePointer<SpectreMarshalledData> {
    public func spectre_get(path: [String]) -> Bool? {
        path.withCStringVaList { spectre_marshal_data_vget_bool( self, $0 ) }
    }

    public func spectre_get(path: [String]) -> Double? {
        path.withCStringVaList { spectre_marshal_data_vget_num( self, $0 ) }
    }

    public func spectre_get(path: [String]) -> String? {
        path.withCStringVaList { .valid( spectre_marshal_data_vget_str( self, $0 ) ) }
    }

    public func spectre_get(path: [String]) -> Date? {
        path.withCStringVaList {
            let time = spectre_get_timegm( spectre_marshal_data_vget_str( self, $0 ) )
            if time == ERR {
                return nil
            }

            return Date( timeIntervalSince1970: TimeInterval( time ) )
        }
    }

    @discardableResult
    public func spectre_set(_ value: Bool, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_bool( value, self, $0 ) }
    }

    @discardableResult
    public func spectre_set(_ value: Double, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_num( value, self, $0 ) }
    }

    @discardableResult
    public func spectre_set(_ value: String?, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_str( value, self, $0 ) }
    }

    public func spectre_find(path: [String]) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        guard let found = path.withCStringVaList( body: { spectre_marshal_data_vfind( self, $0 ) } )
        else { return nil }

        return UnsafeBufferPointer( start: found.pointee.children, count: found.pointee.children_count )
    }
}
