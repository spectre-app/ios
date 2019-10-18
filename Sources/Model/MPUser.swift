//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPUser: Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPUserObserver, MPSiteObserver {
    // TODO: figure out how to batch updates or suspend changes until sites marshalling/authenticate fully complete.
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
            if oldValue != self.masterKeyID {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
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
            if oldValue != self.maskPasswords,
               self.file.mpw_set( self.maskPasswords, path: "user", "_ext_mpw", "maskPasswords" ) {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock,
               self.file.mpw_set( self.biometricLock, path: "user", "_ext_mpw", "biometricLock" ) {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }

            if self.biometricLock {
                if let passwordKeyFactory = self.masterKeyFactory as? MPPasswordKeyFactory {
                    passwordKeyFactory.toKeychain().then { self.masterKeyFactory = $0 ?? passwordKeyFactory }
                }
            }
            else {
                for algorithm in MPAlgorithmVersion.allCases {
                    MPKeychain.deleteKey( for: self.fullName, algorithm: algorithm )
                }
                if self.masterKeyFactory is MPKeychainKeyFactory {
                    self.masterKeyFactory = nil
                }
            }
        }
    }
    public var file:   UnsafeMutablePointer<MPMarshalledFile>
    public var origin: URL?

    public var masterKeyFactory: MPKeyFactory? {
        didSet {
            // TODO: self.identicon = mpw_identicon( self.fullName, masterPassword )
            DispatchQueue.mpw.promise {
                if ({
                        guard let masterKeyFactory = self.masterKeyFactory,
                              let authKey = masterKeyFactory.newMasterKey( algorithm: self.algorithm )
                        else { return false }
                        defer { authKey.deallocate() }
                        guard let authKeyID = String( safeUTF8: mpw_id_buf( authKey, MPMasterKeySize ) )
                        else { return false }

                        if self.masterKeyID == nil {
                            self.masterKeyID = authKeyID
                        }
                        if self.masterKeyID != authKeyID {
                            return false
                        }

                        return true
                    }()) {
                    self.observers.notify { $0.userDidLogin( self ) }
                }
                else {
                    self.observers.notify { $0.userDidLogout( self ) }
                }
            }
        }
    }
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
    var description: String {
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
    var initializing = true {
        didSet {
            self.dirty = false
        }
    }
    var dirty        = false {
        didSet {
            if !self.initializing {
                MPMarshal.shared.setNeedsSave( user: self )
            }
        }
    }

    // MARK: --- Life ---

    init(algorithm: MPAlgorithmVersion? = nil, avatar: Avatar = .avatar_0, fullName: String,
         identicon: MPIdenticon = MPIdenticonUnset, masterKeyID: String? = nil, masterKeyFactory: MPKeyFactory,
         defaultType: MPResultType? = nil, lastUsed: Date = Date(), origin: URL? = nil,
         file: UnsafeMutablePointer<MPMarshalledFile> = mpw_marshal_file( nil, nil, nil ),
         initialize: (MPUser) -> () = { _ in }) {
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
            self.masterKeyFactory = masterKeyFactory
            self.maskPasswords = self.file.mpw_get( path: "user", "_ext_mpw", "maskPasswords" ) ?? false
            self.biometricLock = self.file.mpw_get( path: "user", "_ext_mpw", "biometricLock" ) ?? false

            initialize( self )
            self.initializing = false

            self.observers.register( observer: self )
        }
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

    // MARK: --- MPUserObserver ---

    func userDidChange(_ user: MPUser) {
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
    }

    // MARK: --- Interface ---

    public func use() {
        self.lastUsed = Date()
    }

    // MARK: --- Types ---

    enum Avatar: Int, CaseIterable {
        static let userAvatars: [Avatar] = [
            .avatar_0, .avatar_1, .avatar_2, .avatar_3, .avatar_4, .avatar_5, .avatar_6, .avatar_7, .avatar_8, .avatar_9,
            .avatar_10, .avatar_11, .avatar_12, .avatar_13, .avatar_14, .avatar_15, .avatar_16, .avatar_17, .avatar_18 ]

        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18,
             avatar_add

        public static func decode(avatar: UInt32) -> Avatar {
            Avatar.userAvatars.indices.contains( Int( avatar ) ) ? Avatar.userAvatars[Int( avatar )]: .avatar_0
        }

        public func encode() -> UInt32 {
            UInt32( Avatar.userAvatars.firstIndex( of: self ) ?? 0 )
        }

        public func image() -> UIImage? {
            switch self {
                case .avatar_add:
                    return UIImage.init( named: "avatar-add" )
                default:
                    return UIImage.init( named: "avatar-\(self.rawValue)" )
            }
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
