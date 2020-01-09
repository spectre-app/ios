//
// Created by Maarten Billemont on 2019-11-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

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

    private var records = [ MPLogRecord ]()

    private init() {
    }

    public func register() {
        appConfig.observers.register( observer: self ).didChangeConfig()

        mpw_log_sink_register( { event in
            guard let event = event
            else { return }

            MPLogSink.shared.record( event.pointee )
        } )
    }

    public func enumerate(level: LogLevel) -> [MPLogRecord] {
        self.records.filter( { $0.level <= level } ).sorted()
    }

    fileprivate func record(_ event: MPLogEvent) {
        if let record = MPLogRecord( event ) {
            self.records.append( record )
        }
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
    public var fileName: String {
        self.file.lastPathComponent
    }
    public var source: String {
        "\(self.fileName):\(self.line)"
    }

    public init?(_ event: MPLogEvent) {
        guard let file = String( validate: event.file ),
              let function = String( validate: event.function ),
              let message = String( validate: event.message )
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

