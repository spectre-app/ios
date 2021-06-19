//==============================================================================
// Created by Maarten Billemont on 2019-11-04.
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
    public var theme: String {
        get {
            (InAppFeature.premium.isEnabled ? UserDefaults.shared.string( forKey: #function ): nil)
                    ?? Theme.default.path
        }
        set {
            if newValue != self.theme {
                UserDefaults.shared.set( newValue, forKey: #function )
                Theme.current.parent = Theme.with( path: self.theme ) ?? .default
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.theme ) }
            }
        }
    }
    public var themeSites: Bool {
        get {
            UserDefaults.shared.bool( forKey: #function )
        }
        set {
            if newValue != self.themeSites {
                UserDefaults.shared.set( newValue, forKey: #function )
                self.observers.notify { $0.didChange( appConfig: self, at: \AppConfig.themeSites ) }
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

    // MARK: --- Life ---

    init() {
        UserDefaults.shared.register( defaults: [
            "themeSites": true,
        ] )

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

        Theme.current.parent = Theme.with( path: self.theme ) ?? .default
    }
}

public protocol AppConfigObserver {
    func didChange(appConfig: AppConfig, at change: PartialKeyPath<AppConfig>)
}
