//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
import Bugsnag
import Smartlook
import Countly

typealias Value = Any

class MPTracker : MPConfigObserver {
    static let shared = MPTracker()

    var screens = [ Screen ]()

    private init() {
        // Sentry
        do {
            Client.shared = try Client( dsn: "" )
            Client.shared?.enabled = false
            Client.shared?.enableAutomaticBreadcrumbTracking()
            try Client.shared?.startCrashHandler()
        }
        catch {
            err( "Couldn't install Sentry [>TRC]" )
            trc( "[>] %@", error )
        }

        // Bugsnag
        let configuration = BugsnagConfiguration()
        configuration.apiKey = ""
        configuration.add( beforeSend: { (rawData, report) -> Bool in appConfig.sendInfo } )
        Bugsnag.start( with: configuration )

        // Breadcrumbs & errors
        mpw_log_sink_register( { event in
            if let event = event?.pointee, event.level <= .info,
               let record = MPLogRecord( event ) {
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

                if record.level <= .error {
                    let sentryEvent = Event( level: severity )
                    sentryEvent.message = record.message
                    sentryEvent.logger = "mpw"
                    sentryEvent.timestamp = record.occurrence
                    sentryEvent.tags = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    Client.shared?.appendStacktrace( to: sentryEvent )
                    Client.shared?.send( event: sentryEvent )

                    Bugsnag.notifyError( NSError( domain: "mpw", code: 0, userInfo: [ NSLocalizedDescriptionKey: record.message ] ) )
                }
                else {
                    let breadcrumb = Breadcrumb( level: severity, category: "mpw" )
                    breadcrumb.type = "log"
                    breadcrumb.message = record.message
                    breadcrumb.timestamp = record.occurrence
                    breadcrumb.data = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    Client.shared?.breadcrumbs.add( breadcrumb )

                    Bugsnag.leaveBreadcrumb {
                        $0.name = record.message
                        $0.type = .log
                        $0.metadata = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    }
                }
            }
        } )

        // Smartlook
        Smartlook.setup( key: "" )
//        Smartlook.startRecording()

        // Countly
        let config = CountlyConfig()
        config.host = "https://countly.volto.app"
        config.appKey = ""
        config.features = [ CLYPushNotifications, CLYCrashReporting ]
        config.requiresConsent = true
        config.pushTestMode = CLYPushTestModeDevelopment
        config.alwaysUsePOST = true
        config.secretSalt = ""
//        Countly.sharedInstance().isAutoViewTrackingActive = false
        Countly.sharedInstance().start( with: config )

        appConfig.observers.register( observer: self ).didChangeConfig()
    }

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        self.event( file: file, line: line, function: function, dso: dso,
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Value] = [:]) -> Screen {
        Screen( name: name, tracker: self )
    }

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
            dbg( file: file, line: line, function: function, dso: dso, "# %@", name )
        }
        else {
            dbg( file: file, line: line, function: function, dso: dso, "# %@: [%@]", name, eventParameters )
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

    // MARK: --- MPConfigObserver ---

    public func didChangeConfig() {
        if appConfig.sendInfo {
            Client.shared?.enabled = true
            Countly.sharedInstance().giveConsentForAllFeatures()
        } else {
            Client.shared?.enabled = false
            Countly.sharedInstance().cancelConsentForAllFeatures()
        }
    }

    class Screen {
        let name: String
        private let tracker: MPTracker

        init(name: String, tracker: MPTracker) {
            self.name = name
            self.tracker = tracker
        }

        func open(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                  _ parameters: [String: Value] = [:]) {
            if parameters.isEmpty {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@", self.name )
            }
            else {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@: [%@]", self.name, parameters )
            }

            let stringParameters = parameters.mapValues { String( describing: $0 ) }
            Countly.sharedInstance().recordView( self.name, segmentation: stringParameters )
            Smartlook.trackNavigationEvent( withControllerId: self.name, type: .enter )
        }

        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) -> TimedEvent {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)" )
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String, _ parameters: [String: Value] = [:]) {
            self.tracker.event( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)", parameters )
        }

        func dismiss(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            Smartlook.trackNavigationEvent( withControllerId: self.name, type: .exit )
        }
    }

    class TimedEvent {
        let name:      String
        let start:     Date
        let smartlook: Any

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

        func cancel(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            guard !self.ended
            else { return }

            Smartlook.trackTimedCustomEventCancel( eventId: self.smartlook, reason: nil, props: nil )
            dbg( file: file, line: line, function: function, dso: dso, "X %@", self.name )
            self.ended = true
        }
    }
}
