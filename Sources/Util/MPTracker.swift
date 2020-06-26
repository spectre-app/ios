//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
import Countly

class MPTracker: MPConfigObserver {
    static let shared = MPTracker()

    private init() {
        // Sentry
        if let sentryDSN = decrypt( secret: sentryDSN ) {
            SentrySDK.start( options: [
                "dsn": sentryDSN,
                "debug": appConfig.isDebug,
                "environment": appConfig.isDebug ? "Development": appConfig.isPublic ? "Public": "Private",
                "enabled": appConfig.diagnostics,
                "enableAutoSessionTracking": true,
                "attachStacktrace": true,
            ] )
            SentrySDK.configureScope { $0.setTags( [ "device": self.deviceIdentifier, "owner": self.ownerIdentifier ] ) }
        }

        // Countly
        if let countlyKey = decrypt( secret: countlyKey ), let countlySalt = decrypt( secret: countlySalt ) {
            let countlyConfig = CountlyConfig()
            countlyConfig.host = "https://countly.volto.app"
            countlyConfig.appKey = countlyKey
            countlyConfig.features = [ CLYFeature.pushNotifications ]
            countlyConfig.requiresConsent = true
            #if PUBLIC
            countlyConfig.pushTestMode = nil
            #else
            countlyConfig.pushTestMode = appConfig.isDebug ? CLYPushTestMode.development: CLYPushTestMode.testFlightOrAdHoc
            #endif
            countlyConfig.alwaysUsePOST = true
            countlyConfig.secretSalt = countlySalt
            countlyConfig.deviceID = self.deviceIdentifier
            Countly.sharedInstance().start( with: countlyConfig )
        }

        // Breadcrumbs & errors
        mpw_log_sink_register( {
            guard let logEvent = $0?.pointee, logEvent.level <= .info,
                  let record = MPLogRecord( logEvent )
            else { return false }

            var sentryLevel = SentryLevel.debug
            switch record.level {
                case .info:
                    sentryLevel = .info
                case .warning:
                    sentryLevel = .warning
                case .error:
                    sentryLevel = .error
                case .fatal:
                    sentryLevel = .fatal
                default: ()
            }

            if record.level <= .error {
                let event = Event( level: sentryLevel )
                event.message = record.message
                event.logger = "mpw"
                event.timestamp = record.occurrence
                event.tags = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                SentrySDK.capture( event: event )
            }
            else {
                let breadcrumb = Breadcrumb( level: sentryLevel, category: "mpw" )
                breadcrumb.type = "log"
                breadcrumb.message = record.message
                breadcrumb.timestamp = record.occurrence
                breadcrumb.data = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                SentrySDK.addBreadcrumb( crumb: breadcrumb )
            }

            return true
        } )

        self.logout()
        appConfig.observers.register( observer: self ).didChangeConfig()
    }

    static func enabledNotifications() -> Bool {
        UIApplication.shared.isRegisteredForRemoteNotifications
    }

    static func enableNotifications() {
        appConfig.notificationsDecided = true
        UIApplication.shared.registerForRemoteNotifications()

        Countly.sharedInstance().askForNotificationPermission { _, _ in
            UNUserNotificationCenter.current().getNotificationSettings {
                if $0.authorizationStatus != .authorized {
                    if let settingsURL = URL( string: UIApplication.openSettingsURLString ) {
                        UIApplication.shared.open( settingsURL )
                    }
                }
            }
        }
    }

    static func disableNotifications() {
        appConfig.notificationsDecided = true
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    lazy var deviceIdentifier = self.identifier( for: "device", attributes: [
        kSecAttrDescription: "Unique identifier for the device on this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: false,
    ] )

    lazy var ownerIdentifier = self.identifier( for: "owner", attributes: [
        kSecAttrDescription: "Unique identifier for the owner of this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: true,
    ] )

    func identifier(for named: String, attributes: [CFString: Any] = [:]) -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "identifier",
            kSecAttrAccount: named,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
        ]

        var cfResult: CFTypeRef?
        var status = SecItemCopyMatching( query.merging( [ kSecReturnData: true ] ) as CFDictionary, &cfResult )
        if status == errSecSuccess, let data = cfResult as? Data, !data.isEmpty {
            return data.withUnsafeBytes {
                NSUUID( uuidBytes: $0.bindMemory( to: UInt8.self ).baseAddress! ).uuidString
            }
        }

        let uuid     = NSUUID()
        var uuidData = Data( count: 16 )
        uuidData.withUnsafeMutableBytes {
            uuid.getBytes( $0.bindMemory( to: UInt8.self ).baseAddress! )
        }
        SecItemDelete( query as CFDictionary )
        status = SecItemAdd( query.merging( attributes ).merging( [ kSecValueData: uuidData ] ) as CFDictionary, nil )
        if status != errSecSuccess {
            mperror( title: "Couldn't save \(named) identifier.", error: status )
        }

        return uuid.uuidString
    }

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        self.event( file: file, line: line, function: function, dso: dso,
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func login(user: MPUser) {
        guard let keyId = user.masterKeyID?.uppercased(), let userId = digest( value: keyId ), let userName = digest( value: user.fullName )
        else { return }

        let userConfig: [String: Any] = [
            "algorithm": user.algorithm,
            "avatar": user.avatar,
            "biometricLock": user.biometricLock,
            "maskPasswords": user.maskPasswords,
            "defaultType": user.defaultType,
            "sites": user.sites.count,
        ]

        let user = User( userId: userId )
        SentrySDK.setUser( user )
        user.username = userName
        user.data = userConfig
        Countly.sharedInstance().userLogged( in: userId )
        Countly.user().name = userName as NSString
        Countly.user().custom = userConfig as NSDictionary
    }

    func logout() {
        SentrySDK.setUser( nil )
        Countly.sharedInstance().userLoggedOut()
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Any] = [:]) -> Screen {
        Screen( name: name, tracker: self )
    }

    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               named name: String) -> TimedEvent {
        dbg( file: file, line: line, function: function, dso: dso, "> %@", name )

        return TimedEvent( named: name, start: Date() )
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
        SentrySDK.addBreadcrumb( crumb: sentryBreadcrumb )

        // Countly
        Countly.sharedInstance().recordEvent(
                name, segmentation: stringParameters,
                count: eventParameters["count"] as? UInt ?? 1, sum: eventParameters["sum"] as? Double ?? 0, duration: duration )
    }

    // MARK: --- MPConfigObserver ---

    public func didChangeConfig() {
        if appConfig.diagnostics {
            SentrySDK.currentHub().getClient()?.options.enabled = true
            Countly.sharedInstance().giveConsentForAllFeatures()
        }
        else {
            SentrySDK.currentHub().getClient()?.options.enabled = false
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
            SentrySDK.addBreadcrumb( crumb: sentryBreadcrumb )

            // Countly
            Countly.sharedInstance().recordView( self.name, segmentation: stringParameters )
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
        }
    }

    class TimedEvent {
        let name:      String
        let start:     Date

        private var ended = false

        init(named name: String, start: Date) {
            self.name = name
            self.start = start
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

            dbg( file: file, line: line, function: function, dso: dso, "X %@", self.name )
            self.ended = true
        }
    }
}
