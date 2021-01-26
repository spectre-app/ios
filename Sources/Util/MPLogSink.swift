//
// Created by Maarten Billemont on 2019-11-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import os

@discardableResult
public func pii(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: appConfig.isDebug ? .debug: .trace, format, args )
}

@discardableResult
public func trp(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ condition: Bool, _ format: StaticString = "<trap>", _ args: Any?...) -> Bool {
    guard condition
    else { return false }

    return log( file: file, line: line, function: function, dso: dso, level: .trace, format, args )
}

@discardableResult
public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: .trace, format, args )
}

@discardableResult
public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: .debug, format, args )
}

@discardableResult
public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: .info, format, args )
}

@discardableResult
public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: .warning, format, args )
}

@discardableResult
public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: .error, format, args )
}

@discardableResult
public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) -> Bool {
    log( file: file, line: line, function: function, dso: dso, level: .fatal, format, args )
}

@discardableResult
public func log(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                level: MPLogLevel, _ format: StaticString, _ args: [Any?]) -> Bool {

    if mpw_verbosity < level {
        return false
    }

    // Translate parameters for C API compatibility.
    return file.withCString { file in
        function.withCString { function in
            format.description.withCString { format in
                withVaList( args.map { arg in
                    if let error = arg as? LocalizedError {
                        return [ error.failureReason, error.errorDescription ].compactMap { $0 }.joined( separator: ": " )
                    }

                    guard let arg = arg
                    else { return Int( bitPattern: nil ) }

                    return arg as? CVarArg ?? String( reflecting: arg )
                } ) {
                    // The va_list C type is incompatible with CVaListPointer on x86_64.
                    // FIXME: https://bugs.swift.org/browse/SR-13779
                    withUnsafeBytes( of: $0 ) { args in
                        var event = MPLogEvent(
                                occurrence: time( nil ), level: level, file: file, line: line, function: function, formatter: { event in
                            // Define how our arguments should be interpolated into the format.
                            if event?.pointee.formatted == nil, let args = event?.pointee.args {
                                event?.pointee.formatted = mpw_strdup( CFStringCreateWithFormatAndArguments(
                                        nil, nil, String.valid( event?.pointee.format ) as CFString?,
                                        UnsafeRawPointer( args ).load( as: CVaListPointer.self ) ) as String )
                            }

                            return event?.pointee.formatted ?? event?.pointee.format
                        }, formatted: nil, format: format, args: args.baseAddress?.assumingMemoryBound( to: va_list_c.self ) )

                        // Sink the log event.
                        return mpw_log_esink( &event )
                    }
                }
            }
        }
    }
}

extension MPLogLevel: Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [ MPLogLevel ]( (.fatal)...(.trace) )

    public func distance(to other: MPLogLevel) -> Int32 {
        other.rawValue - self.rawValue
    }

    public func advanced(by n: Int32) -> MPLogLevel {
        MPLogLevel( rawValue: self.rawValue + n )!
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

    public var level: MPLogLevel {
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
            mpw_log_sink_register( { eventPointer in
                guard let event = eventPointer?.pointee
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

                os_log( level, dso: #dsohandle, log: log, "%@ | %@", event.level.description,
                        String.valid( event.formatter( eventPointer ) ) ?? "-" )
                return true
            } )
            mpw_log_sink_register( {
                guard let event = $0?.pointee
                else { return false }

                return MPLogSink.shared.record( event )
            } )

            appConfig.observers.register( observer: self ).didChangeConfig()

            self.registered = true
        }
    }

    func enumerate(level: MPLogLevel) -> [MPLogRecord] {
        self.queue.sync { self.records.filter( { $0.level <= level } ).sorted() }
    }

    fileprivate func record(_ event: MPLogEvent) -> Bool {
        guard let file = String.valid( event.file ),
              let function = String.valid( event.function ),
              let message = String.valid( event.formatted )
        else { return false }

        self.queue.sync {
            self.records.append(
                    MPLogRecord( occurrence: Date( timeIntervalSince1970: TimeInterval( event.occurrence ) ),
                                 level: event.level, file: file, line: event.line, function: function, message: message )
            )
        }
        return true
    }

    // MARK: --- MPConfigObserver ---

    public func didChangeConfig() {
        self.level = appConfig.isDebug ? .trace: appConfig.diagnostics ? .info: .warning
    }
}

struct MPLogRecord: Comparable {
    public let occurrence: Date
    public let level:      MPLogLevel
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

    public static func <(lhs: MPLogRecord, rhs: MPLogRecord) -> Bool {
        lhs.occurrence < rhs.occurrence
    }

    public static func ==(lhs: MPLogRecord, rhs: MPLogRecord) -> Bool {
        lhs.occurrence == rhs.occurrence && lhs.level == rhs.level &&
                lhs.file == rhs.file && lhs.line == rhs.line && lhs.function == rhs.function &&
                lhs.message == rhs.message
    }
}

