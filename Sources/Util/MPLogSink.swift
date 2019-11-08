//
// Created by Maarten Billemont on 2019-11-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Firebase

public class MPLogSink {
    public static let shared = MPLogSink()

    public var level: LogLevel {
        get {
            mpw_verbosity
        }
        set {
            mpw_verbosity = newValue
        }
    }

    private var records = [ Record ]()

    private init() {
    }

    public func register() {
        self.level = appConfig.isDebug ? .debug: appConfig.sendInfo ? .info: .warning

        mpw_log_sink_register( { event in
            guard let event = event
            else { return }

            MPLogSink.shared.record( event.pointee )
        } )
    }

    public func enumerate(level: LogLevel) -> [Record] {
        self.records.filter( { $0.level <= level } ).sorted()
    }

    fileprivate func record(_ event: MPLogEvent) {

        guard let file = String( safeUTF8: event.file ),
              let function = String( safeUTF8: event.function ),
              let message = String( safeUTF8: event.message )
        else { return }

        self.records.append( Record( occurrence: Date( timeIntervalSince1970: TimeInterval( event.occurrence ) ),
                                     level: event.level, file: file, line: event.line, function: function, message: message ) )
    }

    public struct Record: Comparable {
        public let occurrence: Date
        public let level:      LogLevel
        public let file:       String
        public let line:       Int32
        public let function:   String
        public let message:    String
        public var source: String {
            let source = self.file.lastIndex( of: "/" ).flatMap( { String( self.file.suffix( from: self.file.index( after: $0 ) ) ) } )
            return "\(source ?? self.file):\(self.line)"
        }

        public static func <(lhs: Record, rhs: Record) -> Bool {
            lhs.occurrence < rhs.occurrence
        }

        public static func ==(lhs: Record, rhs: Record) -> Bool {
            lhs.occurrence == rhs.occurrence && lhs.level == rhs.level &&
                    lhs.file == rhs.file && lhs.line == rhs.line && lhs.function == rhs.function &&
                    lhs.message == rhs.message
        }
    }
}
