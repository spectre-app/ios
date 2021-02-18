//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
#if TARGET_APP
import Countly
#endif

struct MPTracking {
    let subject:    String
    let action:     String
    let parameters: () -> [String: Any]

    static func subject(_ subject: String, action: String, _ parameters: @autoclosure @escaping () -> [String: Any] = [:]) -> MPTracking {
        MPTracking( subject: subject, action: action, parameters: parameters )
    }

    func scoped(_ scope: String) -> MPTracking {
        MPTracking( subject: "\(scope)::\(self.subject)", action: self.action, parameters: self.parameters )
    }

    func with(parameters: @autoclosure @escaping () -> [String: Any] = [:]) -> MPTracking {
        MPTracking( subject: self.subject, action: self.action, parameters: { self.parameters().merging( parameters() ) } )
    }
}

class MPTracker: MPConfigObserver {
    static let shared = MPTracker()

    #if TARGET_APP
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
    #endif

    lazy var deviceIdentifier = self.identifier( for: "device", attributes: [
        kSecAttrDescription: "Unique identifier for the device on this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: false,
    ] ).uuidString

    lazy var ownerIdentifier = self.identifier( for: "owner", attributes: [
        kSecAttrDescription: "Unique identifier for the owner of this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: true,
    ] ).uuidString

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 extensionController: UIViewController? = nil) {
        // Sentry
        SentrySDK.start {
            $0.dsn = appConfig.diagnostics ? sentryDSN.b64Decrypt(): nil
            $0.environment = appConfig.isDebug ? "Development": appConfig.isPublic ? "Public": "Private"
        }
        SentrySDK.configureScope { $0.setTags( [ "device": self.deviceIdentifier, "owner": self.ownerIdentifier ] ) }

        #if TARGET_APP
        // Countly
        if let countlyKey = countlyKey.b64Decrypt(), let countlySalt = countlySalt.b64Decrypt() {
            let countlyConfig = CountlyConfig()
            countlyConfig.host = "https://countly.spectre.app"
            countlyConfig.appKey = countlyKey
            countlyConfig.features = [ CLYFeature.pushNotifications ]
            countlyConfig.requiresConsent = true
            #if PUBLIC
            countlyConfig.pushTestMode = nil
            #else
            countlyConfig.pushTestMode = appConfig.isDebug ? .development: .testFlightOrAdHoc
            #endif
            countlyConfig.alwaysUsePOST = true
            countlyConfig.secretSalt = countlySalt
            countlyConfig.deviceID = self.deviceIdentifier
            countlyConfig.urlSessionConfiguration = URLSession.optionalConfiguration()
            Countly.sharedInstance().start( with: countlyConfig )
        }
        #endif

        // Breadcrumbs & errors
        mpw_log_sink_register( { logPointer in
            guard let logEvent = logPointer?.pointee, logEvent.level <= .info
            else { return false }

            let level: SentryLevel = map( logEvent.level, [
                .trace: .debug, .debug: .debug, .info: .info, .warning: .warning, .error: .error, .fatal: .fatal ] ) ?? .debug
            let tags               =
                    [ "file": String.valid( logEvent.file )?.lastPathComponent ?? "-",
                      "line": "\(logEvent.line)",
                      "function": String.valid( logEvent.function ) ?? "-" ]

            if logEvent.level <= .error {
                let event = Event( level: level )
                event.logger = "api"
                event.message = SentryMessage( formatted: String.valid( logEvent.formatter( logPointer ) ) ?? "-" )
                event.message?.message = .valid( logEvent.format )
                event.timestamp = Date( timeIntervalSince1970: TimeInterval( logEvent.occurrence ) )
                event.tags = tags
                SentrySDK.capture( event: event )
            }
            else {
                let breadcrumb = Breadcrumb( level: level, category: "api" )
                breadcrumb.type = "log"
                breadcrumb.message = .valid( logEvent.format )
                breadcrumb.timestamp = Date( timeIntervalSince1970: TimeInterval( logEvent.occurrence ) )
                breadcrumb.data = tags
                SentrySDK.addBreadcrumb( crumb: breadcrumb )
            }

            return true
        } )

        self.logout()
        appConfig.observers.register( observer: self ).didChangeConfig()

        self.event( file: file, line: line, function: function, dso: dso,
                    track: .subject( productName, action: "startup", [ "version": productVersion, "build": productBuild ] ) )
    }

    private func identifier(for named: String, attributes: [CFString: Any] = [:]) -> UUID {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "identifier",
            kSecAttrAccount: named,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
        ]

        var cfResult: CFTypeRef?
        var status = SecItemCopyMatching( query.merging( [ kSecReturnData: true ] ) as CFDictionary, &cfResult )
        if status == errSecSuccess, let data = cfResult as? Data, !data.isEmpty {
            return data.withUnsafeBytes( { UUID( uuid: $0.load( as: uuid_t.self ) ) } )
        }

        let uuid = UUID()
        let uuidData = withUnsafePointer( to: uuid.uuid ) { Data( buffer: UnsafeBufferPointer( start: $0, count: 1 ) ) }
        SecItemDelete( query as CFDictionary )
        status = SecItemAdd( query.merging( attributes ).merging( [ kSecValueData: uuidData ] ) as CFDictionary, nil )
        if status != errSecSuccess {
            mperror( title: "Couldn't save \(named) identifier.", error: status )
        }

        return uuid
    }

    func login(user: MPUser) {
        user.userKeyFactory?.authenticatedIdentifier( for: user.algorithm ).success { userId in
            guard let userId = userId
            else { return }

            let userConfig: [String: Any] = [
                "algorithm": user.algorithm,
                "avatar": user.avatar,
                "biometricLock": user.biometricLock,
                "maskPasswords": user.maskPasswords,
                "defaultType": user.defaultType,
                "loginType": user.loginType,
                "sites": user.sites.count,
            ]

            let user = User( userId: userId )
            user.data = userConfig
            SentrySDK.setUser( user )
            #if TARGET_APP
            Countly.sharedInstance().userLogged( in: userId )
            Countly.user().custom = userConfig as NSDictionary
            #endif

            self.event( track: .subject( "user", action: "signed_in", userConfig ) )
        }
    }

    func logout() {
        self.event( track: .subject( "user", action: "signed_out" ) )

        SentrySDK.setUser( nil )
        #if TARGET_APP
        Countly.sharedInstance().userLoggedOut()
        #endif
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Any] = [:]) -> Screen {
        Screen( name: name, tracker: self )
    }

    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               track: MPTracking) -> TimedEvent {
        dbg( file: file, line: line, function: function, dso: dso, "> %@ #%@", track.subject, track.action )
        return TimedEvent( track: track, start: Date() )
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               track: MPTracking) {
        self.event( file: file, line: line, function: function, dso: dso, named: "\(track.subject) >\(track.action)", track.parameters() )
    }

    private func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                       named name: String, _ parameters: [String: Any] = [:], timing: TimedEvent? = nil) {
        var eventParameters = parameters
        #if TARGET_APP
        eventParameters["using"] = "app"
        #elseif TARGET_AUTOFILL
        eventParameters["using"] = "autofill"
        #endif

        var duration = TimeInterval( 0 )
        if let timing = timing {
            duration = Date().timeIntervalSince( timing.start )
            eventParameters["duration"] = "\(number: duration, as: "0.#")"
        }

        // Log
        if eventParameters.isEmpty {
            dbg( file: file, line: line, function: function, dso: dso, "# %@", name )
        }
        else {
            dbg( file: file, line: line, function: function, dso: dso, "# %@: [%@]", name, eventParameters )
        }

        eventParameters.merge( [ "file": file.lastPathComponent, "line": "\(line)", "function": function ], uniquingKeysWith: { $1 } )
        let stringParameters = eventParameters.mapValues { String( reflecting: $0 ) }

        // Sentry
        let sentryBreadcrumb = Breadcrumb( level: .info, category: "event" )
        sentryBreadcrumb.type = "user"
        sentryBreadcrumb.message = name
        sentryBreadcrumb.data = eventParameters
        SentrySDK.addBreadcrumb( crumb: sentryBreadcrumb )

        // Countly
        #if TARGET_APP
        Countly.sharedInstance().recordEvent(
                name, segmentation: stringParameters,
                count: eventParameters["count"] as? UInt ?? 1, sum: eventParameters["sum"] as? Double ?? 0, duration: duration )
        #endif
    }

    // MARK: --- MPConfigObserver ---

    public func didChangeConfig() {
        if appConfig.isApp && appConfig.diagnostics {
            SentrySDK.currentHub().getClient()?.options.enabled = true
            #if TARGET_APP
            Countly.sharedInstance().giveConsentForAllFeatures()
            #endif
        }
        else {
            SentrySDK.currentHub().getClient()?.options.enabled = false
            #if TARGET_APP
            Countly.sharedInstance().cancelConsentForAllFeatures()
            #endif
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
            // Log
            if parameters.isEmpty {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@", self.name )
            }
            else {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@: [%@]", self.name, parameters )
            }

            let eventParameters = [ "file": file.lastPathComponent, "line": "\(line)", "function": function ]
                    .merging( parameters, uniquingKeysWith: { $1 } )
            let stringParameters = eventParameters.mapValues { String( reflecting: $0 ) }

            // Sentry
            let sentryBreadcrumb = Breadcrumb( level: .info, category: "screen" )
            sentryBreadcrumb.type = "navigation"
            sentryBreadcrumb.message = self.name
            sentryBreadcrumb.data = eventParameters
            SentrySDK.addBreadcrumb( crumb: sentryBreadcrumb )

            // Countly
            #if TARGET_APP
            Countly.sharedInstance().recordView( self.name, segmentation: stringParameters )
            #endif
        }

        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   track: MPTracking) -> TimedEvent {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, track: track.scoped( self.name ) )
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   track: MPTracking) {
            self.tracker.event( file: file, line: line, function: function, dso: dso, track: track.scoped( self.name ) )
        }

        func dismiss(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        }
    }

    class TimedEvent {
        let tracking: MPTracking
        let start:    Date

        private var ended = false

        init(track: MPTracking, start: Date) {
            self.tracking = track
            self.start = start
        }

        deinit {
            self.cancel()
        }

        func end(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 _ parameters: [String: Any] = [:]) {
            guard !self.ended
            else { return }

            MPTracker.shared.event( file: file, line: line, function: function, dso: dso,
                                    named: "\(self.tracking.subject) #\(self.tracking.action)",
                                    self.tracking.parameters().merging( parameters ), timing: self )
            self.ended = true
        }

        func cancel(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            guard !self.ended
            else { return }

            dbg( file: file, line: line, function: function, dso: dso, "> %@ X%@", self.tracking.subject, self.tracking.action )
            self.ended = true
        }
    }
}
