//
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

extension MPAlgorithmVersion: Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [ MPAlgorithmVersion ]( (.first)...(.last) )

    public func distance(to other: MPAlgorithmVersion) -> Int32 {
        Int32( other.rawValue ) - Int32( self.rawValue )
    }

    public func advanced(by n: Int32) -> MPAlgorithmVersion {
        MPAlgorithmVersion( rawValue: UInt32( Int32( self.rawValue ) + n ) )!
    }

    public var description: String {
        "v\(self.rawValue)"
    }
}

public enum AppError: LocalizedError {
    case cancelled
    case `issue`(_ error: Error? = nil, title: String, details: CustomStringConvertible? = nil)
    case `internal`(cause: String, details: CustomStringConvertible? = nil)
    case `state`(title: String, details: CustomStringConvertible? = nil)
    case `marshal`(MPMarshalError, title: String, details: CustomStringConvertible? = nil)

    public var errorDescription: String? {
        switch self {
            case .cancelled:
                return "Operation Cancelled"
            case .issue(_, title: let title, _):
                return title
            case .internal( _, _ ):
                return "Internal Inconsistency"
            case .state(let title, _):
                return title
            case .marshal(_, let title, _):
                return title
        }
    }
    public var failureReason: String? {
        switch self {
            case .cancelled:
                return nil
            case .issue(let error, _, let details):
                return [ details?.description, error?.localizedDescription, (error as NSError?)?.localizedFailureReason ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
            case .internal(let cause, let details):
                return [ cause, details?.description ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
            case .state(_, let details):
                return details?.description
            case .marshal(let error, _, let details):
                return [ error.localizedDescription, (error as NSError).localizedFailureReason, details?.description ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
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

extension MPIdenticon: Equatable {
    public static func ==(lhs: MPIdenticon, rhs: MPIdenticon) -> Bool {
        lhs.leftArm == rhs.leftArm && lhs.body == rhs.body && lhs.rightArm == rhs.rightArm &&
                lhs.accessory == rhs.accessory && lhs.color == rhs.color
    }

    public func encoded() -> String? {
        self.color == .unset ? nil: .valid( mpw_identicon_encode( self ), consume: true )
    }

    public func text() -> String? {
        if self.color == .unset {
            return nil
        }

        return [ String( cString: self.leftArm ),
                 String( cString: self.body ),
                 String( cString: self.rightArm ),
                 String( cString: self.accessory ) ].joined()
    }

    public func attributedText() -> NSAttributedString? {
        if self.color == .unset {
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

extension MPKeyID: Hashable, CustomStringConvertible {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        withUnsafeBytes( of: lhs.bytes, { lhs in withUnsafeBytes( of: rhs.bytes, { rhs in lhs.elementsEqual( rhs ) } ) } )
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes( of: self.bytes, { hasher.combine( bytes: $0 ) } )
    }

    public var description: String {
        withUnsafeBytes( of: self.hex, { String.valid( $0 ) ?? "-" } )
    }
}

extension MPIdenticonColor {
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

extension MPKeyPurpose: CustomStringConvertible {
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
        .valid( mpw_purpose_scope( .authentication ) )
    }
}

extension MPMarshalFormat: Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [ MPMarshalFormat ]( (.first)...(.last) )

    public func distance(to other: MPMarshalFormat) -> Int32 {
        Int32( other.rawValue ) - Int32( self.rawValue )
    }

    public func advanced(by n: Int32) -> MPMarshalFormat {
        MPMarshalFormat( rawValue: UInt32( Int32( self.rawValue ) + n ) )!
    }

    public var name: String? {
        .valid( mpw_format_name( self ) )
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
}

extension MPResultType: CustomStringConvertible, CaseIterable {
    public static let allCases: [MPResultType] = [
        .templateMaximum, .templateLong, .templateMedium, .templateShort,
        .templateBasic, .templatePIN, .templateName, .templatePhrase,
        .statefulPersonal, .statefulDevice, .deriveKey,
    ]
    static let recommendedTypes: [MPKeyPurpose: [MPResultType]] = [
        .authentication: [ .templateMaximum, .templatePhrase, .templateLong, .templateBasic, .templatePIN ],
        .identification: [ .templateName, .templateBasic, .templateShort ],
        .recovery: [ .templatePhrase ],
    ]

    public var abbreviation:         String {
        String.valid( mpw_type_abbreviation( self ) ) ?? "?"
    }
    public var description:          String {
        String.valid( mpw_type_short_name( self ) ) ?? "?"
    }
    public var localizedDescription: String {
        String.valid( mpw_type_long_name( self ) ) ?? "?"
    }

    public var nonEmpty: Self? {
        self == .none ? nil: self
    }

    func `in`(class c: MPResultTypeClass) -> Bool {
        self.rawValue & UInt32( c.rawValue ) == UInt32( c.rawValue )
    }

    func has(feature f: MPSiteFeature) -> Bool {
        self.rawValue & UInt32( f.rawValue ) == UInt32( f.rawValue )
    }
}

extension UnsafeMutablePointer where Pointee == MPMarshalledFile {

    public func mpw_get(path: String...) -> Bool? {
        path.withCStringVaList { mpw_marshal_data_vget_bool( self.pointee.data, $0 ) }
    }

    public func mpw_get(path: String...) -> Double? {
        path.withCStringVaList { mpw_marshal_data_vget_num( self.pointee.data, $0 ) }
    }

    public func mpw_get(path: String...) -> String? {
        path.withCStringVaList { .valid( mpw_marshal_data_vget_str( self.pointee.data, $0 ) ) }
    }

    public func mpw_get(path: String...) -> Date? {
        path.withCStringVaList {
            let time = mpw_get_timegm( mpw_marshal_data_vget_str( self.pointee.data, $0 ) )
            if time == ERR {
                return nil
            }

            return Date( timeIntervalSince1970: TimeInterval( time ) )
        }
    }

    @discardableResult
    public func mpw_set(_ value: Bool, path: String...) -> Bool {
        path.withCStringVaList { mpw_marshal_data_vset_bool( value, self.pointee.data, $0 ) }
    }

    @discardableResult
    public func mpw_set(_ value: Double, path: String...) -> Bool {
        path.withCStringVaList { mpw_marshal_data_vset_num( value, self.pointee.data, $0 ) }
    }

    @discardableResult
    public func mpw_set(_ value: String?, path: String...) -> Bool {
        path.withCStringVaList { mpw_marshal_data_vset_str( value, self.pointee.data, $0 ) }
    }

    public func mpw_find(path: String...) -> UnsafeBufferPointer<MPMarshalledData>? {
        guard let found = path.withCStringVaList( body: { mpw_marshal_data_vfind( self.pointee.data, $0 ) } )
        else { return nil }

        return UnsafeBufferPointer( start: found.pointee.children, count: found.pointee.children_count )
    }
}
