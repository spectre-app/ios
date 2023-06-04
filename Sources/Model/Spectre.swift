// =============================================================================
// Created by Maarten Billemont on 2020-09-13.
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

public protocol SpectreOperand {
    func use()

    func result(for name: String?, counter: SpectreCounter?, keyPurpose: SpectreKeyPurpose, keyContext: String?,
                resultType: SpectreResultType?, resultParam: String?, algorithm: SpectreAlgorithm?, operand: SpectreOperand?)
            -> SpectreOperation?

    func state(for name: String?, counter: SpectreCounter?, keyPurpose: SpectreKeyPurpose, keyContext: String?,
               resultType: SpectreResultType?, resultParam: String, algorithm: SpectreAlgorithm?, operand: SpectreOperand?)
            -> SpectreOperation?
}

public struct SpectreOperation {
    let siteName:  String
    let counter:   SpectreCounter
    let type:      SpectreResultType
    let param:     String?
    let purpose:   SpectreKeyPurpose
    let context:   String?
    let identity:  SpectreKeyID?
    let algorithm: SpectreAlgorithm
    let operand:   SpectreOperand
    let task:      Task<String, Error>

    public func copy() {
        Task.detached {
            inf("Copying %@ for: %@", self.purpose, self.siteName)
            try UIPasteboard.general.setObjects(
                [await self.task.value as NSString],
                localOnly: !AppConfig.shared.allowHandoff,
                expirationDate: Date(timeIntervalSinceNow: 3 * 60)
            )
            self.operand.use()
        }
    }

    public func copy(fromView view: UIView, trackingFrom: String) {
        Task.detached {
            let event = Tracker.shared.begin( track: .subject( "site", action: "use" ) )

            do {
                let token = try await self.task.value
                Feedback.shared.play( .trigger )

                inf( "Copying %@ for: %@", self.purpose, self.siteName )
                UIPasteboard.general.setObjects(
                        [ token as NSString ], localOnly: !AppConfig.shared.allowHandoff, expirationDate: Date( timeIntervalSinceNow: 3 * 60 ) )
                self.operand.use()

                await AlertController( title: "Copied \(self.purpose) (3 min)", message: self.siteName, details:
                """
                Your \(self.purpose) for \(self.siteName) is:
                \(token)

                It was copied to the pasteboard, you can now switch to your application and paste it into the \(self.purpose) field.

                Note that after 3 minutes, the \(self.purpose) will expire from the pasteboard for security reasons.
                """ ).show( in: view )

                event.end(
                        [ "result": "success",
                          "from": trackingFrom,
                          "action": "copy",
                          "counter": "\(self.counter)",
                          "purpose": "\(self.purpose)",
                          "type": "\(self.type)",
                          "algorithm": "\(self.algorithm)",
                          "entropy": await Attacker.entropy( type: self.type ) ??? (await Attacker.entropy( string: token )),
                        ] )
            }
            catch {
                event.end(
                        [ "result": "failure",
                          "from": trackingFrom,
                          "action": "copy",
                          "error": error.localizedDescription,
                        ] )
            }
        }
    }
}

extension SpectreOperation: Hashable {
    public static func == (lhs: SpectreOperation, rhs: SpectreOperation) -> Bool {
        lhs.siteName == rhs.siteName &&
        lhs.counter == rhs.counter &&
        lhs.type == rhs.type &&
        lhs.param == rhs.param &&
        lhs.purpose == rhs.purpose &&
        lhs.context == rhs.context &&
        lhs.identity == rhs.identity &&
        lhs.algorithm == rhs.algorithm
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.siteName)
        hasher.combine(self.counter)
        hasher.combine(self.type)
        hasher.combine(self.param)
        hasher.combine(self.purpose)
        hasher.combine(self.context)
        hasher.combine(self.identity)
        hasher.combine(self.algorithm)
    }
}

actor Spectre {
    static let shared = Spectre()

    func user_key(userName: String?, userSecret: String?, algorithmVersion: SpectreAlgorithm) -> UnsafePointer<SpectreUserKey>? {
        spectre_user_key( userName, userSecret, algorithmVersion )
    }

    func site_result(userKey: SpectreUserKey, siteName: String?,
                     resultType: SpectreResultType, resultParam: String?,
                     keyCounter: SpectreCounter, keyPurpose: SpectreKeyPurpose, keyContext: String?) -> String? {
        withUnsafePointer( to: userKey ) { userKey in
            .valid( spectre_site_result( userKey, siteName, resultType, resultParam, keyCounter, keyPurpose, keyContext ) )
        }
    }

    func site_state(userKey: SpectreUserKey, siteName: String?,
                    resultType: SpectreResultType, resultParam: String?,
                    keyCounter: SpectreCounter, keyPurpose: SpectreKeyPurpose, keyContext: String?) -> String? {
        withUnsafePointer( to: userKey ) { userKey in
            .valid( spectre_site_state( userKey, siteName, resultType, resultParam, keyCounter, keyPurpose, keyContext ) )
        }
    }

    func site_key(userKey: SpectreUserKey, siteName: String?,
                  keyCounter: SpectreCounter, keyPurpose: SpectreKeyPurpose, keyContext: String?) -> SpectreSiteKey? {
        withUnsafePointer( to: userKey ) { userKey in
            spectre_site_key( userKey, siteName, keyCounter, keyPurpose, keyContext )?.pointee
        }
    }

    func identicon(userName: String?, userSecret: String?) -> SpectreIdenticon {
        spectre_identicon( userName, userSecret )
    }

    func identicon_encode(_ identicon: SpectreIdenticon) -> String? {
        .valid( spectre_identicon_encode( identicon ) )
    }

    func identicon_encoded(_ encoding: String?) -> SpectreIdenticon {
        spectre_identicon_encoded( encoding )
    }

    func log_sink_register(sink: @escaping @convention(c) (UnsafeMutablePointer<SpectreLogEvent>?) -> Bool) -> Bool {
        spectre_log_sink_register(sink)
    }

    func log_sink_unregister(sink: @escaping @convention(c) (UnsafeMutablePointer<SpectreLogEvent>?) -> Bool) -> Bool {
        spectre_log_sink_unregister(sink)
    }

    func log(level: SpectreLogLevel, file: String, line: Int32, function: String, _ format: StaticString, _ args: Any?...) -> Bool {
        file.withCString { file in
            function.withCString { function in
                format.description.withCString { format in
                    withVaList( args.map(self.toCVarArg) ) { args in
                            // FIXME: https://bugs.swift.org/browse/SR-13779 - The va_list C type is incompatible with CVaListPointer on x86_64.
                            withUnsafeBytes( of: args ) { args in
                                var event = SpectreLogEvent( occurrence: time( nil ), level: level, file: file, line: line, function: function, formatter: { event in
                                    // Define how our arguments should be interpolated into the format.
                                    if event?.pointee.formatted == nil, let args = event?.pointee.args {
                                        event?.pointee.formatted = spectre_strdup( CFStringCreateWithFormatAndArguments(
                                                nil, nil, String.valid( event?.pointee.format ) as CFString?,
                                                UnsafeRawPointer( args ).load( as: CVaListPointer.self ) ) as String )
                                    }

                                    return event?.pointee.formatted ?? event?.pointee.format
                                }, formatted: nil, format: format, args: args.baseAddress?.assumingMemoryBound( to: va_list_c.self ) )

                                // Sink the log event.
                                return spectre_elog( &event )
                            }
                    }
                }
            }
        }
    }

    private func toCVarArg(_ arg: Any?) -> CVarArg {
        guard let arg = arg
        else { return Int( bitPattern: nil ) }

        if let arg = arg as? CVarArg, !(type(of: arg) is AnyObject.Type) {
            return arg
        }

        var prefix = ""
        #if DEBUG
        if isDebuggingObject(arg as AnyObject) {
            prefix += "[*]"
        }
        #endif

        if let error = arg as? Error {
            return prefix + error.detailsDescription
        }
        else {
            return prefix + String( reflecting: arg )
        }
    }
}

