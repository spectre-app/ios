//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    var isApp:       Bool
    let isDebug:     Bool
    var environment: AppConfiguration
    let model:       String = {
#if canImport(UIKit)
        UIDevice.current.model
#elseif canImport(AppKit)
        "Mac"
#endif
    }()

    @UserDefault("runCount") var runCount: Int = .zero
    @UserDefault("diagnostics") var diagnostics = false
    @UserDefault("notifications") var notifications = false
    @UserDefault("memoryProfiler") var memoryProfiler = false
    @UserDefault("diagnosticsDecided") var diagnosticsDecided = false
    @UserDefault("notificationsDecided") var notificationsDecided = false
//    #if !PUBLIC
//    @UserDefault("sandboxStore") var sandboxStore: Bool = false
//    #endif
    @UserDefault("appIcon") var appIcon: AppIcon = .primary
    @UserDefault("theme") var theme: Color.Spectre.Theme = .spectre
    @UserDefault("colorfulSites") var colorfulSites = true
    @UserDefault("allowHandoff") var allowHandoff = true
    @UserDefault("offline") var offline = false
    @UserDefault("masterPasswordCustomer") var masterPasswordCustomer = false // swiftlint:disable:this inclusive_language
    #if !PUBLIC
    @UserDefault("testingPremium") var testingPremium = false {
        didSet {
            Task.detached { await updateStoreFeatures() }
        }
    }
    #endif
    @UserDefault("rating") var rating: Int = .zero
    @UserDefault("reviewed") var reviewed: Date = .distantPast

    // MARK: - Life

    init() {
        UserDefaults.shared.register(defaults: [
            "colorfulSites": true,
            "allowHandoff": true,
        ])

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
        #error("Build should define a configuration, either PRIVATE, PILOT or PUBLIC.")
        #endif

        self.runCount += 1

        withObservationTracking {
            if self.offline {
                URLSession.optional.clear()
                URLSession.required.clear()
            }
            if self.theme.isPremium, !AppFeature.style.isEnabled {
                self.theme = .spectre
            }
        }
        #if TARGET_APP
        #if canImport(UIKit)
        UNUserNotificationCenter.current().getNotificationSettings {
            self.notifications = $0.authorizationStatus != .denied
        }
        #elseif canImport(AppKit)
        // TODO: macOS
        #endif
        #endif
    }

    private static var toggles = SingleLockBox(value: [String: UserDefault<Bool>]())

    static func `for`(_ key: String, default: Bool = false) -> UserDefault<Bool> {
        self.toggles.using { $0[key, defaultSet: UserDefault(wrappedValue: `default`, key)] }
    }
}

extension Date: @retroactive RawRepresentable {
    public var rawValue: Int {
        Int(self.timeIntervalSince1970)
    }

    public init?(rawValue: Int) {
        self = Date(timeIntervalSince1970: TimeInterval(rawValue))
    }
}

@propertyWrapper
@Observable
class UserDefault<T: Equatable>: NSObject {
    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T: RawRepresentable, T.RawValue == Int {
        self.init(wrappedValue: wrappedValue, key, defaultValue: wrappedValue.rawValue) {
            store.set($0.rawValue, forKey: key)
        } load: {
            T(rawValue: store.integer(forKey: key)) ?? wrappedValue
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T: RawRepresentable, T.RawValue == String {
        self.init(wrappedValue: wrappedValue, key, defaultValue: wrappedValue.rawValue) {
            store.set($0.rawValue, forKey: key)
        } load: {
            store.string(forKey: key).flatMap(T.init(rawValue:)) ?? wrappedValue
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == String {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.string(forKey: key) ?? wrappedValue
        }
    }

    public convenience init<E: Equatable>(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == [E] {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.array(forKey: key) as? [E] ?? wrappedValue
        }
    }

    public convenience init<E: Equatable>(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == [String: E] {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.dictionary(forKey: key) as? [String: E] ?? wrappedValue
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == Data {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.data(forKey: key) ?? wrappedValue
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == [String] {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.stringArray(forKey: key) ?? wrappedValue
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == Int {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.integer(forKey: key)
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == Float {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.float(forKey: key)
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == Double {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.double(forKey: key)
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == Bool {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.bool(forKey: key)
        }
    }

    public convenience init(wrappedValue: T, _ key: String, store: UserDefaults = .shared) where T == URL {
        self.init(wrappedValue: wrappedValue, key) {
            store.set($0, forKey: key)
        } load: {
            store.url(forKey: key) ?? wrappedValue
        }
    }

    public init(
        wrappedValue: T, _ key: String, store: UserDefaults = .shared,
        defaultValue: Any? = nil, save: @escaping (T) -> Void, load: @escaping () -> T
    ) {
        self.key = key
        self.store = store
        self.store.register(defaults: [self.key: defaultValue ?? wrappedValue])
        self.save = save
        self.load = load
        super.init()

        self.store.addObserver(self, forKeyPath: self.key, context: nil)
    }

    deinit {
        self.store.removeObserver(self, forKeyPath: self.key)
    }

    var wrappedValue: T {
        get {
            self.access(keyPath: \.wrappedValue)
            return self.load()
        }
        set {
            self.withMutation(keyPath: \.wrappedValue) {
                self.save(newValue)
            }
        }
    }

    private let key: String
    private let store: UserDefaults
    private let save: (T) -> Void
    private let load: () -> T

    // swiftlint:disable:next block_based_kvo
    override public func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?
    ) {
        // trc("change to: %@: %@", keyPath ?? "", change ?? [:])
        self.withMutation(keyPath: \.wrappedValue) {}
    }
}

enum AppConfiguration: String, CustomStringConvertible {
    case `private`, pilot, `public`
}
