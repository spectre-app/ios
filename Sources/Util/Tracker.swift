//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Combine
import Sentry
import System
import UIKit
#if TARGET_APP
// Countly does not support App Extensions.
import Countly
#endif

struct Tracking: CustomStringConvertible {
    let subject:    String
    let action:     String
    var parameters: [String: Any?]

    var description: String {
        "\(self.subject)::\(self.action) \(let: self.parameters.nonEmpty, "({})"))"
    }

    static func subject(_ subject: String, action: String, _ parameters: [String: Any?] = [:]) -> Tracking {
        Tracking(subject: subject, action: action, parameters: parameters)
    }

    func scoped(_ scope: String) -> Tracking {
        Tracking(subject: "\(scope)::\(self.subject)", action: self.action, parameters: self.parameters)
    }

    func with(parameters: [String: Any?] = [:]) -> Tracking {
        Tracking(subject: self.subject, action: self.action, parameters: self.parameters.merging(parameters))
    }
}

class Tracker: ObservableObject {
    static let shared = Tracker()

    #if TARGET_APP
    @discardableResult
    func enableNotifications(userRequested: Bool = true) async -> Bool {
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized {
            AppConfig.shared.notificationsDecided = true
            AppConfig.shared.notifications = true
            if self.hasCountlyStartedConfig != nil {
                await MainActor.run { Countly.sharedInstance().giveConsent(forFeature: .pushNotifications) }
            }
            return true
        }

        do {
            defer { AppConfig.shared.notificationsDecided = true }
            if try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
                AppConfig.shared.notifications = true
                if self.hasCountlyStartedConfig != nil {
                    await MainActor.run { Countly.sharedInstance().giveConsent(forFeature: .pushNotifications) }
                }
                return true
            }
        }
        catch {
            wrn("Notifications not authorized.", data: error)
        }

        if userRequested, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            if self.hasCountlyStartedConfig != nil {
                await MainActor.run { Countly.sharedInstance().giveConsent(forFeature: .pushNotifications) }
            }
            await UIApplication.shared.open(settingsURL)
            return true
        }

        AppConfig.shared.notifications = false
        if self.hasCountlyStartedConfig != nil {
            await MainActor.run { Countly.sharedInstance().cancelConsent(forFeature: .pushNotifications) }
        }
        return false
    }

    func disableNotifications() async {
        AppConfig.shared.notificationsDecided = true
        AppConfig.shared.notifications = false

        await MainActor.run { Countly.sharedInstance().cancelConsent(forFeature: .pushNotifications) }
    }
    #endif

    // identifierForVendor     | survives: restart                           -- doesn't survive: reinstall, other devices
    // identifierForDevice     | survives: restart, reinstall                -- doesn't survive: other devices
    // identifierForOwner      | survives: restart, reinstall, owned devices -- doesn't survive: unowned devices
    // authenticatedIdentifier | survives: restart, reinstall, all devices   -- doesn't survive:
    var identifierForVendor: String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }

    lazy var identifierForDevice = self.identifier(for: "device", attributes: [
        kSecAttrDescription: "Unique identifier for the device running this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: false,
    ]).uuidString
    lazy var identifierForOwner  = self.identifier(for: "owner", attributes: [
        kSecAttrDescription: "Unique identifier for the owner of this app.",
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecAttrSynchronizable: true,
    ]).uuidString
    private lazy var identifiers = [
        "id_vendor": self.identifierForVendor,
        "id_device": self.identifierForDevice,
        "id_owner": self.identifierForOwner,
    ]
    private lazy var tags = [
        "app_version": "\(productVersion)",
        "app_build": "\(productBuild)",
        "app_runCount": "\(AppConfig.shared.runCount)",
        "app_reviewed": "\(AppConfig.shared.reviewed != .distantPast)",
        "app_rating": "\(AppConfig.shared.rating)",
        "app_environment": "\(AppConfig.shared.environment)",
        "app_masterPasswordCustomer": "\(AppConfig.shared.masterPasswordCustomer)",
        "app_appIcon": "\(AppConfig.shared.appIcon)",
        "app_colorfulSites": "\(AppConfig.shared.colorfulSites)",
        "app_allowHandoff": "\(AppConfig.shared.allowHandoff)",
        "app_theme": "\(AppConfig.shared.theme)",
        "app_premium": "\(StoreSubscription.premium.isEnabled)",
    ]
    private var recordSink: AnyCancellable?

    @MainActor
    func startup(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 extensionController: UIViewController? = nil) {
        dbg("Startup", data: self.identifiers)

        // Breadcrumbs & errors
        self.recordSink = logRecords.sink { record in
            guard record.level <= .info
            else { return }

            let sentryLevel: SentryLevel = [
                .trace: .debug, .debug: .debug, .info: .info,
                .warning: .warning, .error: .error, .fatal: .fatal,
            ][record.level] ?? .debug
            let tags               = [
                "src_file": record.fileName,
                "src_line": "\(record.line)",
                "src_func": record.function,
            ]

            if record.level <= .fatal {
                let event = Event(level: sentryLevel)
                event.logger = "api"
                event.message = SentryMessage(formatted: record.message)
                event.timestamp = record.occurrence
                event.tags = tags
                SentrySDK.capture(event: event)
            }
            else {
                let breadcrumb = Breadcrumb(level: sentryLevel, category: "api")
                breadcrumb.type = "log"
                breadcrumb.message = record.message
                breadcrumb.timestamp = record.occurrence
                breadcrumb.data = tags
                SentrySDK.addBreadcrumb(breadcrumb)
            }
        }

        withObservationTracking { [weak self] in
            self?.initialize()
        }

        self.event(
            file: file, line: line, function: function, dso: dso,
            track: .subject(AppConfig.shared.isApp ? "app" : "autofill", action: "startup")
        )
    }

    func appeared(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
        #if TARGET_APP
        assert(self.hasCountlyStartedConfig != nil && Thread.isMainThread)
        Countly.sharedInstance().appLoadingFinished()
        #endif
        self.event(
            file: file, line: line, function: function, dso: dso,
            track: .subject("app", action: "appeared")
        )
    }

    func login(user: User) {
        Task.detached {
            guard let userId = try? user.authenticatedIdentifier
            else {
                wrn("Login [user: unknown]")
                return
            }

            let userConfig: [String: Any] = [
                "algorithm": user.algorithm,
                "avatar": user.avatar,
                "biometricLock": user.biometricLock,
                "maskPasswords": user.maskPasswords,
                "resultType": user.resultType,
                "loginType": user.loginType,
                "sites": user.sites.count,
            ]

            let user = Sentry.User(userId: userId)
            user.data = userConfig
            SentrySDK.setUser(user)

            #if TARGET_APP
            if self.hasCountlyStartedConfig != nil {
                Countly.user().username = userId as NSString
                Countly.user().custom = userConfig as NSDictionary
                Countly.user().save()
                #if TARGET_APP
                DispatchQueue.main.async { Countly.sharedInstance().recordPushNotificationToken() }
                #endif
            }
            #endif

            dbg("Login [user: \(userId)]")
            self.event(track: .subject("user", action: "signed_in", userConfig))
        }
    }

    func logout() {
        self.event(track: .subject("user", action: "signed_out"))

        SentrySDK.setUser(nil)
        #if TARGET_APP
        Countly.user().username = NSNull()
        Countly.user().custom = NSNull()
        Countly.user().save()
        #endif
    }

    func screen(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                named name: String, _ parameters: [String: Any?] = [:])
        -> Screen {
        Screen(name: name, tracker: self)
    }

    func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               track: Tracking)
        -> TimedEvent {
        trc(file: file, line: line, function: function, dso: dso, "> \(track.subject) #\(track.action)")
        return TimedEvent(track: track, start: Date())
    }

    func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
               track: Tracking) {
        self.event(file: file, line: line, function: function, dso: dso, named: "\(track.subject) >\(track.action)", track.parameters)
    }

    #if TARGET_APP
    func feedback(_ rating: Int, comment: String?, contact: String?) {
        if let widget = [
            .private: secrets.countly.private, .pilot: secrets.countly.pilot, .public: secrets.countly.public,
        ][AppConfig.shared.environment]?.feedback.b64Decrypt() {
            Countly.sharedInstance().recordRatingWidget(
                withID: widget, rating: rating, email: contact, comment: comment, userCanBeContacted: contact != nil
            )
        }
    }
    #endif

    func crash() {
        SentrySDK.crash()
    }

    // MARK: - Private

    private func initialize() {
        // Countly
        #if TARGET_APP
        assert(Thread.isMainThread, "Countly assumes main-thread access.")
        if !AppConfig.shared.offline {
            if self.hasCountlyStartedConfig == nil, let countly = [
                .private: secrets.countly.private, .pilot: secrets.countly.pilot, .public: secrets.countly.public,
            ][AppConfig.shared.environment],
                let countlyKey = countly.key.b64Decrypt(), let countlySalt = countly.salt.b64Decrypt() {
                let countlyConfig = using(CountlyConfig()) {
                    $0.host = "https://countly.spectre.app"
                    $0.urlSessionConfiguration = URLSession.optionalConfiguration()
                    $0.secretSalt = countlySalt
                    $0.appKey = countlyKey
                    $0.requiresConsent = true
                    $0.deviceID = self.identifierForOwner
                    $0.features = [CLYFeature.pushNotifications]
                    $0.apm().enableAppStartTimeTracking = true
                    $0.apm().enableManualAppLoadedTrigger = true
                    $0.apm().enableForegroundBackgroundTracking = true
                    $0.enableDebug = false
                    $0.pushTestMode = [
                        .private: .development, .pilot: .testFlightOrAdHoc, .public: nil,
                    ][AppConfig.shared.environment] ?? .development
                }
                Countly.sharedInstance().start(with: countlyConfig)
                self.hasCountlyStartedConfig = countlyConfig
            }

            if let countlyConfig = self.hasCountlyStartedConfig {
                countlyConfig.customMetrics = self.identifiers.merging(self.tags)

                #if TARGET_APP
                if UIApplication.shared.isRegisteredForRemoteNotifications {
                    Countly.sharedInstance().giveConsent(forFeature: .pushNotifications)
                }
                else {
                    Countly.sharedInstance().cancelConsent(forFeature: .pushNotifications)
                }
                #endif

                if AppConfig.shared.diagnostics {
                    Countly.sharedInstance().giveConsent(
                        forFeatures: [.sessions, .events, .userDetails, .viewTracking, .performanceMonitoring, .feedback]
                    )
                }
                else {
                    Countly.sharedInstance().cancelConsent(
                        forFeatures: [.sessions, .events, .userDetails, .viewTracking, .performanceMonitoring, .feedback]
                    )
                }
            }
        }
        else {
            self.hasCountlyStartedConfig = nil
            Countly.sharedInstance().halt()
        }
        #endif

        // Sentry
        if AppConfig.shared.diagnostics, !AppConfig.shared.offline {
            if !self.hasSentryStarted, let dsn = secrets.sentry.dsn.b64Decrypt() {
                // FIXME: Sentry crash reports break with the Address and Behaviour Sanitizer enabled.
                // https://github.com/getsentry/sentry-cocoa/issues/369
                SentrySDK.start {
                    $0.dsn = dsn
                    $0.environment = AppConfig.shared.environment.rawValue.capitalized
                    $0.swiftAsyncStacktraces = true
                    $0.sendDefaultPii = false
                    $0.attachScreenshot = false
                    $0.enableUserInteractionTracing = true
                    $0.tracesSampleRate = 0.1
                }
                self.hasSentryStarted = true
            }

            if self.hasSentryStarted {
                SentrySDK.configureScope {
                    $0.setTags(self.identifiers.merging(self.tags))
                }
            }
        }
        else {
            SentrySDK.close()
            self.hasSentryStarted = false
        }
    }

    private func identifier(for named: String, attributes: [CFString: Any] = [:]) -> UUID {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "identifier",
            kSecAttrAccount: named,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
        ]

        var cfResult: CFTypeRef?
        var status = SecItemCopyMatching(query.merging([kSecReturnData: true]) as CFDictionary, &cfResult)
        if status == errSecSuccess, let data = cfResult as? Data, !data.isEmpty {
            return data.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
        }

        let uuid = UUID()
        let uuidData = withUnsafePointer(to: uuid.uuid) { Data(buffer: UnsafeBufferPointer(start: $0, count: 1)) }
        SecItemDelete(query as CFDictionary)
        status = SecItemAdd(query.merging(attributes).merging([kSecValueData: uuidData]) as CFDictionary, nil)
        if status != errSecSuccess {
            err("Couldn't save \(named) identifier", data: status)
        }

        return uuid
    }

    private func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                       named name: String, _ parameters: [String: Any?] = [:], timing: TimedEvent? = nil) {
        var eventParameters = parameters.compactMapValues { unwrap($0) }
        #if TARGET_APP
        eventParameters["app_container"] = "app"
        #elseif TARGET_AUTOFILL
        eventParameters["app_container"] = "autofill"
        #endif

        var duration: TimeInterval = .zero
        var untimedEventParameters = eventParameters
        if let timing {
            duration = Date().timeIntervalSince(timing.start)
            untimedEventParameters["event.duration"] = "\(number: duration, as: "0.#")"
        }

        // Log
        if untimedEventParameters.isEmpty {
            trc(file: file, line: line, function: function, dso: dso, "# \(name)")
        }
        else {
            trc(file: file, line: line, function: function, dso: dso, "# \(name): [\(untimedEventParameters)]")
        }

        let sourceParameters: [String: Any] = ["src_file": FilePath(file).lastComponent ?? file, "src_line": line, "src_function": function]
        eventParameters.merge(sourceParameters, uniquingKeysWith: { $1 })
        untimedEventParameters.merge(sourceParameters, uniquingKeysWith: { $1 })

        // Sentry
        let sentryBreadcrumb = Breadcrumb(level: .info, category: "event")
        sentryBreadcrumb.type = "user"
        sentryBreadcrumb.message = name
        sentryBreadcrumb.data = untimedEventParameters
        SentrySDK.addBreadcrumb(sentryBreadcrumb)

        // Countly
        #if TARGET_APP
        if self.hasCountlyStartedConfig != nil {
            Countly.sharedInstance().recordEvent(
                name, segmentation: eventParameters.mapValues {
                    String(describing: $0)
                        .replacingOccurrences(of: #"\b0x[A-Z0-9]+\b"#, with: "0x?", options: [.regularExpression, .caseInsensitive])
                },
                count: eventParameters["event.count"] as? UInt ?? 1,
                sum: eventParameters["event.sum"] as? Double ?? 0,
                duration: duration
            )
        }
        #endif
    }

    #if TARGET_APP
    private var hasCountlyStartedConfig: CountlyConfig?
    #endif
    private var hasSentryStarted = false

    class Screen {
        let name: String
        private let tracker: Tracker

        init(name: String, tracker: Tracker) {
            self.name = name
            self.tracker = tracker
            LeakRegistry.shared.register(self)
        }

        func open(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                  _ parameters: [String: Any?] = [:]) {
            // Log
            if parameters.isEmpty {
                trc(file: file, line: line, function: function, dso: dso, "@ \(self.name)")
            }
            else {
                trc(file: file, line: line, function: function, dso: dso, "@ \(self.name): [\(parameters)]")
            }

            let eventParameters = ["file": FilePath(file).lastComponent?.string ?? file, "line": "\(line)", "function": function]
                .merging(parameters.compactMapValues { $0 }, uniquingKeysWith: { $1 })
            let stringParameters = eventParameters.mapValues { String(describing: $0) }

            // Sentry
            let sentryBreadcrumb = Breadcrumb(level: .info, category: "screen")
            sentryBreadcrumb.type = "navigation"
            sentryBreadcrumb.message = self.name
            sentryBreadcrumb.data = eventParameters
            SentrySDK.addBreadcrumb(sentryBreadcrumb)

            // Countly
            #if TARGET_APP
            if self.tracker.hasCountlyStartedConfig != nil {
                Countly.sharedInstance().views().startView(self.name, segmentation: stringParameters)
            }
            #endif
        }

        func begin(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   track: Tracking)
            -> TimedEvent {
            self.tracker.begin(file: file, line: line, function: function, dso: dso, track: track.scoped(self.name))
        }

        func event(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                   track: Tracking) {
            self.tracker.event(file: file, line: line, function: function, dso: dso, track: track.scoped(self.name))
        }

        func dismiss(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            #if TARGET_APP
            Countly.sharedInstance().views().stopView(withName: self.name)
            #endif
        }
    }

    class TimedEvent {
        let tracking: Tracking
        let start:    Date

        private var ended = false

        init(track: Tracking, start: Date) {
            self.tracking = track
            self.start = start
            LeakRegistry.shared.register(self)
        }

        deinit {
            self.cancel()
        }

        func end(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                 _ parameters: [String: Any?] = [:]) {
            guard !self.ended
            else { return }

            Tracker.shared.event(
                file: file, line: line, function: function, dso: dso,
                named: "\(self.tracking.subject) #\(self.tracking.action)",
                self.tracking.parameters.merging(parameters), timing: self
            )
            self.ended = true
        }

        func cancel(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle) {
            guard !self.ended
            else { return }

            Tracker.shared.event(
                file: file, line: line, function: function, dso: dso,
                named: "\(self.tracking.subject) !\(self.tracking.action)",
                self.tracking.parameters.merging(["result": "cancelled"]), timing: self
            )
            self.ended = true
        }
    }
}

func unwrap(_ value: Any?) -> Any? {
    guard let value
    else { return nil }

    let typeName = String(reflecting: type(of: value))
    guard typeName.hasPrefix("() -> ")
    else { return value }

    if let unwrapped = (value as? () -> String)?() ?? (value as? () -> String?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> Int)?() ?? (value as? () -> Int?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> Double)?() ?? (value as? () -> Double?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> Float)?() ?? (value as? () -> Float?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> CGFloat)?() ?? (value as? () -> CGFloat?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> NSString)?() ?? (value as? () -> NSString?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> NSNumber)?() ?? (value as? () -> NSNumber?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> Substring)?() ?? (value as? () -> Substring?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> Int32)?() ?? (value as? () -> Int32?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> Int64)?() ?? (value as? () -> Int64?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> UInt32)?() ?? (value as? () -> UInt32?)?() {
        return unwrapped
    }
    if let unwrapped = (value as? () -> UInt64)?() ?? (value as? () -> UInt64?)?() {
        return unwrapped
    }

    err("Could not unwrap value of type: \(typeName)")
    return nil
}
