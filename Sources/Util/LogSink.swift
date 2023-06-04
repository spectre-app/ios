//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Combine
import Foundation
import os
import System

@TaskLocal
private var currentAction: Tracker.TimedEvent?
let logRecords = PassthroughSubject<LogRecord, Never>()

public func act<R>(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   _ subject: String, _ action: String, parameters: [String: Any?] = [:], perform: () -> R)
    -> R {
    $currentAction.withValue(Tracker.shared.begin(track: .init(subject: subject, action: action, parameters: parameters))) {
        defer { currentAction?.end() }
        return perform()
    }
}

public func trp(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ condition: Bool = true, _ message: String = "<trap>", data: Any?...) {
    guard condition
    else { return }

    log(file: file, line: line, function: function, dso: dso, level: .trace, message)
    print("<SIGTRAP>")
}

public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .trace, message)
}

#if DEBUG
public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                ifDebugging object: AnyObject, _ message: String, data: Any?...) {
    if !isDebuggingObject(object) {
        return
    }

    return log(file: file, line: line, function: function, dso: dso, level: .debug, message)
}
#endif

public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .debug, message)
}

public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .info, message)
}

public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .warning, message)
}

public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .error, message)
}

public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .fatal, message)
}

public func log(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                level: SpectreLogLevel, _ message: String, data: Any?...) {
    logRecords.send(LogRecord(
        occurrence: .now, level: level, file: file, line: line, function: function,
        message: message, action: currentAction, data: data.compactMap(\.self)
    ))
}

extension SpectreLogLevel: Identifiable, Strideable, CaseIterable, CustomStringConvertible {
    public static let allCases = [SpectreLogLevel](.fatal ... .trace)

    public func distance(to other: SpectreLogLevel) -> Int32 {
        other.rawValue - self.rawValue
    }

    public func advanced(by stride: Int32) -> SpectreLogLevel {
        SpectreLogLevel(rawValue: self.rawValue + stride)!
    }

    public var tag: String {
        switch self {
            case .trace: "TRC"
            case .debug: "DBG"
            case .info: "INF"
            case .warning: "WRN"
            case .error: "ERR"
            case .fatal: "FTL"
            @unknown default:
                fatalError("Unsupported log level: \(self.rawValue)")
        }
    }

    public var description: String {
        switch self {
            case .trace: "Trace"
            case .debug: "Debug"
            case .info: "Info"
            case .warning: "Warning"
            case .error: "Error"
            case .fatal: "Fatal"
            @unknown default:
                fatalError("Unsupported log level: \(self.rawValue)")
        }
    }
}

@globalActor
private actor LogState: GlobalActor {
    static var shared = LogState()
    private var records    = [LogRecord]()

    fileprivate func enumerate(level: SpectreLogLevel) -> [LogRecord] {
        self.records.filter { $0.level <= level }.sorted()
    }

    fileprivate func record(_ record: LogRecord) {
        self.records.append(record)
    }
}

class LogSink {
    public static let shared = LogSink()

    public var level: SpectreLogLevel {
        get { spectre_verbosity }
        set { spectre_verbosity = newValue }
    }

    private var recordSink: AnyCancellable?

    public func register() {
        Spectre.shared.use {
            guard self.recordSink == nil
            else { return }

            self.recordSink = logRecords.sink { record in
                let osLevel: OSLogType = [
                    .trace: .debug, .debug: .debug, .info: .info,
                    .warning: .default, .error: .error, .fatal: .fault,
                ][record.level] ?? .debug
                Logger(subsystem: productIdentifier, category: "\(record.fileStem):\(record.line)")
                    .log(level: osLevel, "\(record.message)")
                Task {
                    await LogState.shared.record(record)
                }
            }

            spectre_verbosity = .debug
            _ = $0.log_sink_register { eventPointer in
                guard let event = eventPointer?.pointee, let message = String.valid(event.formatter(eventPointer))
                else { return false }

                logRecords.send(LogRecord(
                    occurrence: .now, level: event.level,
                    file: .valid(event.file) ?? "", line: event.line, function: .valid(event.function) ?? "",
                    message: message, action: currentAction, data: []
                ))
                return true
            }
        }

        withObservationTracking { [weak self] in
            self?.level = AppConfig.shared.isDebug ? .debug : AppConfig.shared.diagnostics ? .info : .warning
        }
    }

    func enumerate(level: SpectreLogLevel) async -> [LogRecord] {
        await LogState.shared.enumerate(level: level)
    }
}

struct LogRecord: Comparable {
    public let occurrence: Date
    public let level:      SpectreLogLevel
    public let file:       String
    public let line:       Int32
    public let function:   String
    public let message:    String
    public let action:     Tracker.TimedEvent?
    public let data:       [Any]

    public var fileName:   String {
        FilePath(self.file).lastComponent?.string ?? self.file
    }

    public var fileStem:   String {
        FilePath(self.file).lastComponent?.stem ?? self.file
    }

    public var source:     String {
        "\(self.fileStem):\(self.line)"
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.occurrence < rhs.occurrence
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.occurrence == rhs.occurrence && lhs.level == rhs.level &&
            lhs.file == rhs.file && lhs.line == rhs.line && lhs.function == rhs.function &&
            lhs.message == rhs.message
    }
}
