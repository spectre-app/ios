//
// Created by Maarten Billemont on 2019-11-04.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

public let appConfig = MPConfig()

public class MPConfig: Observable, Updatable, InAppFeatureObserver {
    public let observers = Observers<MPConfigObserver>()

    public var isDebug              = false
    public var isPublic             = false
    public var diagnostics          = false {
        didSet {
            if self.diagnostics != UserDefaults.standard.bool( forKey: "diagnostics" ) {
                UserDefaults.standard.set( self.diagnostics, forKey: "diagnostics" )
            }
            if oldValue != self.diagnostics {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var diagnosticsDecided   = false {
        didSet {
            if self.diagnosticsDecided != UserDefaults.standard.bool( forKey: "diagnosticsDecided" ) {
                UserDefaults.standard.set( self.diagnosticsDecided, forKey: "diagnosticsDecided" )
            }
        }
    }
    public var notificationsDecided = false {
        didSet {
            if self.notificationsDecided != UserDefaults.standard.bool( forKey: "notificationsDecided" ) {
                UserDefaults.standard.set( self.notificationsDecided, forKey: "notificationsDecided" )
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
            if self.theme != UserDefaults.standard.string( forKey: "theme" ) {
                UserDefaults.standard.set( self.theme, forKey: "theme" )
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
        #if DEBUG
        self.isDebug = true
        #endif
        #if PUBLIC
        self.isPublic = true
        #endif

        self.update()

        self.didChangeObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: nil ) { _ in
            self.update()
        }
        InAppFeature.observers.register(observer: self)
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
        self.diagnostics = UserDefaults.standard.bool( forKey: "diagnostics" )
        self.diagnosticsDecided = UserDefaults.standard.bool( forKey: "diagnosticsDecided" )
        self.notificationsDecided = UserDefaults.standard.bool( forKey: "notificationsDecided" )
        self.theme = (InAppFeature.premium.enabled() ? UserDefaults.standard.string( forKey: "theme" ): nil) ?? Theme.default.path
    }
}

public protocol MPConfigObserver {
    func didChangeConfig()
}
