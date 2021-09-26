// =============================================================================
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation
import Stacksift
import Sentry
import Countly

struct Tracking {
    let subject:    String
    let action:     String
    let parameters: () -> [String: Any?]

    static func subject(_ subject: String, action: String, _ parameters: @autoclosure @escaping () -> [String: Any?] = [:]) -> Tracking {
        Tracking( subject: subject, action: action, parameters: parameters )
    }

    func scoped(_ scope: String) -> Tracking {
        Tracking( subject: "\(scope)::\(self.subject)", action: self.action, parameters: self.parameters )
    }

    func with(parameters: @autoclosure @escaping () -> [String: Any?] = [:]) -> Tracking {
        Tracking( subject: self.subject, action: self.action, parameters: { self.parameters().merging( parameters() ) } )
    }
}

class Tracker: AppConfigObserver {
    static let shared = Tracker()

    public let observers = Observers<TrackerObserver>()

    #if TARGET_APP
    func enabledNotifications() -> Bool {
        UIApplication.shared.isRegisteredForRemoteNotifications
    }

    func enableNotifications(consented: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().getNotificationSettings {
            if $0.authorizationStatus == .authorized {
                DispatchQueue.main.perform {
                    AppConfig.shared.notificationsDecided = true
                    if self.hasCountlyStarted {
                        Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
                    }
                    self.observers.notify { $0.didChange( tracker: self ) }
                    completion( true )
                }
                return
            }

            UNUserNotificationCenter.current().requestAuthorization( options: [ .alert, .badge, .sound ] ) { granted, error in
                DispatchQueue.main.perform {
                    AppConfig.shared.notificationsDecided = true

                    if let error = error {
                        wrn( "Notifications not authorized: %@ [>PII]", error.localizedDescription )
                        pii( "[>] Error: %@", error )
                    }
                    if granted {
                        if self.hasCountlyStarted {
                            Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
                        }
                        self.observers.notify { $0.didChange( tracker: self ) }
                        completion( true )
                        return
                    }

                    if consented, let settingsURL = URL( string: UIApplication.openSettingsURLString ) {
                        if self.hasCountlyStarted {
                            Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
                        }
                        self.observers.notify { $0.didChange( tracker: self ) }
                        UIApplication.shared.open( settingsURL )
                        completion( true )
                        return
                    }

                    completion( false )
                }
            }
        }
    }

    func disableNotifications() {
        AppConfig.shared.notificationsDecided = true

        if self.hasCountlyStarted {
            Countly.sharedInstance().cancelConsent( forFeature: .pushNotifications )
        }
    }
    #endif

    // identifierForVendor     | survives: restart                           -- doesn't survive: reinstall, other devices
    // identifierForDevice     | survives: restart, reinstall                -- doesn't survive: other devices
    // identifierForOwner      | survives: restart, reinstall, owned devices -- doesn't survive: unowned devices
    // authenticatedIdentifier | survives: restart, reinstall, all devices   -- doesn't survive:
    var identifierForVendor: String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
    lazy var identifierForDevice = self.identifier( for: "device", attributes: [
        kSecAttrDescription: "Unique identifier for the device running this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: false,
    ] ).uuidString
    lazy var identifierForOwner  = self.identifier( for: "owner", attributes: [
        kSecAttrDescription: "Unique identifier for the owner of this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: true,
    ] ).uuidString
    private lazy var identifiers
            = [ "id.vendor": self.identifierForVendor, "id.device": self.identifierForDevice, "id.owner": self.identifierForOwner ]

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 extensionController: UIViewController? = nil) {
        inf( "Startup [identifiers: %@]", self.identifiers )

        // Breadcrumbs & errors
        spectre_log_sink_register( { logPointer in
            guard let logEvent = logPointer?.pointee, logEvent.level <= .info
            else { return false }

            let level: SentryLevel = [
                .trace: .debug, .debug: .debug, .info: .info,
                .warning: .warning, .error: .error, .fatal: .fatal,
            ][logEvent.level] ?? .debug
            let tags               = [
                "src.file": String.valid( logEvent.file )?.lastPathComponent,
                "src.line": "\(logEvent.line)",
                "src.func": String.valid( logEvent.function ),
            ]

            if logEvent.level <= .fatal {
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

        AppConfig.shared.observers.register( observer: self ).didChange( appConfig: AppConfig.shared, at: \AppConfig.diagnostics )

        #if TARGET_APP
        self.event( file: file, line: line, function: function, dso: dso,
                    track: .subject( "app", action: "startup", [
                        "app.version": productVersion,
                        "app.build": productBuild,
                        "app.run": AppConfig.shared.runCount,
                    ].merging( self.identifiers ) ) )
        #elseif TARGET_AUTOFILL
        self.event( file: file, line: line, function: function, dso: dso,
                    track: .subject( "autofill", action: "startup", [
                        "app.version": productVersion,
                        "app.build": productBuild,
                        "app.run": AppConfig.shared.runCount,
                    ].merging( self.identifiers ) ) )
        #endif
    }

    func appeared(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        if self.hasCountlyStarted {
            Countly.sharedInstance().appLoadingFinished()
        }

        self.event( file: file, line: line, function: function, dso: dso,
                    track: .subject( "app", action: "appeared" ) )
    }

    func login(user: User) {
        user.authenticatedIdentifier.success { userId in
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

            let user = Sentry.User( userId: userId )
            user.data = userConfig
            SentrySDK.setUser( user )

            if self.hasCountlyStarted {
                Countly.user().username = userId as NSString
                Countly.user().custom = userConfig as NSDictionary
                Countly.user().save()
                #if TARGET_APP
                Countly.sharedInstance().recordPushNotificationToken()
                #endif
            }

            inf( "Login [user: %@]", userId )
            self.event( track: .subject( "user", action: "signed_in", userConfig ) )
        }
    }

    func logout() {
        self.event( track: .subject( "user", action: "signed_out" ) )

        SentrySDK.setUser( nil )
        Countly.user().username = NSNull()
        Countly.user().custom = NSNull()
        Countly.user().save()
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Any?] = [:]) -> Screen {
        Screen( name: name, tracker: self )
    }

    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               track: Tracking) -> TimedEvent {
        dbg( file: file, line: line, function: function, dso: dso, "> %@ #%@", track.subject, track.action )
        return TimedEvent( track: track, start: Date() )
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               track: Tracking) {
        self.event( file: file, line: line, function: function, dso: dso, named: "\(track.subject) >\(track.action)", track.parameters() )
    }

    func crash() {
        SentrySDK.crash()
        Stacksift.testCrash()
    }

    // MARK: - Private

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
            mperror( title: "Couldn't save \(named) identifier", error: status )
        }

        return uuid
    }

    private func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                       named name: String, _ parameters: [String: Any?] = [:], timing: TimedEvent? = nil) {
        var eventParameters = parameters.compactMapValues( { $0 } )
        #if TARGET_APP
        eventParameters["app.container"] = "app"
        #elseif TARGET_AUTOFILL
        eventParameters["app.container"] = "autofill"
        #endif

        var duration               = TimeInterval( 0 )
        var untimedEventParameters = eventParameters
        if let timing = timing {
            duration = Date().timeIntervalSince( timing.start )
            untimedEventParameters["event.duration"] = "\(number: duration, as: "0.#")"
        }

        // Log
        if untimedEventParameters.isEmpty {
            dbg( file: file, line: line, function: function, dso: dso, "# %@", name )
        }
        else {
            dbg( file: file, line: line, function: function, dso: dso, "# %@: [%@]", name, untimedEventParameters )
        }

        let sourceParameters: [String: Any] = [ "src.file": file.lastPathComponent, "src.line": line, "src.function": function ]
        eventParameters.merge( sourceParameters, uniquingKeysWith: { $1 } )
        untimedEventParameters.merge( sourceParameters, uniquingKeysWith: { $1 } )

        // Sentry
        let sentryBreadcrumb = Breadcrumb( level: .info, category: "event" )
        sentryBreadcrumb.type = "user"
        sentryBreadcrumb.message = name
        sentryBreadcrumb.data = untimedEventParameters
        SentrySDK.addBreadcrumb( crumb: sentryBreadcrumb )

        // Countly
        if self.hasCountlyStarted {
            Countly.sharedInstance().recordEvent(
                    name, segmentation: eventParameters.mapValues { String( reflecting: $0 ) },
                    count: eventParameters["event.count"] as? UInt ?? 1,
                    sum: eventParameters["event.sum"] as? Double ?? 0,
                    duration: duration )
        }
    }

    // MARK: - AppConfigObserver

    // FIXME: We should use Countly.sharedInstance().hasStarted instead but it's not exposed yet.
    // https://support.count.ly/hc/en-us/community/posts/900002422786-Stopping-Countly
    private var hasCountlyStarted = false, hasSentryStarted = false, hasStacksiftStarted = false

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        guard change == \AppConfig.isApp || change == \AppConfig.diagnostics || change == \AppConfig.offline
        else { return }

        if !appConfig.offline && !self.hasCountlyStarted {
            if let countly = [
                .private: secrets.countly.private, .pilot: secrets.countly.pilot, .public: secrets.countly.public,
            ][AppConfig.shared.configuration],
               let countlyKey = countly.key.b64Decrypt(), let countlySalt = countly.salt.b64Decrypt() {
                let countlyConfig = CountlyConfig()
                countlyConfig.host = "https://countly.spectre.app"
                countlyConfig.urlSessionConfiguration = URLSession.optionalConfiguration()
                countlyConfig.alwaysUsePOST = true
                countlyConfig.secretSalt = countlySalt
                countlyConfig.appKey = countlyKey
                countlyConfig.requiresConsent = true
                countlyConfig.deviceID = self.identifierForOwner
                countlyConfig.features = [ CLYFeature.pushNotifications ]
                countlyConfig.enablePerformanceMonitoring = true
                //countlyConfig.enableDebug = true
                countlyConfig.pushTestMode = [
                    .private: .development, .pilot: .testFlightOrAdHoc, .public: nil,
                ][AppConfig.shared.configuration] ?? .development
                Countly.sharedInstance().start( with: countlyConfig )
                self.hasCountlyStarted = true

                #if TARGET_APP
                if UIApplication.shared.isRegisteredForRemoteNotifications {
                    Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
                }
                #endif
            }
        }
        if self.hasCountlyStarted {
            if appConfig.offline {
                // FIXME: Instead of cancelling consent, we should turn Countly off instead.
                // https://support.count.ly/hc/en-us/community/posts/900002422786-Stopping-Countly
                Countly.sharedInstance().cancelConsentForAllFeatures()
            }
            else if appConfig.diagnostics {
                Countly.sharedInstance().giveConsent(
                        forFeatures: [ .sessions, .events, .userDetails, .viewTracking, .performanceMonitoring ] )
            }
            else {
                Countly.sharedInstance().cancelConsent(
                        forFeatures: [ .sessions, .events, .userDetails, .viewTracking, .performanceMonitoring ] )
            }
        }

        if appConfig.diagnostics && !appConfig.offline {
            if !self.hasSentryStarted, let dsn = secrets.sentry.dsn.b64Decrypt() {
                // FIXME: Sentry crash reports break with the Address and Behaviour Sanitizer enabled.
                // https://github.com/getsentry/sentry-cocoa/issues/369
                SentrySDK.start {
                    $0.dsn = dsn
                    $0.environment = [ .private: "Private", .pilot: "Pilot", .public: "Public" ][AppConfig.shared.configuration]
                    $0.stitchAsyncCode = true
                    $0.tracesSampleRate = 1
                }
                SentrySDK.configureScope {
                    $0.setTags( self.identifiers )
                }
                self.hasSentryStarted = true
            }
            if !self.hasStacksiftStarted, let apiKey = secrets.stacksift.key.b64Decrypt() {
                Stacksift.shared.installIdentifier = self.identifierForDevice
                Stacksift.start( APIKey: apiKey, monitor: .metricKitOnly )
                self.hasStacksiftStarted = true
            }
        }
        else {
            SentrySDK.close()
            self.hasSentryStarted = false
            // Stacksift doesn't currently support consent opt-out, but only transmits data on start-up.
            // https://github.com/stacksift/SDK/issues/3
            //Stacksift.close()
        }
    }

    class Screen {
        let name: String
        private let tracker: Tracker

        init(name: String, tracker: Tracker) {
            self.name = name
            self.tracker = tracker
        }

        func open(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                  _ parameters: [String: Any?] = [:]) {
            // Log
            if parameters.isEmpty {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@", self.name )
            }
            else {
                dbg( file: file, line: line, function: function, dso: dso, "@ %@: [%@]", self.name, parameters )
            }

            let eventParameters = [ "file": file.lastPathComponent, "line": "\(line)", "function": function ]
                    .merging( parameters.compactMapValues( { $0 } ), uniquingKeysWith: { $1 } )
            let stringParameters = eventParameters.mapValues { String( reflecting: $0 ) }

            // Sentry
            let sentryBreadcrumb = Breadcrumb( level: .info, category: "screen" )
            sentryBreadcrumb.type = "navigation"
            sentryBreadcrumb.message = self.name
            sentryBreadcrumb.data = eventParameters
            SentrySDK.addBreadcrumb( crumb: sentryBreadcrumb )

            // Countly
            if self.tracker.hasCountlyStarted {
                Countly.sharedInstance().recordView( self.name, segmentation: stringParameters )
            }
        }

        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   track: Tracking) -> TimedEvent {
            self.tracker.begin( file: file, line: line, function: function, dso: dso, track: track.scoped( self.name ) )
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   track: Tracking) {
            self.tracker.event( file: file, line: line, function: function, dso: dso, track: track.scoped( self.name ) )
        }

        func dismiss(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        }
    }

    class TimedEvent {
        let tracking: Tracking
        let start:    Date

        private var ended = false

        init(track: Tracking, start: Date) {
            self.tracking = track
            self.start = start
        }

        deinit {
            self.cancel()
        }

        func end(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 _ parameters: [String: Any?] = [:]) {
            guard !self.ended
            else { return }

            Tracker.shared.event( file: file, line: line, function: function, dso: dso,
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

protocol TrackerObserver {
    func didChange(tracker: Tracker)
}
