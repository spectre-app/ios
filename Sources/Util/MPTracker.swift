//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
#if APP_CONTAINER
#if RELEASE && !PUBLIC
import Updraft
#endif
import Countly
#endif

class MPTracker: MPConfigObserver {
    static let shared = MPTracker()

    #if APP_CONTAINER
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

        #if APP_CONTAINER
        // Updraft
        #if RELEASE && !PUBLIC
        if let updraftSdk = updraftSdk.b64Decrypt(), let updraftKey = updraftKey.b64Decrypt() {
            Updraft.shared.start( sdkKey: updraftSdk, appKey: updraftKey )
        }
        #endif

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

            var sentryLevel = SentryLevel.info
            switch logEvent.level {
                case .trace, .debug:
                    sentryLevel = .debug
                case .info:
                    sentryLevel = .info
                case .warning:
                    sentryLevel = .warning
                case .error:
                    sentryLevel = .error
                case .fatal:
                    sentryLevel = .fatal
                @unknown default: ()
            }
            let tags = [ "file": String.valid( logEvent.file )?.lastPathComponent ?? "-",
                         "line": "\(logEvent.line)",
                         "function": String.valid( logEvent.function ) ?? "-" ]

            if logEvent.level <= .error {
                let event = Event( level: sentryLevel )
                event.logger = "mpw"
                event.message = SentryMessage( formatted: String.valid( logEvent.formatter( logPointer ) ) ?? "-" )
                event.message.message = .valid( logEvent.format )
                event.timestamp = Date( timeIntervalSince1970: TimeInterval( logEvent.occurrence ) )
                event.tags = tags
                SentrySDK.capture( event: event )
            }
            else {
                let breadcrumb = Breadcrumb( level: sentryLevel, category: "mpw" )
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
                    named: "\(productName) #launch", [ "version": productVersion, "build": productBuild ] )
    }

    func identifier(for named: String, attributes: [CFString: Any] = [:]) -> UUID {
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
        user.masterKeyFactory?.authenticatedIdentifier( for: user.algorithm ).success { userId in
            guard let userId = userId
            else { return }

            let userConfig: [String: Any] = [
                "algorithm": user.algorithm,
                "avatar": user.avatar,
                "biometricLock": user.biometricLock,
                "maskPasswords": user.maskPasswords,
                "defaultType": user.defaultType,
                "loginType": user.loginType,
                "services": user.services.count,
            ]

            let user = User( userId: userId )
            user.data = userConfig
            SentrySDK.setUser( user )
            #if APP_CONTAINER
            Countly.sharedInstance().userLogged( in: userId )
            Countly.user().custom = userConfig as NSDictionary
            #endif

            self.event( named: "user #login", userConfig )
        }
    }

    func logout() {
        self.event( named: "user #logout" )

        SentrySDK.setUser( nil )
        #if APP_CONTAINER
        Countly.sharedInstance().userLoggedOut()
        #endif
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
        var eventParameters = parameters

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
        #if APP_CONTAINER
        Countly.sharedInstance().recordEvent(
                name, segmentation: stringParameters,
                count: eventParameters["count"] as? UInt ?? 1, sum: eventParameters["sum"] as? Double ?? 0, duration: duration )
        #endif
    }

    // MARK: --- MPConfigObserver ---

    public func didChangeConfig() {
        if appConfig.isApp && appConfig.diagnostics {
            SentrySDK.currentHub().getClient()?.options.enabled = true
            #if APP_CONTAINER
            Countly.sharedInstance().giveConsentForAllFeatures()
            #endif
        }
        else {
            SentrySDK.currentHub().getClient()?.options.enabled = false
            #if APP_CONTAINER
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
            #if APP_CONTAINER
            Countly.sharedInstance().recordView( self.name, segmentation: stringParameters )
            #endif
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
        let name:  String
        let start: Date

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
