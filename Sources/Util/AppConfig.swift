//
// Created by Maarten Billemont on 2019-11-04.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

public class AppConfig: Observable {
    public static let shared = AppConfig()

    public let observers = Observers<AppConfigObserver>()

    public var isApp    = false
    public var isDebug  = false
    public var isPublic = false
    public var runCount: Int {
        get {
            UserDefaults.shared.integer( forKey: #function )
        }
        set {
            if newValue != self.runCount {
                UserDefaults.shared.set( newValue, forKey: #function )
            }
        }
    }
    public var diagnostics: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.diagnostics {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var diagnosticsDecided:   Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.diagnosticsDecided {
                UserDefaults.shared.set( newValue, forKey: #function )
            }
        }
    }
    public var notificationsDecided: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.notificationsDecided {
                UserDefaults.shared.set( newValue, forKey: #function )
            }
        }
    }
    public var sandboxStore: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.sandboxStore {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var theme: String {
        get {
            (InAppFeature.premium.isEnabled ? UserDefaults.shared.string( forKey: #function ): nil)
                    ?? Theme.default.path
        }
        set {
            if newValue != self.theme {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }

    private lazy var themeObserver = ThemeConfigObserver( appConfig: self )
    private var didChangeObserver: NSObjectProtocol?

    // MARK: --- Life ---

    init() {
        #if TARGET_APP
        self.isApp = true
        #endif
        #if DEBUG
        self.isDebug = true
        #endif
        #if PUBLIC
        self.isPublic = true
        #endif
        self.runCount += 1

        self.observers.register( observer: self.themeObserver ).didChangeConfig()
        self.didChangeObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: UserDefaults.shared, queue: nil ) { [unowned self] _ in
            self.observers.notify { $0.didChangeConfig() }
        }
    }

    deinit {
        self.didChangeObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    class ThemeConfigObserver: AppConfigObserver {
        let appConfig: AppConfig

        init(appConfig: AppConfig) {
            self.appConfig = appConfig
        }

        func didChangeConfig() {
            if Theme.current.parent?.path != appConfig.theme {
                Theme.current.parent = Theme.with( path: appConfig.theme ) ?? .default
            }
        }
    }
}

public protocol AppConfigObserver {
    func didChangeConfig()
}
