//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
import Bugsnag
import Smartlook
import Countly

let appSecret    = ""
let sentryDSN    = ""
let bugsnagKey   = ""
let smartlookKey = ""
let countlyKey   = ""
let countlySalt  = ""

class MPTracker: MPConfigObserver {
    static let shared = MPTracker()

    private init() {
        // Sentry
        do {
            let sentry = try Sentry.Client( dsn: sentryDSN )
            Sentry.Client.shared = sentry

            sentry.enabled = false
            sentry.enableAutomaticBreadcrumbTracking()
            try sentry.startCrashHandler()
        }
        catch {
            err( "Couldn't install Sentry [>TRC]" )
            trc( "[>] %@", error )
        }

        // Bugsnag
        let bugsnagConfig = BugsnagConfiguration()
        bugsnagConfig.apiKey = bugsnagKey
        bugsnagConfig.add( beforeSend: { (rawData, report) -> Bool in appConfig.sendInfo } )
        Bugsnag.start( with: bugsnagConfig )

        // Countly
        let countlyConfig = CountlyConfig()
        countlyConfig.host = "https://countly.volto.app"
        countlyConfig.appKey = countlyKey
        countlyConfig.features = [ CLYPushNotifications, CLYCrashReporting ]
        countlyConfig.requiresConsent = true
        countlyConfig.pushTestMode = CLYPushTestModeDevelopment
        countlyConfig.alwaysUsePOST = true
        countlyConfig.secretSalt = countlySalt
        Countly.sharedInstance().start( with: countlyConfig )

        // Smartlook
        Smartlook.setup( key: smartlookKey )
//        Smartlook.startRecording()

        // Breadcrumbs & errors
        mpw_log_sink_register( {
            if let logEvent = $0?.pointee, logEvent.level <= .info,
               let record = MPLogRecord( logEvent ) {

                var sentrySeverity = SentrySeverity.debug
                switch record.level {
                    case .info:
                        sentrySeverity = .info
                    case .warning:
                        sentrySeverity = .warning
                    case .error:
                        sentrySeverity = .error
                    case .fatal:
                        sentrySeverity = .fatal
                    default: ()
                }

                if record.level <= .error {
                    let event = Event( level: sentrySeverity )
                    event.message = record.message
                    event.logger = "mpw"
                    event.timestamp = record.occurrence
                    event.tags = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    Sentry.Client.shared?.appendStacktrace( to: event )
                    Sentry.Client.shared?.send( event: event )

                    Bugsnag.notifyError( NSError( domain: "mpw", code: 0, userInfo: [ NSLocalizedDescriptionKey: record.message ] ) )
                }
                else {
                    let breadcrumb = Breadcrumb( level: sentrySeverity, category: "mpw" )
                    breadcrumb.type = "log"
                    breadcrumb.message = record.message
                    breadcrumb.timestamp = record.occurrence
                    breadcrumb.data = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    Sentry.Client.shared?.breadcrumbs.add( breadcrumb )

                    Bugsnag.leaveBreadcrumb {
                        $0.name = record.message
                        $0.type = .log
                        $0.metadata = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    }
                }
            }
        } )

        appConfig.observers.register( observer: self ).didChangeConfig()
    }

    lazy var deviceIdentifier = self.identifier( for: "device", attributes: [
        kSecAttrDescription: "Unique identifier for the device on this app.",
        kSecAttrAccessible: kSecAttrAccessibleAlwaysThisDeviceOnly,
        kSecAttrSynchronizable: false,
    ] )

    lazy var userIdentifier = self.identifier( for: "user", attributes: [
        kSecAttrDescription: "Unique identifier for the user of this app.",
        kSecAttrAccessible: kSecAttrAccessibleAlways,
        kSecAttrSynchronizable: true,
    ] )

    func identifier(for named: String, attributes: [CFString: Any] = [:]) -> String {
        let query:    [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "identifier",
            kSecAttrAccount: named,
            kSecReturnData: true
        ]
        var cfResult: CFTypeRef?
        var status                    = SecItemCopyMatching( query as CFDictionary, &cfResult )
        if status == errSecSuccess, let data = cfResult as? Data {
            return data.withUnsafeBytes( { NSUUID( uuidBytes: $0.baseAddress?.assumingMemoryBound( to: UInt8.self ) ).uuidString } )
        }

        let uuid      = NSUUID()
        let uuidBytes = UnsafeMutablePointer<UInt8>.allocate( capacity: 16 )
        uuidBytes.initialize( repeating: 0, count: 16 )
        uuid.getBytes( uuidBytes )

        let value = attributes.merging( [ kSecValueData: uuidBytes ], uniquingKeysWith: { $1 } )
        status = SecItemAdd( query.merging( value, uniquingKeysWith: { $1 } ) as CFDictionary, nil )
        if status != errSecSuccess {
            mperror( title: "Couldn't save device identifier.", error: status )
        }

        return uuid.uuidString
    }

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        self.event( file: file, line: line, function: function, dso: dso,
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func login(userId: String) {
        guard let saltedUser = mpw_hash_hmac_sha256( appSecret, appSecret.lengthOfBytes( using: .utf8 ),
                                                     userId, userId.lengthOfBytes( using: .utf8 ) )
        else { return }
        defer { saltedUser.deallocate() }
        guard let saltedUserId = String( safeUTF8: mpw_hex( saltedUser, 32 ) )
        else { return }

        Sentry.Client.shared?.user = Sentry.User( userId: saltedUserId )
        Bugsnag.configuration()?.setUser( saltedUserId, withName: nil, andEmail: nil )
        Countly.sharedInstance().userLogged( in: saltedUserId )
        Smartlook.setUserIdentifier( saltedUserId )
        saltedUser.deallocate()
    }

    func logout() {
        Sentry.Client.shared?.user = nil
        Bugsnag.configuration()?.setUser( nil, withName: nil, andEmail: nil )
        Countly.sharedInstance().userLoggedOut()
        Smartlook.setUserIdentifier( nil )
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Any] = [:]) -> Screen {
        Screen( name: name, tracker: self )
    }

    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String) -> TimedEvent {
        dbg( file: file, line: line, function: function, dso: dso, "> %@", name )

        return TimedEvent( named: name, start: Date(), smartlook: Smartlook.startTimedCustomEvent( name: name, props: nil ) )
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String, _ parameters: [String: Any] = [:], timing: TimedEvent? = nil) {
        var eventParameters: [String: Any] = [ "file": file.lastPathComponent, "line": "\(line)", "function": function ]

        var duration = TimeInterval( 0 )
        if let timing = timing {
            duration = Date().timeIntervalSince( timing.start )
            eventParameters["duration"] = "\(duration, numeric: "0.#")"
        }

        eventParameters.merge( parameters, uniquingKeysWith: { $1 } )
        let stringParameters = eventParameters.mapValues { String( describing: $0 ) }

        // Log
        if eventParameters.isEmpty {
            dbg( file: file, line: line, function: function, dso: dso, "# %@", name )
        }
        else {
            dbg( file: file, line: line, function: function, dso: dso, "# %@: [%@]", name, eventParameters )
        }

        // Sentry
        let sentryBreadcrumb = Breadcrumb( level: .info, category: "event" )
        sentryBreadcrumb.type = "user"
        sentryBreadcrumb.message = name
        sentryBreadcrumb.data = eventParameters
        Sentry.Client.shared?.breadcrumbs.add( sentryBreadcrumb )

        // Bugsnag
        Bugsnag.leaveBreadcrumb {
            $0.name = name
            $0.type = .user
            $0.metadata = eventParameters
        }

        // Countly
        Countly.sharedInstance().recordEvent(
                name, segmentation: stringParameters,
                count: eventParameters["count"] as? UInt ?? 1, sum: eventParameters["sum"] as? Double ?? 0, duration: duration )

        // Smartlook
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
            Sentry.Client.shared?.enabled = true
            Countly.sharedInstance().giveConsentForAllFeatures()
        }
        else {
            Sentry.Client.shared?.enabled = false
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
                  _ parameters: [String: Any] = [:]) {
            let eventParameters = [ "file": file.lastPathComponent, "line": "\(line)", "function": function ]
                    .merging( parameters, uniquingKeysWith: { $1 } )
            let stringParameters = eventParameters.mapValues { String( describing: $0 ) }

            // Log
            if eventParameters.isEmpty {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@", self.name )
            }
            else {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@: [%@]", self.name, eventParameters )
            }

            // Sentry
            let sentryBreadcrumb = Breadcrumb( level: .info, category: "screen" )
            sentryBreadcrumb.type = "navigation"
            sentryBreadcrumb.message = self.name
            sentryBreadcrumb.data = eventParameters
            Sentry.Client.shared?.breadcrumbs.add( sentryBreadcrumb )

            // Bugsnag
            Bugsnag.leaveBreadcrumb {
                $0.name = self.name
                $0.type = .navigation
                $0.metadata = eventParameters
            }

            // Countly
            Countly.sharedInstance().recordView( self.name, segmentation: stringParameters )

            // Smartlook
            Smartlook.trackNavigationEvent( withControllerId: self.name, type: .enter )
        }

        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String) -> TimedEvent {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, named: "\(self.name) #\(event)" )
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   event: String, _ parameters: [String: Any] = [:]) {
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
                 _ parameters: [String: Any] = [:]) {
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
