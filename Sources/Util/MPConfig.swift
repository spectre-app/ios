//
// Created by Maarten Billemont on 2019-11-04.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

let appConfig = MPConfig()

public class MPConfig: Observable {
    public let observers = Observers<MPConfigObserver>()

    public var isDebug = false
    public var isPublic = false
    public var diagnostics = false {
        didSet {
            if self.diagnostics != UserDefaults.standard.bool( forKey: "diagnostics" ) {
                UserDefaults.standard.set( self.diagnostics, forKey: "diagnostics" )
            }
            if oldValue != self.diagnostics {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var diagnosticsDecided = false {
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
    public var premium = false {
        didSet {
            if self.premium != UserDefaults.standard.bool( forKey: "premium" ) {
                UserDefaults.standard.set( self.premium, forKey: "premium" )
            }
            if oldValue != self.premium {
                self.observers.notify { $0.didChangeConfig() }
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
    public var theme = MPTheme.default {
        didSet {
            if self.theme.path != UserDefaults.standard.string( forKey: "theme" ) {
                UserDefaults.standard.set( self.theme.path, forKey: "theme" )
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

        self.load()

        self.didChangeObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: nil ) { _ in
            self.load()
        }
    }

    deinit {
        self.didChangeObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    // MARK: --- Private ---

    private func load() {
        self.diagnostics = UserDefaults.standard.bool( forKey: "diagnostics" )
        self.diagnosticsDecided = UserDefaults.standard.bool( forKey: "diagnosticsDecided" )
        self.notificationsDecided = UserDefaults.standard.bool( forKey: "notificationsDecided" )
        self.premium = UserDefaults.standard.bool( forKey: "premium" )
        self.theme = !self.premium ? .default: MPTheme.with( path: UserDefaults.standard.string( forKey: "theme" ) ) ?? .default
    }
}

public protocol MPConfigObserver {
    func didChangeConfig()
}
