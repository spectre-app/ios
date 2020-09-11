//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPUser: Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPUserObserver, MPSiteObserver {
    public let observers = Observers<MPUserObserver>()

    public var algorithm: MPAlgorithmVersion {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var avatar: Avatar {
        didSet {
            if oldValue != self.avatar {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public let fullName: String
    public var identicon: MPIdenticon {
        didSet {
            if oldValue != self.identicon {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var masterKeyID: String? {
        didSet {
            if !mpw_id_buf_equals( oldValue, self.masterKeyID ) {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public private(set) var masterKeyFactory: MPKeyFactory? {
        willSet {
            if self.masterKeyFactory != nil, newValue == nil {
                let _ = try? self.saveTask.request().await()
            }
        }
        didSet {
            if self.masterKeyFactory !== oldValue {
                if self.masterKeyFactory != nil, oldValue == nil {
                    trc( "Logging in: %@", self )
                    self.observers.notify { $0.userDidLogin( self ) }
                }
                if self.masterKeyFactory == nil, oldValue != nil {
                    trc( "Logging out: %@", self )
                    self.observers.notify { $0.userDidLogout( self ) }
                }

                self.tryKeyFactoryMigration()
                oldValue?.invalidate()
            }
        }
    }
    public var defaultType: MPResultType {
        didSet {
            if oldValue != self.defaultType {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }

    public var maskPasswords = false {
        didSet {
            if oldValue != self.maskPasswords, !self.initializing,
               self.file?.mpw_set( self.maskPasswords, path: "user", "_ext_mpw", "maskPasswords" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock, !self.initializing,
               self.file?.mpw_set( self.biometricLock, path: "user", "_ext_mpw", "biometricLock" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }

            self.tryKeyFactoryMigration()
        }
    }
    public var attacker: MPAttacker? {
        didSet {
            if oldValue != self.attacker, !self.initializing,
               self.file?.mpw_set( self.attacker?.description, path: "user", "_ext_mpw", "attacker" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }

    public var file:   UnsafeMutablePointer<MPMarshalledFile>?
    public var origin: URL?

    public var sites = [ MPSite ]() {
        didSet {
            if oldValue != self.sites {
                self.dirty = true
                self.sites.forEach { site in site.observers.register( observer: self ) }
                self.observers.notify { $0.userDidUpdateSites( self ) }
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var  description: String {
        if let identicon = self.identicon.encoded() {
            return "\(self.fullName): \(identicon)"
        }
        else if let masterKeyID = self.masterKeyID {
            return "\(self.fullName): \(masterKeyID)"
        }
        else {
            return "\(self.fullName)"
        }
    }
    private var initializing = true {
        didSet {
            self.dirty = false
        }
    }
    internal var dirty = false {
        didSet {
            if self.dirty {
                if !self.initializing {
                    self.saveTask.request()
                }
            }
            else {
                self.sites.forEach { $0.dirty = false }
            }
        }
    }

    private lazy var saveTask = DispatchTask( queue: .global(), deadline: .now() + .seconds( 1 ), qos: .utility ) {
        guard self.dirty, self.file != nil
        else { return }

        let _ = try? MPMarshal.shared.save( user: self ).then( { result in
            do {
                let destination = try result.get()
                if let origin = self.origin, origin != destination,
                   FileManager.default.fileExists( atPath: origin.path ) {
                    do { try FileManager.default.removeItem( at: origin ) }
                    catch {
                        mperror( title: "Migration issue", message: "Cannot delete obsolete origin document",
                                 details: origin.lastPathComponent, error: error )
                    }
                }
                self.origin = destination
            }
            catch {
                mperror( title: "Couldn't save self", details: self, error: error )
            }

            self.dirty = false
        } ).await()
    }

    // MARK: --- Life ---

    init(algorithm: MPAlgorithmVersion? = nil, avatar: Avatar = .avatar_0, fullName: String,
         identicon: MPIdenticon = MPIdenticonUnset, masterKeyID: String? = nil,
         defaultType: MPResultType? = nil, lastUsed: Date = Date(), origin: URL? = nil,
         file: UnsafeMutablePointer<MPMarshalledFile>? = mpw_marshal_file( nil, nil, nil ),
         initialize: (MPUser) -> Void = { _ in }) {
        self.algorithm = algorithm ?? .current
        self.avatar = avatar
        self.fullName = fullName
        self.identicon = identicon
        self.masterKeyID = masterKeyID
        self.defaultType = defaultType ?? .default
        self.lastUsed = lastUsed
        self.origin = origin
        self.file = file

        defer {
            self.maskPasswords = self.file?.mpw_get( path: "user", "_ext_mpw", "maskPasswords" ) ?? false
            self.biometricLock = self.file?.mpw_get( path: "user", "_ext_mpw", "biometricLock" ) ?? false
            self.attacker = self.file?.mpw_get( path: "user", "_ext_mpw", "attacker" ).flatMap { MPAttacker.named( $0 ) }

            initialize( self )
            self.initializing = false

            self.observers.register( observer: self )
        }
    }

    func login(using keyFactory: MPKeyFactory) -> Promise<MPUser> {
        DispatchQueue.mpw.promise {
            guard let authKey = keyFactory.newKey( for: self.algorithm )
            else { throw MPError.internal( details: "Cannot authenticate user since master key is missing." ) }
            defer { authKey.deallocate() }
            guard let authKeyID = String.valid( mpw_id_buf( authKey, MemoryLayout<MPMasterKey>.size ) )
            else { throw MPError.internal( details: "Could not determine key ID for authentication key." ) }

            if self.masterKeyID == nil {
                self.masterKeyID = authKeyID
            }
            if !mpw_id_buf_equals( self.masterKeyID, authKeyID ) {
                throw MPError.state( details: "Incorrect master key for user." )
            }
        }.then { (result: Result<Void, Error>) -> MPUser in
            switch result {
                case .success:
                    if let keyFactory = keyFactory as? MPPasswordKeyFactory {
                        self.identicon = keyFactory.identicon
                    }

                    self.masterKeyFactory = keyFactory

                case .failure:
                    self.logout()
            }

            return self
        }
    }

    func logout() {
        self.masterKeyFactory = nil
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.fullName )
    }

    static func ==(lhs: MPUser, rhs: MPUser) -> Bool {
        lhs.fullName == rhs.fullName
    }

    // MARK: Comparable

    static func <(lhs: MPUser, rhs: MPUser) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.fullName > rhs.fullName
    }

    // MARK: --- Private ---

    private func tryKeyFactoryMigration() {
        if self.biometricLock {
            // biometric lock is on; if key factory is password, migrate it to keychain.
            (self.masterKeyFactory as? MPPasswordKeyFactory)?.toKeychain().then {
                do { self.masterKeyFactory = try $0.get() }
                catch { mperror( title: "Couldn't migrate to biometrics", error: error ) }
            }
        }
        else if let keychainKeyFactory = self.masterKeyFactory as? MPKeychainKeyFactory {
            // biometric lock is off; if key factory is keychain, remove and purge it.
            self.masterKeyFactory = nil
            keychainKeyFactory.purgeKeys()
        }
    }

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
    }

    func userDidLogin(_ user: MPUser) {
        MPTracker.shared.login( user: self )
    }

    func userDidLogout(_ user: MPUser) {
        MPTracker.shared.logout()
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
    }

    // MARK: --- Interface ---

    public func use() {
        self.lastUsed = Date()
    }

    // MARK: --- Types ---

    enum Avatar: UInt32, CaseIterable, CustomStringConvertible {
        static let userAvatars: [Avatar] = [
            .avatar_0, .avatar_1, .avatar_2, .avatar_3, .avatar_4, .avatar_5, .avatar_6, .avatar_7, .avatar_8, .avatar_9,
            .avatar_10, .avatar_11, .avatar_12, .avatar_13, .avatar_14, .avatar_15, .avatar_16, .avatar_17, .avatar_18 ]

        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18,
             avatar_add

        public var description: String {
            if case .avatar_add = self {
                return "avatar-add"
            }

            return "avatar-\(self.rawValue)"
        }

        public var image: UIImage? {
            UIImage( named: "\(self)" )
        }

        public mutating func next() {
            self = Avatar.userAvatars[((Avatar.userAvatars.firstIndex( of: self ) ?? -1) + 1) % Avatar.userAvatars.count]
        }
    }
}

protocol MPUserObserver {
    func userDidLogin(_ user: MPUser)
    func userDidLogout(_ user: MPUser)

    func userDidChange(_ user: MPUser)
    func userDidUpdateSites(_ user: MPUser)
}

extension MPUserObserver {
    func userDidLogin(_ user: MPUser) {
    }

    func userDidLogout(_ user: MPUser) {
    }

    func userDidChange(_ user: MPUser) {
    }

    func userDidUpdateSites(_ user: MPUser) {
    }
}
