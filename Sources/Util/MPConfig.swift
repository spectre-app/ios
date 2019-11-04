//
// Created by Maarten Billemont on 2019-11-04.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

let appConfig = MPConfig()

public class MPConfig: Observable {
    public let observers = Observers<MPConfigObserver>()

    public var sendInfo = UserDefaults.standard.bool( forKey: "sendInfo" ) {
        didSet {
            if self.sendInfo != UserDefaults.standard.bool( forKey: "sendInfo" ) {
                UserDefaults.standard.set( self.sendInfo, forKey: "sendInfo" )
            }
            if self.sendInfo != oldValue {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public var premium = UserDefaults.standard.bool( forKey: "premium" ) {
        didSet {
            if self.premium != UserDefaults.standard.bool( forKey: "premium" ) {
                UserDefaults.standard.set( self.premium, forKey: "premium" )
            }
            if self.premium != oldValue {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }
    public private(set) var hasLegacy = false {
        didSet {
            if self.hasLegacy != oldValue {
                self.observers.notify { $0.didChangeConfig() }
            }
        }
    }

    private var observer: NSObjectProtocol?

    // MARK: --- Life ---

    init() {
        self.observer = NotificationCenter.default.addObserver( forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: nil ) { _ in
            self.sendInfo = UserDefaults.standard.bool( forKey: "sendInfo" )
            self.premium = UserDefaults.standard.bool( forKey: "premium" )
        }

        self.checkLegacy()
    }

    deinit {
        self.observer.flatMap { NotificationCenter.default.removeObserver( $0 ) }
    }

    // MARK: --- Interface ---

    public func checkLegacy() {
        MPCoreData.shared.promise {
            (try $0.count( for: MPUserEntity.fetchRequest() )) > 0
        }?.then {
            switch $0 {
                case .success(let hasLegacy):
                    self.hasLegacy = hasLegacy

                case .failure(let error):
                    err( "Couldn't determine legacy store state. [>TRC]" )
                    trc( error.localizedDescription )
            }
        }
    }
}

public protocol MPConfigObserver {
    func didChangeConfig()
}
