//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation
import RegexBuilder
import SwiftUI

public enum AppError: LocalizedError {
    case issue(_ title: String, reason: CustomStringConvertible? = nil, suggestion: String? = nil, cause: Error? = nil)
    case `internal`(reason: String, details: CustomStringConvertible? = nil)
    //    case `state`(title: String, details: CustomStringConvertible? = nil, suggestion: String? = nil)
    case marshal(SpectreMarshalError, title: String, details: CustomStringConvertible? = nil)

    public var errorDescription: String? {
        switch self {
            case let .issue(title, _, _, cause):
                [title, cause?.localizedDescription]
                    .compactMap(\.self).joined(separator: ": ").nonEmpty
            case .internal:
                "Internal Inconsistency"
            //            case .state(let title, _, _):
            //                return title
            case let .marshal(error, title, _):
                [title, error.localizedDescription]
                    .compactMap(\.self).joined(separator: ": ").nonEmpty
        }
    }

    public var failureReason: String? {
        switch self {
            case let .issue(_, reason, _, cause):
                [reason?.description, (cause as NSError?)?.localizedFailureReason]
                    .compactMap(\.self).joined(separator: "\n").nonEmpty
            case let .internal(cause, details):
                [cause, details?.description]
                    .compactMap(\.self).joined(separator: "\n").nonEmpty
            //            case .state(_, let details, _):
            //                return details?.description
            case let .marshal(error, _, details):
                [(error as NSError).localizedFailureReason, details?.description]
                    .compactMap(\.self).joined(separator: "\n").nonEmpty
        }
    }

    public var recoverySuggestion: String? {
        switch self {
            case let .issue(_, _, suggestion, cause):
                [suggestion, (cause as NSError?)?.localizedRecoverySuggestion]
                    .compactMap(\.self).joined(separator: "\n").nonEmpty
            case let .marshal(error, _, _):
                (error as NSError).localizedRecoverySuggestion
            //            case .state(_, _, let suggestion):
            //                return suggestion
            default:
                nil
        }
    }
}

extension SpectreAlgorithm: Strideable, CaseIterable, Identifiable, CustomLocalizedStringResourceConvertible {
    public static let allCases = [Self](.first ... .last)

    public var description: String {
        String.valid(spectre_algorithm_short_name(self)) ?? "?"
    }

    public var localizedDescription: String {
        String.valid(spectre_algorithm_long_name(self)) ?? "?"
    }

    public var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource("\(self.localizedDescription)")
    }
}

extension SpectreCounter: Strideable, CustomStringConvertible {
    public var description: String {
        "\(self.rawValue)"
    }
}

extension SpectreIdenticon: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.leftArm == rhs.leftArm && lhs.body == rhs.body && lhs.rightArm == rhs.rightArm && lhs.accessory == rhs.accessory
            && lhs.color == rhs.color
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(leftArm)
        hasher.combine(body)
        hasher.combine(rightArm)
        hasher.combine(accessory)
        hasher.combine(color)
    }

    public static func from(_ identicon: String, color: SpectreIdenticonColor) -> Self? {
        let regex = Regex {
            Capture(.anyNonNewline)
            Capture(.anyNonNewline)
            Capture(.anyNonNewline)
            Capture(.anyNonNewline)
        }
        guard let match = try? regex.firstMatch(in: identicon)
        else { return nil }

        return match.output.1.withCString { leftArm in
            match.output.2.withCString { body in
                match.output.3.withCString { rightArm in
                    match.output.4.withCString { accessory in
                        self.init(
                            leftArm: spectre_strdup(leftArm),
                            body: spectre_strdup(body),
                            rightArm: spectre_strdup(rightArm),
                            accessory: spectre_strdup(accessory),
                            color: color,
                        )
                    }
                }
            }
        }
    }

    public var isUnset: Bool {
        self.color == .unset
    }

    public func encoded() -> String? {
        self.isUnset ? nil : .valid(spectre_identicon_encode(self), consume: true)
    }

    public func text() -> String? {
        self.isUnset
            ? nil
            : [
                String(cString: self.leftArm),
                String(cString: self.body),
                String(cString: self.rightArm),
                String(cString: self.accessory),
            ].joined()
    }

    //    public func attributedText() -> NSAttributedString? {
    //        if self.isUnset {
    //            return nil
    //        }
    //
    //        let shadow = NSShadow()
    //        shadow.shadowColor = Theme.current.color.shadow.get(forTraits: .current) // TODO: Update on theme change.
    //        shadow.shadowOffset = CGSize( width: 0, height: 1 )
    //        return self.text().flatMap {
    //            NSAttributedString( string: $0, attributes: [
    //                .foregroundColor: self.color.ui(),
    //                .shadow: shadow,
    //            ] )
    //        }
    //    }
}

struct UnsafeSpectrePointer<P>: @unchecked Sendable {
    let pointer: UnsafePointer<P>
}

extension SpectreKeyID: Hashable, CustomStringConvertible {
    public static var unset = SpectreKeyIDUnset

    public static func == (lhs: Self, rhs: Self) -> Bool {
        withUnsafeBytes(of: lhs.bytes) { lhs in withUnsafeBytes(of: rhs.bytes, lhs.elementsEqual) }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: self.bytes) { hasher.combine(bytes: $0) }
    }

    public var description: String {
        withUnsafeBytes(of: self.hex) { String.valid($0) ?? "-" }
    }

    public var isValid: Bool {
        spectre_id_valid([self])
    }
}

extension SpectreIdenticonColor {
    public func ui() -> Color {
        switch self {
            case .unset: .clear
            case .red: .red
            case .green: .green
            case .yellow: .yellow
            case .blue: .blue
            case .purple: .purple
            case .cyan: .cyan
            case .mono: .primary
            default: fatalError("Unsupported color: \(self)")
        }
    }
}

extension SpectreKeyPurpose: CustomStringConvertible, CaseIterable, Identifiable {
    public static let allCases: [Self] = [.authentication, .identification, .recovery]

    public var description: String {
        switch self {
            case .authentication: "password"
            case .identification: "login name"
            case .recovery: "security answer"
            @unknown default: ""
        }
    }

    public var scope: String? {
        .valid(spectre_purpose_scope(.authentication))
    }
}

extension SpectreFormat: Strideable, CaseIterable, Identifiable, CustomStringConvertible {
    public static let allCases = [Self](.first ... .last)

    public var name: String? {
        .valid(spectre_format_name(self))
    }

    public var uti: String? {
        switch self {
            case .none: nil
            case .flat: "app.spectre.user.mpsites"
            case .JSON: "app.spectre.user.json"
            default: fatalError("Unsupported format: \(self)")
        }
    }

    public var description: String {
        switch self {
            case .none: "No Output"
            case .flat: "v1 (sites)"
            case .JSON: "v2 (json)"
            default: fatalError("Unsupported format: \(self.rawValue)")
        }
    }

    public func `is`(url: URL) -> Bool {
        var count: size_t = .zero
        let extensions = UnsafeBufferPointer(start: spectre_format_extensions(self, &count), count: count)
        defer {
            extensions.deallocate()
        }

        return extensions.map { String.valid($0) }.contains(url.pathExtension)
    }
}

extension SpectreResultType: CustomStringConvertible, CaseIterable, Identifiable {
    public static let allCases: [Self] = [
        .templateMaximum, .templateLong, .templateMedium, .templateShort,
        .templateBasic, .templatePIN, .templateName, .templatePhrase,
        .statePersonal, .stateDevice, .deriveKey,
    ]
    static let recommendedTypes: [SpectreKeyPurpose: [SpectreResultType]] = [
        .authentication: [.templateMaximum, .templatePhrase, .templateLong, .templateBasic, .templatePIN],
        .identification: [.templateName, .templateBasic, .templateShort],
        .recovery: [.templatePhrase],
    ]

    public var abbreviation: String {
        String.valid(spectre_type_abbreviation(self)) ?? "?"
    }

    public var description: String {
        String.valid(spectre_type_short_name(self)) ?? "?"
    }

    public var localizedDescription: String {
        String.valid(spectre_type_long_name(self)) ?? "?"
    }

    public var nonEmpty: Self? {
        self == .none ? nil : self
    }

    public var `class`: SpectreResultClass? {
        for `class` in SpectreResultClass.allCases
            where self.in(class: `class`) {
            return `class`
        }

        return nil
    }

    func `in`(class: SpectreResultClass) -> Bool {
        self.rawValue & UInt32(`class`.rawValue) == UInt32(`class`.rawValue)
    }

    func has(feature: SpectreResultFeature) -> Bool {
        self.rawValue & UInt32(feature.rawValue) == UInt32(feature.rawValue)
    }
}

extension SpectreResultClass: CustomStringConvertible, CaseIterable, Identifiable {
    public static let allCases: [Self] = [
        .template, .stateful, .derive,
    ]

    public var description: String {
        switch self {
            case .template: "Generated"
            case .stateful: "Saved"
            case .derive: "Derived"
            default: "\(self.rawValue)"
        }
    }

    public var id: RawValue {
        self.rawValue
    }
}

extension UnsafeMutablePointer where Pointee == SpectreMarshalledFile {
    public func spectre_get(path: String...) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        self.pointee.data.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> Bool? {
        self.pointee.data.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> Double? {
        self.pointee.data.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> String? {
        self.pointee.data.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> Date? {
        self.pointee.data.spectre_get(path: path)
    }

    @discardableResult
    public func spectre_unset(path: String...) -> Bool {
        self.pointee.data.spectre_unset(path: path)
    }

    @discardableResult
    public func spectre_set(_ value: Bool, path: String...) -> Bool {
        self.pointee.data.spectre_set(value, path: path)
    }

    @discardableResult
    public func spectre_set(_ value: Double, path: String...) -> Bool {
        self.pointee.data.spectre_set(value, path: path)
    }

    @discardableResult
    public func spectre_set(_ value: String?, path: String...) -> Bool {
        self.pointee.data.spectre_set(value, path: path)
    }

    @discardableResult
    public func spectre_set(_ value: Date, path: String...) -> Bool {
        self.pointee.data.spectre_set(value, path: path)
    }
}

extension SpectreMarshalledData {
    public func spectre_get(path: String...) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        withUnsafePointer(to: self) {
            Optional($0).spectre_get(path: path)
        }
    }

    public func spectre_get(path: String...) -> Bool? {
        withUnsafePointer(to: self) {
            Optional($0).spectre_get(path: path)
        }
    }

    public func spectre_get(path: String...) -> Double? {
        withUnsafePointer(to: self) {
            Optional($0).spectre_get(path: path)
        }
    }

    public func spectre_get(path: String...) -> String? {
        withUnsafePointer(to: self) {
            Optional($0).spectre_get(path: path)
        }
    }

    public func spectre_get(path: String...) -> Date? {
        withUnsafePointer(to: self) {
            Optional($0).spectre_get(path: path)
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: Bool, path: String...) -> Bool {
        withUnsafeMutablePointer(to: &self) {
            Optional($0).spectre_set(value, path: path)
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: Double, path: String...) -> Bool {
        withUnsafeMutablePointer(to: &self) {
            Optional($0).spectre_set(value, path: path)
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: String?, path: String...) -> Bool {
        withUnsafeMutablePointer(to: &self) {
            Optional($0).spectre_set(value, path: path)
        }
    }

    @discardableResult
    public mutating func spectre_set(_ value: Date, path: String...) -> Bool {
        withUnsafeMutablePointer(to: &self) {
            Optional($0).spectre_set(value, path: path)
        }
    }
}

extension SpectreMarshalError: @unchecked Sendable {}

extension UnsafeMutablePointer<SpectreMarshalledData>? {
    public func spectre_get(path: String...) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        self.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> Bool? {
        self.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> Double? {
        self.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> String? {
        self.spectre_get(path: path)
    }

    public func spectre_get(path: String...) -> Date? {
        self.spectre_get(path: path)
    }

    @discardableResult
    public func spectre_set(_ value: Bool, path: String...) -> Bool {
        self.spectre_set(value, path: path)
    }

    @discardableResult
    public func spectre_set(_ value: Double, path: String...) -> Bool {
        self.spectre_set(value, path: path)
    }

    @discardableResult
    public func spectre_set(_ value: String?, path: String...) -> Bool {
        self.spectre_set(value, path: path)
    }

    @discardableResult
    public func spectre_set(_ value: Date, path: String...) -> Bool {
        self.spectre_set(value, path: path)
    }
}

extension UnsafePointer<SpectreMarshalledData>? {
    public func spectre_get(path: [String]) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        path.withCStringVaList { spectre_marshal_data_vget(self, $0) }.flatMap {
            UnsafeBufferPointer(start: $0.pointee.children, count: $0.pointee.children_count)
        }
    }

    public func spectre_get(path: [String]) -> Bool? {
        path.withCStringVaList { spectre_marshal_data_vget_bool(self, $0) }
    }

    public func spectre_get(path: [String]) -> Double? {
        path.withCStringVaList { spectre_marshal_data_vget_num(self, $0) }
    }

    public func spectre_get(path: [String]) -> String? {
        path.withCStringVaList { .valid(spectre_marshal_data_vget_str(self, $0)) }
    }

    public func spectre_get(path: [String]) -> Date? {
        path.withCStringVaList {
            let time = spectre_get_timegm(spectre_marshal_data_vget_str(self, $0))
            if time == ERR {
                return nil
            }

            return Date(timeIntervalSince1970: TimeInterval(time))
        }
    }
}

extension UnsafeMutablePointer<SpectreMarshalledData>? {
    public func spectre_get(path: [String]) -> UnsafeBufferPointer<SpectreMarshalledData>? {
        path.withCStringVaList { spectre_marshal_data_vget(self, $0) }.flatMap {
            UnsafeBufferPointer(start: $0.pointee.children, count: $0.pointee.children_count)
        }
    }

    public func spectre_get(path: [String]) -> Bool? {
        path.withCStringVaList { spectre_marshal_data_vget_bool(self, $0) }
    }

    public func spectre_get(path: [String]) -> Double? {
        path.withCStringVaList { spectre_marshal_data_vget_num(self, $0) }
    }

    public func spectre_get(path: [String]) -> String? {
        path.withCStringVaList { .valid(spectre_marshal_data_vget_str(self, $0)) }
    }

    public func spectre_get(path: [String]) -> Date? {
        path.withCStringVaList {
            let time = spectre_get_timegm(spectre_marshal_data_vget_str(self, $0))
            if time == ERR {
                return nil
            }

            return Date(timeIntervalSince1970: TimeInterval(time))
        }
    }

    @discardableResult
    func spectre_unset(path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_null(self, $0) }
    }

    @discardableResult
    func spectre_set(_ value: Bool, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_bool(value, self, $0) }
    }

    @discardableResult
    public func spectre_set(_ value: Double, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_num(value, self, $0) }
    }

    @discardableResult
    public func spectre_set(_ value: String?, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_str(value, self, $0) }
    }

    @discardableResult
    public func spectre_set(_ value: Date, path: [String]) -> Bool {
        path.withCStringVaList { spectre_marshal_data_vset_str(spectre_set_timegm(time_t(value.timeIntervalSince1970)), self, $0) }
    }
}
