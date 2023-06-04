// =============================================================================
// Created by Maarten Billemont on 2019-11-07.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation
import os

//@discardableResult
public func pii(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: AppConfig.shared.isDebug ? .info : .trace, format, args )
}

//@discardableResult
public func trp(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ condition: Bool = true, _ format: StaticString = "<trap>", _ args: Any?...) {
    guard condition
    else { return /*false*/ }

//    let logged =
            log( file: file, line: line, function: function, dso: dso, level: .trace, format, args )
    print( "<SIGTRAP>" )
//    return logged
}

//@discardableResult
public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .trace, format, args )
}

#if DEBUG
//@discardableResult
public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                ifDebugging object: AnyObject? = nil, _ format: StaticString, _ args: Any?...) {
    if let object = object, !isDebuggingObject( object ) {
        return //false
    }

    return log( file: file, line: line, function: function, dso: dso, level: .debug, format, args )
}
#endif

//@discardableResult
public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .debug, format, args )
}

//@discardableResult
public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .info, format, args )
}

//@discardableResult
public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .warning, format, args )
}

//@discardableResult
public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .error, format, args )
}

//@discardableResult
public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .fatal, format, args )
}

//@discardableResult
public func log(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                level: SpectreLogLevel, _ format: StaticString, _ args: Any?...) {
    // TODO: make it async?
    Task.detached {
        await Spectre.shared.log(level: level, file: file, line: line, function: function, format, args)
    }
}

extension SpectreLogLevel: Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [ SpectreLogLevel ]( (.fatal)...(.trace) )

    public func distance(to other: SpectreLogLevel) -> Int32 {
        other.rawValue - self.rawValue
    }

    public func advanced(by stride: Int32) -> SpectreLogLevel {
        SpectreLogLevel( rawValue: self.rawValue + stride )!
    }

    public var description: String {
        switch self {
            case .trace:
                return "TRC"
            case .debug:
                return "DBG"
            case .info:
                return "INF"
            case .warning:
                return "WRN"
            case .error:
                return "ERR"
            case .fatal:
                return "FTL"
            @unknown default:
                fatalError( "Unsupported log level: \(self.rawValue)" )
        }
    }
}

public class LogSink: AppConfigObserver {
    public static let shared = LogSink()

    public var level: SpectreLogLevel {
        get {
            spectre_verbosity
        }
        set {
            spectre_verbosity = newValue
        }
    }

    private var registered = false

    private let logState = LogState()
    private actor LogState {
        private var records    = [ LogRecord ]()

        func enumerate(level: SpectreLogLevel) -> [LogRecord] {
            self.records.filter( { $0.level <= level } ).sorted()
        }

        func record(_ record: LogRecord) {
            self.records.append(record )
        }
    }

    public func register() async {
        guard !self.registered
        else { return }

        spectre_verbosity = .debug
        _ = await Spectre.shared.log_sink_register { eventPointer in
            guard let event = eventPointer?.pointee
            else { return false }

            let file  = String.valid( event.file ) ?? "spectre"
            let log   = OSLog( subsystem: productIdentifier, category: "\(file.lastPathComponent):\(event.line)" )
            var level = OSLogType.default
            switch event.level {
                case .trace, .debug:
                    level = .debug
                case .info:
                    level = .info
                case .warning:
                    level = .default
                case .error:
                    level = .error
                case .fatal:
                    level = .fault
                @unknown default: ()
            }

            os_log( level, dso: #dsohandle, log: log, "%@ | %@", event.level.description,
                    String.valid( event.formatter( eventPointer ) ) ?? "-" )
            return true
        }
        _ = await Spectre.shared.log_sink_register {
            guard let event = $0?.pointee
            else { return false }

            return LogSink.shared.record( event )
        }

        AppConfig.shared.observers.register( observer: self )?
                 .didChange( appConfig: AppConfig.shared, at: \AppConfig.diagnostics )

        self.registered = true
    }

    func enumerate(level: SpectreLogLevel) async -> [LogRecord] {
        await self.logState.enumerate(level: level)
    }

    fileprivate func record(_ event: SpectreLogEvent) -> Bool {
        guard let file = String.valid( event.file ),
              let function = String.valid( event.function ),
              let message = String.valid( event.formatted )
        else { return false }

        Task.detached {
            await self.logState.record( LogRecord(
                    occurrence: Date( timeIntervalSince1970: TimeInterval( event.occurrence ) ),
                    level: event.level, file: file, line: event.line, function: function, message: message
            ) )
        }

        return true
    }

    // MARK: - AppConfigObserver

    public func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        self.level = appConfig.isDebug ? .debug : appConfig.diagnostics ? .info : .warning
    }
}

struct LogRecord: Comparable {
    public let occurrence: Date
    public let level:      SpectreLogLevel
    public let file:       String
    public let line:       Int32
    public let function:   String
    public let message:    String
    public var fileName:   String {
        self.file.lastPathComponent
    }
    public var source:     String {
        "\(self.fileName):\(self.line)"
    }

    public static func < (lhs: LogRecord, rhs: LogRecord) -> Bool {
        lhs.occurrence < rhs.occurrence
    }

    public static func == (lhs: LogRecord, rhs: LogRecord) -> Bool {
        lhs.occurrence == rhs.occurrence && lhs.level == rhs.level &&
        lhs.file == rhs.file && lhs.line == rhs.line && lhs.function == rhs.function &&
        lhs.message == rhs.message
    }
}
