//
// Created by Maarten Billemont on 2019-11-04.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

public let appConfig = MPConfig()

public class MPConfig: Observable, Updatable, InAppFeatureObserver {
    public let observers = Observers<MPConfigObserver>()

    public var isApp    = false
    public var isDebug  = false
    public var isPublic = false
    public var diagnostics = false {
        didSet {
            if self.diagnostics != UserDefaults.shared.bool( forKey: "diagnostics" ) {
                UserDefaults.shared.set( self.diagnostics, forKey: "diagnostics" )
            }
            if oldValue != self.diagnostics {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var diagnosticsDecided   = false {
        didSet {
            if self.diagnosticsDecided != UserDefaults.shared.bool( forKey: "diagnosticsDecided" ) {
                UserDefaults.shared.set( self.diagnosticsDecided, forKey: "diagnosticsDecided" )
            }
        }
    }
    public var notificationsDecided = false {
        didSet {
            if self.notificationsDecided != UserDefaults.shared.bool( forKey: "notificationsDecided" ) {
                UserDefaults.shared.set( self.notificationsDecided, forKey: "notificationsDecided" )
            }
        }
    }
    public private(set) var hasLegacy = false {
        didSet {
            if oldValue != self.hasLegacy {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var theme = Theme.default.path {
        didSet {
            if self.theme != UserDefaults.shared.string( forKey: "theme" ) {
                UserDefaults.shared.set( self.theme, forKey: "theme" )
            }
            if Theme.current.parent?.path != self.theme {
                Theme.current.parent = Theme.with( path: self.theme ) ?? .default
            }
            if oldValue != self.theme {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }

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

        self.update()

        self.didChangeObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: UserDefaults.shared, queue: nil ) { [unowned self] _ in
            self.update()
        }
        InAppFeature.observers.register( observer: self )
    }

    deinit {
        self.didChangeObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    // MARK: --- InAppFeatureObserver ---

    func featureDidChange(_ feature: InAppFeature) {
        self.update()
    }

    // MARK: --- Private ---

    public func update() {
        self.diagnostics = UserDefaults.shared.bool( forKey: "diagnostics" )
        self.diagnosticsDecided = UserDefaults.shared.bool( forKey: "diagnosticsDecided" )
        self.notificationsDecided = UserDefaults.shared.bool( forKey: "notificationsDecided" )
        self.theme = (InAppFeature.premium.isEnabled ? UserDefaults.shared.string( forKey: "theme" ): nil) ?? Theme.default.path
    }
}

public protocol MPConfigObserver {
    func didChangeConfig()
}
