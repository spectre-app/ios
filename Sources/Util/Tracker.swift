//==============================================================================
// Created by Maarten Billemont on 2019-11-14.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import Foundation
import Sentry
#if TARGET_APP
import Countly
#endif

struct Tracking {
    let subject:    String
    let action:     String
    let parameters: () -> [String: Any]

    static func subject(_ subject: String, action: String, _ parameters: @autoclosure @escaping () -> [String: Any] = [:]) -> Tracking {
        Tracking( subject: subject, action: action, parameters: parameters )
    }

    func scoped(_ scope: String) -> Tracking {
        Tracking( subject: "\(scope)::\(self.subject)", action: self.action, parameters: self.parameters )
    }

    func with(parameters: @autoclosure @escaping () -> [String: Any] = [:]) -> Tracking {
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

    func enableNotifications(consented: Bool = true, completion: @escaping (Bool) -> () = { _ in }) {
        UNUserNotificationCenter.current().getNotificationSettings {
            if $0.authorizationStatus == .authorized {
                DispatchQueue.main.perform {
                    AppConfig.shared.notificationsDecided = true
                    Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
                    self.observers.notify { $0.didChange( tracker: self ) }
                    completion( true )
                }
                return
            }

            UNUserNotificationCenter.current().requestAuthorization( options: [ .alert, .badge, .sound ] ) { granted, error in
                DispatchQueue.main.perform {
                    AppConfig.shared.notificationsDecided = true

                    if let error = error {
                        wrn( "Notification authorization error: %@", error )
                    }
                    if granted {
                        Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
                        self.observers.notify { $0.didChange( tracker: self ) }
                        completion( true )
                        return
                    }

                    if consented, let settingsURL = URL( string: UIApplication.openSettingsURLString ) {
                        Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
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
        Countly.sharedInstance().cancelConsent( forFeature: .pushNotifications )
    }
    #endif

    // identifierForVendor     | survives: restart                           -- doesn't survive: reinstall, other devices
    // identifierForDevice     | survives: restart, reinstall                -- doesn't survive: other devices
    // identifierForOwner      | survives: restart, reinstall, owned devices -- doesn't survive: unowned devices
    // authenticatedIdentifier | survives: restart, reinstall, all devices   -- doesn't survive:
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

    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 extensionController: UIViewController? = nil) {
        let identifiers = [ "device": self.identifierForDevice, "owner": self.identifierForOwner,
                            "vendor": UIDevice.current.identifierForVendor?.uuidString ?? "" ]
        inf( "Startup [identifiers: %@]", identifiers )

        // Sentry
        SentrySDK.start {
            $0.dsn = AppConfig.shared.diagnostics ? sentryDSN.b64Decrypt(): nil
            $0.environment = AppConfig.shared.isDebug ? "Development": AppConfig.shared.isPublic ? "Public": "Private"
        }
        SentrySDK.configureScope { $0.setTags( identifiers ) }

        #if TARGET_APP
        // Countly
        if let countlyKey = countlyKey.b64Decrypt(), let countlySalt = countlySalt.b64Decrypt() {
            let countlyConfig = CountlyConfig()
            countlyConfig.host = "https://countly.spectre.app"
            countlyConfig.urlSessionConfiguration = URLSession.optionalConfiguration()
            countlyConfig.alwaysUsePOST = true
            countlyConfig.secretSalt = countlySalt
            countlyConfig.appKey = countlyKey
            countlyConfig.requiresConsent = true
            countlyConfig.deviceID = self.identifierForOwner
            countlyConfig.customMetrics = identifiers
            countlyConfig.features = [ CLYFeature.pushNotifications ]
            #if !PUBLIC
            countlyConfig.pushTestMode = AppConfig.shared.isDebug ? .development: .testFlightOrAdHoc
            #endif
            Countly.sharedInstance().start( with: countlyConfig )

            if UIApplication.shared.isRegisteredForRemoteNotifications {
                Countly.sharedInstance().giveConsent( forFeature: .pushNotifications )
            }
        }
        #endif

        // Breadcrumbs & errors
        spectre_log_sink_register( { logPointer in
            guard let logEvent = logPointer?.pointee, logEvent.level <= .info
            else { return false }

            let level: SentryLevel = map( logEvent.level, [
                .trace: .debug, .debug: .debug, .info: .info, .warning: .warning, .error: .error, .fatal: .fatal ] ) ?? .debug
            let tags               =
                    [ "srcFile": String.valid( logEvent.file )?.lastPathComponent ?? "-",
                      "srcLine": "\(logEvent.line)",
                      "srcFunc": String.valid( logEvent.function ) ?? "-" ]

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

        AppConfig.shared.observers.register( observer: self ).didChange( appConfig: AppConfig.shared, at: \AppConfig.diagnostics )

        #if TARGET_APP
        self.event( file: file, line: line, function: function, dso: dso,
                    track: .subject( "app", action: "startup", [ "version": productVersion, "build": productBuild,
                                                                 "run": AppConfig.shared.runCount ] ) )
        #elseif TARGET_AUTOFILL
        self.event( file: file, line: line, function: function, dso: dso,
                    track: .subject( "autofill", action: "startup", [ "version": productVersion, "build": productBuild,
                                                                      "run": AppConfig.shared.runCount ] ) )
        #endif
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
            #if TARGET_APP
            Countly.sharedInstance().userLogged( in: userId )
            Countly.user().custom = userConfig as NSDictionary
            Countly.sharedInstance().recordPushNotificationToken()
            #endif

            inf( "Login [user: %@]", userId )
            self.event( track: .subject( "user", action: "signed_in", userConfig ) )
        }
    }

    func logout() {
        self.event( track: .subject( "user", action: "signed_out" ) )

        SentrySDK.setUser( nil )
        #if TARGET_APP
        //Countly.sharedInstance().userLoggedOut() // FIXME: Countly doesn't return to the configuration's deviceIdentifier on logout.
        Countly.sharedInstance().setNewDeviceID( self.identifierForOwner, onServer: false )
        #endif
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Any] = [:]) -> Screen {
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

    // MARK: --- AppConfigObserver ---

    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>) {
        guard change == \AppConfig.isApp || change == \AppConfig.diagnostics
        else { return }

        if appConfig.isApp && appConfig.diagnostics {
            SentrySDK.currentHub().getClient()?.options.enabled = true
            #if TARGET_APP
            Countly.sharedInstance().giveConsent( forFeatures: [
                .sessions, .events, .userDetails, .viewTracking, .performanceMonitoring ] )
            #endif
        }
        else {
            SentrySDK.currentHub().getClient()?.options.enabled = false
            #if TARGET_APP
            Countly.sharedInstance().cancelConsent( forFeatures: [
                .sessions, .events, .userDetails, .viewTracking, .performanceMonitoring ] )
            #endif
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
                 _ parameters: [String: Any] = [:]) {
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
