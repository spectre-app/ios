//
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

extension MPAlgorithmVersion: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ MPAlgorithmVersion ]( (.first)...(.last) )

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

public enum MPError: LocalizedError {
    case `issue`(_ error: Error? = nil, title: String, details: String? = nil)
    case `internal`(details: String)
    case `state`(details: String)
    case `marshal`(MPMarshalError, title: String)

    public var errorDescription: String? {
        switch self {
            case .issue(_, title: let title, _):
                return title
            case .internal( _ ):
                return "An internal error occurred."
            case .state( _ ):
                return "Not ready."
            case .marshal(_, let title):
                return title
        }
    }
    public var failureReason: String? {
        switch self {
            case .issue(let error, _, let details):
                return [ details, error?.localizedDescription, (error as NSError?)?.localizedFailureReason ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
            case .internal(let details):
                return details
            case .state(let details):
                return details
            case .marshal(let error, _):
                return [ error.localizedDescription, (error as NSError).localizedFailureReason ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
        }
    }
    public var recoverySuggestion: String? {
        switch self {
            case .issue(let error, _, _):
                return (error as NSError?)?.localizedRecoverySuggestion
            case .marshal(let error, _):
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
        if self.color == .unset {
            return nil
        }

        return .valid( mpw_identicon_encode( self ) )
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
                return "user name"
            case .recovery:
                return "security answer"
            @unknown default:
                return ""
        }
    }
}

extension MPMarshalFormat: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ MPMarshalFormat ]( (.first)...(.last) )

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
                return "com.lyndir.masterpassword.sites"
            case .JSON:
                return "com.lyndir.masterpassword.json"
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
