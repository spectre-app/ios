//
// Created by Maarten Billemont on 2019-11-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import os

public func pii(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: appConfig.isDebug ? .debug: .trace, format, args )
}

public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .trace, format, args )
}

public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .debug, format, args )
}

public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .info, format, args )
}

public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .warning, format, args )
}

public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .error, format, args )
}

public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .fatal, format, args )
}

public func log(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                level: LogLevel, _ format: StaticString, _ args: [Any?]) {

    if mpw_verbosity < level {
        return
    }

    let message = String( format: format.description, arguments: args.map { arg in
        if let error = arg as? LocalizedError {
            return [ error.failureReason, error.errorDescription ].compactMap { $0 }.joined( separator: ": " )
        }

        guard let arg = arg
        else { return Int( bitPattern: nil ) }

        return arg as? CVarArg ?? String( reflecting: arg )
    } )

    mpw_log_ssink( level, file, line, function, message )
}

extension LogLevel: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ LogLevel ]( (.fatal)...(.trace) )

    public func distance(to other: LogLevel) -> Int32 {
        other.rawValue - self.rawValue
    }

    public func advanced(by n: Int32) -> LogLevel {
        LogLevel( rawValue: self.rawValue + n )!
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

public class MPLogSink: MPConfigObserver {
    public static let shared = MPLogSink()

    public var level: LogLevel {
        get {
            mpw_verbosity
        }
        set {
            mpw_verbosity = newValue
        }
    }

    private let queue      = DispatchQueue( label: "\(productName): Log Sink", qos: .utility )
    private var registered = false
    private var records    = [ MPLogRecord ]()

    public func register() {
        self.queue.sync {
            guard !registered
            else { return }

            mpw_verbosity = .debug
            mpw_log_sink_register( { event in
                guard let event = event?.pointee
                else { return false }

                let file  = String.valid( event.file ) ?? "mpw"
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

                os_log( level, dso: #dsohandle, log: log, "%@", String.valid( event.message ) ?? "-" )
                return true
            } )
            mpw_log_sink_register( { event in
                guard let event = event
                else { return false }

                return MPLogSink.shared.record( event.pointee )
            } )

            appConfig.observers.register( observer: self ).didChangeConfig()

            self.registered = true
        }
    }

    public func enumerate(level: LogLevel) -> [MPLogRecord] {
        self.queue.sync { self.records.filter( { $0.level <= level } ).sorted() }
    }

    fileprivate func record(_ event: MPLogEvent) -> Bool {
        guard let record = MPLogRecord( event )
        else { return false }

        self.queue.sync { self.records.append( record ) }
        return true
    }

    // MARK: --- MPConfigObserver ---

    public func didChangeConfig() {
        self.level = appConfig.isDebug ? .debug: appConfig.diagnostics ? .info: .warning
    }
}

public struct MPLogRecord: Comparable {
    public let occurrence: Date
    public let level:      LogLevel
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

    public init?(_ event: MPLogEvent) {
        guard let file = String.valid( event.file ),
              let function = String.valid( event.function ),
              let message = String.valid( event.message )
        else { return nil }

        self.occurrence = Date( timeIntervalSince1970: TimeInterval( event.occurrence ) )
        self.level = event.level
        self.file = file
        self.line = event.line
        self.function = function
        self.message = message
    }

    public static func <(lhs: MPLogRecord, rhs: MPLogRecord) -> Bool {
        lhs.occurrence < rhs.occurrence
    }

    public static func ==(lhs: MPLogRecord, rhs: MPLogRecord) -> Bool {
        lhs.occurrence == rhs.occurrence && lhs.level == rhs.level &&
                lhs.file == rhs.file && lhs.line == rhs.line && lhs.function == rhs.function &&
                lhs.message == rhs.message
    }
}

