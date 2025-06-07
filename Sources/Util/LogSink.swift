//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Combine
import Foundation
import os
import OSLog
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

    log(file: file, line: line, function: function, dso: dso, level: .trace, message, data: data)
    print("<SIGTRAP>")
}

public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .trace, message, data: data)
}

#if DEBUG
public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                ifDebugging object: AnyObject, _ message: String, data: Any?...) {
    if !isDebuggingObject(object) {
        return
    }

    return log(file: file, line: line, function: function, dso: dso, level: .debug, message, data: data)
}
#endif

public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .debug, message, data: data)
}

public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .info, message, data: data)
}

public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .warning, message, data: data)
}

public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .error, message, data: data)
}

public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ message: String, data: Any?...) {
    log(file: file, line: line, function: function, dso: dso, level: .fatal, message, data: data)
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

class LogSink {
    public static let shared = LogSink()

    public var level: SpectreLogLevel {
        get { spectre_verbosity }
        set { spectre_verbosity = newValue }
    }

    private var recordSink: AnyCancellable?
    private var dateFormatter = using(DateFormatter()) {
        $0.dateFormat = "DDD'-'HH':'mm':'ss"
    }

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
                    .log(level: osLevel,
                    """
                    \("\(let: record.action?.tracking, "({}) ")")\
                    \(record.message)\
                    \("\(let: record.data.nonEmpty, "\n{}")", privacy: .sensitive(mask: .none))
                    """)
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

    func enumerate(level: SpectreLogLevel) async -> [String] {
        let levels: [OSLogType] = SpectreLogLevel.allCases.filter({ $0.rawValue <= level.rawValue }).compactMap {
            [
                .trace: .debug, .debug: .debug, .info: .info,
                .warning: .default, .error: .error, .fatal: .fault,
            ][$0]
        }
        do {
            return try OSLogStore(scope: .currentProcessIdentifier)
                .getEntries(matching: NSPredicate(
                    format: "(subsystem == 'app.spectre' AND messageType IN %@) OR messageType IN { 0x10, 0x11 }", levels.map(\.rawValue)
                ))
                .compactMap { $0 as? OSLogEntryLog }
                .map { "\(self.dateFormatter.string(from: $0.date)) \($0.level) | \($0.composedMessage)" }
        } catch {
            return ["Couldn't access logs: \(error)"]
        }
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

extension OSLogEntryLog.Level: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
            case .debug:      "DBG"
            case .info:       "INF"
            case .notice:     "NOT"
            case .error:      "ERR"
            case .fault:      "FLT"
            case .undefined:  "UND"
            @unknown default: "UNK"
        }
    }
}
