//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
import Smartlook
import Countly

typealias Value = Any

class MPTracker {
    static let shared = MPTracker()

    private var screens = [ Screen ]()

    private init() {

        // Sentry
        do {
            Client.shared = try Client( dsn: "" )
            Client.shared?.enabled = appConfig.sendInfo as NSNumber
            try Client.shared?.startCrashHandler()
            Client.shared?.enableAutomaticBreadcrumbTracking()

            mpw_log_sink_register( { event in
                if let event: MPLogEvent = event?.pointee, event.level <= .info,
                   let message = String( safeUTF8: event.message ) {
                    var severity = SentrySeverity.debug
                    switch event.level {
                        case .info:
                            severity = .info
                        case .warning:
                            severity = .warning
                        case .error:
                            severity = .error
                        case .fatal:
                            severity = .fatal
                        default: ()
                    }

                    if event.level <= .error {
                        let sentryEvent = Event( level: severity )
                        sentryEvent.message = message
                        sentryEvent.logger = "mpw"
                        sentryEvent.timestamp = Date( timeIntervalSince1970: TimeInterval( event.occurrence ) )
                        var file = String( safeUTF8: event.file ) ?? "-"
                        file = file.lastIndex( of: "/" ).flatMap( { String( file.suffix( from: file.index( after: $0 ) ) ) } ) ?? file
                        sentryEvent.tags = [ "file": file, "line": "\(event.line)", "function": String( safeUTF8: event.function ) ?? "-" ]
                        Client.shared?.appendStacktrace( to: sentryEvent )
                        Client.shared?.send( event: sentryEvent )
                    }
                    else {
                        let breadcrumb = Breadcrumb( level: severity, category: "mpw" )
                        breadcrumb.type = message
                        breadcrumb.message = message
                        breadcrumb.timestamp = Date( timeIntervalSince1970: TimeInterval( event.occurrence ) )
                        var file = String( safeUTF8: event.file ) ?? "-"
                        file = file.lastIndex( of: "/" ).flatMap( { String( file.suffix( from: file.index( after: $0 ) ) ) } ) ?? file
                        breadcrumb.data = [ "file": file, "line": "\(event.line)", "function": String( safeUTF8: event.function ) ?? "-" ]
                        Client.shared?.breadcrumbs.add( breadcrumb )
                    }
                }
            } )
        }
        catch {
            err( "Couldn't install Sentry [>TRC]" )
            trc( "[>] %@", error )
        }

        // Smartlook
        Smartlook.setup( key: "" )
        Smartlook.startRecording()

        // Countly
        let config = CountlyConfig()
        config.host = "https://try.count.ly"
        config.appKey = ""
        config.enableDebug = true
        config.features = [ CLYPushNotifications, CLYCrashReporting, CLYAutoViewTracking ]
        config.requiresConsent = true
        config.pushTestMode = CLYPushTestModeDevelopment
        config.alwaysUsePOST = true
        config.secretSalt = ""
        Countly.sharedInstance().start( with: config )
        Countly.sharedInstance().giveConsentForAllFeatures()
    }

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        self.event( file: file, line: line, function: function, dso: dso,
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String) -> Screen {
        let screen = Screen( name: name, tracker: self )
        self.screens.append( screen )

        screen.begin( file: file, line: line, function: function, dso: dso )
        screen.event( file: file, line: line, function: function, dso: dso, event: "open" )

        return screen
    }

    @discardableResult
    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String) -> TimedEvent {
        dbg( file: file, line: line, function: function, dso: dso, "> %@", name )

        return TimedEvent( named: name, start: Date(), smartlook: Smartlook.startTimedCustomEvent( name: name, props: nil ) )
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String, _ parameters: [String: Value] = [:], timing: TimedEvent? = nil) {
        var duration        = TimeInterval( 0 )
        var eventParameters = parameters
        if let timing = timing {
            duration = Date().timeIntervalSince( timing.start )
            eventParameters["duration"] = Int( duration )
        }
        let stringParameters = eventParameters.mapValues { String( describing: $0 ) }

        if eventParameters.isEmpty {
            dbg( file: file, line: line, function: function, dso: dso, "@ %@", name )
        }
        else {
            dbg( file: file, line: line, function: function, dso: dso, "@ %@: [%@]", name, eventParameters )
        }

        Countly.sharedInstance().recordEvent(
                name, segmentation: stringParameters,
                count: eventParameters["count"] as? UInt ?? 1, sum: eventParameters["sum"] as? Double ?? 0, duration: duration )
        if let timing = timing {
            Smartlook.trackTimedCustomEvent( eventId: timing.smartlook, props: stringParameters )
        }
        else {
            Smartlook.trackCustomEvent( name: name, props: stringParameters )
        }
    }

    func cancel(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                timing: TimedEvent) {
        Smartlook.trackTimedCustomEventCancel( eventId: timing.smartlook, reason: nil, props: nil )
        dbg( file: file, line: line, function: function, dso: dso, "X %@", timing.name )
    }

    class Screen {
        let name: String
        private let tracker: MPTracker
        private var timing:  MPTracker.TimedEvent?

        init(name: String, tracker: MPTracker) {
            self.name = name
            self.tracker = tracker
        }

        fileprivate func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            self.timing = self.tracker.begin( file: file, line: line, function: function, dso: dso, named: self.name )
        }

        @discardableResult
        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) -> TimedEvent {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)" )
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) {
            self.tracker.event( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)" )
        }

        func dismiss(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            self.event( file: file, line: line, function: function, dso: dso, event: "close" )
            self.timing?.end( file: file, line: line, function: function, dso: dso )

            self.tracker.screens.removeAll { $0 === self }
        }
    }

    class TimedEvent {
        let name: String
        let start : Date
        let smartlook : Any

        private var ended = false

        init(named name: String, start: Date, smartlook: Any) {
            self.name = name
            self.start = start
            self.smartlook = smartlook
        }

        deinit {
            self.cancel()
        }

        func end(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 _ parameters: [String: Value] = [:]) {
            guard !self.ended
            else { return }

            MPTracker.shared.event( file: file, line: line, function: function, dso: dso, named: self.name, parameters, timing: self )
            self.ended = true
        }

        func cancel() {
            guard !self.ended
            else { return }

            MPTracker.shared.cancel( timing: self )
            self.ended = true
        }
    }
}
