//
// Created by Maarten Billemont on 2019-11-04.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

let appConfig = MPConfig()

public class MPConfig: Observable {
    public let observers = Observers<MPConfigObserver>()

    public var isDebug = false
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

    private var observer: NSObjectProtocol?

    // MARK: --- Life ---

    init() {
        assert( {
                    self.isDebug = true
                    return true
                }() )

        self.load()
        self.checkLegacy()

        self.observer = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: nil ) { _ in
            self.load()
        }
    }

    deinit {
        self.observer.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    // MARK: --- Interface ---

    public func checkLegacy() {
        MPCoreData.shared.promise {
            (try $0.count( for: MPUserEntity.fetchRequest() )) > 0
        }.then {
            switch $0 {
                case .success(let hasLegacy):
                    self.hasLegacy = hasLegacy ?? false

                case .failure(let error):
                    err( "Couldn't determine legacy store state. [>TRC]" )
                    trc( "[>] %@", error )
            }
        }
    }

    // MARK: --- Private ---

    private func load() {
        self.diagnostics = UserDefaults.standard.bool( forKey: "diagnostics" )
        self.diagnosticsDecided = UserDefaults.standard.bool( forKey: "diagnosticsDecided" )
        self.premium = UserDefaults.standard.bool( forKey: "premium" )
        self.theme = !self.premium ? .default: MPTheme.with( path: UserDefaults.standard.string( forKey: "theme" ) ) ?? .default
    }
}

public protocol MPConfigObserver {
    func didChangeConfig()
}
