//
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import Sentry
import Smartlook
import Countly

class MPTracker: MPConfigObserver {
    static let shared = MPTracker()

    private init() {
        // Sentry
        if let sentryDSN = decrypt( secret: sentryDSN ) {
            do {
                Sentry.Client.shared = try Sentry.Client( dsn: sentryDSN )
                Sentry.Client.shared?.enabled = appConfig.diagnostics as NSNumber
                Sentry.Client.shared?.enableAutomaticBreadcrumbTracking()
                Sentry.Client.shared?.tags = [ "device": self.deviceIdentifier, "owner": self.ownerIdentifier ]
                try Sentry.Client.shared?.startCrashHandler()
            }
            catch {
                err( "Couldn't install Sentry [>TRC]" )
                trc( "[>] %@", error )
            }
        }

        // Countly
        if let countlyKey = decrypt( secret: countlyKey ), let countlySalt = decrypt( secret: countlySalt ) {
            let countlyConfig = CountlyConfig()
            countlyConfig.host = "https://countly.volto.app"
            countlyConfig.appKey = countlyKey
            countlyConfig.features = [ CLYPushNotifications ]
            countlyConfig.requiresConsent = true
            #if PUBLIC
            countlyConfig.pushTestMode = nil
            #else
            countlyConfig.pushTestMode = appConfig.isDebug ? CLYPushTestModeDevelopment: CLYPushTestModeTestFlightOrAdHoc
            #endif
            countlyConfig.alwaysUsePOST = true
            countlyConfig.secretSalt = countlySalt
            countlyConfig.deviceID = self.deviceIdentifier
            Countly.sharedInstance().start( with: countlyConfig )
        }

        // Smartlook
        if !appConfig.isPublic, let smartlookKey = decrypt( secret: smartlookKey ) {
            Smartlook.setSessionProperty( value: self.deviceIdentifier, forName: "device" )
            Smartlook.setSessionProperty( value: self.ownerIdentifier, forName: "owner" )
            Smartlook.setup( key: smartlookKey )

            Sentry.Client.shared?.extra?["smartlook"] = Smartlook.getDashboardSessionURL()
        }

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
                }
                else {
                    let breadcrumb = Breadcrumb( level: sentrySeverity, category: "mpw" )
                    breadcrumb.type = "log"
                    breadcrumb.message = record.message
                    breadcrumb.timestamp = record.occurrence
                    breadcrumb.data = [ "file": record.fileName, "line": "\(record.line)", "function": record.function ]
                    Sentry.Client.shared?.breadcrumbs.add( breadcrumb )
                }
            }
        } )

        self.logout()
        appConfig.observers.register( observer: self ).didChangeConfig()
    }

    static func enabledNotifications() -> Bool {
        UIApplication.shared.isRegisteredForRemoteNotifications &&
                !(UIApplication.shared.currentUserNotificationSettings?.types.isEmpty ?? true)
    }

    static func enableNotifications() {
        appConfig.notificationsDecided = true
        UIApplication.shared.registerForRemoteNotifications()

        if #available( iOS 10, * ) {
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
        else {
            Countly.sharedInstance().askForNotificationPermission()
            if !self.enabledNotifications(), let settingsURL = URL( string: UIApplication.openSettingsURLString ) {
                UIApplication.shared.openURL( settingsURL )
            }
        }
    }

    static func disableNotifications() {
        appConfig.notificationsDecided = true
        UIApplication.shared.unregisterForRemoteNotifications()

        if self.enabledNotifications(), let settingsURL = URL( string: UIApplication.openSettingsURLString ) {
            UIApplication.shared.openURL( settingsURL )
        }
    }

    lazy var deviceIdentifier = self.identifier( for: "device", attributes: [
        kSecAttrDescription: "Unique identifier for the device on this app.",
        kSecAttrAccessible: kSecAttrAccessibleAlwaysThisDeviceOnly,
        kSecAttrSynchronizable: false,
    ] )

    lazy var ownerIdentifier = self.identifier( for: "owner", attributes: [
        kSecAttrDescription: "Unique identifier for the owner of this app.",
        kSecAttrAccessible: kSecAttrAccessibleAlways,
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
        guard let keyId = user.masterKeyID, let userId = digest( value: keyId ), let userName = digest( value: user.fullName )
        else { return }

        if let activeUserId = Sentry.Client.shared?.user?.userId {
            err( "User logged in while another still active. [>TRC]" )
            trc( "[>] Active user: %s, will replace by login user: %s", activeUserId, userId )
        }

        let userConfig: [String: Any] = [
            "algorithm": user.algorithm,
            "avatar": user.avatar,
            "biometricLock": user.biometricLock,
            "maskPasswords": user.maskPasswords,
            "defaultType": user.defaultType,
            "sites": user.sites.count,
        ]

        Sentry.Client.shared?.user = Sentry.User( userId: userId )
        Sentry.Client.shared?.user?.username = userName
        Sentry.Client.shared?.user?.extra = userConfig
        Countly.sharedInstance().userLogged( in: userId )
        Countly.user().name = userName as NSString
        Countly.user().custom = userConfig as NSDictionary
        Smartlook.setUserIdentifier( userId )
    }

    func logout() {
        Sentry.Client.shared?.user = nil
        Countly.sharedInstance().userLoggedOut()
        Smartlook.setUserIdentifier( "n/a" )
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
        if appConfig.diagnostics {
            Sentry.Client.shared?.enabled = true
            Countly.sharedInstance().giveConsentForAllFeatures()
            if !appConfig.isPublic && !Smartlook.isRecording() {
                Smartlook.startRecording()
            }
        }
        else {
            Sentry.Client.shared?.enabled = false
            Countly.sharedInstance().cancelConsentForAllFeatures()
            if !appConfig.isPublic && Smartlook.isRecording() {
                Smartlook.stopRecording()
            }
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
