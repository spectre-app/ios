// =============================================================================
// Created by Maarten Billemont on 2019-11-04.
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

public class AppConfig: Observable {
    public static let shared = AppConfig()

    public let observers = Observers<AppConfigObserver>()

    public var isApp:       Bool
    public let isDebug:     Bool
    public var environment: AppConfiguration
    public var runCount: Int {
        get {
            UserDefaults.shared.integer( forKey: #function )
        }
        set {
            if newValue != self.runCount {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.runCount ) }
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
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.diagnostics ) }
            }
        }
    }
    public var memoryProfiler: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.memoryProfiler {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.memoryProfiler ) }
            }
        }
    }
    public var diagnosticsDecided: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.diagnosticsDecided {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.diagnosticsDecided ) }
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
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.notificationsDecided ) }
            }
        }
    }
    #if !PUBLIC
    public var sandboxStore: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.sandboxStore {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.sandboxStore ) }
            }
        }
    }
    #endif
    public var appIcon: AppIcon {
        get {
            UserDefaults.shared.string( forKey: #function ).flatMap { appIcon in
                AppIcon.allCases.first { $0.rawValue == appIcon }
            } ?? AppIcon.primary
        }
        set {
            if newValue != self.appIcon {
                UserDefaults.shared.set( newValue.rawValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.appIcon ) }
            }
        }
    }
    public var theme: String {
        get {
            let theme = UserDefaults.shared.string( forKey: #function ) ?? Theme.default.path
            if !InAppFeature.premium.isEnabled, Theme.with( path: theme )?.pattern?.isPremium ?? false {
                return Theme.default.path
            }
            return theme
        }
        set {
            if newValue != self.theme {
                UserDefaults.shared.set( newValue, forKey: #function )
                Theme.current.parent = Theme.with( path: self.theme ) ?? .default
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.theme ) }
            }
        }
    }
    public var colorfulSites: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.colorfulSites {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.colorfulSites ) }
            }
        }
    }
    public var allowHandoff: Bool {
        get {
            InAppFeature.premium.isEnabled && UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.allowHandoff {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.allowHandoff ) }
            }
        }
    }
    public var offline: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.offline {
                if self.offline {
                    URLSession.optional.unset()
                    URLSession.required.unset()
                }

                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.offline ) }
            }
        }
    }
    public var masterPasswordCustomer: Bool { // swiftlint:disable:this inclusive_language
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.masterPasswordCustomer {
                UserDefaults.shared.set( newValue, forKey: #function )
                // swiftlint:disable:next inclusive_language
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.masterPasswordCustomer ) }
            }
        }
    }
    #if !PUBLIC
    public var testingPremium: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.testingPremium {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.testingPremium ) }
            }
        }
    }
    #endif
    public var rating: Int {
        get {
            UserDefaults.shared.integer( forKey: #function )
        }
        set {
            if newValue != self.rating {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.rating ) }
            }
        }
    }
    public var reviewed: Date? {
        get {
            UserDefaults.shared.double( forKey: #function ).nonEmpty.flatMap {
                Date( timeIntervalSince1970: $0 )
            }
        }
        set {
            if newValue != self.reviewed {
                UserDefaults.shared.set( newValue?.timeIntervalSince1970, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.reviewed ) }
            }
        }
    }

    // MARK: - Life

    init() {
        UserDefaults.shared.register( defaults: [
            "colorfulSites": true,
            "allowHandoff": true,
        ] )

        #if TARGET_APP
        self.isApp = true
        #else
        self.isApp = false
        #endif
        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
        #if PRIVATE
        self.environment = .private
        #elseif PILOT
        self.environment = .pilot
        #elseif PUBLIC
        self.environment = .public
        #else
        #error( "Build should define a configuration, either PRIVATE, PILOT or PUBLIC." )
        #endif
        self.runCount += 1

        Theme.current.parent = Theme.with( path: self.theme ) ?? .default
    }
}

public enum AppConfiguration: String, CustomStringConvertible {
    case `private`, `pilot`, `public`
}

public protocol AppConfigObserver {
    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>)
}
